using System.Net.Mail;
using Tetri.Core.Ledger;

namespace Tetri.Core.Auth;

public static class AuthValidation
{
    public const int MaximumEmailLength = 254;
    public const int MaximumDisplayNameLength = 80;
    public const int MinimumHandleLength = 3;
    public const int MaximumHandleLength = 24;
    public const int MinimumPasswordLength = 10;
    public const int MaximumPasswordLength = 128;

    public static string NormalizeEmail(string? email)
    {
        var normalized = email?.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(normalized) || normalized.Length > MaximumEmailLength
            || !MailAddress.TryCreate(normalized, out var address)
            || !string.Equals(address.Address, normalized, StringComparison.Ordinal))
        {
            throw new DomainException("invalid_email", "Enter a valid email address.", 400);
        }

        return normalized;
    }

    public static string NormalizeHandle(string? handle)
    {
        var name = handle?.Trim().ToLowerInvariant() ?? "";
        if (name.StartsWith('@'))
        {
            name = name[1..];
        }

        if (name.Length is < MinimumHandleLength or > MaximumHandleLength
            || name.Any(c => c is not (>= 'a' and <= 'z') and not (>= '0' and <= '9') and not '_'))
        {
            throw new DomainException("invalid_handle", "Use 3 to 24 letters, numbers or underscores for your handle.", 400);
        }

        return "@" + name;
    }

    public static string NormalizeDisplayName(string? displayName)
    {
        var normalized = displayName?.Trim();
        if (string.IsNullOrEmpty(normalized) || normalized.Length > MaximumDisplayNameLength
            || normalized.Any(char.IsControl))
        {
            throw new DomainException("invalid_request", "Enter a name between 1 and 80 characters.", 400);
        }

        return normalized;
    }

    public static void ValidatePassword(string? password)
    {
        if (password is null || password.Length is < MinimumPasswordLength or > MaximumPasswordLength)
        {
            throw new DomainException("invalid_password", "Use a password between 10 and 128 characters.", 400);
        }
    }
}
