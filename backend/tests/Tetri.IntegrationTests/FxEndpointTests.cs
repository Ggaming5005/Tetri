using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using Tetri.Core.Fx;

namespace Tetri.IntegrationTests;

public sealed class FxEndpointTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Quote_and_conversion_contracts_replay_success_and_reject_reused_key_on_transfer()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await FxServiceTests.SeedRatesAsync(bank);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var session = await AuthTestClient.RegisterAsync(client);
        var rates = await AuthTestClient.GetJsonAsync(client, "/api/v1/fx/rates", session.AccessToken);
        rates.GetProperty("spread").GetDecimal().Should().Be(0.005m);
        rates.GetProperty("rates").GetArrayLength().Should().Be(3);
        using var quoteResponse = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Post,
            "/api/v1/fx/quote", session.AccessToken, new { amount = new { minor = 1000, currency = "USD" }, toCurrency = "GEL" });
        quoteResponse.StatusCode.Should().Be(HttpStatusCode.Created, await quoteResponse.Content.ReadAsStringAsync());
        var quote = (await quoteResponse.Content.ReadFromJsonAsync<FxQuoteResponse>())!;
        var key = Guid.CreateVersion7().ToString("D");
        var body = JsonSerializer.Serialize(new { quoteId = quote.QuoteId });
        using var first = await PostAsync(client, session.AccessToken, key, body);
        using var replay = await PostAsync(client, session.AccessToken, key, body);
        first.StatusCode.Should().Be(HttpStatusCode.Created, await first.Content.ReadAsStringAsync());
        replay.StatusCode.Should().Be(first.StatusCode);
        (await replay.Content.ReadAsStringAsync()).Should().Be(await first.Content.ReadAsStringAsync());
        (await bank.BalanceAsync(session.User.Id, "USD")).Should().Be(29_000);

        using var reused = await PostAsync(client, session.AccessToken, key,
            """{"recipientHandle":"@someone","amount":{"minor":100,"currency":"GEL"}}""", "/api/v1/transfers");
        reused.StatusCode.Should().Be(HttpStatusCode.UnprocessableEntity);
        (await AuthTestClient.ProblemCodeAsync(reused)).Should().Be("idempotency_key_reused");
        await database.AssertLedgerInvariantsAsync();
    }

    [Theory]
    [InlineData(null, "{\"quoteId\":\"00000000-0000-0000-0000-000000000001\"}", "invalid_idempotency_key")]
    [InlineData("malformed", "{\"quoteId\":\"00000000-0000-0000-0000-000000000001\"}", "invalid_idempotency_key")]
    [InlineData("key", "{}", "invalid_request")]
    [InlineData("key", "{\"quoteId\":\"00000000-0000-0000-0000-000000000000\"}", "invalid_request")]
    [InlineData("key", "{\"quoteId\":\"00000000-0000-0000-0000-000000000001\",\"rate\":99}", "invalid_request")]
    [InlineData("key", "{\"quoteId\":\"00000000-0000-0000-0000-000000000001\",\"quoteId\":\"00000000-0000-0000-0000-000000000002\"}", "invalid_request")]
    public async Task Conversion_validation_happens_before_claim(string? key, string json, string code)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var user = await AuthTestClient.RegisterAsync(client);
        using var response = await PostAsync(client, user.AccessToken, key == "key" ? Guid.CreateVersion7().ToString("D") : key, json);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await AuthTestClient.ProblemCodeAsync(response)).Should().Be(code);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM idempotency_keys WHERE user_id = @user;", ("user", user.User.Id))).Should().Be(0);
    }

    [Fact]
    public async Task Unavailable_rates_return_503_without_a_quote_and_all_fx_routes_require_auth()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await bank.ExecuteSqlAsync("DELETE FROM fx_rates;");
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var user = await AuthTestClient.RegisterAsync(client);
        using var unavailable = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Post,
            "/api/v1/fx/quote", user.AccessToken, new { amount = new { minor = 1000, currency = "USD" }, toCurrency = "GEL" });
        unavailable.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        (await AuthTestClient.ProblemCodeAsync(unavailable)).Should().Be("rates_unavailable");
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM fx_quotes WHERE user_id = @user;", ("user", user.User.Id))).Should().Be(0);
        using var rates = await client.GetAsync("/api/v1/fx/rates");
        using var quote = await client.PostAsJsonAsync("/api/v1/fx/quote", new { });
        using var conversion = await client.PostAsJsonAsync("/api/v1/conversions", new { });
        rates.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        quote.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        conversion.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Theory]
    [InlineData("{\"amount\":{\"minor\":1.5,\"currency\":\"USD\"},\"toCurrency\":\"GEL\"}")]
    [InlineData("{\"amount\":{\"minor\":100,\"currency\":\"USD\"},\"toCurrency\":\"USD\"}")]
    [InlineData("{\"amount\":{\"minor\":100,\"currency\":\"GBP\"},\"toCurrency\":\"USD\"}")]
    [InlineData("{\"amount\":{\"minor\":100,\"minor\":200,\"currency\":\"USD\"},\"toCurrency\":\"GEL\"}")]
    public async Task Invalid_quotes_are_rejected_without_storage(string json)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var user = await AuthTestClient.RegisterAsync(client);
        using var response = await PostAsync(client, user.AccessToken, null, json, "/api/v1/fx/quote");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM fx_quotes WHERE user_id = @user;", ("user", user.User.Id))).Should().Be(0);
    }

    private static async Task<HttpResponseMessage> PostAsync(HttpClient client, string token, string? key,
        string json, string path = "/api/v1/conversions")
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (key is not null)
            request.Headers.Add("Idempotency-Key", key);
        return await client.SendAsync(request);
    }
}
