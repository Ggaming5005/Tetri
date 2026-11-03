using System.Text.Json;

namespace Tetri.Core.Fx;

public static class NbgRateParser
{
    public static IReadOnlyList<FxRateValue> Parse(string json)
    {
        using var document = JsonDocument.Parse(json);
        var rates = new List<FxRateValue>();
        foreach (var day in document.RootElement.EnumerateArray())
        {
            foreach (var entry in day.GetProperty("currencies").EnumerateArray())
            {
                var code = entry.GetProperty("code").GetString();
                var rate = entry.GetProperty("rate").GetDecimal();
                var quantity = entry.GetProperty("quantity").GetInt64();
                if (string.IsNullOrWhiteSpace(code) || rate <= 0 || quantity <= 0)
                    throw new JsonException("NBG supplied an invalid currency rate or quantity.");
                var date = entry.GetProperty("validFromDate").GetDateTimeOffset();
                rates.Add(new FxRateValue(code, rate / quantity, DateOnly.FromDateTime(date.UtcDateTime)));
            }
        }

        return rates;
    }
}
