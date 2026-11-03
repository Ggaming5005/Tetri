namespace Tetri.Core.Entities;

public sealed class Account
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid? OwnerUserId { get; set; }
    public required string Kind { get; set; }
    public required string Currency { get; set; }
    public long Balance { get; set; }
    public long Version { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
