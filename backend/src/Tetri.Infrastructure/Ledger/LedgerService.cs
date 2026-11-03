using System.Data;
using System.Text.Json;
using Npgsql;
using NpgsqlTypes;
using Tetri.Core.Ledger;

namespace Tetri.Infrastructure.Ledger;

public sealed class LedgerService(NpgsqlDataSource dataSource)
{
    private static readonly (string Currency, long Minor)[] StarterGrants =
        [("GEL", 100_000), ("USD", 30_000), ("EUR", 30_000)];

    public async Task<TransferReceipt> TransferAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid senderUserId,
        TransferRequest request,
        AuditContext audit,
        CancellationToken ct)
    {
        ValidateAmount(request.Amount);
        var recipient = await FindRecipientAsync(connection, transaction, request.RecipientHandle, ct);
        if (recipient.Id == senderUserId)
        {
            throw new DomainException("self_transfer", "Choose someone else to send money to.");
        }

        var accounts = await LockTransferAccountsAsync(
            connection, transaction, senderUserId, recipient.Id, request.Amount.Currency, ct);
        var sender = accounts.SingleOrDefault(x => x.OwnerUserId == senderUserId)
            ?? throw new DomainException("account_not_found", "Choose an available account and try again.", 404);
        var receiver = accounts.SingleOrDefault(x => x.OwnerUserId == recipient.Id)
            ?? throw new DomainException("recipient_not_found", "Choose another recipient and try again.", 404);

        if (sender.Balance < request.Amount.Minor)
        {
            throw new DomainException("insufficient_funds", $"Not enough money in your {request.Amount.Currency} account. Try a smaller amount.");
        }

        var senderBalance = checked(sender.Balance - request.Amount.Minor);
        var receiverBalance = AddBalance(receiver.Balance, request.Amount.Minor);
        var senderVersion = checked(sender.Version + 1);
        var receiverVersion = checked(receiver.Version + 1);
        var transactionId = Guid.CreateVersion7();
        var createdAt = UtcNowMicroseconds();
        var description = string.IsNullOrWhiteSpace(request.Description)
            ? $"Transfer to {recipient.Handle}"
            : request.Description;

        await WriteMovementAsync(connection, transaction, transactionId, "transfer", senderUserId,
            description, sender.Id, receiver.Id, request.Amount, createdAt, ct);
        await UpdateAccountAsync(connection, transaction, sender.Id, senderBalance, senderVersion, ct);
        await UpdateAccountAsync(connection, transaction, receiver.Id, receiverBalance, receiverVersion, ct);
        await WriteTransferAuditAsync(connection, transaction, senderUserId, recipient.Id,
            transactionId, request.Amount, audit, createdAt, ct);

        return new TransferReceipt(transactionId, request.Amount, recipient.Handle, recipient.DisplayName, createdAt);
    }

    public async Task GrantStarterBalancesAsync(Guid userId, CancellationToken ct)
    {
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        await GrantStarterBalancesAsync(connection, transaction, userId, ct);
        await transaction.CommitAsync(ct);
    }

    public async Task GrantStarterBalancesAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, CancellationToken ct)
    {
        var createdAt = UtcNowMicroseconds();
        foreach (var (currency, _) in StarterGrants)
        {
            await using var command = new NpgsqlCommand(
                """
                INSERT INTO accounts (id, owner_user_id, kind, currency, balance, version, created_at)
                VALUES (@id, @user, 'user', @currency, 0, 0, @created_at);
                """, connection, transaction);
            command.Parameters.AddWithValue("id", Guid.CreateVersion7());
            command.Parameters.AddWithValue("user", userId);
            command.Parameters.AddWithValue("currency", currency);
            command.Parameters.AddWithValue("created_at", createdAt);
            await command.ExecuteNonQueryAsync(ct);
        }

        var accounts = await LockStarterAccountsAsync(connection, transaction, userId, ct);
        foreach (var (currency, minor) in StarterGrants)
        {
            var funding = accounts.Single(x => x.Kind == "funding" && x.Currency == currency);
            var user = accounts.Single(x => x.OwnerUserId == userId && x.Currency == currency);
            var fundingBalance = AddBalance(funding.Balance, -minor);
            var userBalance = AddBalance(user.Balance, minor);
            var fundingVersion = checked(funding.Version + 1);
            var userVersion = checked(user.Version + 1);

            await WriteMovementAsync(connection, transaction, Guid.CreateVersion7(), "starter_grant",
                userId, $"Sandbox starter balance in {currency}", funding.Id, user.Id,
                new MoneyAmount(minor, currency), createdAt, ct);
            await UpdateAccountAsync(connection, transaction, funding.Id, fundingBalance, fundingVersion, ct);
            await UpdateAccountAsync(connection, transaction, user.Id, userBalance, userVersion, ct);
        }
    }

    public async Task<IReadOnlyList<LedgerViolation>> ReconcileAsync(CancellationToken ct)
    {
        await using var command = dataSource.CreateCommand(
            """
            SELECT 'unbalanced_journal' AS code, COUNT(*) AS total
            FROM (
                SELECT transaction_id, currency FROM entries
                GROUP BY transaction_id, currency HAVING SUM(amount) <> 0
            ) AS invalid_journals
            UNION ALL
            SELECT 'cached_balance_mismatch', COUNT(*)
            FROM accounts AS a
            LEFT JOIN (SELECT account_id, SUM(amount) AS balance FROM entries GROUP BY account_id) AS e
                ON e.account_id = a.id
            WHERE a.balance <> COALESCE(e.balance, 0)
            UNION ALL
            SELECT 'entry_currency_mismatch', COUNT(*)
            FROM entries AS e JOIN accounts AS a ON a.id = e.account_id
            WHERE e.currency <> a.currency
            UNION ALL
            SELECT 'negative_user_balance', COUNT(*) FROM accounts WHERE kind = 'user' AND balance < 0;
            """);
        await using var reader = await command.ExecuteReaderAsync(ct);
        var violations = new List<LedgerViolation>();
        while (await reader.ReadAsync(ct))
        {
            var count = reader.GetInt64(1);
            if (count > 0)
            {
                violations.Add(new LedgerViolation(reader.GetString(0), count));
            }
        }

        return violations;
    }

    private static void ValidateAmount(MoneyAmount amount)
    {
        if (amount.Minor <= 0)
        {
            throw new DomainException("invalid_amount", "Enter an amount greater than zero.", 400);
        }

        if (!MoneyFormatting.IsSupportedCurrency(amount.Currency))
        {
            throw new DomainException("unsupported_currency", "Choose GEL, USD or EUR.", 400);
        }
    }

    private static async Task<Recipient> FindRecipientAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, string handle, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            "SELECT id, handle, display_name FROM users WHERE handle = @handle;", connection, transaction);
        command.Parameters.AddWithValue("handle", handle.Trim());
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
        {
            throw new DomainException("recipient_not_found", "Check the handle and try again.", 404);
        }

        return new Recipient(reader.GetGuid(0), reader.GetString(1), reader.GetString(2));
    }

    private static async Task<List<LockedAccount>> LockTransferAccountsAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid sender, Guid recipient,
        string currency, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT id, owner_user_id, kind, currency, balance, version
            FROM accounts
            WHERE kind = 'user' AND currency = @currency AND owner_user_id IN (@sender, @recipient)
            ORDER BY id FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("currency", currency);
        command.Parameters.AddWithValue("sender", sender);
        command.Parameters.AddWithValue("recipient", recipient);
        return await ReadLockedAccountsAsync(command, ct);
    }

    private static async Task<List<LockedAccount>> LockStarterAccountsAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT id, owner_user_id, kind, currency, balance, version
            FROM accounts WHERE kind = 'funding' OR owner_user_id = @user
            ORDER BY id FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("user", userId);
        return await ReadLockedAccountsAsync(command, ct);
    }

    private static async Task<List<LockedAccount>> ReadLockedAccountsAsync(NpgsqlCommand command, CancellationToken ct)
    {
        await using var reader = await command.ExecuteReaderAsync(ct);
        var accounts = new List<LockedAccount>();
        while (await reader.ReadAsync(ct))
        {
            accounts.Add(new LockedAccount(reader.GetGuid(0), reader.IsDBNull(1) ? null : reader.GetGuid(1),
                reader.GetString(2), reader.GetString(3), reader.GetInt64(4), reader.GetInt64(5)));
        }

        return accounts;
    }

    private static async Task WriteMovementAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid id, string kind, Guid userId,
        string description, Guid debitAccountId, Guid creditAccountId, MoneyAmount amount,
        DateTime createdAt, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO journal_transactions (id, kind, status, initiated_by_user_id, description, created_at)
            VALUES (@id, @kind, 'posted', @user, @description, @created_at);
            INSERT INTO entries (id, transaction_id, account_id, amount, currency, created_at)
            VALUES (@debit_id, @id, @debit_account, @debit_amount, @currency, @created_at),
                   (@credit_id, @id, @credit_account, @credit_amount, @currency, @created_at);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("kind", kind);
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("created_at", createdAt);
        command.Parameters.AddWithValue("debit_id", Guid.CreateVersion7());
        command.Parameters.AddWithValue("credit_id", Guid.CreateVersion7());
        command.Parameters.AddWithValue("debit_account", debitAccountId);
        command.Parameters.AddWithValue("credit_account", creditAccountId);
        command.Parameters.AddWithValue("debit_amount", checked(-amount.Minor));
        command.Parameters.AddWithValue("credit_amount", amount.Minor);
        command.Parameters.AddWithValue("currency", amount.Currency);
        await command.ExecuteNonQueryAsync(ct);
    }

    private static async Task UpdateAccountAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid accountId, long balance,
        long version, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            "UPDATE accounts SET balance = @balance, version = @version WHERE id = @id;", connection, transaction);
        command.Parameters.AddWithValue("id", accountId);
        command.Parameters.AddWithValue("balance", balance);
        command.Parameters.AddWithValue("version", version);
        if (await command.ExecuteNonQueryAsync(ct) != 1)
        {
            throw new InvalidOperationException("A locked ledger account was not updated.");
        }
    }

    private static async Task WriteTransferAuditAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid sender, Guid recipient,
        Guid transactionId, MoneyAmount amount, AuditContext audit, DateTime createdAt, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO audit_log (id, user_id, action, target_type, target_id, ip, user_agent, details, created_at)
            VALUES (@id, @user, 'transfer', 'journal_transaction', @target, @ip, @user_agent, @details, @created_at);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", Guid.CreateVersion7());
        command.Parameters.AddWithValue("user", sender);
        command.Parameters.AddWithValue("target", transactionId);
        command.Parameters.AddWithValue("ip", NpgsqlDbType.Text, (object?)audit.Ip ?? DBNull.Value);
        command.Parameters.AddWithValue("user_agent", NpgsqlDbType.Text, (object?)audit.UserAgent ?? DBNull.Value);
        command.Parameters.AddWithValue("details", NpgsqlDbType.Jsonb,
            JsonSerializer.Serialize(new { recipientUserId = recipient, minor = amount.Minor, currency = amount.Currency }));
        command.Parameters.AddWithValue("created_at", createdAt);
        await command.ExecuteNonQueryAsync(ct);
    }

    private static long AddBalance(long balance, long amount)
    {
        try
        {
            return checked(balance + amount);
        }
        catch (OverflowException)
        {
            throw new DomainException("balance_limit_exceeded", "This account cannot accept that amount. Try a smaller amount.");
        }
    }

    private static DateTime UtcNowMicroseconds()
    {
        var now = DateTime.UtcNow;
        return new DateTime(now.Ticks - now.Ticks % 10, DateTimeKind.Utc);
    }

    private sealed record Recipient(Guid Id, string Handle, string DisplayName);
    private sealed record LockedAccount(Guid Id, Guid? OwnerUserId, string Kind, string Currency, long Balance, long Version);
}
