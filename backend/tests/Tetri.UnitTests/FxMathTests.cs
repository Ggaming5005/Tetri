using FluentAssertions;
using Tetri.Core.Fx;
using Tetri.Core.Ledger;

namespace Tetri.UnitTests;

public sealed class FxMathTests
{
    [Theory]
    [InlineData(2500, "2.7", 6750, 6716, 34)]
    [InlineData(1, "1.5", 1, 1, 0)]
    [InlineData(101, "0.333333", 33, 33, 0)]
    [InlineData(1_000_000_000_000, "2.7", 2_700_000_000_000, 2_686_500_000_000, 13_500_000_000)]
    [InlineData(long.MaxValue, "1", long.MaxValue, 9_177_255_176_670_501_927, 46_116_860_184_273_880)]
    public void Outputs_are_floored_in_integer_minor_units(long amount, string rate, long gross, long net, long fee)
    {
        var result = FxMath.Calculate(amount, decimal.Parse(rate, System.Globalization.CultureInfo.InvariantCulture), 0.005m);
        result.Should().Be(new FxCalculation(gross, net, fee));
        result.Fee.Should().Be(result.GrossOut - result.NetOut);
    }

    [Fact]
    public void Zero_net_output_is_rejected()
    {
        var act = () => FxMath.Calculate(1, 1m, 0.005m);
        act.Should().Throw<DomainException>().Which.Code.Should().Be("amount_too_small");
    }

    [Theory]
    [InlineData(2)]
    [InlineData(100000000000)]
    public void Output_overflow_is_a_domain_rejection(long rate)
    {
        var act = () => FxMath.Calculate(long.MaxValue, rate, 0.005m);
        act.Should().Throw<DomainException>().Which.Code.Should().Be("amount_too_large");
    }

    [Fact]
    public void Fee_is_the_difference_between_two_independent_floors()
    {
        for (var amount = 1; amount <= 10_000; amount++)
        {
            var result = FxMath.Calculate(amount, 2.597m, 0.005m);
            result.GrossOut.Should().Be((long)decimal.Floor(amount * 2.597m));
            result.NetOut.Should().Be((long)decimal.Floor(amount * 2.597m * 0.995m));
            result.Fee.Should().Be(result.GrossOut - result.NetOut);
        }
    }
}
