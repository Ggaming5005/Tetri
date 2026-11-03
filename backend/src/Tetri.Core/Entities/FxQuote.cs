namespace Tetri.Core.Entities;

public sealed class FxQuote
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid UserId { get; set; }
    public required string FromCurrency { get; set; }
    public required string ToCurrency { get; set; }
    public long AmountIn { get; set; }
    public long GrossOut { get; set; }
    public long NetOut { get; set; }
    public long Fee { get; set; }
    public decimal Rate { get; set; }
    public DateOnly RateDate { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? UsedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
