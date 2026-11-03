import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_error.dart';
import '../../core/api_models.dart';
import '../../core/api.dart';
import '../../core/money.dart';
import '../../core/strings_money.dart';
import '../transfer/money_retry.dart';

class ConversionController extends ChangeNotifier {
  ConversionController(
    this.api, {
    String Function()? createKey,
    RetryDelay? delay,
    DateTime Function()? now,
  }) : _createKey = createKey ?? const Uuid().v4,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  static const previewDebounce = Duration(milliseconds: 300);
  final BankApi api;
  final String Function() _createKey;
  final RetryDelay _delay;
  final DateTime Function() _now;
  DateTime? _firstAttemptAt;
  Timer? _previewTimer;
  int _revision = 0;
  bool _disposed = false;
  Money? input;
  String? toCurrency;
  FxQuote? preview;
  FxQuote? review;
  String? idempotencyKey;
  ConversionReceipt? receipt;
  ApiError? error;
  bool previewLoading = false;
  bool reviewLoading = false;
  bool isSubmitting = false;
  bool uncertain = false;
  bool retryWindowExpired = false;
  bool refreshed = false;
  bool needsReview = false;

  void updateInput(Money amount, String target) {
    if (isSubmitting || reviewLoading || uncertain) return;
    _previewTimer?.cancel();
    _revision++;
    input = amount;
    toCurrency = target;
    preview = null;
    review = null;
    receipt = null;
    error = null;
    refreshed = false;
    needsReview = false;
    previewLoading = amount.minor > 0 && amount.currency != target;
    if (previewLoading) _previewTimer = Timer(previewDebounce, loadPreview);
    _notify();
  }

  Future<void> loadPreview() async {
    _previewTimer?.cancel();
    final amount = input;
    final target = toCurrency;
    if (amount == null ||
        target == null ||
        amount.minor <= 0 ||
        amount.currency == target) {
      return;
    }
    final revision = _revision;
    previewLoading = true;
    error = null;
    _notify();
    try {
      final quote = await api.quote(amount, target);
      if (revision == _revision && !_disposed) preview = quote;
    } on ApiError catch (failure) {
      if (revision == _revision && !_disposed) error = failure;
    } finally {
      if (revision == _revision && !_disposed) {
        previewLoading = false;
        _notify();
      }
    }
  }

  Future<bool> openReview() async {
    if (reviewLoading || isSubmitting || uncertain) return false;
    final amount = input;
    final target = toCurrency;
    if (amount == null ||
        target == null ||
        amount.minor <= 0 ||
        amount.currency == target) {
      return false;
    }
    _previewTimer?.cancel();
    _revision++;
    previewLoading = false;
    reviewLoading = true;
    error = null;
    review = null;
    _notify();
    try {
      final quote = await api.quote(amount, target);
      if (_disposed) return false;
      review = quote;
      preview = quote;
      idempotencyKey = _createKey();
      _firstAttemptAt = null;
      retryWindowExpired = false;
      receipt = null;
      return true;
    } on ApiError catch (failure) {
      error = failure;
      return false;
    } finally {
      reviewLoading = false;
      _notify();
    }
  }

  Future<void> confirm() async {
    if (isSubmitting || reviewLoading || receipt != null) return;
    final quote = review;
    final key = idempotencyKey;
    if (quote == null || key == null) return;
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
    needsReview = false;
    error = null;
    _notify();
    try {
      receipt = await retryMoneyRequest(
        () {
          _checkRetryWindow();
          return api.convert(quoteId: quote.quoteId, idempotencyKey: key);
        },
        delay: _delay,
        onUncertain: () => uncertain = true,
      );
      uncertain = false;
    } on ApiError catch (failure) {
      if (failure.code == 'quote_expired') {
        // New terms always require another explicit confirmation, even if the amount is unchanged.
        uncertain = false;
        review = null;
        refreshed = true;
        needsReview = true;
        input = quote.amountIn;
        toCurrency = quote.netOut.currency;
        isSubmitting = false;
        await openReview();
      } else {
        error = failure;
        uncertain =
            retryWindowExpired ||
            outcomeMayBePending(failure) ||
            (uncertain && !authoritativeMoneyRejection(failure));
      }
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
    _previewTimer?.cancel();
    super.dispose();
  }
}
