import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tetri/core/api_models.dart';

void main() {
  final readers = <String, DateTime Function(Object?)>{
    'FxRate': (value) => FxRate.fromJson({
      'currency': 'USD',
      'rateToGel': 2.7357,
      'rateDate': value,
    }).rateDate,
    'FxQuote': (value) =>
        FxQuote.fromJson({...quoteJson, 'rateDate': value}).rateDate,
    'ConversionReceipt': (value) => ConversionReceipt.fromJson({
      ...quoteJson,
      'rateDate': value,
      'transactionId': 'transaction-id',
      'createdAt': '2026-11-03T12:00:00Z',
    }).rateDate,
  };

  for (final reader in readers.entries) {
    test('${reader.key} preserves the exact calendar day at UTC midnight', () {
      for (final text in [
        '2026-11-03',
        '2027-01-01',
        '2024-02-29',
        '2026-12-31',
      ]) {
        final date = reader.value(text);
        expect(date.isUtc, isTrue);
        expect(date.toIso8601String(), '${text}T00:00:00.000Z');
        expect(DateFormat('yyyy-MM-dd').format(date), text);
        expect(date.hour, 0);
      }
    });

    test('${reader.key} rejects malformed and impossible calendar dates', () {
      for (final value in <Object?>[
        null,
        20261103,
        '',
        '2026-1-03',
        '2026-11-3',
        '2026/11/03',
        '2026-11-03\n',
        ' 2026-11-03',
        '2026-11-03T00:00:00Z',
        '2026-00-03',
        '2026-13-03',
        '2026-11-00',
        '2026-11-31',
        '2026-02-29',
        '2024-02-30',
        '0000-01-01',
      ]) {
        expect(
          () => reader.value(value),
          throwsFormatException,
          reason: '$value',
        );
      }
    });
  }

  test(
    'expiration and transaction timestamps still convert their offset to UTC',
    () {
      const offsetTimestamp = '2026-11-03T01:30:00+04:00';
      final expected = DateTime.utc(2026, 11, 2, 21, 30);
      final quote = FxQuote.fromJson({
        ...quoteJson,
        'expiresAt': offsetTimestamp,
      });
      final conversion = ConversionReceipt.fromJson({
        ...quoteJson,
        'transactionId': 'transaction-id',
        'createdAt': offsetTimestamp,
      });
      final transfer = TransferReceipt.fromJson({
        'id': 'transfer-id',
        'amount': {'minor': 2500, 'currency': 'GEL'},
        'recipientHandle': '@nino',
        'recipientDisplayName': 'Nino',
        'createdAt': offsetTimestamp,
      });
      final transaction = TransactionView.fromJson({
        'id': 'transaction-id',
        'kind': 'transfer',
        'status': 'posted',
        'description': 'To Nino',
        'createdAt': offsetTimestamp,
        'entries': <Json>[],
      });
      final session = SessionData.fromJson({
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'expiresAt': offsetTimestamp,
        'user': {
          'id': 'user',
          'email': 'user@example.test',
          'displayName': 'Nino',
          'handle': '@nino',
        },
      });
      for (final timestamp in [
        quote.expiresAt,
        conversion.createdAt,
        transfer.createdAt,
        transaction.createdAt,
        session.expiresAt,
      ]) {
        expect(timestamp, expected);
        expect(timestamp.isUtc, isTrue);
      }
      expect(quote.rateDate, DateTime.utc(2026, 11, 3));
      expect(conversion.rateDate, DateTime.utc(2026, 11, 3));
    },
  );
}

const quoteJson = {
  'quoteId': 'quote-id',
  'amountIn': {'minor': 10000, 'currency': 'USD'},
  'netOut': {'minor': 27220, 'currency': 'GEL'},
  'fee': {'minor': 137, 'currency': 'GEL'},
  'rate': 2.7357,
  'rateDate': '2026-11-03',
  'expiresAt': '2026-11-03T12:01:00Z',
};
