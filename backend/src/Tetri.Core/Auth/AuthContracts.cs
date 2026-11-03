namespace Tetri.Core.Auth;

public sealed record RegisterRequest(string Email, string DisplayName, string Handle, string Password);
public sealed record LoginRequest(string Email, string Password);
public sealed record RefreshRequest(string RefreshToken);
public sealed record AuthUser(Guid Id, string Email, string DisplayName, string Handle);
public sealed record AuthResponse(string AccessToken, string RefreshToken, DateTime ExpiresAt, AuthUser User);
public sealed record HandleAvailability(bool Available);
public sealed record AccessToken(string Value, DateTime ExpiresAt);
