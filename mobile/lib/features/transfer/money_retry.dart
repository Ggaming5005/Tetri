import '../../core/api_error.dart';

typedef RetryDelay = Future<void> Function(Duration duration);

Future<T> retryMoneyRequest<T>(
  Future<T> Function() action, {
  required RetryDelay delay,
  void Function()? onUncertain,
}) async {
  const waits = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  for (var attempt = 0; ; attempt++) {
    try {
      return await action();
    } on ApiError catch (error) {
      if (outcomeMayBePending(error)) onUncertain?.call();
      final automatic =
          error.isTimeout ||
          error.isTransport ||
          error.code == 'request_in_progress';
      if (!automatic || attempt == waits.length) rethrow;
      await delay(waits[attempt]);
    }
  }
}

bool outcomeMayBePending(ApiError error) =>
    error.retryable ||
    error.isTimeout ||
    error.isTransport ||
    error.code == 'request_in_progress' ||
    (error.status != null && error.status! >= 500);

bool authoritativeMoneyRejection(ApiError error) => const {
  'insufficient_funds',
  'quote_expired',
  'quote_used',
  'quote_not_found',
  'amount_too_small',
  'amount_too_large',
  'recipient_not_found',
  'self_transfer',
  'balance_limit_exceeded',
  'account_not_found',
}.contains(error.code);
