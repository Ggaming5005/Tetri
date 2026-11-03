/// Money is always stored as integer minor units: 1050 means 10.50.
final class Money {
  const Money(this.minor, this.currency)
    : assert(currency == 'GEL' || currency == 'USD' || currency == 'EUR');

  final int minor;
  final String currency;

  @override
  bool operator ==(Object other) =>
      other is Money && minor == other.minor && currency == other.currency;

  @override
  int get hashCode => Object.hash(minor, currency);
}

final class MoneyAccount {
  const MoneyAccount({required this.id, required this.balance});

  final String id;
  final Money balance;
  String get currency => balance.currency;
}

final class MoneyParts {
  const MoneyParts(this.prefix, this.whole, this.fraction);

  final String prefix;
  final String whole;
  final String fraction;
  String get text => '$prefix$whole$fraction';
}

abstract final class MoneyFormat {
  static String symbol(String currency) => switch (currency) {
    'GEL' => '₾',
    'USD' => r'$',
    'EUR' => '€',
    _ => throw ArgumentError.value(currency, 'currency'),
  };

  static String flag(String currency) => switch (currency) {
    'GEL' => '🇬🇪',
    'USD' => '🇺🇸',
    'EUR' => '🇪🇺',
    _ => throw ArgumentError.value(currency, 'currency'),
  };

  static MoneyParts parts(Money amount, {bool showSign = false}) {
    // Work with decimal digits so even the signed 64-bit minimum is safe.
    final raw = amount.minor.toString();
    final negative = raw.startsWith('-');
    final digits = (negative ? raw.substring(1) : raw).padLeft(3, '0');
    final whole = digits.substring(0, digits.length - 2);
    final grouped = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
      grouped.write(whole[index]);
    }
    final sign = negative ? '-' : (showSign && amount.minor > 0 ? '+' : '');
    return MoneyParts(
      '$sign${symbol(amount.currency)}',
      grouped.toString(),
      '.${digits.substring(digits.length - 2)}',
    );
  }

  static String format(Money amount, {bool showSign = false}) =>
      parts(amount, showSign: showSign).text;

  static String semantics(Money amount, {bool showSign = false}) {
    final formatted = parts(amount, showSign: showSign);
    final sign = amount.minor < 0
        ? '-'
        : (showSign && amount.minor > 0 ? '+' : '');
    return '$sign${formatted.whole}${formatted.fraction} ${amount.currency}';
  }
}

/// Canonical decimal text for the amount keypad; no floating point arithmetic.
abstract final class MoneyInput {
  static const backspace = 'backspace';
  static final _pattern = RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]{0,2})?$');
  static final _maximumMinor = BigInt.parse('9223372036854775807');

  static String press(String value, String key) {
    final current = value.isEmpty ? '0' : value;
    _requireValid(current);
    if (key == backspace) {
      return current.length == 1
          ? '0'
          : current.substring(0, current.length - 1);
    }
    if (key == '.') return current.contains('.') ? current : '$current.';
    if (!RegExp(r'^[0-9]$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key');
    }
    final next = current == '0' ? key : '$current$key';
    return _valid(next) ? next : current;
  }

  static int minorUnits(String value) {
    final current = value.isEmpty ? '0' : value;
    _requireValid(current);
    return _minor(current).toInt();
  }

  static BigInt _minor(String value) {
    final parts = value.split('.');
    final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
    return BigInt.parse('${parts.first}$fraction');
  }

  static bool _valid(String value) =>
      _pattern.hasMatch(value) && _minor(value) <= _maximumMinor;

  static void _requireValid(String value) {
    if (!_valid(value)) {
      throw FormatException('Invalid minor-unit amount', value);
    }
  }
}
