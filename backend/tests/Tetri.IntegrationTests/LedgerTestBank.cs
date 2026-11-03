using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Npgsql;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Idempotency;
using Tetri.Infrastructure.Ledger;

namespace Tetri.IntegrationTests;

internal sealed class LedgerTestBank(string connectionString) : IAsyncDisposable
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public static readonly AuditContext Audit = new("127.0.0.1", "Tetri.IntegrationTests");
    public NpgsqlDataSource DataSource { get; } = NpgsqlDataSource.Create(connectionString);
    public LedgerService Ledger => new(DataSource);

    public IdempotencyService CreateIdempotency(IIdempotencyTestHooks? hooks = null) =>
        new(DataSource, hooks ?? new NoOpIdempotencyTestHooks(), TimeProvider.System);

    public async Task<TestUser> CreateIdentityAsync()
    {
        await using var connection = await DataSource.OpenConnectionAsync();
        return await InsertIdentityAsync(connection, null);
    }

    public async Task<TestUser> CreateUserAsync(long gelBalance = 100_000)
    {
        await using var connection = await DataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var user = await InsertIdentityAsync(connection, transaction);
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO accounts (id, owner_user_id, kind, currency, balance, version)
            VALUES (@gel, @user, 'user', 'GEL', 0, 0),
                   (@usd, @user, 'user', 'USD', 0, 0),
                   (@eur, @user, 'user', 'EUR', 0, 0);
            """, connection, transaction);
        command.Parameters.AddWithValue("user", user.Id);
        command.Parameters.AddWithValue("gel", Guid.CreateVersion7());
        command.Parameters.AddWithValue("usd", Guid.CreateVersion7());
        command.Parameters.AddWithValue("eur", Guid.CreateVersion7());
        await command.ExecuteNonQueryAsync();
        if (gelBalance > 0)
        {
            await TopUpAsync(connection, transaction, user.Id, gelBalance);
        }

        await transaction.CommitAsync();
        return user;
    }

    public async Task TopUpAsync(Guid userId, long amount)
    {
        await using var connection = await DataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await TopUpAsync(connection, transaction, userId, amount);
        await transaction.CommitAsync();
    }

    public Task<long> BalanceAsync(Guid userId, string currency = "GEL") => ScalarAsync<long>(
        "SELECT balance FROM accounts WHERE owner_user_id = @user AND currency = @currency;",
        ("user", userId), ("currency", currency));

    public Task<long> TransferCountAsync(Guid userId) => ScalarAsync<long>(
        "SELECT COUNT(*) FROM journal_transactions WHERE initiated_by_user_id = @user AND kind = 'transfer';",
        ("user", userId));

    public Task<long> TransferEntryCountAsync(Guid userId) => ScalarAsync<long>(
        """
        SELECT COUNT(*) FROM entries AS e
        JOIN journal_transactions AS j ON j.id = e.transaction_id
        WHERE j.initiated_by_user_id = @user AND j.kind = 'transfer';
        """, ("user", userId));

    public Task<int> ExpireClaimAsync(Guid userId, string key) => ExecuteSqlAsync(
        "UPDATE idempotency_keys SET locked_until = now() - interval '1 minute' WHERE user_id = @user AND key = @key;",
        ("user", userId), ("key", key));

    public async Task<TransferReceipt> TransferAsync(Guid senderId, TransferRequest request)
    {
        await using var connection = await DataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted);
        var receipt = await Ledger.TransferAsync(connection, transaction, senderId, request, Audit, CancellationToken.None);
        await transaction.CommitAsync();
        return receipt;
    }

    public Task<StoredResponse> PostAsync(
        Guid senderId, string key, TransferRequest request,
        IdempotencyService? idempotency = null, string endpoint = "/api/v1/transfers") =>
        (idempotency ?? CreateIdempotency()).ExecuteAsync(
            senderId, key, endpoint, RequestHash(request),
            async (connection, transaction, cancellationToken) =>
            {
                var receipt = await Ledger.TransferAsync(
                    connection, transaction, senderId, request, Audit, cancellationToken);
                return new StoredResponse(201, JsonSerializer.Serialize(receipt, Json));
            }, CancellationToken.None);

    public static string RequestHash(TransferRequest request) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(request, Json))))
            .ToLowerInvariant();

    public async Task<T> ScalarAsync<T>(string sql, params (string Name, object Value)[] parameters)
    {
        await using var connection = await DataSource.OpenConnectionAsync();
        await using var command = CreateCommand(sql, connection, parameters);
        return (T)(await command.ExecuteScalarAsync() ?? throw new InvalidOperationException("Expected a scalar result."));
    }

    public async Task<int> ExecuteSqlAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var connection = await DataSource.OpenConnectionAsync();
        await using var command = CreateCommand(sql, connection, parameters);
        return await command.ExecuteNonQueryAsync();
    }

    public ValueTask DisposeAsync() => DataSource.DisposeAsync();

    private static NpgsqlCommand CreateCommand(
        string sql, NpgsqlConnection connection, (string Name, object Value)[] parameters)
    {
        var command = new NpgsqlCommand(sql, connection);
        foreach (var (name, value) in parameters)
        {
            command.Parameters.AddWithValue(name, value);
        }

        return command;
    }

    private static async Task<TestUser> InsertIdentityAsync(NpgsqlConnection connection, NpgsqlTransaction? transaction)
    {
        var id = Guid.CreateVersion7();
        var handle = "@u" + id.ToString("N")[16..];
        const string displayName = "Ledger Test";
        var email = $"{id:N}@example.test";
        var user = new TestUser(id, handle, displayName, email);
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO users (id, email, display_name, handle, password_hash)
            VALUES (@id, @email, @name, @handle, @password_hash);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("email", email);
        command.Parameters.AddWithValue("name", displayName);
        command.Parameters.AddWithValue("handle", handle);
        command.Parameters.AddWithValue("password_hash", new PasswordHasher<TestUser>().HashPassword(user, TestCredentials.Password));
        await command.ExecuteNonQueryAsync();
        return user;
    }

    private static async Task TopUpAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, long amount)
    {
        // Fixture funding follows the same conservation rule as production grants.
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO journal_transactions (id, kind, status, initiated_by_user_id, description)
            VALUES (@journal, 'starter_grant', 'posted', @user, 'Balanced test fixture funding');
            INSERT INTO entries (id, transaction_id, account_id, amount, currency)
            SELECT @credit, @journal, id, @amount, 'GEL'
            FROM accounts WHERE owner_user_id = @user AND currency = 'GEL';
            INSERT INTO entries (id, transaction_id, account_id, amount, currency)
            SELECT @debit, @journal, id, -@amount, 'GEL'
            FROM accounts WHERE kind = 'funding' AND currency = 'GEL';
            UPDATE accounts SET balance = balance + @amount, version = version + 1
            WHERE owner_user_id = @user AND currency = 'GEL';
            UPDATE accounts SET balance = balance - @amount, version = version + 1
            WHERE kind = 'funding' AND currency = 'GEL';
            """, connection, transaction);
        command.Parameters.AddWithValue("journal", Guid.CreateVersion7());
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("credit", Guid.CreateVersion7());
        command.Parameters.AddWithValue("debit", Guid.CreateVersion7());
        command.Parameters.AddWithValue("amount", amount);
        await command.ExecuteNonQueryAsync();
    }
}

internal sealed record TestUser(Guid Id, string Handle, string DisplayName, string Email);
