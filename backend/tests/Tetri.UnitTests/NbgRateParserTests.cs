using System.Reflection;
using System.Text.Json;
using FluentAssertions;
using Tetri.Core.Fx;

namespace Tetri.UnitTests;

public sealed class NbgRateParserTests
{
    [Fact]
    public void Saved_official_feed_normalizes_quantities_and_uses_each_entry_effective_date()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(
            "Tetri.UnitTests.Fixtures.nbg-rates-2026-11-03.json")!;
        using var reader = new StreamReader(stream);
        var rates = NbgRateParser.Parse(reader.ReadToEnd());
        rates.Single(rate => rate.Currency == "USD").RateToGel.Should().Be(2.597m);
        rates.Single(rate => rate.Currency == "EUR").RateToGel.Should().Be(2.9047m);
        rates.Single(rate => rate.Currency == "JPY").RateToGel.Should().Be(0.016417m);
        rates.Should().OnlyContain(rate => rate.RateDate == new DateOnly(2026, 11, 4));
    }

    [Fact]
    public void Publication_timestamp_and_top_level_date_do_not_override_valid_from_date()
    {
        const string json = """
            [{"date":"2026-10-01T00:00:00Z","currencies":[
              {"code":"USD","rate":2.7,"quantity":1,"date":"2026-10-02T17:00:00Z","validFromDate":"2026-10-03T00:00:00Z"},
              {"code":"EUR","rate":30,"quantity":10,"date":"2026-10-02T17:00:00Z","validFromDate":"2026-10-04T00:00:00Z"}
            ]}]
            """;
        NbgRateParser.Parse(json).Should().Equal(
            new FxRateValue("USD", 2.7m, new DateOnly(2026, 10, 3)),
            new FxRateValue("EUR", 3m, new DateOnly(2026, 10, 4)));
    }

    [Theory]
    [InlineData(0, 2.7)]
    [InlineData(-1, 2.7)]
    [InlineData(1, 0)]
    [InlineData(1, -1)]
    public void Invalid_feed_values_are_rejected(int quantity, decimal rate)
    {
        var json = JsonSerializer.Serialize(new[] { new { currencies = new[]
        {
            new { code = "USD", quantity, rate, validFromDate = "2026-10-03T00:00:00Z" }
        } } });
        var act = () => NbgRateParser.Parse(json);
        act.Should().Throw<JsonException>();
    }
}
