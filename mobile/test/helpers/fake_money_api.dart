import 'package:dio/dio.dart';
import 'package:tetri/core/api.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';

class FakeMoneyApi extends BankApi {
  FakeMoneyApi() : super(Dio());
  static const balances = [
    MoneyAccount(id: 'gel', balance: Money(100000, 'GEL')),
    MoneyAccount(id: 'usd', balance: Money(30000, 'USD')),
    MoneyAccount(id: 'eur', balance: Money(30000, 'EUR')),
  ];
  static const nino = RecipientView(displayName: 'Nino', handle: '@nino');
  final transferErrors = <ApiError>[];
  final conversionErrors = <ApiError>[];
  final quoteErrors = <ApiError>[];
  final quoteResults = <FxQuote>[];
  final transfers = <({String key, String handle, Money amount})>[];
  final conversions = <({String key, String quoteId})>[];
  final issuedQuotes = <String, FxQuote>{};
  int quoteCalls = 0;

  @override
  Future<List<MoneyAccount>> accounts() async => balances;
  @override
  Future<RecipientView> lookup(String handle) async => nino;
  @override
  Future<TransactionPage> transactions({
    String? accountId,
    String filter = 'all',
    String? cursor,
    int pageSize = 20,
  }) async => const TransactionPage(items: []);

  @override
  Future<TransferReceipt> transfer({
    required String recipientHandle,
    required Money amount,
    required String idempotencyKey,
  }) async {
    transfers.add((
      key: idempotencyKey,
      handle: recipientHandle,
      amount: amount,
    ));
    if (transferErrors.isNotEmpty) throw transferErrors.removeAt(0);
    return TransferReceipt(
      id: 'transfer',
      amount: amount,
      recipientHandle: recipientHandle,
      recipientDisplayName: 'Nino',
      createdAt: DateTime.utc(2026, 11, 3),
    );
  }

  @override
  Future<FxQuote> quote(Money amount, String toCurrency) async {
    quoteCalls++;
    if (quoteErrors.isNotEmpty) throw quoteErrors.removeAt(0);
    final gross = amount.minor * 25 ~/ 10;
    final net = amount.minor * 25 * 995 ~/ 10000;
    final result = quoteResults.isNotEmpty
        ? quoteResults.removeAt(0)
        : FxQuote(
            quoteId: 'quote-$quoteCalls',
            amountIn: amount,
            netOut: Money(net, toCurrency),
            fee: Money(gross - net, toCurrency),
            rate: '2.5',
            rateDate: DateTime.utc(2026, 11, 3),
            expiresAt: DateTime.utc(2026, 11, 3, 12, 1),
          );
    issuedQuotes[result.quoteId] = result;
    return result;
  }

  @override
  Future<ConversionReceipt> convert({
    required String quoteId,
    required String idempotencyKey,
  }) async {
    conversions.add((key: idempotencyKey, quoteId: quoteId));
    if (conversionErrors.isNotEmpty) throw conversionErrors.removeAt(0);
    final quote = issuedQuotes[quoteId]!;
    return ConversionReceipt(
      transactionId: 'conversion',
      quoteId: quoteId,
      amountIn: quote.amountIn,
      netOut: quote.netOut,
      fee: quote.fee,
      rate: quote.rate,
      rateDate: quote.rateDate,
      createdAt: DateTime.utc(2026, 11, 3, 12),
    );
  }
}
