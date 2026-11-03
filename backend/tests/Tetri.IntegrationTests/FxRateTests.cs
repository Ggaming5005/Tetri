using System.Net;
using FluentAssertions;
using Tetri.Core.Fx;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Fx;

namespace Tetri.IntegrationTests;

public sealed class FxRateTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    private static readonly DateTimeOffset Now = new(2026, 10, 3, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Refresh_normalizes_stores_effective_dates_and_leaves_existing_days_unchanged()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await bank.ExecuteSqlAsync("DELETE FROM fx_rates;");
        using var handler = new FeedHandler(Feed("2026-10-03", 25m, 10, 30m, 10));
        using var client = new HttpClient(handler);
        var service = new FxRateService(client, bank.DataSource, new FixedTimeProvider(Now));
        await service.RefreshAsync(default);
        var originalFetch = await bank.ScalarAsync<DateTime>("SELECT fetched_at FROM fx_rates WHERE currency = 'USD';");
        handler.Body = Feed("2026-10-03", 99m, 1, 98m, 1);
        await service.RefreshAsync(default);

        (await service.GetCurrentAsync(default)).Should().BeEquivalentTo(new[]
        {
            new FxRateValue("GEL", 1m, new DateOnly(2026, 10, 3)),
            new FxRateValue("USD", 2.5m, new DateOnly(2026, 10, 3)),
            new FxRateValue("EUR", 3m, new DateOnly(2026, 10, 3))
        });
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM fx_rates;")).Should().Be(2);
        (await bank.ScalarAsync<DateTime>("SELECT fetched_at FROM fx_rates WHERE currency = 'USD';")).Should().Be(originalFetch);
        handler.Requests.Should().OnlyContain(uri => uri == FxRateService.FeedUrl);
    }

    [Fact]
    public async Task Current_rates_exclude_future_dates_and_keep_prior_rates_when_fetch_fails()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await bank.ExecuteSqlAsync("DELETE FROM fx_rates;");
        using var handler = new FeedHandler(Feed("2026-10-02", 2.5m, 1, 3m, 1));
        using var client = new HttpClient(handler);
        var service = new FxRateService(client, bank.DataSource, new FixedTimeProvider(Now));
        await service.RefreshAsync(default);
        handler.Body = Feed("2026-10-04", 9m, 1, 10m, 1);
        await service.RefreshAsync(default);
        var current = await service.GetCurrentAsync(default);
        current.Should().OnlyContain(rate => rate.RateDate == new DateOnly(2026, 10, 2));
        current.Single(rate => rate.Currency == "USD").RateToGel.Should().Be(2.5m);
        handler.Fail = true;
        var act = () => service.RefreshAsync(default);
        await act.Should().ThrowAsync<HttpRequestException>();
        (await service.GetCurrentAsync(default)).Should().BeEquivalentTo(current);
    }

    [Fact]
    public async Task No_effective_rates_returns_retryable_503_including_a_future_only_feed()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await bank.ExecuteSqlAsync("DELETE FROM fx_rates;");
        using var handler = new FeedHandler(Feed("2026-10-04", 2.5m, 1, 3m, 1));
        using var client = new HttpClient(handler);
        var service = new FxRateService(client, bank.DataSource, new FixedTimeProvider(Now));
        var act = () => service.GetCurrentAsync(default);
        var error = (await act.Should().ThrowAsync<DomainException>()).Which;
        error.StatusCode.Should().Be(503);
        error.Code.Should().Be("rates_unavailable");
        await service.RefreshAsync(default);
        (await act.Should().ThrowAsync<DomainException>()).Which.Code.Should().Be("rates_unavailable");
    }

    private static string Feed(string date, decimal usd, int usdQuantity, decimal eur, int eurQuantity) =>
        System.Text.Json.JsonSerializer.Serialize(new[] { new
        {
            date = "2026-09-01T00:00:00Z", currencies = new[]
            {
                new { code = "USD", rate = usd, quantity = usdQuantity, validFromDate = date + "T00:00:00Z" },
                new { code = "EUR", rate = eur, quantity = eurQuantity, validFromDate = date + "T00:00:00Z" }
            }
        } });

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private sealed class FeedHandler(string body) : HttpMessageHandler
    {
        public string Body { get; set; } = body;
        public bool Fail { get; set; }
        public List<string> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Requests.Add(request.RequestUri!.AbsoluteUri);
            if (Fail)
                throw new HttpRequestException("Simulated unavailable official feed.");
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(Body) });
        }
    }
}
