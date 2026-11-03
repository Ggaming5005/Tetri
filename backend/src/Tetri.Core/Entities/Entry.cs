namespace Tetri.Core.Entities;

public sealed class Entry
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid TransactionId { get; set; }
    public Guid AccountId { get; set; }
    public long Amount { get; set; }
    public required string Currency { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
