import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_error.dart';
import '../../core/api_models.dart';
import '../../core/api.dart';
import '../../core/money.dart';
import '../../core/strings_money.dart';
import 'money_retry.dart';

final class TransferReview {
  const TransferReview({
    required this.recipient,
    required this.amount,
    required this.idempotencyKey,
  });
  final RecipientView recipient;
  final Money amount;
  final String idempotencyKey;
}

class TransferController extends ChangeNotifier {
  TransferController(
    this.api, {
    String Function()? createKey,
    RetryDelay? delay,
    DateTime Function()? now,
  }) : _createKey = createKey ?? const Uuid().v4,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final BankApi api;
  final String Function() _createKey;
  final RetryDelay _delay;
  final DateTime Function() _now;
  DateTime? _firstAttemptAt;
  TransferReview? review;
  TransferReceipt? receipt;
  ApiError? error;
  bool isSubmitting = false;
  bool uncertain = false;
  bool retryWindowExpired = false;
  bool _disposed = false;

  void openReview(RecipientView recipient, Money amount) {
    if (isSubmitting || uncertain) {
      throw StateError('Resolve the current transfer before starting another.');
    }
    review = TransferReview(
      recipient: recipient,
      amount: amount,
      idempotencyKey: _createKey(),
    );
    receipt = null;
    error = null;
    _firstAttemptAt = null;
    retryWindowExpired = false;
    _notify();
  }

  Future<void> confirm() async {
    if (isSubmitting || receipt != null) return;
    final confirmed = review;
    if (confirmed == null) {
      throw StateError('Review the transfer before confirming.');
    }
    if (_firstAttemptAt != null &&
        _now().difference(_firstAttemptAt!) >= const Duration(hours: 24)) {
      retryWindowExpired = true;
      uncertain = true;
      error = const ApiError(
        code: 'confirmation_expired',
        message: MoneyStrings.confirmationExpired,
      );
      _notify();
      return;
    }
    _firstAttemptAt ??= _now();
    isSubmitting = true;
    error = null;
    _notify();
    try {
      receipt = await retryMoneyRequest(
        () {
          _checkRetryWindow();
          return api.transfer(
            recipientHandle: confirmed.recipient.handle,
            amount: confirmed.amount,
            idempotencyKey: confirmed.idempotencyKey,
          );
        },
        delay: _delay,
        onUncertain: () => uncertain = true,
      );
      uncertain = false;
    } on ApiError catch (failure) {
      error = failure;
      uncertain =
          retryWindowExpired ||
          outcomeMayBePending(failure) ||
          (uncertain && !authoritativeMoneyRejection(failure));
    } finally {
      isSubmitting = false;
      _notify();
    }
  }

  void _checkRetryWindow() {
    if (_firstAttemptAt != null &&
        _now().difference(_firstAttemptAt!) >= const Duration(hours: 24)) {
      retryWindowExpired = true;
      throw const ApiError(
        code: 'confirmation_expired',
        message: MoneyStrings.confirmationExpired,
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
