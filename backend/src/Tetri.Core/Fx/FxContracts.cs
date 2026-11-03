using Tetri.Core.Ledger;

namespace Tetri.Core.Fx;

public sealed class FxOptions
{
    public decimal Spread { get; set; } = 0.005m;
    public bool FetchEnabled { get; set; } = true;
    public double RefreshHours { get; set; } = 6;
}

public sealed record FxRateValue(string Currency, decimal RateToGel, DateOnly RateDate);
public sealed record FxRatesResponse(IReadOnlyList<FxRateValue> Rates, decimal Spread);
public sealed record FxQuoteRequest(MoneyAmount Amount, string ToCurrency);
public sealed record FxQuoteResponse(Guid QuoteId, MoneyAmount AmountIn, MoneyAmount NetOut,
    MoneyAmount Fee, decimal Rate, DateOnly RateDate, DateTime ExpiresAt);
public sealed record ConversionRequest(Guid QuoteId);
public sealed record ConversionReceipt(Guid TransactionId, Guid QuoteId, MoneyAmount AmountIn,
    MoneyAmount NetOut, MoneyAmount Fee, decimal Rate, DateOnly RateDate, DateTime CreatedAt);
