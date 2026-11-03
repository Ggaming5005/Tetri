import 'dart:io';

import 'package:dio/dio.dart';

import 'strings_core.dart';

class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.status,
    this.retryable = false,
    this.isTimeout = false,
    this.isTransport = false,
    this.isDroppedConnection = false,
  });
  final String code, message;
  final int? status;
  final bool retryable, isTimeout, isTransport, isDroppedConnection;

  factory ApiError.from(Object error) {
    if (error is ApiError) return error;
    if (error is! DioException) {
      return const ApiError(
        code: 'invalid_response',
        message: CoreStrings.invalidResponse,
        retryable: true,
      );
    }
    if (error.error is ApiError) return error.error! as ApiError;
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final code = data is Map && data['code'] is String
        ? data['code'] as String
        : 'request_failed';
    final timeout = const [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ].contains(error.type);
    final transport =
        timeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown && error.response == null);
    final cause = error.error;
    final dropped =
        cause is HttpException ||
        (cause is SocketException &&
            const [
              32,
              54,
              104,
              10053,
              10054,
            ].contains(cause.osError?.errorCode));
    final retryable =
        transport ||
        status == 429 ||
        (status != null && status >= 500) ||
        code == 'request_in_progress';
    final message = switch (code) {
      'invalid_credentials' => CoreStrings.invalidCredentials,
      'refresh_invalid' => CoreStrings.signInAgain,
      'handle_taken' => CoreStrings.handleTaken,
      'email_taken' => CoreStrings.emailTaken,
      'recipient_not_found' => CoreStrings.recipientNotFound,
      'self_transfer' => CoreStrings.selfTransfer,
      'insufficient_funds' => CoreStrings.insufficientFunds,
      'amount_too_small' => CoreStrings.amountTooSmall,
      'quote_expired' => CoreStrings.quoteExpired,
      'quote_used' => CoreStrings.quoteUsed,
      'request_in_progress' => CoreStrings.requestInProgress,
      'idempotency_key_reused' => CoreStrings.idempotencyReused,
      'rates_unavailable' => CoreStrings.ratesUnavailable,
      'rate_limited' => CoreStrings.rateLimited,
      _ =>
        transport || status == null || status >= 500
            ? CoreStrings.offline
            : status == 429
            ? CoreStrings.rateLimited
            : status == 404
            ? CoreStrings.notFound
            : CoreStrings.invalidRequest,
    };
    return ApiError(
      code: code,
      message: message,
      status: status,
      retryable: retryable,
      isTimeout: timeout,
      isTransport: transport,
      isDroppedConnection: dropped,
    );
  }

  @override
  String toString() => message;
}
