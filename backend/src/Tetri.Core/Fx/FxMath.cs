using Tetri.Core.Ledger;

namespace Tetri.Core.Fx;

public static class FxMath
{
    public static FxCalculation Calculate(long amountIn, decimal rate, decimal spread)
    {
        if (amountIn <= 0)
            throw new DomainException("invalid_amount", "Enter an amount greater than zero.", 400);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(rate);
        if (spread is < 0 or >= 1)
            throw new ArgumentOutOfRangeException(nameof(spread));

        try
        {
            var output = checked(amountIn * rate);
            var gross = checked((long)decimal.Floor(output));
            var net = checked((long)decimal.Floor(output * (1m - spread)));
            if (net <= 0)
                throw new DomainException("amount_too_small", "Enter a larger amount to convert.");
            return new FxCalculation(gross, net, checked(gross - net));
        }
        catch (OverflowException)
        {
            throw new DomainException("amount_too_large", "Enter a smaller amount to convert.");
        }
    }
}

public sealed record FxCalculation(long GrossOut, long NetOut, long Fee);
