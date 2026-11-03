using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Identity;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class AuthEndpointTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Register_creates_profile_three_funded_accounts_and_a_hashed_session()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var grants = new Dictionary<string, long> { ["GEL"] = 100_000, ["USD"] = 30_000, ["EUR"] = 30_000 };
        var funding = new Dictionary<string, long>();
        foreach (var currency in grants.Keys)
        {
            funding[currency] = await bank.ScalarAsync<long>(
                "SELECT balance FROM accounts WHERE kind = 'funding' AND currency = @currency;", ("currency", currency));
        }

        var email = $"REGISTER-{Guid.CreateVersion7():N}@EXAMPLE.TEST";
        var session = await AuthTestClient.RegisterAsync(client, email);

        session.User.Id.Version.Should().Be(7);
        session.User.Email.Should().Be(email.ToLowerInvariant());
        session.ExpiresAt.Should().BeAfter(DateTime.UtcNow.AddMinutes(14)).And.BeBefore(DateTime.UtcNow.AddMinutes(16));
        var accounts = await AuthTestClient.GetJsonAsync(client, "/api/v1/accounts", session.AccessToken);
        accounts.GetArrayLength().Should().Be(3);
        foreach (var account in accounts.EnumerateArray())
        {
            var currency = account.GetProperty("currency").GetString()!;
            account.GetProperty("balance").GetProperty("minor").GetInt64().Should().Be(grants[currency]);
            account.GetProperty("balance").GetProperty("currency").GetString().Should().Be(currency);
            (await bank.ScalarAsync<long>(
                "SELECT balance FROM accounts WHERE kind = 'funding' AND currency = @currency;", ("currency", currency)))
                .Should().Be(funding[currency] - grants[currency]);
        }

        var passwordHash = await bank.ScalarAsync<string>("SELECT password_hash FROM users WHERE id = @id;", ("id", session.User.Id));
        passwordHash.Should().NotBe(TestCredentials.Password);
        new PasswordHasher<AuthUser>().VerifyHashedPassword(session.User, passwordHash, TestCredentials.Password)
            .Should().Be(PasswordVerificationResult.Success);
        var tokenHash = AuthTestClient.TokenHash(session.RefreshToken);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM refresh_tokens WHERE user_id = @user AND token_hash = @hash;",
            ("user", session.User.Id), ("hash", tokenHash))).Should().Be(1);
        (await bank.ScalarAsync<long>(
            "SELECT COUNT(*) FROM entries WHERE transaction_id IN (SELECT id FROM journal_transactions WHERE initiated_by_user_id = @user);",
            ("user", session.User.Id))).Should().Be(6);
        var me = await AuthTestClient.GetJsonAsync(client, "/api/v1/me", session.AccessToken);
        me.GetProperty("id").GetGuid().Should().Be(session.User.Id);
        me.EnumerateObject().Select(property => property.Name).Should().BeEquivalentTo(new[] { "id", "email", "displayName", "handle" });
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Login_uses_real_credentials_and_records_success_and_failure_audits()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var registered = await AuthTestClient.RegisterAsync(client);
        var failuresBefore = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM audit_log WHERE action = 'login_failed';");

        using var wrongPassword = await client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email = registered.User.Email,
            password = "definitely-the-wrong-password"
        });
        using var unknownEmail = await client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email = $"missing-{Guid.CreateVersion7():N}@example.test",
            password = TestCredentials.Password
        });
        var signedIn = await AuthTestClient.LoginAsync(client, registered.User.Email);

        wrongPassword.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        unknownEmail.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        (await AuthTestClient.ProblemCodeAsync(wrongPassword)).Should().Be("invalid_credentials");
        (await AuthTestClient.ProblemCodeAsync(unknownEmail)).Should().Be("invalid_credentials");
        signedIn.User.Should().Be(registered.User);
        signedIn.RefreshToken.Should().NotBe(registered.RefreshToken);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM audit_log WHERE action = 'login_failed';"))
            .Should().Be(failuresBefore + 2);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM audit_log WHERE action = 'login' AND user_id = @user;",
            ("user", registered.User.Id))).Should().Be(2);
    }

    [Fact]
    public async Task Duplicate_email_or_handle_cannot_create_extra_accounts_or_grants()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var registered = await AuthTestClient.RegisterAsync(client);
        var usersBefore = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users;");
        var journalsBefore = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions;");

        using var duplicateEmail = await client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = registered.User.Email.ToUpperInvariant(),
            displayName = "Duplicate",
            handle = "@u" + Guid.CreateVersion7().ToString("N")[16..],
            password = TestCredentials.Password
        });
        using var duplicateHandle = await client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = $"{Guid.CreateVersion7():N}@example.test",
            displayName = "Duplicate",
            handle = registered.User.Handle,
            password = TestCredentials.Password
        });

        duplicateEmail.StatusCode.Should().Be(HttpStatusCode.Conflict);
        duplicateHandle.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await AuthTestClient.ProblemCodeAsync(duplicateEmail)).Should().Be("email_taken");
        (await AuthTestClient.ProblemCodeAsync(duplicateHandle)).Should().Be("handle_taken");
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users;")).Should().Be(usersBefore);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions;")).Should().Be(journalsBefore);
    }

    [Fact]
    public async Task Concurrent_registration_for_one_handle_has_one_atomic_winner()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var handle = "@u" + Guid.CreateVersion7().ToString("N")[16..];
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var requests = Enumerable.Range(0, 2).Select(async _ =>
        {
            await start.Task;
            return await client.PostAsJsonAsync("/api/v1/auth/register", new
            {
                email = $"{Guid.CreateVersion7():N}@example.test",
                displayName = "Registration Race",
                handle,
                password = TestCredentials.Password
            });
        }).ToArray();
        start.SetResult();
        var responses = await Task.WhenAll(requests);
        try
        {
            responses.Count(response => response.StatusCode == HttpStatusCode.Created).Should().Be(1);
            var loser = responses.Single(response => response.StatusCode != HttpStatusCode.Created);
            loser.StatusCode.Should().Be(HttpStatusCode.Conflict);
            (await AuthTestClient.ProblemCodeAsync(loser)).Should().Be("handle_taken");
            (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users WHERE handle = @handle;", ("handle", handle))).Should().Be(1);
            (await bank.ScalarAsync<long>(
                "SELECT COUNT(*) FROM accounts WHERE owner_user_id IN (SELECT id FROM users WHERE handle = @handle);",
                ("handle", handle))).Should().Be(3);
            await database.AssertLedgerInvariantsAsync();
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [Theory]
    [InlineData("not-an-email", "@valid_handle", "a-long-password", "invalid_email")]
    [InlineData("valid@example.test", "@ab", "a-long-password", "invalid_handle")]
    [InlineData("valid@example.test", "@valid_handle", "123456789", "invalid_password")]
    public async Task Invalid_registration_is_rejected_without_creating_a_user(string email, string handle, string password, string code)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var before = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users;");
        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", new { email, displayName = "Invalid", handle, password });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await AuthTestClient.ProblemCodeAsync(response)).Should().Be(code);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM users;")).Should().Be(before);
    }

    [Fact]
    public async Task Handle_availability_is_anonymous_and_exposes_only_availability()
    {
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var registered = await AuthTestClient.RegisterAsync(client);
        using var taken = await client.GetAsync($"/api/v1/auth/handle-available?handle={Uri.EscapeDataString(registered.User.Handle)}");
        var availableHandle = "@u" + Guid.CreateVersion7().ToString("N")[16..];
        using var available = await client.GetAsync($"/api/v1/auth/handle-available?handle={availableHandle}");

        taken.StatusCode.Should().Be(HttpStatusCode.OK);
        available.StatusCode.Should().Be(HttpStatusCode.OK);
        var takenBody = await taken.Content.ReadFromJsonAsync<JsonElement>();
        var availableBody = await available.Content.ReadFromJsonAsync<JsonElement>();
        takenBody.EnumerateObject().Select(property => property.Name).Should().Equal("available");
        availableBody.EnumerateObject().Select(property => property.Name).Should().Equal("available");
        takenBody.GetProperty("available").GetBoolean().Should().BeFalse();
        availableBody.GetProperty("available").GetBoolean().Should().BeTrue();
    }
}
