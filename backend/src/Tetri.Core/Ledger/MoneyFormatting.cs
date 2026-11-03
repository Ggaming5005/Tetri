using System.Globalization;

namespace Tetri.Core.Ledger;

public static class MoneyFormatting
{
    public static bool IsSupportedCurrency(string? currency) => currency is "GEL" or "USD" or "EUR";

    public static string Format(MoneyAmount amount, bool showPositiveSign = false)
    {
        var symbol = amount.Currency switch
        {
            "GEL" => "₾",
            "USD" => "$",
            "EUR" => "€",
            _ => throw new ArgumentOutOfRangeException(nameof(amount), "The currency is not supported.")
        };

        // Negating long.MinValue overflows, so compute its unsigned magnitude in two steps.
        var magnitude = amount.Minor < 0
            ? (ulong)(-(amount.Minor + 1)) + 1
            : (ulong)amount.Minor;
        var sign = amount.Minor < 0 ? "-" : showPositiveSign && amount.Minor > 0 ? "+" : "";
        var whole = (magnitude / 100).ToString("N0", CultureInfo.InvariantCulture);
        var fraction = (magnitude % 100).ToString("D2", CultureInfo.InvariantCulture);
        return $"{sign}{symbol}{whole}.{fraction}";
    }

    public static bool TryParse(string? text, string currency, out MoneyAmount? amount)
    {
        amount = null;
        if (!IsSupportedCurrency(currency) || string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        var input = text.Trim();
        var sign = "";
        if (input[0] is '-' or '+')
        {
            sign = input[..1];
            input = input[1..];
        }

        var parts = input.Split('.');
        if (parts.Length > 2 || !IsDigits(parts[0])
            || (parts.Length == 2 && (parts[1].Length is < 1 or > 2 || !IsDigits(parts[1]))))
        {
            return false;
        }

        var fraction = parts.Length == 2 ? parts[1].PadRight(2, '0') : "00";
        if (!long.TryParse(sign + parts[0] + fraction, NumberStyles.AllowLeadingSign,
                CultureInfo.InvariantCulture, out var minor))
        {
            return false;
        }

        amount = new MoneyAmount(minor, currency);
        return true;
    }

    private static bool IsDigits(string value) => value.Length > 0 && value.All(c => c is >= '0' and <= '9');
}
