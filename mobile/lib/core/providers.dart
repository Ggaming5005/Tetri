import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'money.dart';
import 'session.dart';

final dioProvider = Provider<Dio>((ref) {
  const endpoint = String.fromEnvironment(
    'TETRI_API_URL',
    defaultValue: 'http://10.0.2.2:5080/api/v1',
  );
  final dio = Dio(
    BaseOptions(
      baseUrl: endpoint.replaceFirst(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: Headers.jsonContentType,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final sessionProvider = Provider<SessionController>((ref) {
  final controller = SessionController(
    dio: ref.watch(dioProvider),
    store: SecureSessionStore(),
    biometrics: DeviceBiometricGate(),
  );
  ref.onDispose(controller.dispose);
  unawaited(controller.initialize());
  return controller;
});

final bankApiProvider = Provider<BankApi>((ref) {
  ref.watch(sessionProvider);
  return BankApi(ref.watch(dioProvider));
});

final accountsProvider = FutureProvider<List<MoneyAccount>>(
  (ref) => ref.watch(bankApiProvider).accounts(),
);
