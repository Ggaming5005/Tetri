namespace Tetri.Core.Auth;

public sealed class JwtOptions
{
    public string SigningKey { get; set; } = "";
    public string Issuer { get; set; } = "Tetri";
    public string Audience { get; set; } = "Tetri.Mobile";
}
