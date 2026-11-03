import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/session.dart';

void main() {
  test('three simultaneous 401s rotate once and persist before any request retries', () async {
    final allOldRequests = Completer<void>();
    final rotationStarted = Completer<void>();
    final saved = Completer<void>();
    var oldRequests = 0, rotations = 0, retried = 0;
    final fixture = Fixture((request) async {
      if (request.path == '/auth/refresh') {
        rotations++;
        rotationStarted.complete();
        return jsonResponse(200, replacement.toJson());
      }
      if (request.headers['Authorization'] == 'Bearer old-access') {
        if (++oldRequests == 3) allOldRequests.complete();
        await allOldRequests.future;
        return jsonResponse(401, {'code': 'unauthorized'});
      }
      retried++;
      expect(saved.isCompleted, isTrue);
      return jsonResponse(200, accountJson);
    });
    fixture.store.beforeWrite = () => saved.future;
    await fixture.initialize();
    final requests = List.generate(3, (_) => fixture.api.accounts());
    await rotationStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(retried, 0);
    saved.complete();
    await Future.wait(requests);
    expect(rotations, 1);
    expect(retried, 3);
    expect(fixture.store.session?.refreshToken, 'new-refresh');
    expect(fixture.session.status, SessionStatus.signedIn);
  });

  test(
    'a delayed 401 uses the already rotated token without a second refresh',
    () async {
      final lateRequestStarted = Completer<void>();
      final releaseLate = Completer<void>();
      var rotations = 0;
      final fixture = Fixture((request) async {
        if (request.path == '/auth/refresh') {
          rotations++;
          return jsonResponse(200, replacement.toJson());
        }
        if (request.headers['Authorization'] == 'Bearer old-access') {
          if (request.path == '/me') {
            lateRequestStarted.complete();
            await releaseLate.future;
          }
          return jsonResponse(401, {});
        }
        return jsonResponse(
          200,
          request.path == '/me' ? sampleUser.toJson() : accountJson,
        );
      });
      await fixture.initialize();
      final profile = fixture.api.profile();
      await lateRequestStarted.future;
      await fixture.api.accounts();
      releaseLate.complete();
      expect((await profile).id, sampleUser.id);
      expect(rotations, 1);
    },
  );

  test(
    'lost refresh responses retry the same token with 1, 2, 4 second backoff',
    () async {
      var rotations = 0;
      final fixture = Fixture((request) async {
        if (request.path == '/auth/refresh') {
          expect((request.data as Json)['refreshToken'], 'old-refresh');
          if (++rotations <= 3) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return jsonResponse(200, replacement.toJson());
        }
        return request.headers['Authorization'] == 'Bearer old-access'
            ? jsonResponse(401, {})
            : jsonResponse(200, accountJson);
      });
      await fixture.initialize();
      await fixture.api.accounts();
      expect(rotations, 4);
      expect(fixture.delays, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ]);
      expect(fixture.store.deletes, 0);
    },
  );

  test(
    'a dropped connection retries while no network fails without signing out',
    () async {
      var rotations = 0;
      final fixture = Fixture((request) async {
        if (request.path == '/auth/refresh') {
          if (++rotations == 1) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
              error: const SocketException(
                'Connection reset',
                osError: OSError('reset', 10054),
              ),
            );
          }
          return jsonResponse(200, replacement.toJson());
        }
        return request.headers['Authorization'] == 'Bearer old-access'
            ? jsonResponse(401, {})
            : jsonResponse(200, accountJson);
      });
      await fixture.initialize();
      await fixture.api.accounts();
      expect(rotations, 2);
      expect(fixture.delays, const [Duration(seconds: 1)]);
    },
  );

  for (final outcome in ['offline', 'timeout', '500', '429', '401-other']) {
    test(
      'refresh $outcome retains session and allows a later request to retry',
      () async {
        var recover = false, rotations = 0;
        final fixture = Fixture((request) async {
          if (request.path == '/auth/refresh') {
            rotations++;
            if (recover) return jsonResponse(200, replacement.toJson());
            if (outcome == 'offline') {
              throw DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
                error: const SocketException(
                  'No route to host',
                  osError: OSError('offline', 10065),
                ),
              );
            }
            if (outcome == 'timeout') {
              throw DioException(
                requestOptions: request,
                type: DioExceptionType.receiveTimeout,
              );
            }
            return jsonResponse(
              outcome == '401-other' ? 401 : int.parse(outcome),
              {'code': outcome == '429' ? 'rate_limited' : 'unexpected'},
            );
          }
          return request.headers['Authorization'] == 'Bearer old-access'
              ? jsonResponse(401, {})
              : jsonResponse(200, accountJson);
        });
        await fixture.initialize();
        await expectLater(fixture.api.accounts(), throwsA(isA<ApiError>()));
        expect(fixture.store.session?.refreshToken, 'old-refresh');
        expect(fixture.store.deletes, 0);
        expect(fixture.session.status, SessionStatus.signedIn);
        expect(rotations, outcome == 'timeout' ? 4 : 1);
        recover = true;
        await fixture.api.accounts();
        expect(fixture.store.session?.refreshToken, 'new-refresh');
        expect(fixture.session.error, isNull);
      },
    );
  }

  test(
    'only refresh_invalid 401 deletes stored credentials and signs out',
    () async {
      final fixture = Fixture(
        (request) async => jsonResponse(401, {
          'code': request.path == '/auth/refresh'
              ? 'refresh_invalid'
              : 'unauthorized',
        }),
      );
      await fixture.initialize();
      await expectLater(
        fixture.api.accounts(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'refresh_invalid'),
        ),
      );
      expect(fixture.store.deletes, 1);
      expect(fixture.store.session, isNull);
      expect(fixture.session.user, isNull);
      expect(fixture.session.status, SessionStatus.signedOut);
    },
  );

  test(
    'biometric restore reads no session before a successful unlock',
    () async {
      final fixture = Fixture((_) async => jsonResponse(200, accountJson));
      fixture.store.biometrics = true;
      fixture.gate.allowed = false;
      await fixture.initialize();
      expect(fixture.session.status, SessionStatus.locked);
      expect(fixture.store.reads, 0);
      expect(fixture.session.user, isNull);
      expect(await fixture.session.unlock(), isFalse);
      expect(fixture.store.reads, 0);
      fixture.gate.allowed = true;
      expect(await fixture.session.unlock(), isTrue);
      expect(fixture.store.reads, 1);
      expect(fixture.session.user?.id, sampleUser.id);
    },
  );

  test(
    'locked requests cannot touch the network or read secure tokens',
    () async {
      var requests = 0;
      final fixture = Fixture((_) async {
        requests++;
        return jsonResponse(200, accountJson);
      });
      fixture.store.biometrics = true;
      await fixture.initialize();
      await expectLater(
        fixture.api.accounts(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'session_locked'),
        ),
      );
      expect(requests, 0);
      expect(fixture.store.reads, 0);
    },
  );

  test(
    'locking during rotation saves the new pair without unlocking or replaying',
    () async {
      final started = Completer<void>(), finish = Completer<void>();
      var replays = 0;
      final fixture = Fixture((request) async {
        if (request.path == '/auth/refresh') {
          started.complete();
          await finish.future;
          return jsonResponse(200, replacement.toJson());
        }
        if (request.headers['Authorization'] == 'Bearer new-access') replays++;
        return jsonResponse(401, {});
      });
      fixture.store.biometrics = true;
      await fixture.initialize();
      await fixture.session.unlock();
      final call = fixture.api.accounts();
      final assertion = expectLater(
        call,
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'session_locked'),
        ),
      );
      await started.future;
      fixture.session.lock();
      finish.complete();
      await assertion;
      expect(fixture.session.status, SessionStatus.locked);
      expect(fixture.session.user, isNull);
      expect(fixture.store.session?.refreshToken, 'new-refresh');
      expect(replays, 0);
      expect(await fixture.session.unlock(), isTrue);
    },
  );

  test(
    'sign out during rotation cannot resurrect stored credentials',
    () async {
      final started = Completer<void>(), finish = Completer<void>();
      final fixture = Fixture((request) async {
        if (request.path == '/auth/refresh') {
          started.complete();
          await finish.future;
          return jsonResponse(200, replacement.toJson());
        }
        return jsonResponse(request.path == '/auth/logout' ? 204 : 401, {});
      });
      await fixture.initialize();
      final assertion = expectLater(
        fixture.api.accounts(),
        throwsA(isA<ApiError>()),
      );
      await started.future;
      await fixture.session.signOut();
      finish.complete();
      await assertion;
      expect(fixture.store.session, isNull);
      expect(fixture.session.status, SessionStatus.signedOut);
    },
  );

  test(
    'a new login never joins an older session refresh still in flight',
    () async {
      final oldStarted = Completer<void>(), releaseOld = Completer<void>();
      final third = SessionData(
        accessToken: 'third-access',
        refreshToken: 'third-refresh',
        expiresAt: DateTime.utc(2027),
        user: sampleUser,
      );
      var newRotations = 0;
      final fixture = Fixture((request) async {
        if (request.path == '/auth/login') {
          return jsonResponse(200, replacement.toJson());
        }
        if (request.path == '/auth/refresh') {
          if ((request.data as Json)['refreshToken'] == 'old-refresh') {
            oldStarted.complete();
            await releaseOld.future;
            return jsonResponse(200, replacement.toJson());
          }
          newRotations++;
          return jsonResponse(200, third.toJson());
        }
        return request.headers['Authorization'] == 'Bearer third-access'
            ? jsonResponse(200, accountJson)
            : jsonResponse(401, {});
      });
      await fixture.initialize();
      final oldResult = expectLater(
        fixture.api.accounts(),
        throwsA(isA<ApiError>()),
      );
      await oldStarted.future;
      await fixture.session.signIn(
        email: sampleUser.email,
        password: 'password-123',
      );
      await fixture.api.accounts();
      expect(newRotations, 1);
      releaseOld.complete();
      await oldResult;
      expect(fixture.store.session?.refreshToken, 'third-refresh');
      expect(fixture.session.status, SessionStatus.signedIn);
    },
  );

  test(
    'failed secure persistence never lets requests use unsaved rotated tokens',
    () async {
      var replays = 0;
      final fixture = Fixture((request) async {
        if (request.path == '/auth/refresh') {
          return jsonResponse(200, replacement.toJson());
        }
        if (request.headers['Authorization'] == 'Bearer new-access') replays++;
        return jsonResponse(401, {});
      });
      fixture.store.beforeWrite = () async =>
          throw StateError('storage unavailable');
      await fixture.initialize();
      await expectLater(
        fixture.api.accounts(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'secure_storage'),
        ),
      );
      expect(replays, 0);
      expect(fixture.store.session?.refreshToken, 'old-refresh');
      expect(fixture.session.status, SessionStatus.signedIn);
    },
  );

  test('login and registration are anonymous and save a session before publishing it', () async {
    final paths = <String>[];
    final fixture = Fixture((request) async {
      paths.add(request.path);
      expect(request.headers.containsKey('Authorization'), isFalse);
      return jsonResponse(200, replacement.toJson());
    });
    fixture.store.session = null;
    await fixture.initialize();
    await fixture.session.signIn(
      email: 'test@example.test',
      password: 'password-123',
    );
    expect(fixture.session.status, SessionStatus.signedIn);
    expect(fixture.store.session?.accessToken, 'new-access');
    await fixture.session.register(
      email: 'test@example.test',
      displayName: 'Test',
      handle: '@test',
      password: 'password-123',
    );
    expect(paths, ['/auth/login', '/auth/register']);
  });

  test(
    'biometric preference requires authentication and the offer is persisted',
    () async {
      final fixture = Fixture((_) async => jsonResponse(200, {}));
      await fixture.initialize();
      expect(fixture.session.shouldOfferBiometrics, isTrue);
      fixture.gate.allowed = false;
      await expectLater(
        fixture.session.setBiometrics(true),
        throwsA(isA<ApiError>()),
      );
      expect(fixture.store.biometrics, isFalse);
      fixture.gate.allowed = true;
      await fixture.session.setBiometrics(true);
      expect(fixture.store.biometrics, isTrue);
      expect(fixture.store.offerSeen, isTrue);
      expect(fixture.session.shouldOfferBiometrics, isFalse);
      fixture.session.lock();
      expect(fixture.session.status, SessionStatus.locked);
    },
  );
}

const sampleUser = AuthUser(
  id: 'user-1',
  email: 'user@example.test',
  displayName: 'Nino',
  handle: '@nino',
);
final original = SessionData(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresAt: DateTime.utc(2026),
  user: sampleUser,
);
final replacement = SessionData(
  accessToken: 'new-access',
  refreshToken: 'new-refresh',
  expiresAt: DateTime.utc(2027),
  user: sampleUser,
);
const accountJson = [
  {
    'id': 'account-1',
    'currency': 'GEL',
    'balance': {'minor': 10000, 'currency': 'GEL'},
    'version': 1,
  },
];

ResponseBody jsonResponse(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

class MemoryStore implements SessionStore {
  SessionData? session = original;
  bool biometrics = false, offerSeen = false;
  int reads = 0, deletes = 0;
  Future<void> Function()? beforeWrite;
  @override
  Future<bool> readBiometricsEnabled() async => biometrics;
  @override
  Future<void> writeBiometricsEnabled(bool value) async {
    biometrics = value;
  }

  @override
  Future<bool> readBiometricsOfferSeen() async => offerSeen;
  @override
  Future<void> writeBiometricsOfferSeen(bool value) async {
    offerSeen = value;
  }

  @override
  Future<SessionData?> readSession() async {
    reads++;
    return session;
  }

  @override
  Future<void> writeSession(SessionData value) async {
    await beforeWrite?.call();
    session = value;
  }

  @override
  Future<void> deleteSession() async {
    deletes++;
    session = null;
  }
}

class FakeBiometrics implements BiometricGate {
  bool allowed = true, supported = true;
  @override
  Future<bool> available() async => supported;
  @override
  Future<bool> authenticate() async => allowed;
}

class Fixture {
  Fixture(Future<ResponseBody> Function(RequestOptions) respond) {
    dio.httpClientAdapter = FakeAdapter(respond);
    session = SessionController(
      dio: dio,
      store: store,
      biometrics: gate,
      delay: (duration) async {
        delays.add(duration);
      },
    );
    api = BankApi(dio);
    addTearDown(() {
      session.dispose();
      dio.close(force: true);
    });
  }
  final dio = Dio(BaseOptions(baseUrl: 'https://tetri.example/api/v1'));
  final store = MemoryStore();
  final gate = FakeBiometrics();
  final delays = <Duration>[];
  late final SessionController session;
  late final BankApi api;
  Future<void> initialize() => session.initialize();
}
