import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'api_error.dart';
import 'api_models.dart';
import 'strings_core.dart';

enum SessionStatus { restoring, signedOut, locked, signedIn }

abstract interface class SessionStore {
  Future<bool> readBiometricsEnabled();
  Future<void> writeBiometricsEnabled(bool value);
  Future<bool> readBiometricsOfferSeen();
  Future<void> writeBiometricsOfferSeen(bool value);
  Future<SessionData?> readSession();
  Future<void> writeSession(SessionData session);
  Future<void> deleteSession();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _sessionKey = 'tetri.session';
  static const _biometricsKey = 'tetri.biometrics';
  static const _offerKey = 'tetri.biometricsOfferSeen';
  @override
  Future<bool> readBiometricsEnabled() async =>
      await _storage.read(key: _biometricsKey) == 'true';
  @override
  Future<void> writeBiometricsEnabled(bool value) =>
      _storage.write(key: _biometricsKey, value: value.toString());
  @override
  Future<bool> readBiometricsOfferSeen() async =>
      await _storage.read(key: _offerKey) == 'true';
  @override
  Future<void> writeBiometricsOfferSeen(bool value) =>
      _storage.write(key: _offerKey, value: value.toString());
  @override
  Future<SessionData?> readSession() async {
    final encoded = await _storage.read(key: _sessionKey);
    return encoded == null
        ? null
        : SessionData.fromJson(jsonDecode(encoded) as Json);
  }

  @override
  Future<void> writeSession(SessionData session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  @override
  Future<void> deleteSession() => _storage.delete(key: _sessionKey);
}

abstract interface class BiometricGate {
  Future<bool> available();
  Future<bool> authenticate();
}

class DeviceBiometricGate implements BiometricGate {
  DeviceBiometricGate([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;
  @override
  Future<bool> available() async =>
      await _auth.canCheckBiometrics &&
      (await _auth.getAvailableBiometrics()).isNotEmpty;
  @override
  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: CoreStrings.biometricReason,
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
}

class SessionController extends ChangeNotifier {
  SessionController({
    required this._dio,
    required this._store,
    required this._biometrics,
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed {
    _interceptor = InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: (response, handler) {
        if (_error != null && _status == SessionStatus.signedIn) {
          _error = null;
          _notify();
        }
        handler.next(response);
      },
      onError: _onError,
    );
    _dio.interceptors.add(_interceptor);
  }

  final Dio _dio;
  final SessionStore _store;
  final BiometricGate _biometrics;
  final Future<void> Function(Duration) _delay;
  late final Interceptor _interceptor;
  SessionStatus _status = SessionStatus.restoring;
  SessionData? _session;
  ApiError? _error;
  bool _biometricsEnabled = false,
      _offerSeen = false,
      _busy = false,
      _disposed = false;
  int _generation = 0, _authorizationEpoch = 0;
  Future<SessionData>? _refresh;
  int _refreshGeneration = 0;
  Future<void> _writes = Future<void>.value();

  SessionStatus get status => _status;
  AuthUser? get user => _session?.user;
  ApiError? get error => _error;
  bool get busy => _busy;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get shouldOfferBiometrics =>
      _status == SessionStatus.signedIn && !_biometricsEnabled && !_offerSeen;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static const _anonymous = {
    '/auth/register',
    '/auth/login',
    '/auth/refresh',
    '/auth/handle-available',
    '/health',
  };
  bool _requiresAuth(RequestOptions options) =>
      !_anonymous.contains(options.path);
  ApiError get _unavailable => ApiError(
    code: _status == SessionStatus.locked ? 'session_locked' : 'signed_out',
    message: _status == SessionStatus.locked
        ? CoreStrings.unlock
        : CoreStrings.signInAgain,
  );

  Future<void> _serializeWrite(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> initialize() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      _biometricsEnabled = await _store.readBiometricsEnabled();
      _offerSeen = await _store.readBiometricsOfferSeen();
      if (_biometricsEnabled) {
        _session = null;
        _status = SessionStatus.locked;
      } else {
        await _restore();
      }
    } catch (_) {
      _error = const ApiError(
        code: 'secure_storage',
        message: CoreStrings.storage,
        retryable: true,
      );
      _status = SessionStatus.restoring;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _restore() async {
    final pending = _refresh;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        /* Its outcome is handled by refresh. */
      }
    }
    final generation = _generation;
    final session = await _store.readSession();
    if (generation != _generation) return;
    _session = session;
    _status = session == null
        ? SessionStatus.signedOut
        : SessionStatus.signedIn;
  }

  Future<void> signIn({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});
  Future<void> register({
    required String email,
    required String displayName,
    required String handle,
    required String password,
  }) => _authenticate('/auth/register', {
    'email': email,
    'displayName': displayName,
    'handle': handle,
    'password': password,
  });

  Future<void> _authenticate(String path, Json body) async {
    if (_busy) {
      throw const ApiError(
        code: 'request_in_progress',
        message: CoreStrings.requestInProgress,
        retryable: true,
      );
    }
    _busy = true;
    _error = null;
    final generation = ++_generation;
    _authorizationEpoch++;
    _notify();
    try {
      final response = await _dio.post<dynamic>(path, data: body);
      final session = SessionData.fromJson(response.data as Json);
      await _save(session, generation);
      if (generation != _generation) throw _unavailable;
      _session = session;
      _status = SessionStatus.signedIn;
    } catch (error) {
      _error = ApiError.from(error);
      throw _error!;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _save(SessionData session, int generation) =>
      _serializeWrite(() async {
        if (generation != _generation) throw _unavailable;
        try {
          await _store.writeSession(session);
        } catch (_) {
          throw const ApiError(
            code: 'secure_storage',
            message: CoreStrings.storage,
            retryable: true,
          );
        }
      });

  Future<bool> biometricsAvailable() async {
    try {
      return await _biometrics.available();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock() async {
    if (_busy || _status != SessionStatus.locked) return false;
    _busy = true;
    _error = null;
    final epoch = _authorizationEpoch;
    _notify();
    try {
      if (!await _biometrics.authenticate()) {
        _error = const ApiError(
          code: 'unlock_cancelled',
          message: CoreStrings.biometricCancelled,
        );
        return false;
      }
      if (epoch != _authorizationEpoch) return false;
      await _restore();
      return _status == SessionStatus.signedIn;
    } catch (_) {
      _error = const ApiError(
        code: 'unlock_failed',
        message: CoreStrings.biometricsUnavailable,
      );
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> setBiometrics(bool enabled) async {
    if (_status != SessionStatus.signedIn) throw _unavailable;
    final generation = _generation;
    if (enabled &&
        (!await biometricsAvailable() || !await _biometrics.authenticate())) {
      throw const ApiError(
        code: 'biometrics_unavailable',
        message: CoreStrings.biometricsUnavailable,
      );
    }
    if (generation != _generation || _status != SessionStatus.signedIn) {
      throw _unavailable;
    }
    await _store.writeBiometricsEnabled(enabled);
    await _store.writeBiometricsOfferSeen(true);
    _biometricsEnabled = enabled;
    _offerSeen = true;
    _notify();
  }

  Future<void> dismissBiometricsOffer() async {
    await _store.writeBiometricsOfferSeen(true);
    _offerSeen = true;
    _notify();
  }

  void lock() {
    if (!_biometricsEnabled || _status != SessionStatus.signedIn) return;
    _authorizationEpoch++;
    _session = null;
    _status = SessionStatus.locked;
    _error = null;
    _notify();
  }

  Future<void> signOut() async {
    final generation = _generation;
    final session = _session;
    try {
      if (session != null) {
        await _dio.post<dynamic>(
          '/auth/logout',
          data: {'refreshToken': session.refreshToken},
        );
      }
    } catch (_) {
      // An explicit sign out still removes this device's credentials offline.
    } finally {
      if (generation == _generation) await _clear();
    }
  }

  Future<void> _clear() async {
    _generation++;
    _authorizationEpoch++;
    _session = null;
    _biometricsEnabled = false;
    _status = SessionStatus.signedOut;
    await _serializeWrite(() async {
      await _store.deleteSession();
      await _store.writeBiometricsEnabled(false);
    });
    _notify();
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_requiresAuth(options)) {
      final session = _session;
      if (session == null ||
          _status != SessionStatus.signedIn ||
          (options.extra.containsKey('sessionEpoch') &&
              options.extra['sessionEpoch'] != _authorizationEpoch)) {
        handler.reject(
          DioException(requestOptions: options, error: _unavailable),
        );
        return;
      }
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      options.extra['sessionEpoch'] = _authorizationEpoch;
      options.extra['accessToken'] = session.accessToken;
    }
    handler.next(options);
  }

  void _onError(DioException failure, ErrorInterceptorHandler handler) async {
    final request = failure.requestOptions;
    if (failure.response?.statusCode != 401 ||
        !_requiresAuth(request) ||
        request.extra['authRetried'] == true) {
      final error = ApiError.from(failure);
      if (error.retryable && _status == SessionStatus.signedIn) {
        _error = error;
        _notify();
      }
      handler.next(failure);
      return;
    }
    try {
      if (request.extra['sessionEpoch'] != _authorizationEpoch) {
        throw _unavailable;
      }
      await _refreshFor(request.extra['accessToken'] as String);
      if (request.extra['sessionEpoch'] != _authorizationEpoch ||
          _status != SessionStatus.signedIn) {
        throw _unavailable;
      }
      final response = await _dio.fetch<dynamic>(
        request.copyWith(extra: {...request.extra, 'authRetried': true}),
      );
      handler.resolve(response);
    } catch (error) {
      final apiError = ApiError.from(error);
      _error = apiError;
      _notify();
      handler.reject(
        DioException(
          requestOptions: request,
          error: apiError,
          response: failure.response,
        ),
      );
    }
  }

  Future<SessionData> _refreshFor(String failedAccessToken) async {
    final current = _session;
    if (current == null || _status != SessionStatus.signedIn) {
      throw _unavailable;
    }
    // A late 401 may belong to the token another request already replaced.
    if (current.accessToken != failedAccessToken) return current;
    final existing = _refresh;
    if (existing != null && _refreshGeneration == _generation) return existing;
    _refreshGeneration = _generation;
    final operation = _rotate(current, _generation, _authorizationEpoch);
    _refresh = operation;
    try {
      return await operation;
    } finally {
      if (identical(_refresh, operation)) _refresh = null;
    }
  }

  Future<SessionData> _rotate(
    SessionData previous,
    int generation,
    int epoch,
  ) async {
    for (var attempt = 0; ; attempt++) {
      if (generation != _generation || epoch != _authorizationEpoch) {
        throw _unavailable;
      }
      try {
        final response = await _requestRotation(previous.refreshToken);
        final replacement = SessionData.fromJson(response.data as Json);
        if (generation != _generation) throw _unavailable;
        // Persist both tokens in one blob before any waiting request can use them.
        // A response arriving after lock is saved, but never unlocks the device.
        await _save(replacement, generation);
        if (generation != _generation) throw _unavailable;
        if (epoch == _authorizationEpoch && _status == SessionStatus.signedIn) {
          _session = replacement;
        }
        return replacement;
      } catch (failure) {
        final error = ApiError.from(failure);
        if (generation != _generation) throw _unavailable;
        if (error.status == 401 && error.code == 'refresh_invalid') {
          _error = error;
          await _clear();
          throw error;
        }
        if ((error.isTimeout || error.isDroppedConnection) &&
            attempt < 3 &&
            epoch == _authorizationEpoch) {
          await _delay(Duration(seconds: 1 << attempt));
          continue;
        }
        throw error;
      }
    }
  }

  Future<Response<dynamic>> _requestRotation(String refreshToken) async {
    final cancel = CancelToken();
    // Bound the whole request, not each socket phase separately. Four attempts
    // plus 1/2/4-second backoff remain inside the server's 60-second grace.
    final timer = Timer(
      const Duration(seconds: 10),
      () => cancel.cancel('refresh_timeout'),
    );
    try {
      return await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        cancelToken: cancel,
      );
    } on DioException catch (error) {
      if (cancel.isCancelled && error.type == DioExceptionType.cancel) {
        throw const ApiError(
          code: 'refresh_timeout',
          message: CoreStrings.offline,
          retryable: true,
          isTimeout: true,
          isTransport: true,
        );
      }
      rethrow;
    } finally {
      timer.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _authorizationEpoch++;
    _dio.interceptors.remove(_interceptor);
    super.dispose();
  }
}
