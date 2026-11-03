import 'money.dart';

typedef Json = Map<String, dynamic>;

Money moneyFromJson(dynamic value) {
  final json = value as Json;
  final minor = json['minor'];
  final currency = json['currency'];
  if (minor is! int || !const ['GEL', 'USD', 'EUR'].contains(currency)) {
    throw const FormatException('Invalid money response');
  }
  return Money(minor, currency as String);
}

Json moneyToJson(Money money) => {
  'minor': money.minor,
  'currency': money.currency,
};
DateTime _timestamp(dynamic value) => DateTime.parse(value as String).toUtc();

DateTime _calendarDate(dynamic value) {
  if (value is! String ||
      value.length != 10 ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid rate date');
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final date = DateTime.utc(year, month, day);
  // DateTime normalizes invalid components; calendar dates must not roll over.
  if (year < 1 || date.year != year || date.month != month || date.day != day) {
    throw const FormatException('Invalid rate date');
  }
  return date;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.handle,
  });
  final String id, email, displayName, handle;
  factory AuthUser.fromJson(Json json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    handle: json['handle'] as String,
  );
  Json toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'handle': handle,
  };
}

class SessionData {
  const SessionData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });
  final String accessToken, refreshToken;
  final DateTime expiresAt;
  final AuthUser user;
  factory SessionData.fromJson(Json json) => SessionData(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresAt: _timestamp(json['expiresAt']),
    user: AuthUser.fromJson(json['user'] as Json),
  );
  Json toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'user': user.toJson(),
  };
}

class RecipientView {
  const RecipientView({required this.displayName, required this.handle});
  final String displayName, handle;
  factory RecipientView.fromJson(Json json) => RecipientView(
    displayName: json['displayName'] as String,
    handle: json['handle'] as String,
  );
}

class EntryView {
  const EntryView({required this.accountId, required this.amount});
  final String accountId;
  final Money amount;
  factory EntryView.fromJson(Json json) => EntryView(
    accountId: json['accountId'] as String,
    amount: moneyFromJson(json['amount']),
  );
}

class TransactionView {
  const TransactionView({
    required this.id,
    required this.kind,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.entries,
    this.counterparty,
    this.rate,
    this.fee,
  });
  final String id, kind, status, description;
  final DateTime createdAt;
  final List<EntryView> entries;
  final RecipientView? counterparty;
  final String? rate;
  final Money? fee;
  factory TransactionView.fromJson(Json json) => TransactionView(
    id: json['id'] as String,
    kind: json['kind'] as String,
    status: json['status'] as String,
    description: json['description'] as String,
    createdAt: _timestamp(json['createdAt']),
    entries: List.unmodifiable(
      (json['entries'] as List).map(
        (entry) => EntryView.fromJson(entry as Json),
      ),
    ),
    counterparty: json['counterparty'] == null
        ? null
        : RecipientView.fromJson(json['counterparty'] as Json),
    rate: json['rate']?.toString(),
    fee: json['fee'] == null ? null : moneyFromJson(json['fee']),
  );
}

class TransactionPage {
  const TransactionPage({required this.items, this.nextCursor});
  final List<TransactionView> items;
  final String? nextCursor;
  factory TransactionPage.fromJson(Json json) => TransactionPage(
    items: List.unmodifiable(
      (json['items'] as List).map(
        (item) => TransactionView.fromJson(item as Json),
      ),
    ),
    nextCursor: json['nextCursor'] as String?,
  );
}

class FxRate {
  const FxRate({
    required this.currency,
    required this.rateToGel,
    required this.rateDate,
  });
  final String currency, rateToGel;
  final DateTime rateDate;
  factory FxRate.fromJson(Json json) => FxRate(
    currency: json['currency'] as String,
    rateToGel: json['rateToGel'].toString(),
    rateDate: _calendarDate(json['rateDate']),
  );
}

class FxRates {
  const FxRates({required this.rates, required this.spread});
  final List<FxRate> rates;
  final String spread;
  factory FxRates.fromJson(Json json) => FxRates(
    rates: List.unmodifiable(
      (json['rates'] as List).map((rate) => FxRate.fromJson(rate as Json)),
    ),
    spread: json['spread'].toString(),
  );
}

class FxQuote {
  const FxQuote({
    required this.quoteId,
    required this.amountIn,
    required this.netOut,
    required this.fee,
    required this.rate,
    required this.rateDate,
    required this.expiresAt,
  });
  final String quoteId, rate;
  final Money amountIn, netOut, fee;
  final DateTime rateDate, expiresAt;
  factory FxQuote.fromJson(Json json) => FxQuote(
    quoteId: json['quoteId'] as String,
    amountIn: moneyFromJson(json['amountIn']),
    netOut: moneyFromJson(json['netOut']),
    fee: moneyFromJson(json['fee']),
    rate: json['rate'].toString(),
    rateDate: _calendarDate(json['rateDate']),
    expiresAt: _timestamp(json['expiresAt']),
  );
}

class TransferReceipt {
  const TransferReceipt({
    required this.id,
    required this.amount,
    required this.recipientHandle,
    required this.recipientDisplayName,
    required this.createdAt,
  });
  final String id, recipientHandle, recipientDisplayName;
  final Money amount;
  final DateTime createdAt;
  factory TransferReceipt.fromJson(Json json) => TransferReceipt(
    id: json['id'] as String,
    amount: moneyFromJson(json['amount']),
    recipientHandle: json['recipientHandle'] as String,
    recipientDisplayName: json['recipientDisplayName'] as String,
    createdAt: _timestamp(json['createdAt']),
  );
}

class ConversionReceipt {
  const ConversionReceipt({
    required this.transactionId,
    required this.quoteId,
    required this.amountIn,
    required this.netOut,
    required this.fee,
    required this.rate,
    required this.rateDate,
    required this.createdAt,
  });
  final String transactionId, quoteId, rate;
  final Money amountIn, netOut, fee;
  final DateTime rateDate, createdAt;
  factory ConversionReceipt.fromJson(Json json) => ConversionReceipt(
    transactionId: json['transactionId'] as String,
    quoteId: json['quoteId'] as String,
    amountIn: moneyFromJson(json['amountIn']),
    netOut: moneyFromJson(json['netOut']),
    fee: moneyFromJson(json['fee']),
    rate: json['rate'].toString(),
    rateDate: _calendarDate(json['rateDate']),
    createdAt: _timestamp(json['createdAt']),
  );
}
