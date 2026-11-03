namespace Tetri.Core.Entities;

public sealed class RefreshTokenFamily
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid UserId { get; set; }
    public DateTime? RevokedAt { get; set; }
    public string? RevokedReason { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
