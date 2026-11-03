import '../../core/api_models.dart';
import '../../core/money.dart';

/// Rates remain decimal text until converted to an exact integer fraction.
Money? totalInGel(List<MoneyAccount> accounts, FxRates rates) {
  var numerator = BigInt.zero;
  var denominator = BigInt.one;
  for (final account in accounts) {
    var rateNumerator = BigInt.one;
    var rateDenominator = BigInt.one;
    if (account.currency != 'GEL') {
      final matches = rates.rates.where(
        (rate) => rate.currency == account.currency,
      );
      if (matches.isEmpty) return null;
      final rate = _decimalFraction(matches.first.rateToGel);
      if (rate == null) return null;
      (rateNumerator, rateDenominator) = rate;
    }
    numerator =
        numerator * rateDenominator +
        BigInt.from(account.balance.minor) * rateNumerator * denominator;
    denominator *= rateDenominator;
    final divisor = numerator.gcd(denominator);
    numerator ~/= divisor;
    denominator ~/= divisor;
  }
  final minor = numerator ~/ denominator;
  if (minor > BigInt.parse('9223372036854775807') || minor.isNegative) {
    return null;
  }
  return Money(minor.toInt(), 'GEL');
}

(BigInt, BigInt)? _decimalFraction(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
      .firstMatch(value);
  if (match == null) return null;
  final fraction = match[2] ?? '';
  final exponent = int.tryParse(match[3] ?? '0');
  if (exponent == null || exponent.abs() > 28 || fraction.length > 28) {
    return null;
  }
  var numerator = BigInt.parse('${match[1]}$fraction');
  var denominator = BigInt.from(10).pow(fraction.length);
  if (exponent >= 0) {
    numerator *= BigInt.from(10).pow(exponent);
  } else {
    denominator *= BigInt.from(10).pow(-exponent);
  }
  return numerator > BigInt.zero ? (numerator, denominator) : null;
}
