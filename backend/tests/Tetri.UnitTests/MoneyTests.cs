using FluentAssertions;
using Tetri.Core.Ledger;

namespace Tetri.UnitTests;

public sealed class MoneyTests
{
    [Theory]
    [InlineData(123456, "GEL", "₾1,234.56")]
    [InlineData(123456, "USD", "$1,234.56")]
    [InlineData(123456, "EUR", "€1,234.56")]
    [InlineData(0, "GEL", "₾0.00")]
    [InlineData(1, "USD", "$0.01")]
    [InlineData(-1050, "EUR", "-€10.50")]
    [InlineData(long.MaxValue, "USD", "$92,233,720,368,547,758.07")]
    [InlineData(long.MinValue, "GEL", "-₾92,233,720,368,547,758.08")]
    public void Formats_minor_units_without_losing_precision(long minor, string currency, string expected)
    {
        MoneyFormatting.Format(new MoneyAmount(minor, currency)).Should().Be(expected);
    }

    [Theory]
    [InlineData(100, "+₾1.00")]
    [InlineData(-100, "-₾1.00")]
    [InlineData(0, "₾0.00")]
    public void Positive_sign_does_not_change_zero_or_negative_values(long minor, string expected)
    {
        MoneyFormatting.Format(new MoneyAmount(minor, "GEL"), showPositiveSign: true).Should().Be(expected);
    }

    [Theory]
    [InlineData("0", 0)]
    [InlineData("10", 1000)]
    [InlineData("10.5", 1050)]
    [InlineData("10.05", 1005)]
    [InlineData("-0.01", -1)]
    [InlineData(" +25.00 ", 2500)]
    [InlineData("92233720368547758.07", long.MaxValue)]
    [InlineData("-92233720368547758.08", long.MinValue)]
    public void Parses_invariant_decimal_text_using_only_integer_arithmetic(string text, long expected)
    {
        MoneyFormatting.TryParse(text, "GEL", out var amount).Should().BeTrue();
        amount.Should().Be(new MoneyAmount(expected, "GEL"));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData("1.001")]
    [InlineData("1.")]
    [InlineData(".50")]
    [InlineData("1,234.56")]
    [InlineData("₾1.00")]
    [InlineData("1e2")]
    [InlineData("NaN")]
    [InlineData("1.2.3")]
    [InlineData("--1")]
    [InlineData("+")]
    [InlineData("92233720368547758.08")]
    [InlineData("-92233720368547758.09")]
    public void Rejects_ambiguous_overprecise_and_out_of_range_input(string? text)
    {
        MoneyFormatting.TryParse(text, "USD", out var amount).Should().BeFalse();
        amount.Should().BeNull();
    }

    [Fact]
    public void Unsupported_currency_cannot_be_parsed_or_formatted()
    {
        MoneyFormatting.TryParse("1.00", "GBP", out _).Should().BeFalse();
        var format = () => MoneyFormatting.Format(new MoneyAmount(100, "GBP"));
        format.Should().Throw<ArgumentOutOfRangeException>();
    }
}
