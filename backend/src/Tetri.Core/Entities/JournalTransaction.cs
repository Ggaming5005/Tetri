namespace Tetri.Core.Entities;

public sealed class JournalTransaction
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public required string Kind { get; set; }
    public string Status { get; set; } = "posted";
    public Guid? InitiatedByUserId { get; set; }
    public required string Description { get; set; }
    public decimal? FxRate { get; set; }
    public Guid? QuoteId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
