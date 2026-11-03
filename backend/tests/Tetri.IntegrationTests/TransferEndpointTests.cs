using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using Tetri.Core.Ledger;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class TransferEndpointTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Fifty_parallel_transfers_cannot_overspend_repeated_twenty_times()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();

        for (var iteration = 0; iteration < 20; iteration++)
        {
            var sender = await bank.CreateUserAsync(10_000);
            var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
            var recipient = await bank.CreateUserAsync(0);
            var request = new TransferRequest(recipient.Handle, new MoneyAmount(1_000, "GEL"));
            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var requests = Enumerable.Range(0, 50).Select(async _ =>
            {
                await start.Task;
                return await PostAsync(client, senderToken, NewKey(), request);
            }).ToArray();

            start.SetResult();
            var responses = await Task.WhenAll(requests).WaitAsync(TimeSpan.FromSeconds(90));

            responses.Count(response => response.Status == HttpStatusCode.Created)
                .Should().Be(10, $"iteration {iteration + 1} starts with exactly 100.00 GEL");
            var rejections = responses.Where(response => response.Status != HttpStatusCode.Created).ToArray();
            rejections.Should().HaveCount(40);
            foreach (var rejection in rejections)
            {
                rejection.Status.Should().Be(HttpStatusCode.UnprocessableEntity);
                rejection.Code.Should().Be("insufficient_funds");
            }

            (await bank.BalanceAsync(sender.Id)).Should().Be(0);
            (await bank.BalanceAsync(recipient.Id)).Should().Be(10_000);
            (await bank.TransferCountAsync(sender.Id)).Should().Be(10);
            (await bank.TransferEntryCountAsync(sender.Id)).Should().Be(20);
            await database.AssertLedgerInvariantsAsync();
        }
    }

    [Fact]
    public async Task Opposite_direction_transfers_do_not_deadlock_and_preserve_balances()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var first = await bank.CreateUserAsync(100_000);
        var second = await bank.CreateUserAsync(100_000);
        var firstToken = (await AuthTestClient.LoginAsync(client, first)).AccessToken;
        var secondToken = (await AuthTestClient.LoginAsync(client, second)).AccessToken;
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var requests = Enumerable.Range(0, 100).Select(async index =>
        {
            await start.Task;
            var senderToken = index % 2 == 0 ? firstToken : secondToken;
            var recipient = index % 2 == 0 ? second : first;
            return await PostAsync(client, senderToken, NewKey(),
                new TransferRequest(recipient.Handle, new MoneyAmount(100, "GEL")));
        }).ToArray();

        start.SetResult();
        var responses = await Task.WhenAll(requests).WaitAsync(TimeSpan.FromSeconds(90));

        responses.Should().OnlyContain(response => response.Status == HttpStatusCode.Created);
        (await bank.BalanceAsync(first.Id)).Should().Be(100_000);
        (await bank.BalanceAsync(second.Id)).Should().Be(100_000);
        (await bank.TransferCountAsync(first.Id)).Should().Be(50);
        (await bank.TransferCountAsync(second.Id)).Should().Be(50);
        (await bank.TransferEntryCountAsync(first.Id)).Should().Be(100);
        (await bank.TransferEntryCountAsync(second.Id)).Should().Be(100);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Http_replay_preserves_the_exact_status_and_body()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync(10_000);
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var recipient = await bank.CreateUserAsync(0);
        var request = new TransferRequest(recipient.Handle, new MoneyAmount(2_500, "GEL"), "Lunch");
        var key = NewKey();

        var first = await PostAsync(client, senderToken, key, request);
        var retry = await PostAsync(client, senderToken, key, request);

        first.Status.Should().Be(HttpStatusCode.Created);
        retry.Should().Be(first);
        first.ContentType.Should().Be("application/json");
        var receipt = JsonSerializer.Deserialize<TransferReceipt>(first.Body, LedgerTestBank.Json)!;
        receipt.Amount.Should().Be(request.Amount);
        receipt.RecipientHandle.Should().Be(recipient.Handle);
        receipt.RecipientDisplayName.Should().Be(recipient.DisplayName);
        (await bank.BalanceAsync(sender.Id)).Should().Be(7_500);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Reordered_json_properties_have_the_same_idempotency_hash()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync(10_000);
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        var firstJson = $$$"""{"recipientHandle":"{{{recipient.Handle}}}","amount":{"minor":1000,"currency":"GEL"}}""";
        var secondJson = $$$"""{ "amount": { "currency": "GEL", "minor": 1000 }, "recipientHandle": "{{{recipient.Handle}}}" }""";

        var first = await PostJsonAsync(client, senderToken, key, firstJson);
        var reordered = await PostJsonAsync(client, senderToken, key, secondJson);

        first.Status.Should().Be(HttpStatusCode.Created);
        reordered.Should().Be(first);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Concurrent_http_retries_move_money_once()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync(10_000);
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var recipient = await bank.CreateUserAsync(0);
        var request = new TransferRequest(recipient.Handle, new MoneyAmount(1_000, "GEL"));
        var key = NewKey();

        var responses = await Task.WhenAll(PostAsync(client, senderToken, key, request), PostAsync(client, senderToken, key, request));
        var retry = await PostAsync(client, senderToken, key, request);

        responses.Should().Contain(response => response.Status == HttpStatusCode.Created);
        foreach (var response in responses)
        {
            if (response.Status == HttpStatusCode.Created)
            {
                response.Should().Be(retry);
            }
            else
            {
                response.Status.Should().Be(HttpStatusCode.Conflict);
                response.Code.Should().Be("request_in_progress");
            }
        }

        retry.Status.Should().Be(HttpStatusCode.Created);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_000);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("not-a-uuid")]
    public async Task Missing_or_malformed_idempotency_key_is_rejected_before_claim(string? key)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync();
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var recipient = await bank.CreateUserAsync(0);

        var response = await PostAsync(client, senderToken, key,
            new TransferRequest(recipient.Handle, new MoneyAmount(100, "GEL")));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.Code.Should().Be("invalid_idempotency_key");
        await AssertNoClaimOrTransferAsync(bank, sender.Id);
    }

    [Theory]
    [InlineData(0, "GEL", "invalid_amount")]
    [InlineData(-1, "GEL", "invalid_amount")]
    [InlineData(100, "GBP", "unsupported_currency")]
    public async Task Invalid_amount_or_currency_is_rejected_before_claim(long amount, string currency, string code)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync();
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var recipient = await bank.CreateUserAsync(0);

        var response = await PostAsync(client, senderToken, NewKey(),
            new TransferRequest(recipient.Handle, new MoneyAmount(amount, currency)));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.Code.Should().Be(code);
        await AssertNoClaimOrTransferAsync(bank, sender.Id);
    }

    [Theory]
    [InlineData("{\"recipientHandle\":\"@nino\",\"amount\":{\"minor\":1.5,\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"@nino\",\"amount\":{\"minor\":9223372036854775808,\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"@nino\",\"amount\":{\"minor\":100,\"minor\":200,\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"@nino\",\"amount\":{\"minor\":100,\"Minor\":200,\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"@nino\",\"amount\":{\"Minor\":200,\"minor\":100,\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"@nino\",\"amount\":{\"minor\":\"2500\",\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"\",\"amount\":{\"minor\":100,\"currency\":\"GEL\"}}")]
    [InlineData("{\"recipientHandle\":\"@nino\"}")]
    public async Task Invalid_request_shape_cannot_create_an_idempotency_claim(string json)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync();
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var balanceBefore = await bank.BalanceAsync(sender.Id);

        var response = await PostJsonAsync(client, senderToken, NewKey(), json);

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.Code.Should().Be("invalid_request");
        await AssertNoClaimOrTransferAsync(bank, sender.Id);
        (await bank.BalanceAsync(sender.Id)).Should().Be(balanceBefore);
    }

    [Fact]
    public async Task Different_body_with_the_same_key_returns_422_over_http()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync(10_000);
        var senderToken = (await AuthTestClient.LoginAsync(client, sender)).AccessToken;
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        await PostAsync(client, senderToken, key, new TransferRequest(recipient.Handle, new MoneyAmount(100, "GEL")));

        var response = await PostAsync(client, senderToken, key, new TransferRequest(recipient.Handle, new MoneyAmount(200, "GEL")));

        response.Status.Should().Be(HttpStatusCode.UnprocessableEntity);
        response.Code.Should().Be("idempotency_key_reused");
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_900);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Production_authentication_never_accepts_the_test_user_header()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await bank.CreateUserAsync();
        var recipient = await bank.CreateUserAsync(0);

        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/transfers")
        {
            Content = System.Net.Http.Json.JsonContent.Create(
                new TransferRequest(recipient.Handle, new MoneyAmount(100, "GEL")))
        };
        request.Headers.Add("X-Test-User", sender.Id.ToString("D"));
        request.Headers.Add("Idempotency-Key", NewKey());
        using var response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        await AssertNoClaimOrTransferAsync(bank, sender.Id);
    }

    private static async Task AssertNoClaimOrTransferAsync(LedgerTestBank bank, Guid userId)
    {
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM idempotency_keys WHERE user_id = @user;", ("user", userId)))
            .Should().Be(0);
        (await bank.TransferCountAsync(userId)).Should().Be(0);
    }

    private static string NewKey() => Guid.CreateVersion7().ToString("D");

    private static Task<HttpOutcome> PostAsync(HttpClient client, string accessToken, string? key, TransferRequest transfer) =>
        PostJsonAsync(client, accessToken, key, JsonSerializer.Serialize(transfer, LedgerTestBank.Json));

    private static async Task<HttpOutcome> PostJsonAsync(HttpClient client, string accessToken, string? key, string json)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/transfers")
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        if (key is not null)
        {
            request.Headers.Add("Idempotency-Key", key);
        }

        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(body);
        var code = document.RootElement.TryGetProperty("code", out var value) ? value.GetString() : null;
        return new HttpOutcome(response.StatusCode, body, code, response.Content.Headers.ContentType?.MediaType);
    }

    private sealed record HttpOutcome(HttpStatusCode Status, string Body, string? Code, string? ContentType);
}
