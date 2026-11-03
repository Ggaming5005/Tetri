import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/money.dart';

void main() {
  group('Minor-unit formatting', () {
    test('all currencies, signs, cents and grouping', () {
      expect(MoneyFormat.format(const Money(123456, 'GEL')), '₾1,234.56');
      expect(MoneyFormat.format(const Money(123456, 'USD')), r'$1,234.56');
      expect(MoneyFormat.format(const Money(123456, 'EUR')), '€1,234.56');
      expect(MoneyFormat.format(const Money(-50, 'USD')), r'-$0.50');
      expect(
        MoneyFormat.format(const Money(50, 'EUR'), showSign: true),
        '+€0.50',
      );
      expect(
        MoneyFormat.format(const Money(0, 'GEL'), showSign: true),
        '₾0.00',
      );
      expect(MoneyFormat.format(const Money(1, 'GEL')), '₾0.01');
    });

    test('full signed 64-bit amounts retain every digit', () {
      expect(
        MoneyFormat.format(const Money(9223372036854775807, 'GEL')),
        '₾92,233,720,368,547,758.07',
      );
      expect(
        MoneyFormat.format(const Money(-9223372036854775808, 'USD')),
        r'-$92,233,720,368,547,758.08',
      );
    });

    test('account currency always agrees with its balance', () {
      const account = MoneyAccount(id: 'usd', balance: Money(1050, 'USD'));
      expect(account.currency, 'USD');
      expect(account.balance, const Money(1050, 'USD'));
    });
  });

  group('Amount input', () {
    test('prevents leading zeros and a second decimal point', () {
      expect(MoneyInput.press('0', '0'), '0');
      expect(MoneyInput.press('0', '5'), '5');
      expect(MoneyInput.press('', '.'), '0.');
      expect(MoneyInput.press('0.', '.'), '0.');
      expect(MoneyInput.press('12.3', '4'), '12.34');
      expect(MoneyInput.press('12.34', '5'), '12.34');
    });

    test('backspace remains canonical and clears to zero', () {
      expect(MoneyInput.press('12.34', MoneyInput.backspace), '12.3');
      expect(MoneyInput.press('12.', MoneyInput.backspace), '12');
      expect(MoneyInput.press('1', MoneyInput.backspace), '0');
      expect(MoneyInput.press('0', MoneyInput.backspace), '0');
    });

    test('parses exactly without floating point and bounds to Int64', () {
      expect(MoneyInput.minorUnits('0.29'), 29);
      expect(MoneyInput.minorUnits('10.'), 1000);
      expect(MoneyInput.minorUnits('10.5'), 1050);
      expect(
        MoneyInput.minorUnits('92233720368547758.07'),
        9223372036854775807,
      );
      expect(
        MoneyInput.press('92233720368547758.0', '8'),
        '92233720368547758.0',
      );
      expect(() => MoneyInput.minorUnits('01.00'), throwsFormatException);
      expect(() => MoneyInput.minorUnits('-1'), throwsFormatException);
    });
  });
}
