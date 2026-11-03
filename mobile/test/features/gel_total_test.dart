import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/features/home/gel_total.dart';

import '../helpers/banking_fakes.dart';

void main() {
  test('total uses exact decimal rates across all three accounts', () {
    expect(totalInGel(sampleAccounts, sampleRates), const Money(271000, 'GEL'));
  });
  test('total floors the exact sum instead of rounding each account first', () {
    final rates = FxRates(
      rates: [
        FxRate(currency: 'USD', rateToGel: '1.6', rateDate: DateTime(2024)),
        FxRate(currency: 'EUR', rateToGel: '1.6', rateDate: DateTime(2024)),
      ],
      spread: '0.005',
    );
    expect(
      totalInGel(const [
        MoneyAccount(id: 'a', balance: Money(1, 'USD')),
        MoneyAccount(id: 'b', balance: Money(1, 'EUR')),
      ], rates),
      const Money(3, 'GEL'),
    );
  });
  test('large balances do not pass through floating point', () {
    final rates = FxRates(
      rates: [
        FxRate(
          currency: 'USD',
          rateToGel: '1.000000000000000001',
          rateDate: DateTime(2024),
        ),
      ],
      spread: '0.005',
    );
    expect(
      totalInGel(const [
        MoneyAccount(id: 'a', balance: Money(9007199254740993, 'USD')),
      ], rates),
      const Money(9007199254740993, 'GEL'),
    );
  });
  test('missing, invalid or overflowing rates leave the total unavailable', () {
    expect(
      totalInGel(sampleAccounts, const FxRates(rates: [], spread: '0.005')),
      isNull,
    );
    for (final value in ['bad', '-1', '0', '1e300']) {
      expect(
        totalInGel(
          const [MoneyAccount(id: 'a', balance: Money(1, 'USD'))],
          FxRates(
            rates: [
              FxRate(
                currency: 'USD',
                rateToGel: value,
                rateDate: DateTime(2024),
              ),
            ],
            spread: '0.005',
          ),
        ),
        isNull,
      );
    }
    expect(
      totalInGel(const [
        MoneyAccount(id: 'a', balance: Money(9223372036854775807, 'USD')),
      ], sampleRates),
      isNull,
    );
  });
}
