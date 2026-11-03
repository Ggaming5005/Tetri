using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Npgsql;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class RefreshTokenTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Normal_rotation_revokes_parent_links_replacement_and_keeps_only_one_live_token()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);

        var replacement = await AuthTestClient.RefreshAsync(client, original.RefreshToken);

        var parent = await ReadTokenAsync(bank, original.RefreshToken);
        var child = await ReadTokenAsync(bank, replacement.RefreshToken);
        parent.RevokedReason.Should().Be("rotated");
        parent.RevokedAt.Should().NotBeNull();
        parent.ReplacedById.Should().Be(child.Id);
        child.ParentId.Should().Be(parent.Id);
        child.FamilyId.Should().Be(parent.FamilyId);
        child.RevokedAt.Should().BeNull();
        (await LiveCountAsync(bank, child.FamilyId)).Should().Be(1);
        (await AuthTestClient.GetJsonAsync(client, "/api/v1/me", replacement.AccessToken)).GetProperty("id").GetGuid()
            .Should().Be(original.User.Id);
    }

    [Fact]
    public async Task Grace_retry_supersedes_unused_replacement_and_preserves_original_rotation_time()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);
        var lost = await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        var before = await ReadTokenAsync(bank, original.RefreshToken);

        var retry = await AuthTestClient.RefreshAsync(client, original.RefreshToken);

        var after = await ReadTokenAsync(bank, original.RefreshToken);
        var superseded = await ReadTokenAsync(bank, lost.RefreshToken);
        var live = await ReadTokenAsync(bank, retry.RefreshToken);
        superseded.RevokedReason.Should().Be("retry_superseded");
        after.RevokedAt.Should().Be(before.RevokedAt);
        after.ReplacedById.Should().Be(live.Id);
        live.ParentId.Should().Be(after.Id);
        (await LiveCountAsync(bank, live.FamilyId)).Should().Be(1);
        (await FamilyRevokedCountAsync(bank, live.FamilyId)).Should().Be(0);
    }

    [Fact]
    public async Task Two_consecutive_lost_responses_can_be_recovered_with_the_original_token()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);
        await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        await AuthTestClient.RefreshAsync(client, original.RefreshToken);

        var recovered = await AuthTestClient.RefreshAsync(client, original.RefreshToken);

        var parent = await ReadTokenAsync(bank, original.RefreshToken);
        var child = await ReadTokenAsync(bank, recovered.RefreshToken);
        parent.ReplacedById.Should().Be(child.Id);
        (await LiveCountAsync(bank, child.FamilyId)).Should().Be(1);
        (await FamilyRevokedCountAsync(bank, child.FamilyId)).Should().Be(0);
        (await AuthTestClient.RefreshAsync(client, recovered.RefreshToken)).User.Id.Should().Be(original.User.Id);
    }

    [Fact]
    public async Task Grace_window_never_extends_after_repeated_retries()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);
        await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        var newest = await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        await bank.ExecuteSqlAsync("UPDATE refresh_tokens SET revoked_at = now() - interval '61 seconds' WHERE token_hash = @hash;",
            ("hash", AuthTestClient.TokenHash(original.RefreshToken)));

        await AssertInvalidAsync(client, original.RefreshToken);

        var parent = await ReadTokenAsync(bank, original.RefreshToken);
        await AssertFamilyRevokedAsync(bank, parent.FamilyId, "reuse_detected");
        await AssertInvalidAsync(client, newest.RefreshToken);
    }

    [Fact]
    public async Task Reusing_an_expired_rotated_token_revokes_its_family_and_live_replacement()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);
        var replacement = await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        await bank.ExecuteSqlAsync("""
            UPDATE refresh_tokens
            SET expires_at = now() - interval '1 second', revoked_at = now() - interval '61 seconds'
            WHERE token_hash = @hash;
            """, ("hash", AuthTestClient.TokenHash(original.RefreshToken)));

        await AssertInvalidAsync(client, original.RefreshToken);

        var child = await ReadTokenAsync(bank, replacement.RefreshToken);
        child.RevokedAt.Should().NotBeNull();
        child.RevokedReason.Should().Be("reuse_detected");
        await AssertFamilyRevokedAsync(bank, child.FamilyId, "reuse_detected");
        await AssertInvalidAsync(client, replacement.RefreshToken);
    }

    [Fact]
    public async Task Reusing_a_parent_after_its_replacement_was_used_revokes_the_entire_family()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);
        var second = await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        var third = await AuthTestClient.RefreshAsync(client, second.RefreshToken);

        await AssertInvalidAsync(client, original.RefreshToken);

        await AssertFamilyRevokedAsync(bank, (await ReadTokenAsync(bank, original.RefreshToken)).FamilyId, "reuse_detected");
        await AssertInvalidAsync(client, third.RefreshToken);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Concurrent_normal_or_grace_refreshes_keep_one_live_token_without_revoking_family(bool alreadyRotated)
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var original = await AuthTestClient.RegisterAsync(client);
        if (alreadyRotated) await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var requests = Enumerable.Range(0, 2).Select(async _ =>
        {
            await start.Task;
            return await AuthTestClient.RefreshAsync(client, original.RefreshToken);
        }).ToArray();
        start.SetResult();

        var responses = await Task.WhenAll(requests);

        responses.Select(response => response.RefreshToken).Should().OnlyHaveUniqueItems();
        var parent = await ReadTokenAsync(bank, original.RefreshToken);
        (await LiveCountAsync(bank, parent.FamilyId)).Should().Be(1);
        (await FamilyRevokedCountAsync(bank, parent.FamilyId)).Should().Be(0);
        var responseIds = new[]
        {
            (await ReadTokenAsync(bank, responses[0].RefreshToken)).Id,
            (await ReadTokenAsync(bank, responses[1].RefreshToken)).Id
        };
        responseIds.Should().Contain(parent.ReplacedById!.Value);
    }

    [Fact]
    public async Task Logout_racing_rotation_never_leaves_a_live_token()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        for (var iteration = 0; iteration < 5; iteration++)
        {
            var original = await AuthTestClient.RegisterAsync(client);
            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var refresh = Task.Run(async () =>
            {
                await start.Task;
                return await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = original.RefreshToken });
            });
            var logout = Task.Run(async () =>
            {
                await start.Task;
                return await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Post, "/api/v1/auth/logout", original.AccessToken,
                    new { refreshToken = original.RefreshToken });
            });
            start.SetResult();
            using var refreshResponse = await refresh;
            using var logoutResponse = await logout;

            refreshResponse.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.Unauthorized);
            logoutResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);
            await AssertFamilyRevokedAsync(bank, (await ReadTokenAsync(bank, original.RefreshToken)).FamilyId, "logout");
        }
    }

    [Fact]
    public async Task Unknown_expired_and_logged_out_tokens_return_refresh_invalid()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        await AssertInvalidAsync(client, Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32)));
        var expired = await AuthTestClient.RegisterAsync(client);
        await bank.ExecuteSqlAsync("UPDATE refresh_tokens SET expires_at = now() - interval '1 second' WHERE token_hash = @hash;",
            ("hash", AuthTestClient.TokenHash(expired.RefreshToken)));
        await AssertInvalidAsync(client, expired.RefreshToken);
        var loggedOut = await AuthTestClient.RegisterAsync(client);
        using var logout = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Post, "/api/v1/auth/logout", loggedOut.AccessToken,
            new { refreshToken = loggedOut.RefreshToken });
        logout.StatusCode.Should().Be(HttpStatusCode.NoContent);
        await AssertInvalidAsync(client, loggedOut.RefreshToken);
    }

    [Fact]
    public async Task Revoking_one_session_does_not_revoke_another_session_for_the_same_user()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var first = await AuthTestClient.RegisterAsync(client);
        var otherSession = await AuthTestClient.LoginAsync(client, first.User.Email);
        await AuthTestClient.RefreshAsync(client, first.RefreshToken);
        await bank.ExecuteSqlAsync("UPDATE refresh_tokens SET revoked_at = now() - interval '61 seconds' WHERE token_hash = @hash;",
            ("hash", AuthTestClient.TokenHash(first.RefreshToken)));

        await AssertInvalidAsync(client, first.RefreshToken);

        (await AuthTestClient.RefreshAsync(client, otherSession.RefreshToken)).User.Id.Should().Be(first.User.Id);
    }

    [Fact]
    public async Task Logout_cannot_revoke_another_users_or_another_sessions_family()
    {
        await using var factory = new TransferApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();
        var first = await AuthTestClient.RegisterAsync(client);
        var second = await AuthTestClient.RegisterAsync(client);
        var anotherFirstSession = await AuthTestClient.LoginAsync(client, first.User.Email);
        foreach (var target in new[] { second, anotherFirstSession })
        {
            using var response = await AuthTestClient.SendAuthorizedAsync(client, HttpMethod.Post, "/api/v1/auth/logout", first.AccessToken,
                new { refreshToken = target.RefreshToken });
            response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
            (await AuthTestClient.ProblemCodeAsync(response)).Should().Be("forbidden");
            (await AuthTestClient.RefreshAsync(client, target.RefreshToken)).User.Id.Should().Be(target.User.Id);
        }
    }

    private static async Task AssertInvalidAsync(HttpClient client, string refreshToken)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        (await AuthTestClient.ProblemCodeAsync(response)).Should().Be("refresh_invalid");
    }

    private static Task<long> LiveCountAsync(LedgerTestBank bank, Guid familyId) => bank.ScalarAsync<long>(
        "SELECT COUNT(*) FROM refresh_tokens WHERE family_id = @family AND revoked_at IS NULL;", ("family", familyId));

    private static Task<long> FamilyRevokedCountAsync(LedgerTestBank bank, Guid familyId) => bank.ScalarAsync<long>(
        "SELECT COUNT(*) FROM refresh_token_families WHERE id = @family AND revoked_at IS NOT NULL;", ("family", familyId));

    private static async Task AssertFamilyRevokedAsync(LedgerTestBank bank, Guid familyId, string reason)
    {
        (await LiveCountAsync(bank, familyId)).Should().Be(0);
        (await bank.ScalarAsync<string>("SELECT revoked_reason FROM refresh_token_families WHERE id = @family;", ("family", familyId)))
            .Should().Be(reason);
    }

    private static async Task<TokenRow> ReadTokenAsync(LedgerTestBank bank, string token)
    {
        await using var connection = await bank.DataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT id, family_id, parent_id, revoked_at, revoked_reason, replaced_by_id FROM refresh_tokens WHERE token_hash = @hash;",
            connection);
        command.Parameters.AddWithValue("hash", AuthTestClient.TokenHash(token));
        await using var reader = await command.ExecuteReaderAsync();
        (await reader.ReadAsync()).Should().BeTrue();
        return new TokenRow(reader.GetGuid(0), reader.GetGuid(1), reader.IsDBNull(2) ? null : reader.GetGuid(2),
            reader.IsDBNull(3) ? null : reader.GetDateTime(3), reader.IsDBNull(4) ? null : reader.GetString(4),
            reader.IsDBNull(5) ? null : reader.GetGuid(5));
    }

    private sealed record TokenRow(Guid Id, Guid FamilyId, Guid? ParentId, DateTime? RevokedAt, string? RevokedReason, Guid? ReplacedById);
}
