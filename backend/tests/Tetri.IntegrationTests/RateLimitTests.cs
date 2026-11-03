using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FluentAssertions;
using Tetri.Core.Ledger;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class RateLimitTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Sixth_login_in_one_minute_from_one_ip_is_rate_limited()
    {
        await using var factory = new TransferApiFactory(database.ConnectionString, useRealRateLimits: true);
        using var client = factory.CreateClient();
        for (var attempt = 0; attempt < 5; attempt++)
        {
            using var rejected = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "absent@example.test", password = TestCredentials.Password });
            rejected.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        }
        using var limited = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "absent@example.test", password = TestCredentials.Password });
        await AssertRateLimitedAsync(limited);
    }

    [Fact]
    public async Task Sixth_registration_from_one_ip_cannot_create_a_user()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString, useRealRateLimits: true);
        using var client = factory.CreateClient();
        for (var attempt = 0; attempt < 5; attempt++) await AuthTestClient.RegisterAsync(client);
        var before = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users;");

        using var limited = await client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = $"{Guid.CreateVersion7():N}@example.test",
            handle = "@u" + Guid.CreateVersion7().ToString("N")[16..],
            displayName = "Limited",
            password = TestCredentials.Password
        });

        await AssertRateLimitedAsync(limited);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users;")).Should().Be(before);
    }

    [Fact]
    public async Task Handle_availability_is_limited_to_twenty_checks_per_ip()
    {
        await using var factory = new TransferApiFactory(database.ConnectionString, useRealRateLimits: true);
        using var client = factory.CreateClient();
        for (var attempt = 0; attempt < 20; attempt++)
        {
            using var response = await client.GetAsync("/api/v1/auth/handle-available?handle=@available_test");
            response.StatusCode.Should().Be(HttpStatusCode.OK);
        }
        using var limited = await client.GetAsync("/api/v1/auth/handle-available?handle=@available_test");
        await AssertRateLimitedAsync(limited);
    }

    [Fact]
    public async Task Thirty_first_money_request_is_limited_per_user_and_conversions_share_the_limit()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString, useRealRateLimits: true);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var senderSession = await AuthTestClient.LoginAsync(client, sender);
        var recipientSession = await AuthTestClient.LoginAsync(client, recipient);
        for (var attempt = 0; attempt < 30; attempt++)
        {
            using var response = await SendTransferAsync(client, senderSession.AccessToken, recipient.Handle);
            response.StatusCode.Should().Be(HttpStatusCode.Created);
        }

        using var limitedTransfer = await SendTransferAsync(client, senderSession.AccessToken, recipient.Handle);
        using var limitedConversion = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Post,
            "/api/v1/conversions", senderSession.AccessToken, new { quoteId = Guid.CreateVersion7() });

        await AssertRateLimitedAsync(limitedTransfer);
        await AssertRateLimitedAsync(limitedConversion);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(30);
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_970);
        using var anotherUser = await SendTransferAsync(client, recipientSession.AccessToken, sender.Handle);
        anotherUser.StatusCode.Should().Be(HttpStatusCode.Created, "users sharing an IP have separate money limits");
    }

    private static async Task<HttpResponseMessage> SendTransferAsync(HttpClient client, string accessToken, string recipient)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/transfers")
        {
            Content = JsonContent.Create(new TransferRequest(recipient, new MoneyAmount(1, "GEL")))
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString("D"));
        return await client.SendAsync(request);
    }

    private static async Task AssertRateLimitedAsync(HttpResponseMessage response)
    {
        response.StatusCode.Should().Be(HttpStatusCode.TooManyRequests);
        (await AuthTestClient.ProblemCodeAsync(response)).Should().Be("rate_limited");
    }
}
