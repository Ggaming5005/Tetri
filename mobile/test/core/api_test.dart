import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';

void main() {
  test(
    'all read routes decode typed data and retain cursor/account filters',
    () async {
      final requests = <RequestOptions>[];
      final api = makeApi((request) {
        requests.add(request);
        return switch (request.path) {
          '/me' => userJson,
          '/accounts' => [
            {
              'id': 'account',
              'currency': 'GEL',
              'balance': {'minor': 9223372036854775807, 'currency': 'GEL'},
              'version': 2,
            },
          ],
          '/transactions' || '/accounts/account/transactions' => {
            'items': [transactionJson],
            'nextCursor': 'opaque-next',
          },
          '/transactions/transaction' => transactionJson,
          '/users/lookup' => {'displayName': 'Nino', 'handle': '@nino'},
          '/auth/handle-available' => {'available': false},
          '/fx/rates' => {
            'rates': [
              {
                'currency': 'USD',
                'rateToGel': 2.7357,
                'rateDate': '2026-11-03',
              },
            ],
            'spread': 0.005,
          },
          _ => throw StateError(request.path),
        };
      });
      expect((await api.profile()).handle, '@giorgi');
      expect((await api.accounts()).single.balance.minor, 9223372036854775807);
      final page = await api.transactions(
        filter: 'sent',
        cursor: 'prior-cursor',
        pageSize: 30,
      );
      expect(page.nextCursor, 'opaque-next');
      expect(
        page.items.single.entries.single.amount,
        const Money(-2500, 'GEL'),
      );
      await api.transactions(accountId: 'account');
      final detail = await api.transaction('transaction');
      expect(detail.counterparty?.displayName, 'Nino');
      expect(detail.createdAt, DateTime.utc(2026, 11, 3, 12));
      expect((await api.lookup('@nino')).handle, '@nino');
      expect(await api.handleAvailable('@nino'), isFalse);
      final rates = await api.rates();
      expect(rates.rates.single.rateDate, DateTime.utc(2026, 11, 3));
      expect(rates.rates.single.rateToGel, '2.7357');
      expect(rates.spread, '0.005');
      expect(requests.first.uri.toString(), 'https://tetri.example/api/v1/me');
      expect(
        requests.singleWhere((r) => r.path == '/transactions').queryParameters,
        {'filter': 'sent', 'cursor': 'prior-cursor', 'pageSize': 30},
      );
      expect(
        requests
            .singleWhere((r) => r.path == '/accounts/account/transactions')
            .queryParameters,
        {'filter': 'all', 'pageSize': 20},
      );
    },
  );

  test(
    'money writes retain integer minor units and the supplied idempotency key',
    () async {
      final requests = <RequestOptions>[];
      final api = makeApi((request) {
        requests.add(request);
        if (request.path == '/transfers') {
          return {
            'id': 'transfer-id',
            'amount': {'minor': 2500, 'currency': 'GEL'},
            'recipientHandle': '@nino',
            'recipientDisplayName': 'Nino',
            'createdAt': '2026-11-03T12:00:00Z',
          };
        }
        return {
          ...quoteJson,
          if (request.path == '/conversions') 'transactionId': 'conversion-id',
          if (request.path == '/conversions')
            'createdAt': '2026-11-03T12:00:00Z',
        };
      });
      final transfer = await api.transfer(
        recipientHandle: '@nino',
        amount: const Money(2500, 'GEL'),
        idempotencyKey: 'transfer-key',
      );
      expect(transfer.id, 'transfer-id');
      expect(requests[0].headers['Idempotency-Key'], 'transfer-key');
      expect(requests[0].data, {
        'recipientHandle': '@nino',
        'amount': {'minor': 2500, 'currency': 'GEL'},
      });
      final quote = await api.quote(const Money(10000, 'USD'), 'GEL');
      expect(quote.quoteId, 'quote-id');
      expect(quote.netOut, const Money(27220, 'GEL'));
      expect(quote.fee, const Money(137, 'GEL'));
      expect(quote.rateDate, DateTime.utc(2026, 11, 3));
      expect(quote.expiresAt, DateTime.utc(2026, 11, 3, 12, 1));
      final conversion = await api.convert(
        quoteId: quote.quoteId,
        idempotencyKey: 'conversion-key',
      );
      expect(conversion.transactionId, 'conversion-id');
      expect(requests[2].data, {'quoteId': 'quote-id'});
      expect(requests[2].headers['Idempotency-Key'], 'conversion-key');
    },
  );

  test(
    'fractional or unsupported money responses are rejected instead of rounded',
    () {
      expect(
        () => moneyFromJson({'minor': 1.5, 'currency': 'GEL'}),
        throwsFormatException,
      );
      expect(
        () => moneyFromJson({'minor': 1, 'currency': 'GBP'}),
        throwsFormatException,
      );
      expect(
        () => moneyFromJson({'minor': '2500', 'currency': 'GEL'}),
        throwsFormatException,
      );
    },
  );

  test('problem details become stable human errors without exposing server details', () async {
    final api = makeApi(
      (_) => {
        'code': 'insufficient_funds',
        'detail': 'internal SQL stack trace',
      },
      status: 422,
    );
    await expectLater(
      api.transfer(
        recipientHandle: '@nino',
        amount: const Money(2500, 'GEL'),
        idempotencyKey: 'key',
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', 'insufficient_funds')
            .having((e) => e.status, 'status', 422)
            .having((e) => e.message, 'message', isNot(contains('SQL')))
            .having((e) => e.retryable, 'retryable', isFalse),
      ),
    );
  });

  test(
    'session serializes both tokens with user and UTC expiration in one value',
    () {
      final session = SessionData(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2026, 11, 3),
        user: AuthUser.fromJson(userJson),
      );
      final restored = SessionData.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Json,
      );
      expect(restored.refreshToken, 'refresh');
      expect(restored.accessToken, 'access');
      expect(restored.expiresAt.isUtc, isTrue);
      expect(restored.user.id, 'user');
    },
  );
}

const userJson = {
  'id': 'user',
  'email': 'user@example.test',
  'displayName': 'Giorgi',
  'handle': '@giorgi',
};
const transactionJson = {
  'id': 'transaction',
  'kind': 'transfer',
  'status': 'posted',
  'description': 'To Nino',
  'createdAt': '2026-11-03T12:00:00Z',
  'entries': [
    {
      'accountId': 'account',
      'amount': {'minor': -2500, 'currency': 'GEL'},
    },
  ],
  'counterparty': {'displayName': 'Nino', 'handle': '@nino'},
  'rate': null,
  'fee': null,
};
const quoteJson = {
  'quoteId': 'quote-id',
  'amountIn': {'minor': 10000, 'currency': 'USD'},
  'netOut': {'minor': 27220, 'currency': 'GEL'},
  'fee': {'minor': 137, 'currency': 'GEL'},
  'rate': 2.7357,
  'rateDate': '2026-11-03',
  'expiresAt': '2026-11-03T12:01:00Z',
};

BankApi makeApi(Object Function(RequestOptions) respond, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://tetri.example/api/v1'));
  dio.httpClientAdapter = ApiAdapter(respond, status);
  addTearDown(() => dio.close(force: true));
  return BankApi(dio);
}

class ApiAdapter implements HttpClientAdapter {
  ApiAdapter(this.respond, this.status);
  final Object Function(RequestOptions) respond;
  final int status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(respond(options)),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}
