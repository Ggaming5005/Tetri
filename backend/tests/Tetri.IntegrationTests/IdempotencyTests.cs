using System.Text.Json;
using FluentAssertions;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Idempotency;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class IdempotencyTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Identical_retry_returns_the_same_body_and_moves_money_once()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var request = RequestTo(recipient);
        var key = NewKey();

        var first = await bank.PostAsync(sender.Id, key, request);
        var retry = await bank.PostAsync(sender.Id, key, request);

        first.StatusCode.Should().Be(201);
        retry.Should().Be(first);
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_000);
        (await bank.BalanceAsync(recipient.Id)).Should().Be(1_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
        (await bank.TransferEntryCountAsync(sender.Id)).Should().Be(2);
    }

    [Fact]
    public async Task Reusing_a_key_with_a_different_body_is_rejected()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        await bank.PostAsync(sender.Id, key, RequestTo(recipient));

        var reused = await bank.PostAsync(sender.Id, key, RequestTo(recipient, 2_000));

        AssertProblem(reused, 422, "idempotency_key_reused");
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Reusing_a_key_on_a_different_endpoint_is_rejected()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        var request = RequestTo(recipient);
        await bank.PostAsync(sender.Id, key, request);

        var reused = await bank.PostAsync(sender.Id, key, request, endpoint: "/api/v1/conversions");

        AssertProblem(reused, 422, "idempotency_key_reused");
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Parallel_identical_requests_move_money_once_and_retry_resolves_the_result()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var request = RequestTo(recipient);
        var key = NewKey();
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var attempts = Enumerable.Range(0, 2).Select(async _ =>
        {
            await start.Task;
            return await bank.PostAsync(sender.Id, key, request);
        }).ToArray();

        start.SetResult();
        var responses = await Task.WhenAll(attempts);
        var final = await bank.PostAsync(sender.Id, key, request);

        responses.Should().Contain(response => response.StatusCode == 201);
        foreach (var response in responses)
        {
            if (response.StatusCode == 201)
            {
                response.Should().Be(final);
            }
            else
            {
                AssertProblem(response, 409, "request_in_progress");
            }
        }

        final.StatusCode.Should().Be(201);
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Insufficient_funds_is_cached_even_after_the_account_is_funded()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(0);
        var recipient = await bank.CreateUserAsync(0);
        var request = RequestTo(recipient);
        var key = NewKey();
        var rejected = await bank.PostAsync(sender.Id, key, request);
        AssertProblem(rejected, 422, "insufficient_funds");
        await bank.TopUpAsync(sender.Id, 2_000);

        (await bank.PostAsync(sender.Id, key, request)).Should().Be(rejected);
        (await bank.BalanceAsync(sender.Id)).Should().Be(2_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(0);
        (await bank.PostAsync(sender.Id, NewKey(), request)).StatusCode.Should().Be(201);
        (await bank.BalanceAsync(sender.Id)).Should().Be(1_000);
    }

    [Fact]
    public async Task Stale_claim_is_taken_over_and_completed()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var request = RequestTo(recipient);
        var key = NewKey();
        await bank.ExecuteSqlAsync(
            """
            INSERT INTO idempotency_keys
                (user_id, key, endpoint, request_hash, status, attempt_token, locked_until)
            VALUES (@user, @key, '/api/v1/transfers', @hash, 'in_progress', @attempt, now() - interval '1 minute');
            """, ("user", sender.Id), ("key", key), ("hash", LedgerTestBank.RequestHash(request)),
            ("attempt", Guid.CreateVersion7()));

        var result = await bank.PostAsync(sender.Id, key, request);

        result.StatusCode.Should().Be(201);
        (await bank.PostAsync(sender.Id, key, request)).Should().Be(result);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
    }

    [Fact]
    public async Task Worker_paused_after_claim_cannot_post_after_another_worker_takes_over()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        var request = RequestTo(recipient);
        var hooks = new PausingIdempotencyHooks(IdempotencyPausePoint.AfterClaim);
        var workerA = bank.PostAsync(sender.Id, key, request, bank.CreateIdempotency(hooks));
        StoredResponse winner;
        try
        {
            await hooks.WaitUntilPausedAsync(IdempotencyPausePoint.AfterClaim);
            (await bank.ExpireClaimAsync(sender.Id, key)).Should().Be(1);
            winner = await bank.PostAsync(sender.Id, key, request);
            winner.StatusCode.Should().Be(201);
        }
        finally
        {
            hooks.ReleaseAll();
        }

        (await workerA.WaitAsync(TimeSpan.FromSeconds(15))).Should().Be(winner);
        (await bank.PostAsync(sender.Id, key, request)).Should().Be(winner);
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Money_transaction_lock_blocks_takeover_even_after_claim_expiry()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        var request = RequestTo(recipient);
        var hooks = new PausingIdempotencyHooks(IdempotencyPausePoint.AfterClaim, IdempotencyPausePoint.BeforeCommit);
        var workerA = bank.PostAsync(sender.Id, key, request, bank.CreateIdempotency(hooks));
        try
        {
            await hooks.WaitUntilPausedAsync(IdempotencyPausePoint.AfterClaim);
            (await bank.ExpireClaimAsync(sender.Id, key)).Should().Be(1);
            hooks.Release(IdempotencyPausePoint.AfterClaim);
            await hooks.WaitUntilPausedAsync(IdempotencyPausePoint.BeforeCommit);

            var blocked = await bank.PostAsync(sender.Id, key, request).WaitAsync(TimeSpan.FromSeconds(15));

            AssertProblem(blocked, 409, "request_in_progress");
            (await bank.BalanceAsync(sender.Id)).Should().Be(10_000, "worker A has not committed yet");
        }
        finally
        {
            hooks.ReleaseAll();
        }

        var winner = await workerA.WaitAsync(TimeSpan.FromSeconds(15));
        winner.StatusCode.Should().Be(201);
        (await bank.PostAsync(sender.Id, key, request)).Should().Be(winner);
        (await bank.BalanceAsync(sender.Id)).Should().Be(9_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Stale_rejection_cannot_overwrite_a_newer_success()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(0);
        var recipient = await bank.CreateUserAsync(0);
        var key = NewKey();
        var request = RequestTo(recipient);
        var hooks = new PausingIdempotencyHooks(IdempotencyPausePoint.BeforeRejection);
        var workerA = bank.PostAsync(sender.Id, key, request, bank.CreateIdempotency(hooks));
        StoredResponse winner;
        try
        {
            await hooks.WaitUntilPausedAsync(IdempotencyPausePoint.BeforeRejection);
            (await bank.ExpireClaimAsync(sender.Id, key)).Should().Be(1);
            await bank.TopUpAsync(sender.Id, 2_000);
            winner = await bank.PostAsync(sender.Id, key, request);
            winner.StatusCode.Should().Be(201);
        }
        finally
        {
            hooks.ReleaseAll();
        }

        (await workerA.WaitAsync(TimeSpan.FromSeconds(15))).Should().Be(winner);
        (await bank.PostAsync(sender.Id, key, request)).Should().Be(winner);
        (await bank.BalanceAsync(sender.Id)).Should().Be(1_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Unexpected_failure_after_ledger_writes_rolls_back_and_can_be_retried()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var request = RequestTo(recipient);
        var key = NewKey();
        var idempotency = bank.CreateIdempotency();

        await Assert.ThrowsAsync<InvalidOperationException>(() => idempotency.ExecuteAsync(
            sender.Id, key, "/api/v1/transfers", LedgerTestBank.RequestHash(request),
            async (connection, transaction, cancellationToken) =>
            {
                await bank.Ledger.TransferAsync(connection, transaction, sender.Id, request, LedgerTestBank.Audit, cancellationToken);
                throw new InvalidOperationException("Simulated crash before commit.");
            }, CancellationToken.None));

        (await bank.BalanceAsync(sender.Id)).Should().Be(10_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(0);
        (await bank.ScalarAsync<string>(
            "SELECT status FROM idempotency_keys WHERE user_id = @user AND key = @key;", ("user", sender.Id), ("key", key)))
            .Should().Be("in_progress");
        await bank.ExpireClaimAsync(sender.Id, key);
        (await bank.PostAsync(sender.Id, key, request)).StatusCode.Should().Be(201);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(1);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Cleanup_removes_only_expired_keys_without_touching_the_ledger()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);
        var request = RequestTo(recipient);
        var oldKey = NewKey();
        var recentKey = NewKey();
        await bank.PostAsync(sender.Id, oldKey, request);
        await bank.PostAsync(sender.Id, recentKey, request);
        await bank.ExecuteSqlAsync(
            "UPDATE idempotency_keys SET created_at = now() - interval '25 hours' WHERE user_id = @user AND key = @key;",
            ("user", sender.Id), ("key", oldKey));

        (await bank.CreateIdempotency().CleanupAsync()).Should().Be(1);

        (await bank.ScalarAsync<long>(
            "SELECT COUNT(*) FROM idempotency_keys WHERE user_id = @user AND key = @key;", ("user", sender.Id), ("key", oldKey)))
            .Should().Be(0);
        (await bank.ScalarAsync<long>(
            "SELECT COUNT(*) FROM idempotency_keys WHERE user_id = @user AND key = @key;", ("user", sender.Id), ("key", recentKey)))
            .Should().Be(1);
        (await bank.BalanceAsync(sender.Id)).Should().Be(8_000);
        (await bank.TransferCountAsync(sender.Id)).Should().Be(2);
    }

    private static string NewKey() => Guid.CreateVersion7().ToString("D");
    private static TransferRequest RequestTo(TestUser recipient, long amount = 1_000) =>
        new(recipient.Handle, new MoneyAmount(amount, "GEL"));

    private static void AssertProblem(StoredResponse response, int statusCode, string code)
    {
        response.StatusCode.Should().Be(statusCode);
        using var document = JsonDocument.Parse(response.Body);
        document.RootElement.GetProperty("code").GetString().Should().Be(code);
    }
}
