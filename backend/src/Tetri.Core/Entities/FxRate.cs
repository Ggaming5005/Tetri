namespace Tetri.Core.Entities;

public sealed class FxRate
{
    public required string Currency { get; set; }
    public decimal RateToGel { get; set; }
    public DateOnly RateDate { get; set; }
    public DateTime FetchedAt { get; set; } = DateTime.UtcNow;
}
