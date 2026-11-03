import 'package:dio/dio.dart';

import 'api_error.dart';
import 'api_models.dart';
import 'money.dart';

class BankApi {
  BankApi(this.dio);
  final Dio dio;

  Future<T> _read<T>(
    Future<Response<dynamic>> request,
    T Function(dynamic) decode,
  ) async {
    try {
      return decode((await request).data);
    } catch (error) {
      throw ApiError.from(error);
    }
  }

  Future<AuthUser> profile() =>
      _read(dio.get('/me'), (data) => AuthUser.fromJson(data as Json));
  Future<List<MoneyAccount>> accounts() => _read(
    dio.get('/accounts'),
    (data) => List.unmodifiable(
      (data as List).map(
        (item) => MoneyAccount(
          id: (item as Json)['id'] as String,
          balance: moneyFromJson(item['balance']),
        ),
      ),
    ),
  );
  Future<TransactionPage> transactions({
    String? accountId,
    String filter = 'all',
    String? cursor,
    int pageSize = 20,
  }) => _read(
    dio.get(
      accountId == null
          ? '/transactions'
          : '/accounts/${Uri.encodeComponent(accountId)}/transactions',
      queryParameters: {
        'filter': filter,
        'pageSize': pageSize,
        'cursor': ?cursor,
      },
    ),
    (data) => TransactionPage.fromJson(data as Json),
  );
  Future<TransactionView> transaction(String id) => _read(
    dio.get('/transactions/${Uri.encodeComponent(id)}'),
    (data) => TransactionView.fromJson(data as Json),
  );
  Future<RecipientView> lookup(String handle) => _read(
    dio.get('/users/lookup', queryParameters: {'handle': handle}),
    (data) => RecipientView.fromJson(data as Json),
  );
  Future<bool> handleAvailable(String handle) => _read(
    dio.get('/auth/handle-available', queryParameters: {'handle': handle}),
    (data) => (data as Json)['available'] as bool,
  );
  Future<FxRates> rates() =>
      _read(dio.get('/fx/rates'), (data) => FxRates.fromJson(data as Json));
  Future<FxQuote> quote(Money amount, String toCurrency) => _read(
    dio.post(
      '/fx/quote',
      data: {'amount': moneyToJson(amount), 'toCurrency': toCurrency},
    ),
    (data) => FxQuote.fromJson(data as Json),
  );
  Future<TransferReceipt> transfer({
    required String recipientHandle,
    required Money amount,
    required String idempotencyKey,
  }) => _read(
    dio.post(
      '/transfers',
      data: {'recipientHandle': recipientHandle, 'amount': moneyToJson(amount)},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => TransferReceipt.fromJson(data as Json),
  );
  Future<ConversionReceipt> convert({
    required String quoteId,
    required String idempotencyKey,
  }) => _read(
    dio.post(
      '/conversions',
      data: {'quoteId': quoteId},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => ConversionReceipt.fromJson(data as Json),
  );
}
