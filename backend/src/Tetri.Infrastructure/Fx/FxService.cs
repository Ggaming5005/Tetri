using System.Text.Json;
using Microsoft.Extensions.Options;
using Npgsql;
using NpgsqlTypes;
using Tetri.Core.Entities;
using Tetri.Core.Fx;
using Tetri.Core.Ledger;

namespace Tetri.Infrastructure.Fx;

public sealed class FxService(
    NpgsqlDataSource dataSource, FxRateService rates, IOptions<FxOptions> options, TimeProvider timeProvider)
{
    public async Task<FxQuoteResponse> CreateQuoteAsync(Guid userId, FxQuoteRequest request, CancellationToken ct)
    {
        ValidateQuoteRequest(request);
        var current = await rates.GetCurrentAsync(ct);
        var from = current.Single(rate => rate.Currency == request.Amount.Currency);
        var to = current.Single(rate => rate.Currency == request.ToCurrency);
        decimal rate;
        try
        {
            rate = from.RateToGel / to.RateToGel;
        }
        catch (OverflowException)
        {
            throw new DomainException("rates_unavailable", "Exchange rates are unavailable. Try again later.", 503);
        }

        var calculation = FxMath.Calculate(request.Amount.Minor, rate, options.Value.Spread);
        // A cross rate is only as fresh as its older contributing rate; GEL itself has no dated feed.
        var rateDate = request.Amount.Currency == "GEL" ? to.RateDate
            : request.ToCurrency == "GEL" ? from.RateDate
            : from.RateDate < to.RateDate ? from.RateDate : to.RateDate;
        var now = UtcNow();
        var quoteId = Guid.CreateVersion7();
        var expiresAt = now.AddSeconds(60);
        await using var command = dataSource.CreateCommand(
            """
            INSERT INTO fx_quotes
                (id, user_id, from_currency, to_currency, amount_in, gross_out, net_out, fee, rate, rate_date, expires_at, created_at)
            VALUES (@id, @user, @from, @to, @amount, @gross, @net, @fee, @rate, @date, @expires, @created);
            """);
        command.Parameters.AddWithValue("id", quoteId);
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("from", request.Amount.Currency);
        command.Parameters.AddWithValue("to", request.ToCurrency);
        command.Parameters.AddWithValue("amount", request.Amount.Minor);
        command.Parameters.AddWithValue("gross", calculation.GrossOut);
        command.Parameters.AddWithValue("net", calculation.NetOut);
        command.Parameters.AddWithValue("fee", calculation.Fee);
        command.Parameters.AddWithValue("rate", rate);
        command.Parameters.AddWithValue("date", rateDate);
        command.Parameters.AddWithValue("expires", expiresAt);
        command.Parameters.AddWithValue("created", now);
        await command.ExecuteNonQueryAsync(ct);
        return new FxQuoteResponse(quoteId, request.Amount, new MoneyAmount(calculation.NetOut, request.ToCurrency),
            new MoneyAmount(calculation.Fee, request.ToCurrency), rate, rateDate, expiresAt);
    }

    public async Task<ConversionReceipt> ConvertAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, Guid quoteId,
        AuditContext audit, CancellationToken ct)
    {
        var quote = await LockQuoteAsync(connection, transaction, userId, quoteId, ct);
        var accounts = await LockAccountsAsync(connection, transaction, userId, quote, ct);
        var now = UtcNow();
        if (quote.UsedAt is not null)
            throw new DomainException("quote_used", "This quote has already been used. Request a new quote.", 409);
        if (quote.ExpiresAt <= now)
            throw new DomainException("quote_expired", "This quote has expired. Review a new quote to continue.", 409);

        var from = Account(accounts, "user", quote.FromCurrency);
        var to = Account(accounts, "user", quote.ToCurrency);
        var poolFrom = Account(accounts, "fx_pool", quote.FromCurrency);
        var poolTo = Account(accounts, "fx_pool", quote.ToCurrency);
        var fees = Account(accounts, "fees", quote.ToCurrency);
        if (from.Balance < quote.AmountIn)
            throw new DomainException("insufficient_funds", $"Not enough money in your {quote.FromCurrency} account. Try a smaller amount.");

        var movements = new List<Movement>
        {
            new(from, checked(-quote.AmountIn)), new(poolFrom, quote.AmountIn),
            new(poolTo, checked(-quote.GrossOut)), new(to, quote.NetOut)
        };
        if (quote.Fee != 0)
            movements.Add(new Movement(fees, quote.Fee));

        // Calculate every resulting balance before inserting anything, including limits on system accounts.
        var balances = movements.Select(movement => (Movement: movement,
            Balance: AddBalance(movement.Account.Balance, movement.Amount),
            Version: checked(movement.Account.Version + 1))).ToArray();
        var transactionId = Guid.CreateVersion7();
        await WriteJournalAsync(connection, transaction, transactionId, userId, quote, now, ct);
        foreach (var (movement, balance, version) in balances)
            await WriteMovementAsync(connection, transaction, transactionId, movement, balance, version, now, ct);
        await WriteAuditAsync(connection, transaction, transactionId, userId, quote, audit, now, ct);
        await using var markUsed = new NpgsqlCommand(
            "UPDATE fx_quotes SET used_at = @now WHERE id = @id AND used_at IS NULL;", connection, transaction);
        markUsed.Parameters.AddWithValue("now", now);
        markUsed.Parameters.AddWithValue("id", quote.Id);
        if (await markUsed.ExecuteNonQueryAsync(ct) != 1)
            throw new InvalidOperationException("The locked FX quote was not marked used.");

        return new ConversionReceipt(transactionId, quote.Id, new MoneyAmount(quote.AmountIn, quote.FromCurrency),
            new MoneyAmount(quote.NetOut, quote.ToCurrency), new MoneyAmount(quote.Fee, quote.ToCurrency),
            quote.Rate, quote.RateDate, now);
    }

    public static void ValidateQuoteRequest(FxQuoteRequest? request)
    {
        if (request?.Amount is null)
            throw new DomainException("invalid_request", "Choose an amount and two currencies.", 400);
        if (request.Amount.Minor <= 0)
            throw new DomainException("invalid_amount", "Enter an amount greater than zero.", 400);
        if (!MoneyFormatting.IsSupportedCurrency(request.Amount.Currency) || !MoneyFormatting.IsSupportedCurrency(request.ToCurrency))
            throw new DomainException("unsupported_currency", "Choose GEL, USD or EUR.", 400);
        if (request.Amount.Currency == request.ToCurrency)
            throw new DomainException("same_currency", "Choose a different currency to convert to.", 400);
    }

    private static async Task<FxQuote> LockQuoteAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, Guid quoteId, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT from_currency, to_currency, amount_in, gross_out, net_out, fee, rate, rate_date, expires_at, used_at
            FROM fx_quotes WHERE id = @id AND user_id = @user FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("id", quoteId);
        command.Parameters.AddWithValue("user", userId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
            throw new DomainException("quote_not_found", "Request a new quote and try again.", 404);
        return new FxQuote
        {
            Id = quoteId,
            UserId = userId,
            FromCurrency = reader.GetString(0),
            ToCurrency = reader.GetString(1),
            AmountIn = reader.GetInt64(2),
            GrossOut = reader.GetInt64(3),
            NetOut = reader.GetInt64(4),
            Fee = reader.GetInt64(5),
            Rate = reader.GetDecimal(6),
            RateDate = reader.GetFieldValue<DateOnly>(7),
            ExpiresAt = reader.GetDateTime(8),
            UsedAt = reader.IsDBNull(9) ? null : reader.GetDateTime(9)
        };
    }

    private static async Task<List<LockedAccount>> LockAccountsAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, FxQuote quote, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT id, kind, currency, balance, version FROM accounts
            WHERE (kind = 'user' AND owner_user_id = @user AND currency IN (@from, @to))
               OR (kind = 'fx_pool' AND currency IN (@from, @to))
               OR (kind = 'fees' AND currency = @to)
            ORDER BY id FOR UPDATE;
            """, connection, transaction);
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("from", quote.FromCurrency);
        command.Parameters.AddWithValue("to", quote.ToCurrency);
        await using var reader = await command.ExecuteReaderAsync(ct);
        var accounts = new List<LockedAccount>();
        while (await reader.ReadAsync(ct))
            accounts.Add(new LockedAccount(reader.GetGuid(0), reader.GetString(1), reader.GetString(2),
                reader.GetInt64(3), reader.GetInt64(4)));
        return accounts;
    }

    private static LockedAccount Account(List<LockedAccount> accounts, string kind, string currency) =>
        accounts.SingleOrDefault(account => account.Kind == kind && account.Currency == currency)
        ?? throw new DomainException("account_not_found", "Choose an available account and try again.", 404);

    private static async Task WriteJournalAsync(NpgsqlConnection connection, NpgsqlTransaction transaction,
        Guid transactionId, Guid userId, FxQuote quote, DateTime now, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO journal_transactions (id, kind, status, initiated_by_user_id, description, fx_rate, quote_id, created_at)
            VALUES (@id, 'conversion', 'posted', @user, @description, @rate, @quote, @now);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", transactionId);
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("description", $"Converted {quote.FromCurrency} to {quote.ToCurrency}");
        command.Parameters.AddWithValue("rate", quote.Rate);
        command.Parameters.AddWithValue("quote", quote.Id);
        command.Parameters.AddWithValue("now", now);
        await command.ExecuteNonQueryAsync(ct);
    }

    private static async Task WriteMovementAsync(NpgsqlConnection connection, NpgsqlTransaction transaction,
        Guid transactionId, Movement movement, long balance, long version, DateTime now, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO entries (id, transaction_id, account_id, amount, currency, created_at)
            VALUES (@entry, @journal, @account, @amount, @currency, @now);
            UPDATE accounts SET balance = @balance, version = @version WHERE id = @account;
            """, connection, transaction);
        command.Parameters.AddWithValue("entry", Guid.CreateVersion7());
        command.Parameters.AddWithValue("journal", transactionId);
        command.Parameters.AddWithValue("account", movement.Account.Id);
        command.Parameters.AddWithValue("amount", movement.Amount);
        command.Parameters.AddWithValue("currency", movement.Account.Currency);
        command.Parameters.AddWithValue("now", now);
        command.Parameters.AddWithValue("balance", balance);
        command.Parameters.AddWithValue("version", version);
        if (await command.ExecuteNonQueryAsync(ct) != 2)
            throw new InvalidOperationException("A locked conversion account was not updated.");
    }

    private static async Task WriteAuditAsync(NpgsqlConnection connection, NpgsqlTransaction transaction,
        Guid transactionId, Guid userId, FxQuote quote, AuditContext audit, DateTime now, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO audit_log (id, user_id, action, target_type, target_id, ip, user_agent, details, created_at)
            VALUES (@id, @user, 'conversion', 'journal_transaction', @target, @ip, @agent, @details, @now);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", Guid.CreateVersion7());
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("target", transactionId);
        command.Parameters.AddWithValue("ip", NpgsqlDbType.Text, (object?)audit.Ip ?? DBNull.Value);
        command.Parameters.AddWithValue("agent", NpgsqlDbType.Text, (object?)audit.UserAgent ?? DBNull.Value);
        command.Parameters.AddWithValue("details", NpgsqlDbType.Jsonb, JsonSerializer.Serialize(new
        {
            quoteId = quote.Id,
            amountIn = quote.AmountIn,
            grossOut = quote.GrossOut,
            netOut = quote.NetOut,
            fee = quote.Fee,
            fromCurrency = quote.FromCurrency,
            toCurrency = quote.ToCurrency,
            rate = quote.Rate
        }));
        command.Parameters.AddWithValue("now", now);
        await command.ExecuteNonQueryAsync(ct);
    }

    private static long AddBalance(long balance, long amount)
    {
        try { return checked(balance + amount); }
        catch (OverflowException)
        {
            throw new DomainException("balance_limit_exceeded", "This account cannot accept that amount. Try a smaller amount.");
        }
    }

    private DateTime UtcNow()
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        return new DateTime(now.Ticks - now.Ticks % 10, DateTimeKind.Utc);
    }

    private sealed record LockedAccount(Guid Id, string Kind, string Currency, long Balance, long Version);
    private sealed record Movement(LockedAccount Account, long Amount);
}
