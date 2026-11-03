using System.Data;
using System.Text.Json;
using Npgsql;
using NpgsqlTypes;
using Tetri.Core.Idempotency;
using Tetri.Core.Ledger;

namespace Tetri.Infrastructure.Idempotency;

public sealed class IdempotencyService(
    NpgsqlDataSource dataSource,
    IIdempotencyTestHooks hooks,
    TimeProvider timeProvider)
{
    private static readonly TimeSpan ClaimDuration = TimeSpan.FromSeconds(30);

    public async Task<StoredResponse> ExecuteAsync(
        Guid userId,
        string key,
        string endpoint,
        string requestHash,
        Func<NpgsqlConnection, NpgsqlTransaction, CancellationToken, Task<StoredResponse>> execute,
        CancellationToken cancellationToken = default)
    {
        if (!Guid.TryParse(key, out var parsedKey))
        {
            throw new DomainException("invalid_idempotency_key", "Provide a UUID Idempotency-Key header.", 400);
        }

        key = parsedKey.ToString("D");
        var attemptToken = Guid.CreateVersion7();
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        var existingResponse = await ClaimAsync(
            connection, userId, key, endpoint, requestHash, attemptToken, cancellationToken);
        if (existingResponse is not null)
        {
            return existingResponse;
        }

        await hooks.AfterClaimAsync(userId, key, attemptToken, cancellationToken);
        StoredResponse rejection;
        await using (var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken))
        {
            if (!await LockOwnedClaimAsync(connection, transaction, userId, key, attemptToken, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return await ReadOutcomeAsync(connection, userId, key, endpoint, requestHash, cancellationToken);
            }

            try
            {
                var response = await execute(connection, transaction, cancellationToken);
                var storedResponse = await CompleteAsync(
                    connection, transaction, userId, key, attemptToken, response, cancellationToken);
                if (storedResponse is null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return await ReadOutcomeAsync(connection, userId, key, endpoint, requestHash, cancellationToken);
                }

                await hooks.BeforeCommitAsync(userId, key, attemptToken, cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return storedResponse;
            }
            catch (DomainException exception) when (exception.StatusCode is > 400 and < 500)
            {
                await transaction.RollbackAsync(cancellationToken);
                rejection = Problem(exception.StatusCode, exception.Code, exception.Message);
            }
        }

        await hooks.BeforeRejectionAsync(userId, key, attemptToken, cancellationToken);
        await using (var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken))
        {
            var storedResponse = await CompleteAsync(
                connection, transaction, userId, key, attemptToken, rejection, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            if (storedResponse is not null)
            {
                return storedResponse;
            }
        }

        return await ReadOutcomeAsync(connection, userId, key, endpoint, requestHash, cancellationToken);
    }

    public async Task<int> CleanupAsync(CancellationToken cancellationToken = default)
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            """
            WITH expired AS (
                SELECT user_id, key
                FROM idempotency_keys
                WHERE created_at <= @cutoff
                  AND (status = 'completed' OR locked_until <= @now)
                FOR UPDATE SKIP LOCKED
            )
            DELETE FROM idempotency_keys AS k
            USING expired AS e
            WHERE k.user_id = e.user_id AND k.key = e.key;
            """, connection);
        command.Parameters.AddWithValue("cutoff", now.AddHours(-24));
        command.Parameters.AddWithValue("now", now);
        return await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task<StoredResponse?> ClaimAsync(
        NpgsqlConnection connection,
        Guid userId,
        string key,
        string endpoint,
        string requestHash,
        Guid attemptToken,
        CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        await using (var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken))
        {
            try
            {
                // Unique-conflict detection can also wait while another worker completes the existing key.
                await using var timeout = new NpgsqlCommand("SET LOCAL lock_timeout = '2s';", connection, transaction);
                await timeout.ExecuteNonQueryAsync(cancellationToken);
                await using var command = new NpgsqlCommand(
                    """
                    INSERT INTO idempotency_keys
                        (user_id, key, endpoint, request_hash, status, attempt_token, locked_until, created_at)
                    VALUES (@user_id, @key, @endpoint, @request_hash, 'in_progress', @attempt_token, @locked_until, @now)
                    ON CONFLICT (user_id, key) DO NOTHING;
                    """, connection, transaction);
                AddIdentity(command, userId, key);
                command.Parameters.AddWithValue("endpoint", endpoint);
                command.Parameters.AddWithValue("request_hash", requestHash);
                command.Parameters.AddWithValue("attempt_token", attemptToken);
                command.Parameters.AddWithValue("locked_until", now.Add(ClaimDuration));
                command.Parameters.AddWithValue("now", now);
                var inserted = await command.ExecuteNonQueryAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                if (inserted == 1)
                {
                    return null;
                }
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.LockNotAvailable)
            {
                await transaction.RollbackAsync(cancellationToken);
                return await ReadOutcomeAsync(connection, userId, key, endpoint, requestHash, cancellationToken);
            }
        }

        var claim = await ReadClaimAsync(connection, userId, key, cancellationToken);
        var response = ExistingOutcome(claim, endpoint, requestHash);
        if (response is not null)
        {
            return response;
        }

        now = timeProvider.GetUtcNow().UtcDateTime;
        if (claim!.LockedUntil > now)
        {
            return InProgress();
        }

        await using (var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken))
        {
            try
            {
                await using var timeout = new NpgsqlCommand("SET LOCAL lock_timeout = '2s';", connection, transaction);
                await timeout.ExecuteNonQueryAsync(cancellationToken);
                await using var command = new NpgsqlCommand(
                    """
                    UPDATE idempotency_keys
                    SET attempt_token = @attempt_token, locked_until = @locked_until
                    WHERE user_id = @user_id AND key = @key
                      AND endpoint = @endpoint AND request_hash = @request_hash
                      AND status = 'in_progress' AND locked_until <= @now;
                    """, connection, transaction);
                AddIdentity(command, userId, key);
                command.Parameters.AddWithValue("endpoint", endpoint);
                command.Parameters.AddWithValue("request_hash", requestHash);
                command.Parameters.AddWithValue("attempt_token", attemptToken);
                command.Parameters.AddWithValue("locked_until", now.Add(ClaimDuration));
                command.Parameters.AddWithValue("now", now);
                var updated = await command.ExecuteNonQueryAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                if (updated == 1)
                {
                    return null;
                }
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.LockNotAvailable)
            {
                // A lock timeout aborts the transaction; the outcome must be read after rollback.
                await transaction.RollbackAsync(cancellationToken);
            }
        }

        return await ReadOutcomeAsync(connection, userId, key, endpoint, requestHash, cancellationToken);
    }

    private static async Task<bool> LockOwnedClaimAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid userId,
        string key,
        Guid attemptToken,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT 1 FROM idempotency_keys
            WHERE user_id = @user_id AND key = @key
              AND status = 'in_progress' AND attempt_token = @attempt_token
            FOR UPDATE;
            """, connection, transaction);
        AddIdentity(command, userId, key);
        command.Parameters.AddWithValue("attempt_token", attemptToken);
        return await command.ExecuteScalarAsync(cancellationToken) is not null;
    }

    private static async Task<StoredResponse?> CompleteAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid userId,
        string key,
        Guid attemptToken,
        StoredResponse response,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            """
            UPDATE idempotency_keys
            SET status = 'completed', response_status = @response_status, response_body = @response_body
            WHERE user_id = @user_id AND key = @key
              AND status = 'in_progress' AND attempt_token = @attempt_token
            RETURNING response_body::text;
            """, connection, transaction);
        AddIdentity(command, userId, key);
        command.Parameters.AddWithValue("attempt_token", attemptToken);
        command.Parameters.AddWithValue("response_status", response.StatusCode);
        command.Parameters.AddWithValue("response_body", NpgsqlDbType.Jsonb, CanonicalJson.Canonicalize(response.Body));
        var body = await command.ExecuteScalarAsync(cancellationToken) as string;
        // Both the first response and replay use PostgreSQL's numeric representation and canonical key order.
        return body is null ? null : new StoredResponse(response.StatusCode, CanonicalJson.Canonicalize(body));
    }

    private static async Task<StoredResponse> ReadOutcomeAsync(
        NpgsqlConnection connection,
        Guid userId,
        string key,
        string endpoint,
        string requestHash,
        CancellationToken cancellationToken)
    {
        var claim = await ReadClaimAsync(connection, userId, key, cancellationToken);
        return ExistingOutcome(claim, endpoint, requestHash) ?? InProgress();
    }

    private static async Task<Claim?> ReadClaimAsync(
        NpgsqlConnection connection,
        Guid userId,
        string key,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT endpoint, request_hash, status, locked_until, response_status, response_body::text
            FROM idempotency_keys
            WHERE user_id = @user_id AND key = @key;
            """, connection);
        AddIdentity(command, userId, key);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new Claim(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetDateTime(3),
            reader.IsDBNull(4) ? null : reader.GetInt32(4), reader.IsDBNull(5) ? null : reader.GetString(5));
    }

    private static StoredResponse? ExistingOutcome(Claim? claim, string endpoint, string requestHash)
    {
        if (claim is null)
        {
            return InProgress();
        }

        if (claim.Endpoint != endpoint || claim.RequestHash != requestHash)
        {
            return Problem(422, "idempotency_key_reused", "Use a new Idempotency-Key for a different request.");
        }

        return claim.Status == "completed"
            ? new StoredResponse(claim.ResponseStatus!.Value, CanonicalJson.Canonicalize(claim.ResponseBody!))
            : null;
    }

    private static StoredResponse InProgress() =>
        Problem(409, "request_in_progress", "This request is still being processed. Retry with the same Idempotency-Key.");

    private static StoredResponse Problem(int status, string code, string message) => new(status,
        CanonicalJson.Canonicalize(JsonSerializer.Serialize(new { type = "about:blank", title = message, status, code })));

    private static void AddIdentity(NpgsqlCommand command, Guid userId, string key)
    {
        command.Parameters.AddWithValue("user_id", userId);
        command.Parameters.AddWithValue("key", key);
    }

    private sealed record Claim(
        string Endpoint, string RequestHash, string Status, DateTime LockedUntil,
        int? ResponseStatus, string? ResponseBody);
}
