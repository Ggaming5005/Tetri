using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Npgsql;
using Tetri.Core.Ledger;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class OwnershipAndHistoryTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Accounts_and_transaction_details_expose_only_the_callers_entries()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await AuthTestClient.RegisterAsync(client);
        var recipient = await AuthTestClient.RegisterAsync(client);
        var outsider = await AuthTestClient.RegisterAsync(client);
        var transfer = await bank.TransferAsync(sender.User.Id,
            new TransferRequest(recipient.User.Handle, new MoneyAmount(2_500, "GEL")));
        var ownAccounts = await AccountIdsAsync(bank, sender.User.Id);
        var recipientAccounts = await AccountIdsAsync(bank, recipient.User.Id);

        var accounts = await AuthTestClient.GetJsonAsync(client, "/api/v1/accounts", sender.AccessToken);
        accounts.EnumerateArray().Select(account => account.GetProperty("id").GetGuid()).Should().BeEquivalentTo(ownAccounts);
        using var forbiddenAccount = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Get,
            $"/api/v1/accounts/{recipientAccounts[0]}/transactions", sender.AccessToken);
        forbiddenAccount.StatusCode.Should().Be(HttpStatusCode.NotFound);
        var senderDetail = await AuthTestClient.GetJsonAsync(client, $"/api/v1/transactions/{transfer.Id}", sender.AccessToken);
        var recipientDetail = await AuthTestClient.GetJsonAsync(client, $"/api/v1/transactions/{transfer.Id}", recipient.AccessToken);

        AssertOwnEntries(senderDetail, ownAccounts, -2_500);
        AssertOwnEntries(recipientDetail, recipientAccounts, 2_500);
        senderDetail.GetProperty("counterparty").GetProperty("handle").GetString().Should().Be(recipient.User.Handle);
        recipientDetail.GetProperty("counterparty").GetProperty("handle").GetString().Should().Be(sender.User.Handle);
        using var unrelated = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Get,
            $"/api/v1/transactions/{transfer.Id}", outsider.AccessToken);
        unrelated.StatusCode.Should().Be(HttpStatusCode.NotFound);

        var history = await AuthTestClient.GetJsonAsync(client, "/api/v1/transactions?pageSize=100", sender.AccessToken);
        foreach (var item in history.GetProperty("items").EnumerateArray())
        {
            item.GetProperty("entries").EnumerateArray().Select(entry => entry.GetProperty("accountId").GetGuid())
                .Should().OnlyContain(id => ownAccounts.Contains(id));
        }
        var recipientGrant = await bank.ScalarAsync<Guid>(
            "SELECT id FROM journal_transactions WHERE initiated_by_user_id = @user AND kind = 'starter_grant' LIMIT 1;",
            ("user", recipient.User.Id));
        using var privateGrant = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Get,
            $"/api/v1/transactions/{recipientGrant}", sender.AccessToken);
        privateGrant.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Cursor_paging_with_equal_timestamps_has_no_duplicates_or_missing_transactions()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var sender = await AuthTestClient.RegisterAsync(client);
        var recipient = await AuthTestClient.RegisterAsync(client);
        for (var index = 0; index < 5; index++)
        {
            await bank.TransferAsync(sender.User.Id, new TransferRequest(recipient.User.Handle, new MoneyAmount(100 + index, "GEL")));
        }
        var sharedTime = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
        await bank.ExecuteSqlAsync(
            """
            UPDATE journal_transactions SET created_at = @created
            WHERE id IN (SELECT e.transaction_id FROM entries e JOIN accounts a ON a.id = e.account_id WHERE a.owner_user_id = @user);
            """, ("created", sharedTime), ("user", sender.User.Id));
        var expected = await HistoryIdsAsync(bank, sender.User.Id);
        var actual = new List<Guid>();
        string? cursor = null;
        do
        {
            var path = "/api/v1/transactions?pageSize=2" + (cursor is null ? "" : $"&cursor={Uri.EscapeDataString(cursor)}");
            var page = await AuthTestClient.GetJsonAsync(client, path, sender.AccessToken);
            var items = page.GetProperty("items");
            items.GetArrayLength().Should().BeInRange(1, 2);
            actual.AddRange(items.EnumerateArray().Select(item => item.GetProperty("id").GetGuid()));
            cursor = page.GetProperty("nextCursor").GetString();
            actual.Count.Should().BeLessThanOrEqualTo(expected.Count, "cursor paging must always advance");
        } while (cursor is not null);

        actual.Should().Equal(expected).And.OnlyHaveUniqueItems();
        actual.Should().HaveCount(8);
    }

    [Fact]
    public async Task Account_history_and_activity_filters_keep_direction_and_account_scope()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var first = await AuthTestClient.RegisterAsync(client);
        var second = await AuthTestClient.RegisterAsync(client);
        var sent = await bank.TransferAsync(first.User.Id, new TransferRequest(second.User.Handle, new MoneyAmount(100, "GEL")));
        var received = await bank.TransferAsync(second.User.Id, new TransferRequest(first.User.Handle, new MoneyAmount(200, "GEL")));

        var sentPage = await AuthTestClient.GetJsonAsync(client, "/api/v1/transactions?filter=sent", first.AccessToken);
        sentPage.GetProperty("items").EnumerateArray().Select(item => item.GetProperty("id").GetGuid()).Should().Equal(sent.Id);
        var receivedPage = await AuthTestClient.GetJsonAsync(client, "/api/v1/transactions?filter=received", first.AccessToken);
        var receivedItems = receivedPage.GetProperty("items").EnumerateArray().ToArray();
        receivedItems.Select(item => item.GetProperty("id").GetGuid()).Should().Contain(received.Id).And.NotContain(sent.Id);
        receivedItems.SelectMany(item => item.GetProperty("entries").EnumerateArray())
            .Should().OnlyContain(entry => entry.GetProperty("amount").GetProperty("minor").GetInt64() > 0);
        var conversions = await AuthTestClient.GetJsonAsync(client, "/api/v1/transactions?filter=conversions", first.AccessToken);
        conversions.GetProperty("items").GetArrayLength().Should().Be(0);
        var usdAccount = await bank.ScalarAsync<Guid>(
            "SELECT id FROM accounts WHERE owner_user_id = @user AND currency = 'USD';", ("user", first.User.Id));
        var accountPage = await AuthTestClient.GetJsonAsync(client, $"/api/v1/accounts/{usdAccount}/transactions", first.AccessToken);
        accountPage.GetProperty("items").GetArrayLength().Should().Be(1);
        accountPage.GetProperty("items")[0].GetProperty("entries")[0].GetProperty("accountId").GetGuid().Should().Be(usdAccount);
    }

    [Fact]
    public async Task Recipient_lookup_returns_only_handle_and_display_name()
    {
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var caller = await AuthTestClient.RegisterAsync(client);
        var recipient = await AuthTestClient.RegisterAsync(client);

        var lookup = await AuthTestClient.GetJsonAsync(client,
            $"/api/v1/users/lookup?handle={Uri.EscapeDataString(recipient.User.Handle)}", caller.AccessToken);

        lookup.EnumerateObject().Select(property => property.Name).Should().BeEquivalentTo(new[] { "displayName", "handle" });
        lookup.GetProperty("displayName").GetString().Should().Be(recipient.User.DisplayName);
        lookup.GetProperty("handle").GetString().Should().Be(recipient.User.Handle);
    }

    [Theory]
    [InlineData("pageSize=0", "invalid_page_size")]
    [InlineData("pageSize=101", "invalid_page_size")]
    [InlineData("cursor=not-a-cursor", "invalid_cursor")]
    [InlineData("filter=unknown", "invalid_filter")]
    public async Task Invalid_history_queries_return_stable_problem_codes(string query, string code)
    {
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var session = await AuthTestClient.RegisterAsync(client);
        using var response = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Get, $"/api/v1/transactions?{query}", session.AccessToken);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await AuthTestClient.ProblemCodeAsync(response)).Should().Be(code);
    }

    [Theory]
    [InlineData("GET", "/api/v1/me")]
    [InlineData("GET", "/api/v1/accounts")]
    [InlineData("GET", "/api/v1/accounts/00000000-0000-0000-0000-000000000001/transactions")]
    [InlineData("GET", "/api/v1/transactions")]
    [InlineData("GET", "/api/v1/transactions/00000000-0000-0000-0000-000000000001")]
    [InlineData("GET", "/api/v1/users/lookup?handle=@nino")]
    [InlineData("GET", "/api/v1/fx/rates")]
    [InlineData("POST", "/api/v1/fx/quote")]
    [InlineData("POST", "/api/v1/conversions")]
    [InlineData("POST", "/api/v1/transfers")]
    [InlineData("POST", "/api/v1/auth/logout")]
    public async Task Protected_endpoints_require_a_real_access_token(string method, string path)
    {
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(new HttpMethod(method), path);
        if (method == "POST") request.Content = JsonContent.Create(new { });
        using var response = await client.SendAsync(request);
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        (await AuthTestClient.ProblemCodeAsync(response)).Should().Be("unauthorized");
    }

    [Fact]
    public async Task OpenApi_is_browsable_in_development_and_documents_the_api()
    {
        await using var factory = new TransferApiFactory(database.ConnectionString, environment: "Development");
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/openapi");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var document = await response.Content.ReadFromJsonAsync<JsonElement>();
        var paths = document.GetProperty("paths");
        foreach (var path in new[] { "/api/v1/auth/register", "/api/v1/auth/login", "/api/v1/accounts", "/api/v1/transactions", "/api/v1/fx/quote", "/api/v1/conversions", "/api/v1/transfers" })
        {
            paths.TryGetProperty(path, out _).Should().BeTrue($"OpenAPI should describe {path}");
        }
    }

    private static void AssertOwnEntries(JsonElement transaction, IReadOnlyCollection<Guid> accountIds, long amount)
    {
        var entries = transaction.GetProperty("entries");
        entries.GetArrayLength().Should().Be(1);
        accountIds.Should().Contain(entries[0].GetProperty("accountId").GetGuid());
        entries[0].GetProperty("amount").GetProperty("minor").GetInt64().Should().Be(amount);
    }

    private static async Task<List<Guid>> AccountIdsAsync(LedgerTestBank bank, Guid userId)
    {
        await using var connection = await bank.DataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("SELECT id FROM accounts WHERE owner_user_id = @user ORDER BY currency;", connection);
        command.Parameters.AddWithValue("user", userId);
        await using var reader = await command.ExecuteReaderAsync();
        var ids = new List<Guid>();
        while (await reader.ReadAsync()) ids.Add(reader.GetGuid(0));
        return ids;
    }

    private static async Task<List<Guid>> HistoryIdsAsync(LedgerTestBank bank, Guid userId)
    {
        await using var connection = await bank.DataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            """
            SELECT j.id FROM journal_transactions j
            WHERE EXISTS (SELECT 1 FROM entries e JOIN accounts a ON a.id = e.account_id
                          WHERE e.transaction_id = j.id AND a.owner_user_id = @user)
            ORDER BY j.created_at DESC, j.id DESC;
            """, connection);
        command.Parameters.AddWithValue("user", userId);
        await using var reader = await command.ExecuteReaderAsync();
        var ids = new List<Guid>();
        while (await reader.ReadAsync()) ids.Add(reader.GetGuid(0));
        return ids;
    }
}
