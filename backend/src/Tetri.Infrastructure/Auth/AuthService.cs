using System.Data;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using Tetri.Core.Auth;
using Tetri.Core.Entities;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Ledger;

namespace Tetri.Infrastructure.Auth;

public sealed partial class AuthService(
    NpgsqlDataSource dataSource,
    LedgerService ledger,
    JwtTokenService jwt,
    IPasswordHasher<User> passwordHasher,
    TimeProvider timeProvider)
{
    private static readonly User DummyUser = new()
    {
        Email = "unused@example.invalid",
        DisplayName = "Unused",
        Handle = "@unused",
        PasswordHash = ""
    };
    private static readonly Lazy<string> DummyPasswordHash = new(() =>
        new PasswordHasher<User>().HashPassword(DummyUser, Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))));

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, AuditContext audit, CancellationToken ct)
    {
        var user = new User
        {
            Email = AuthValidation.NormalizeEmail(request.Email),
            DisplayName = AuthValidation.NormalizeDisplayName(request.DisplayName),
            Handle = AuthValidation.NormalizeHandle(request.Handle),
            PasswordHash = "",
            CreatedAt = Now()
        };
        AuthValidation.ValidatePassword(request.Password);
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);

        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        try
        {
            await InsertUserAsync(connection, transaction, user, ct);
            await ledger.GrantStarterBalancesAsync(connection, transaction, user.Id, ct);
            var response = await CreateSessionAsync(connection, transaction, user, audit, ct);
            await AuditAsync(connection, transaction, user.Id, "register", "user", user.Id, audit, "{}", ct);
            await transaction.CommitAsync(ct);
            return response;
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation
                                                   && exception.ConstraintName is "ux_users_email" or "ux_users_handle")
        {
            await transaction.RollbackAsync(ct);
            throw exception.ConstraintName == "ux_users_handle"
                ? new DomainException("handle_taken", "That handle is taken. Choose another one.", 409)
                : new DomainException("email_taken", "An account already uses this email. Sign in instead.", 409);
        }
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, AuditContext audit, CancellationToken ct)
    {
        var email = AuthValidation.NormalizeEmail(request.Email);
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        var user = await FindUserByEmailAsync(connection, email, ct);
        var password = request.Password ?? "";
        var verification = PasswordVerificationResult.Failed;
        if (password.Length <= AuthValidation.MaximumPasswordLength)
        {
            // Unknown emails still perform password hashing rather than exposing a fast rejection path.
            verification = passwordHasher.VerifyHashedPassword(user ?? DummyUser,
                user?.PasswordHash ?? DummyPasswordHash.Value, password);
        }

        if (user is null || verification == PasswordVerificationResult.Failed)
        {
            await AuditAsync(connection, null, user?.Id, "login_failed", "user", user?.Id, audit, "{}", ct);
            throw new DomainException("invalid_credentials", "Check your email and password, then try again.", 401);
        }

        await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        if (verification == PasswordVerificationResult.SuccessRehashNeeded)
        {
            await UpdatePasswordHashAsync(connection, transaction, user.Id,
                passwordHasher.HashPassword(user, password), ct);
        }

        var response = await CreateSessionAsync(connection, transaction, user, audit, ct);
        await transaction.CommitAsync(ct);
        return response;
    }

    public async Task<AuthResponse> RefreshAsync(RefreshRequest request, AuditContext audit, CancellationToken ct)
    {
        var tokenHash = HashPresentedToken(request.RefreshToken);
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        var family = await LockFamilyForTokenAsync(connection, transaction, tokenHash, ct);
        var token = await ReadTokenAsync(connection, transaction, tokenHash, ct) ?? throw InvalidRefresh();
        var now = Now();
        if (family.RevokedAt is not null)
        {
            throw InvalidRefresh();
        }

        if (token.RevokedAt is null)
        {
            if (token.ExpiresAt <= now)
            {
                throw InvalidRefresh();
            }

            await RevokeTokenAsync(connection, transaction, token, "rotated", audit, now, ct);
        }
        else if (token.ExpiresAt > now && token.RevokedReason == "rotated" && now >= token.RevokedAt
                 && now - token.RevokedAt.Value < TimeSpan.FromSeconds(60)
                 && token.ReplacedById is Guid replacementId
                 && await ReadTokenByIdAsync(connection, transaction, replacementId, ct) is { RevokedAt: null } replacement
                 && replacement.FamilyId == family.Id && replacement.ExpiresAt > now)
        {
            await RevokeTokenAsync(connection, transaction, replacement, "retry_superseded", audit, now, ct);
        }
        else
        {
            await RevokeFamilyAsync(connection, transaction, family, "reuse_detected", audit, now, ct);
            await transaction.CommitAsync(ct);
            throw InvalidRefresh();
        }

        var user = await ReadUserAsync(connection, transaction, family.UserId, ct);
        var refresh = await InsertRefreshTokenAsync(connection, transaction, user.Id, family.Id, token.Id, now, ct);
        await ReplaceTokenPointerAsync(connection, transaction, token.Id, refresh.Id, ct);
        var response = CreateResponse(user, family.Id, refresh.Value);
        await transaction.CommitAsync(ct);
        return response;
    }

    public async Task LogoutAsync(Guid userId, Guid familyId, RefreshRequest request, AuditContext audit, CancellationToken ct)
    {
        var tokenHash = HashPresentedToken(request.RefreshToken);
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        var family = await LockFamilyForTokenAsync(connection, transaction, tokenHash, ct);
        if (family.UserId != userId || family.Id != familyId)
        {
            throw new DomainException("forbidden", "Use the refresh token for your current session.", 403);
        }

        _ = await ReadTokenAsync(connection, transaction, tokenHash, ct) ?? throw InvalidRefresh();
        if (family.RevokedAt is not null)
        {
            throw InvalidRefresh();
        }

        await RevokeFamilyAsync(connection, transaction, family, "logout", audit, Now(), ct);
        await transaction.CommitAsync(ct);
    }

    public async Task<HandleAvailability> HandleAvailableAsync(string handle, CancellationToken ct)
    {
        var normalized = AuthValidation.NormalizeHandle(handle);
        await using var command = dataSource.CreateCommand("SELECT EXISTS (SELECT 1 FROM users WHERE handle = @handle);");
        command.Parameters.AddWithValue("handle", normalized);
        var exists = (bool)(await command.ExecuteScalarAsync(ct))!;
        return new HandleAvailability(!exists);
    }

    private AuthResponse CreateResponse(User user, Guid familyId, string refreshToken)
    {
        var access = jwt.Create(user, familyId);
        return new AuthResponse(access.Value, refreshToken, access.ExpiresAt,
            new AuthUser(user.Id, user.Email, user.DisplayName, user.Handle));
    }

    private DateTime Now()
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        return new DateTime(now.Ticks - now.Ticks % 10, DateTimeKind.Utc);
    }

    private static string HashPresentedToken(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 256)
        {
            throw InvalidRefresh();
        }

        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    }

    private static DomainException InvalidRefresh() =>
        new("refresh_invalid", "Your session has ended. Sign in again.", 401);

    private sealed record FamilyState(Guid Id, Guid UserId, DateTime? RevokedAt);
    private sealed record TokenState(Guid Id, Guid UserId, Guid FamilyId, DateTime ExpiresAt,
        DateTime? RevokedAt, string? RevokedReason, Guid? ReplacedById);
    private sealed record NewRefreshToken(Guid Id, string Value);
}
