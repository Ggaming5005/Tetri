using System.Net;
using System.Text.Json;
using FluentAssertions;
using Microsoft.Extensions.Options;
using Npgsql;
using Tetri.Core.Fx;
using Tetri.Core.Idempotency;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Fx;
using Tetri.Infrastructure.Idempotency;

namespace Tetri.IntegrationTests;

public sealed class FxServiceTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Conversion_writes_exact_quote_legs_audit_and_fee_even_after_rates_change()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var quote = await fx.CreateQuoteAsync(user.Id, new(new(1000, "USD"), "GEL"), default);
        quote.NetOut.Should().Be(new MoneyAmount(2487, "GEL"));
        quote.Fee.Should().Be(new MoneyAmount(13, "GEL"));
        var feesBefore = await bank.ScalarAsync<long>("SELECT balance FROM accounts WHERE kind = 'fees' AND currency = 'GEL';");
        await bank.ExecuteSqlAsync("UPDATE fx_rates SET rate_to_gel = 99;");

        var response = await ConvertAsync(bank, fx, user.Id, quote.QuoteId);
        response.StatusCode.Should().Be(201);
        var receipt = JsonSerializer.Deserialize<ConversionReceipt>(response.Body, LedgerTestBank.Json)!;
        receipt.Rate.Should().Be(quote.Rate);
        receipt.NetOut.Should().Be(quote.NetOut);
        receipt.Fee.Should().Be(quote.Fee);
        (await bank.BalanceAsync(user.Id, "USD")).Should().Be(29_000);
        (await bank.BalanceAsync(user.Id, "GEL")).Should().Be(102_487);
        (await bank.ScalarAsync<long>("SELECT balance FROM accounts WHERE kind = 'fees' AND currency = 'GEL';"))
            .Should().Be(feesBefore + 13);

        await using var connection = await bank.DataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            """
            SELECT a.kind, e.currency, e.amount FROM entries e JOIN accounts a ON a.id = e.account_id
            WHERE transaction_id = @id ORDER BY a.kind, e.currency;
            """, connection);
        command.Parameters.AddWithValue("id", receipt.TransactionId);
        await using (var reader = await command.ExecuteReaderAsync())
        {
            var legs = new List<(string Kind, string Currency, long Amount)>();
            while (await reader.ReadAsync())
                legs.Add((reader.GetString(0), reader.GetString(1), reader.GetInt64(2)));
            legs.Should().BeEquivalentTo(new[]
            {
                ("user", "USD", -1000L), ("fx_pool", "USD", 1000L),
                ("fx_pool", "GEL", -2500L), ("user", "GEL", 2487L), ("fees", "GEL", 13L)
            });
        }
        (await bank.ScalarAsync<decimal>("SELECT fx_rate FROM journal_transactions WHERE id = @id;", ("id", receipt.TransactionId)))
            .Should().Be(quote.Rate);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM audit_log WHERE target_id = @id AND action = 'conversion' AND ip = '127.0.0.1' AND user_agent = 'Tetri.IntegrationTests';", ("id", receipt.TransactionId)))
            .Should().Be(1);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM fx_quotes WHERE id = @id AND used_at IS NOT NULL;", ("id", quote.QuoteId)))
            .Should().Be(1);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Zero_fee_omits_the_fee_entry_and_cross_rates_go_through_gel()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var quote = await fx.CreateQuoteAsync(user.Id, new(new(1, "USD"), "GEL"), default);
        quote.NetOut.Minor.Should().Be(2);
        quote.Fee.Minor.Should().Be(0);
        var response = await ConvertAsync(bank, fx, user.Id, quote.QuoteId);
        var receipt = JsonSerializer.Deserialize<ConversionReceipt>(response.Body, LedgerTestBank.Json)!;
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM entries WHERE transaction_id = @id;", ("id", receipt.TransactionId)))
            .Should().Be(4);
        var cross = await fx.CreateQuoteAsync(user.Id, new(new(3000, "USD"), "EUR"), default);
        cross.Rate.Should().Be(2.5m / 3m);
        cross.NetOut.Currency.Should().Be("EUR");
        cross.Fee.Currency.Should().Be("EUR");
        (cross.ExpiresAt - DateTime.UtcNow).Should().BeCloseTo(TimeSpan.FromSeconds(60), TimeSpan.FromSeconds(2));
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Quote_ownership_expiry_and_single_use_are_enforced_without_extra_movements()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        var other = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var quote = await fx.CreateQuoteAsync(user.Id, new(new(1000, "USD"), "GEL"), default);
        AssertCode(await ConvertAsync(bank, fx, other.Id, quote.QuoteId), 404, "quote_not_found");
        var expired = await fx.CreateQuoteAsync(user.Id, new(new(1000, "USD"), "GEL"), default);
        await bank.ExecuteSqlAsync("UPDATE fx_quotes SET expires_at = now() - interval '1 second' WHERE id = @id;", ("id", expired.QuoteId));
        AssertCode(await ConvertAsync(bank, fx, user.Id, expired.QuoteId), 409, "quote_expired");
        (await ConvertAsync(bank, fx, user.Id, quote.QuoteId)).StatusCode.Should().Be(201);
        AssertCode(await ConvertAsync(bank, fx, user.Id, quote.QuoteId), 409, "quote_used");
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions WHERE initiated_by_user_id = @user AND kind = 'conversion';", ("user", user.Id)))
            .Should().Be(1);
        (await bank.BalanceAsync(other.Id, "USD")).Should().Be(30_000);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Cached_insufficient_funds_survives_top_up_and_quote_stays_unused()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var quote = await fx.CreateQuoteAsync(user.Id, new(new(200_000, "GEL"), "USD"), default);
        var key = Guid.CreateVersion7().ToString("D");
        var first = await ConvertAsync(bank, fx, user.Id, quote.QuoteId, key);
        AssertCode(first, 422, "insufficient_funds");
        await bank.TopUpAsync(user.Id, 200_000);
        (await ConvertAsync(bank, fx, user.Id, quote.QuoteId, key)).Should().Be(first);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM fx_quotes WHERE id = @id AND used_at IS NULL;", ("id", quote.QuoteId)))
            .Should().Be(1);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions WHERE initiated_by_user_id = @user AND kind = 'conversion';", ("user", user.Id)))
            .Should().Be(0);
        (await ConvertAsync(bank, fx, user.Id, quote.QuoteId)).StatusCode.Should().Be(201);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Concurrent_confirmations_of_one_quote_post_once_and_replay_exact_bytes()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var quote = await fx.CreateQuoteAsync(user.Id, new(new(1000, "USD"), "GEL"), default);
        var key = Guid.CreateVersion7().ToString("D");
        var responses = await Task.WhenAll(Enumerable.Range(0, 10)
            .Select(index => ConvertAsync(bank, fx, user.Id, quote.QuoteId, index == 0 ? key : null)));
        responses.Count(response => response.StatusCode == 201).Should().Be(1);
        responses.Where(response => response.StatusCode != 201).Should().OnlyContain(response => response.StatusCode == 409);
        foreach (var rejection in responses.Where(response => response.StatusCode == 409))
            AssertCode(rejection, 409, "quote_used");
        (await ConvertAsync(bank, fx, user.Id, quote.QuoteId, key)).Should().Be(responses[0]);
        (await bank.BalanceAsync(user.Id, "USD")).Should().Be(29_000);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Opposite_conversions_lock_accounts_in_one_order_without_deadlock()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var quotes = await Task.WhenAll(Enumerable.Range(0, 20).Select(index => fx.CreateQuoteAsync(user.Id,
            index % 2 == 0 ? new(new(100, "USD"), "GEL") : new(new(250, "GEL"), "USD"), default)));
        var results = await Task.WhenAll(quotes.Select(quote => ConvertAsync(bank, fx, user.Id, quote.QuoteId)))
            .WaitAsync(TimeSpan.FromSeconds(30));
        results.Should().OnlyContain(response => response.StatusCode == 201);
        (await bank.BalanceAsync(user.Id, "USD")).Should().Be(29_990);
        (await bank.BalanceAsync(user.Id, "GEL")).Should().Be(99_980);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Tiny_amount_rejection_does_not_store_a_quote()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await FundedUserAsync(bank);
        await SeedRatesAsync(bank);
        using var client = new HttpClient(new OfflineHandler());
        var fx = Service(bank, client);
        var act = () => fx.CreateQuoteAsync(user.Id, new(new(1, "GEL"), "USD"), default);
        (await act.Should().ThrowAsync<DomainException>()).Which.Code.Should().Be("amount_too_small");
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM fx_quotes WHERE user_id = @user;", ("user", user.Id))).Should().Be(0);
    }

    private static FxService Service(LedgerTestBank bank, HttpClient client) =>
        new(bank.DataSource, new FxRateService(client, bank.DataSource, TimeProvider.System),
            Options.Create(new FxOptions()), TimeProvider.System);

    private static async Task<TestUser> FundedUserAsync(LedgerTestBank bank)
    {
        var user = await bank.CreateIdentityAsync();
        await bank.Ledger.GrantStarterBalancesAsync(user.Id, default);
        return user;
    }

    internal static async Task SeedRatesAsync(LedgerTestBank bank)
    {
        await bank.ExecuteSqlAsync("DELETE FROM fx_rates;");
        await bank.ExecuteSqlAsync("""
            INSERT INTO fx_rates (currency, rate_to_gel, rate_date) VALUES ('USD', 2.5, @date), ('EUR', 3, @date);
            """, ("date", DateOnly.FromDateTime(DateTime.UtcNow)));
    }

    private static Task<StoredResponse> ConvertAsync(LedgerTestBank bank, FxService fx, Guid userId, Guid quoteId, string? key = null)
    {
        var body = JsonSerializer.Serialize(new ConversionRequest(quoteId), LedgerTestBank.Json);
        return bank.CreateIdempotency().ExecuteAsync(userId, key ?? Guid.CreateVersion7().ToString("D"),
            "/api/v1/conversions", CanonicalJson.Hash(body), async (connection, transaction, ct) =>
            {
                var receipt = await fx.ConvertAsync(connection, transaction, userId, quoteId, LedgerTestBank.Audit, ct);
                return new StoredResponse(201, JsonSerializer.Serialize(receipt, LedgerTestBank.Json));
            });
    }

    private static void AssertCode(StoredResponse response, int status, string code)
    {
        response.StatusCode.Should().Be(status);
        JsonDocument.Parse(response.Body).RootElement.GetProperty("code").GetString().Should().Be(code);
    }

    private sealed class OfflineHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            throw new InvalidOperationException("Conversion tests must not call the live rates feed.");
    }
}
