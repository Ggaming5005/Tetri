using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using NpgsqlTypes;
using Tetri.Core.Auth;
using Tetri.Core.Entities;
using Tetri.Core.Ledger;

namespace Tetri.Infrastructure.Auth;

public sealed partial class AuthService
{
    private async Task<AuthResponse> CreateSessionAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, User user, AuditContext audit, CancellationToken ct)
    {
        var familyId = Guid.CreateVersion7();
        var now = Now();
        await using (var command = new NpgsqlCommand(
            "INSERT INTO refresh_token_families (id, user_id, created_at) VALUES (@id, @user, @created);",
            connection, transaction))
        {
            command.Parameters.AddWithValue("id", familyId);
            command.Parameters.AddWithValue("user", user.Id);
            command.Parameters.AddWithValue("created", now);
            await command.ExecuteNonQueryAsync(ct);
        }

        var refresh = await InsertRefreshTokenAsync(connection, transaction, user.Id, familyId, null, now, ct);
        await AuditAsync(connection, transaction, user.Id, "login", "refresh_token_family", familyId, audit, "{}", ct);
        return CreateResponse(user, familyId, refresh.Value);
    }

    private static async Task InsertUserAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, User user, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO users (id, email, display_name, handle, password_hash, created_at)
            VALUES (@id, @email, @display_name, @handle, @password_hash, @created_at);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", user.Id);
        command.Parameters.AddWithValue("email", user.Email);
        command.Parameters.AddWithValue("display_name", user.DisplayName);
        command.Parameters.AddWithValue("handle", user.Handle);
        command.Parameters.AddWithValue("password_hash", user.PasswordHash);
        command.Parameters.AddWithValue("created_at", user.CreatedAt);
        await command.ExecuteNonQueryAsync(ct);
    }

    private static async Task<User?> FindUserByEmailAsync(NpgsqlConnection connection, string email, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            "SELECT id, email, display_name, handle, password_hash, created_at FROM users WHERE email = @email;", connection);
        command.Parameters.AddWithValue("email", email);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? ReadUser(reader) : null;
    }

    private static async Task<User> ReadUserAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            "SELECT id, email, display_name, handle, password_hash, created_at FROM users WHERE id = @id;",
            connection, transaction);
        command.Parameters.AddWithValue("id", userId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? ReadUser(reader) : throw InvalidRefresh();
    }

    private static User ReadUser(NpgsqlDataReader reader) => new()
    {
        Id = reader.GetGuid(0),
        Email = reader.GetString(1),
        DisplayName = reader.GetString(2),
        Handle = reader.GetString(3),
        PasswordHash = reader.GetString(4),
        CreatedAt = reader.GetDateTime(5)
    };

    private static async Task UpdatePasswordHashAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, string hash, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            "UPDATE users SET password_hash = @hash WHERE id = @id;", connection, transaction);
        command.Parameters.AddWithValue("hash", hash);
        command.Parameters.AddWithValue("id", userId);
        await command.ExecuteNonQueryAsync(ct);
    }

    private static async Task<FamilyState> LockFamilyForTokenAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, string tokenHash, CancellationToken ct)
    {
        Guid familyId;
        await using (var lookup = new NpgsqlCommand(
            "SELECT family_id FROM refresh_tokens WHERE token_hash = @hash;", connection, transaction))
        {
            lookup.Parameters.AddWithValue("hash", tokenHash);
            familyId = await lookup.ExecuteScalarAsync(ct) is Guid found ? found : throw InvalidRefresh();
        }

        await using var command = new NpgsqlCommand(
            "SELECT id, user_id, revoked_at FROM refresh_token_families WHERE id = @id FOR UPDATE;",
            connection, transaction);
        command.Parameters.AddWithValue("id", familyId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
        {
            throw InvalidRefresh();
        }

        return new FamilyState(reader.GetGuid(0), reader.GetGuid(1), reader.IsDBNull(2) ? null : reader.GetDateTime(2));
    }

    private static async Task<TokenState?> ReadTokenAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, string hash, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT id, user_id, family_id, expires_at, revoked_at, revoked_reason, replaced_by_id
            FROM refresh_tokens WHERE token_hash = @hash;
            """, connection, transaction);
        command.Parameters.AddWithValue("hash", hash);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? ReadToken(reader) : null;
    }

    private static async Task<TokenState?> ReadTokenByIdAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid id, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            SELECT id, user_id, family_id, expires_at, revoked_at, revoked_reason, replaced_by_id
            FROM refresh_tokens WHERE id = @id;
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? ReadToken(reader) : null;
    }

    private static TokenState ReadToken(NpgsqlDataReader reader) => new(
        reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2), reader.GetDateTime(3),
        reader.IsDBNull(4) ? null : reader.GetDateTime(4), reader.IsDBNull(5) ? null : reader.GetString(5),
        reader.IsDBNull(6) ? null : reader.GetGuid(6));

    private static async Task<NewRefreshToken> InsertRefreshTokenAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid userId, Guid familyId,
        Guid? parentId, DateTime now, CancellationToken ct)
    {
        var id = Guid.CreateVersion7();
        var value = Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(32));
        var hash = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO refresh_tokens (id, user_id, token_hash, family_id, parent_id, expires_at, created_at)
            VALUES (@id, @user, @hash, @family, @parent, @expires, @created);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("hash", hash);
        command.Parameters.AddWithValue("family", familyId);
        command.Parameters.AddWithValue("parent", NpgsqlDbType.Uuid, (object?)parentId ?? DBNull.Value);
        command.Parameters.AddWithValue("expires", now.AddDays(30));
        command.Parameters.AddWithValue("created", now);
        await command.ExecuteNonQueryAsync(ct);
        return new NewRefreshToken(id, value);
    }

    private static async Task ReplaceTokenPointerAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, Guid tokenId, Guid replacementId, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            "UPDATE refresh_tokens SET replaced_by_id = @replacement WHERE id = @id;", connection, transaction);
        command.Parameters.AddWithValue("replacement", replacementId);
        command.Parameters.AddWithValue("id", tokenId);
        await command.ExecuteNonQueryAsync(ct);
    }

    private async Task RevokeTokenAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, TokenState token,
        string reason, AuditContext audit, DateTime now, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            UPDATE refresh_tokens SET revoked_at = @now, revoked_reason = @reason
            WHERE id = @id AND family_id = @family AND revoked_at IS NULL;
            """, connection, transaction);
        command.Parameters.AddWithValue("now", now);
        command.Parameters.AddWithValue("reason", reason);
        command.Parameters.AddWithValue("id", token.Id);
        command.Parameters.AddWithValue("family", token.FamilyId);
        if (await command.ExecuteNonQueryAsync(ct) != 1)
        {
            throw new InvalidOperationException("A refresh token changed while its session was locked.");
        }

        await AuditAsync(connection, transaction, token.UserId, "token_revoked", "refresh_token", token.Id,
            audit, JsonSerializer.Serialize(new { reason, familyId = token.FamilyId }), ct);
    }

    private async Task RevokeFamilyAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, FamilyState family,
        string reason, AuditContext audit, DateTime now, CancellationToken ct)
    {
        await using (var command = new NpgsqlCommand(
            "UPDATE refresh_token_families SET revoked_at = @now, revoked_reason = @reason WHERE id = @id;",
            connection, transaction))
        {
            command.Parameters.AddWithValue("now", now);
            command.Parameters.AddWithValue("reason", reason);
            command.Parameters.AddWithValue("id", family.Id);
            await command.ExecuteNonQueryAsync(ct);
        }

        var revokedIds = new List<Guid>();
        await using (var command = new NpgsqlCommand(
            """
            UPDATE refresh_tokens SET revoked_at = @now, revoked_reason = @reason
            WHERE family_id = @family AND revoked_at IS NULL RETURNING id;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("now", now);
            command.Parameters.AddWithValue("reason", reason);
            command.Parameters.AddWithValue("family", family.Id);
            await using var reader = await command.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                revokedIds.Add(reader.GetGuid(0));
            }
        }

        var details = JsonSerializer.Serialize(new { reason, familyId = family.Id });
        foreach (var id in revokedIds)
        {
            await AuditAsync(connection, transaction, family.UserId, "token_revoked", "refresh_token", id, audit, details, ct);
        }

        await AuditAsync(connection, transaction, family.UserId, "token_family_revoked", "refresh_token_family",
            family.Id, audit, details, ct);
    }

    private async Task AuditAsync(
        NpgsqlConnection connection, NpgsqlTransaction? transaction, Guid? userId,
        string action, string targetType, Guid? targetId, AuditContext audit, string details, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO audit_log (id, user_id, action, target_type, target_id, ip, user_agent, details, created_at)
            VALUES (@id, @user, @action, @target_type, @target, @ip, @agent, @details, @now);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", Guid.CreateVersion7());
        command.Parameters.AddWithValue("user", NpgsqlDbType.Uuid, (object?)userId ?? DBNull.Value);
        command.Parameters.AddWithValue("action", action);
        command.Parameters.AddWithValue("target_type", targetType);
        command.Parameters.AddWithValue("target", NpgsqlDbType.Uuid, (object?)targetId ?? DBNull.Value);
        command.Parameters.AddWithValue("ip", NpgsqlDbType.Text, (object?)audit.Ip ?? DBNull.Value);
        command.Parameters.AddWithValue("agent", NpgsqlDbType.Text, (object?)audit.UserAgent ?? DBNull.Value);
        command.Parameters.AddWithValue("details", NpgsqlDbType.Jsonb, details);
        command.Parameters.AddWithValue("now", Now());
        await command.ExecuteNonQueryAsync(ct);
    }
}
