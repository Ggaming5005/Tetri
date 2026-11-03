import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/app_pin.dart';
import 'package:tetri/core/strings_pin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creating a PIN persists only a fresh salt, derived verifier and versioned policy state', () async {
    final fixture = PinFixture();
    expect(await fixture.controller.isEnabled(), isFalse);
    expect(fixture.deriver.defaultCalls, 0);
    await fixture.controller.create('0123');
    final first = fixture.record;
    expect(first.keys.toSet(), {
      'version',
      'salt',
      'hash',
      'algorithm',
      'failures',
      'lastAttempt',
      'blockedUntil',
    });
    expect(first['version'], 1);
    expect(first.values, isNot(contains('0123')));
    expect(base64Decode(first['salt'] as String), hasLength(16));
    expect(base64Decode(first['hash'] as String), hasLength(32));
    expect(first['algorithm'], AppPinController.sha256);
    expect(first['failures'], 0);
    expect(first['lastAttempt'], isNull);
    expect(first['blockedUntil'], isNull);
    expect(await fixture.recreated().isEnabled(), isTrue);
    expect(fixture.deriver.defaultCalls, 1);
    await fixture.controller.create('0123');
    expect(fixture.record['salt'], isNot(first['salt']));
    expect(fixture.record['hash'], isNot(first['hash']));
    await fixture.controller.verify('0123');
  });

  test(
    'four ASCII digits are required before storage access or derivation',
    () async {
      final fixture = PinFixture();
      for (final invalid in [
        '',
        '123',
        '12345',
        '12a4',
        '-123',
        ' 1234',
        '1234\n',
        '１２３４',
        '١٢٣٤',
      ]) {
        await expectLater(
          fixture.controller.create(invalid),
          pinError(PinStrings.invalidFormat),
        );
        await expectLater(
          fixture.controller.verify(invalid),
          pinError(PinStrings.invalidFormat),
        );
      }
      expect(fixture.store.reads, 0);
      expect(fixture.store.writes, isEmpty);
      expect(fixture.deriver.defaultCalls, 0);
      expect(fixture.deriver.calls, 0);
      await expectLater(
        fixture.controller.verify('1234'),
        pinError(PinStrings.notConfigured),
      );
    },
  );

  test(
    'each attempt is reserved before the KDF and failures survive recreation',
    () async {
      final fixture = PinFixture();
      await fixture.controller.create('1234');
      fixture.deriver.beforeDerive = () async {
        expect(fixture.record['failures'], 1);
        expect(fixture.record['lastAttempt'], fixture.now.toIso8601String());
      };
      await expectLater(
        fixture.controller.verify('4321'),
        pinError(PinStrings.incorrect),
      );
      fixture.deriver.beforeDerive = null;
      await expectLater(
        fixture.recreated().verify('4321'),
        pinError(PinStrings.incorrect),
      );
      expect(fixture.record['failures'], 2);
      expect(fixture.deriver.calls, 3);
    },
  );

  test(
    'fifth attempt starts a persisted cooldown and later failures double it',
    () async {
      final fixture = PinFixture();
      await fixture.controller.create('1234');
      for (var attempt = 1; attempt <= 4; attempt++) {
        await expectLater(
          fixture.controller.verify('4321'),
          pinError(PinStrings.incorrect),
        );
      }
      final firstRetry = fixture.now.add(const Duration(seconds: 30));
      await expectLater(
        fixture.controller.verify('4321'),
        pinError(PinStrings.cooldown, retryAt: firstRetry),
      );
      expect(fixture.record['failures'], 5);
      final calls = fixture.deriver.calls;
      fixture.now = firstRetry.subtract(const Duration(microseconds: 1));
      await expectLater(
        fixture.recreated().verify('1234'),
        pinError(PinStrings.cooldown, retryAt: firstRetry),
      );
      expect(fixture.deriver.calls, calls);
      fixture.now = firstRetry;
      await expectLater(
        fixture.recreated().verify('4321'),
        pinError(
          PinStrings.cooldown,
          retryAt: fixture.now.add(const Duration(seconds: 60)),
        ),
      );
      expect(fixture.record['failures'], 6);
    },
  );

  test('concurrent controllers cannot bypass reservation or exceed five guesses before cooldown', () async {
    final fixture = PinFixture();
    await fixture.controller.create('1234');
    var active = 0, maximumActive = 0;
    fixture.deriver.beforeDerive = () async {
      active++;
      if (active > maximumActive) maximumActive = active;
      await Future<void>.delayed(Duration.zero);
      active--;
    };
    final outcomes = await Future.wait(
      List.generate(20, (_) async {
        try {
          await fixture.recreated().verify('4321');
          return false;
        } on PinException {
          return true;
        }
      }),
    );
    expect(outcomes, everyElement(isTrue));
    expect(fixture.record['failures'], 5);
    expect(fixture.deriver.calls, 6);
    expect(maximumActive, 1);
  });

  test('ten failed guesses remain blocked after restart and a clock jump, until biometric reset', () async {
    final fixture = PinFixture();
    await fixture.controller.create('1234');
    final original = fixture.record;
    for (
      var attempt = 1;
      attempt <= AppPinController.hardAttemptLimit;
      attempt++
    ) {
      await expectLater(
        fixture.recreated().verify('4321'),
        throwsA(isA<PinException>()),
      );
      fixture.advancePastCooldown();
    }
    expect(fixture.record['failures'], 10);
    final blockedUntil = DateTime.parse(
      fixture.record['blockedUntil'] as String,
    );
    final lastAttempt = DateTime.parse(fixture.record['lastAttempt'] as String);
    expect(
      blockedUntil.difference(lastAttempt),
      AppPinController.maximumCooldown,
    );
    final calls = fixture.deriver.calls;
    fixture.now = fixture.now.add(const Duration(days: 3650));
    await expectLater(
      fixture.recreated().verify('1234'),
      pinError(PinStrings.attemptLimit),
    );
    expect(fixture.deriver.calls, calls);
    await fixture.controller.resetAttempts();
    expect(fixture.record['hash'], original['hash']);
    expect(fixture.record['salt'], original['salt']);
    expect(fixture.record['algorithm'], original['algorithm']);
    expect(fixture.record['failures'], 0);
    expect(fixture.record['blockedUntil'], isNull);
    await fixture.recreated().verify('1234');
  });

  test(
    'the tenth reserved attempt may succeed and reset all failures',
    () async {
      final fixture = PinFixture();
      await fixture.controller.create('1234');
      for (
        var attempt = 1;
        attempt < AppPinController.hardAttemptLimit;
        attempt++
      ) {
        await expectLater(
          fixture.controller.verify('4321'),
          throwsA(isA<PinException>()),
        );
        fixture.advancePastCooldown();
      }
      await fixture.recreated().verify('1234');
      expect(fixture.record['failures'], 0);
      expect(fixture.record['blockedUntil'], isNull);
      await expectLater(
        fixture.controller.verify('4321'),
        pinError(PinStrings.incorrect),
      );
      expect(fixture.record['failures'], 1);
    },
  );

  test('moving the wall clock backwards cannot bypass attempts or a blocked-until timestamp', () async {
    final fixture = PinFixture();
    await fixture.controller.create('1234');
    await expectLater(
      fixture.controller.verify('4321'),
      pinError(PinStrings.incorrect),
    );
    final originalTime = fixture.now;
    fixture.now = fixture.now.subtract(const Duration(hours: 2));
    final calls = fixture.deriver.calls;
    await expectLater(
      fixture.recreated().verify('1234'),
      pinError(PinStrings.clockChanged, retryAt: originalTime),
    );
    expect(fixture.deriver.calls, calls);
    fixture.now = originalTime;
    for (var attempt = 2; attempt <= 5; attempt++) {
      await expectLater(
        fixture.controller.verify('4321'),
        throwsA(isA<PinException>()),
      );
    }
    fixture.now = originalTime.subtract(const Duration(days: 1));
    await expectLater(
      fixture.recreated().verify('1234'),
      pinError(
        PinStrings.cooldown,
        retryAt: originalTime.add(const Duration(seconds: 30)),
      ),
    );
    expect(fixture.record['failures'], 5);
    await fixture.controller.resetAttempts();
    await fixture.controller.verify('1234');
  });

  test(
    'malformed records fail closed for both availability and verification',
    () async {
      final fixture = PinFixture();
      await fixture.controller.create('1234');
      final original = fixture.record;
      final corruptions = <String>[
        '',
        '{',
        'null',
        '[]',
        jsonEncode({...original, 'version': 2}),
        jsonEncode({...original, 'version': 1.0}),
        jsonEncode({...original, 'algorithm': 'sha256'}),
        jsonEncode({...original, 'salt': base64Encode(Uint8List(15))}),
        jsonEncode({...original, 'hash': base64Encode(Uint8List(31))}),
        jsonEncode({...original, 'hash': 'not base64'}),
        jsonEncode({...original, 'failures': -1}),
        jsonEncode({...original, 'failures': 11}),
        jsonEncode({...original, 'failures': 1.0}),
        jsonEncode({...original, 'failures': 1}),
        jsonEncode({...original, 'extra': '1234'}),
        jsonEncode({...original, 'lastAttempt': '2030-01-02T12:00:00'}),
        jsonEncode({
          ...original,
          'failures': 5,
          'lastAttempt': fixture.now.toIso8601String(),
        }),
        jsonEncode({
          ...original,
          'failures': 5,
          'lastAttempt': fixture.now.toIso8601String(),
          'blockedUntil': fixture.now.toIso8601String(),
        }),
      ];
      final calls = fixture.deriver.calls;
      for (final encoded in corruptions) {
        fixture.store.value = encoded;
        await expectLater(
          fixture.recreated().isEnabled(),
          pinError(PinStrings.corruptRecord),
        );
        await expectLater(
          fixture.recreated().verify('1234'),
          pinError(PinStrings.corruptRecord),
        );
      }
      expect(fixture.deriver.calls, calls);
      expect(fixture.deriver.defaultCalls, 1);
    },
  );

  test(
    'storage reads and reservation writes fail closed without deriving',
    () async {
      final fixture = PinFixture();
      await fixture.controller.create('1234');
      fixture.store.failReads = true;
      await expectLater(
        fixture.controller.isEnabled(),
        pinError(PinStrings.storageUnavailable),
      );
      await expectLater(
        fixture.controller.verify('1234'),
        pinError(PinStrings.storageUnavailable),
      );
      fixture.store.failReads = false;
      fixture.store.failWriteAt = fixture.store.writeCalls + 1;
      await expectLater(
        fixture.controller.verify('1234'),
        pinError(PinStrings.storageUnavailable),
      );
      expect(fixture.deriver.calls, 1);
      expect(fixture.record['failures'], 0);
    },
  );

  test('a matching PIN never grants access when persisting the success reset fails', () async {
    final fixture = PinFixture();
    await fixture.controller.create('1234');
    fixture.store.failWriteAt = fixture.store.writeCalls + 2;
    await expectLater(
      fixture.controller.verify('1234'),
      pinError(PinStrings.storageUnavailable),
    );
    expect(fixture.record['failures'], 1);
    fixture.store.failWriteAt = null;
    await fixture.recreated().verify('1234');
    expect(fixture.record['failures'], 0);
  });

  test('native failures and invalid output consume the reservation but never unlock', () async {
    final fixture = PinFixture();
    await fixture.controller.create('1234');
    fixture.deriver.failDerive = true;
    await expectLater(
      fixture.controller.verify('1234'),
      pinError(PinStrings.unavailable),
    );
    expect(fixture.record['failures'], 1);
    fixture.deriver.failDerive = false;
    fixture.deriver.outputLength = 31;
    await expectLater(
      fixture.recreated().verify('1234'),
      pinError(PinStrings.unavailable),
    );
    expect(fixture.record['failures'], 2);
  });

  test('creation accepts the native legacy choice but never downgrades a saved algorithm', () async {
    final fixture = PinFixture();
    fixture.deriver.algorithm = AppPinController.sha1;
    await fixture.controller.create('1234');
    expect(fixture.record['algorithm'], AppPinController.sha1);
    fixture.deriver.algorithm = AppPinController.sha256;
    await fixture.recreated().verify('1234');
    expect(fixture.deriver.defaultCalls, 1);
    expect(fixture.deriver.usedAlgorithms, everyElement(AppPinController.sha1));
    fixture.deriver.algorithm = 'weak';
    await expectLater(
      fixture.controller.create('1234'),
      pinError(PinStrings.unavailable),
    );
    expect(fixture.record['algorithm'], AppPinController.sha1);
  });

  test(
    'clear waits for an in-flight attempt and reports storage errors',
    () async {
      final fixture = PinFixture();
      await fixture.controller.create('1234');
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.deriver.beforeDerive = () async {
        entered.complete();
        await release.future;
      };
      final attempted = expectLater(
        fixture.controller.verify('4321'),
        pinError(PinStrings.incorrect),
      );
      await entered.future;
      final clearing = fixture.recreated().clear();
      expect(fixture.store.clears, 0);
      release.complete();
      await attempted;
      await clearing;
      expect(await fixture.controller.isEnabled(), isFalse);
      fixture.store.failClear = true;
      await expectLater(
        fixture.controller.clear(),
        pinError(PinStrings.storageUnavailable),
      );
    },
  );

  test(
    'device derivation uses the agreed method channel and typed byte contract',
    () async {
      const channel = MethodChannel('dev.tetri/pin');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'defaultAlgorithm'
                ? AppPinController.sha256
                : Uint8List(32);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const deriver = DevicePinDeriver();
      expect(await deriver.defaultAlgorithm(), AppPinController.sha256);
      final salt = Uint8List(16);
      expect(
        await deriver.derive('0123', salt, AppPinController.sha256),
        hasLength(32),
      );
      expect(calls.map((call) => call.method), ['defaultAlgorithm', 'derive']);
      expect(calls.last.arguments, {
        'pin': '0123',
        'salt': salt,
        'algorithm': AppPinController.sha256,
      });
    },
  );
}

Matcher pinError(String message, {DateTime? retryAt}) => throwsA(
  isA<PinException>()
      .having((error) => error.message, 'message', message)
      .having((error) => error.retryAt, 'retryAt', retryAt),
);

class PinFixture {
  final store = MemoryPinStore();
  final deriver = FakePinDeriver();
  DateTime now = DateTime.utc(2030, 1, 2, 12);
  late final controller = recreated();
  AppPinController recreated() =>
      AppPinController(store: store, deriver: deriver, now: () => now);
  Map<String, dynamic> get record =>
      jsonDecode(store.value!) as Map<String, dynamic>;
  void advancePastCooldown() {
    final until = record['blockedUntil'] as String?;
    if (until != null) now = DateTime.parse(until);
  }
}

class MemoryPinStore implements AppPinStore {
  String? value;
  final writes = <String>[];
  int reads = 0, writeCalls = 0, clears = 0;
  int? failWriteAt;
  bool failReads = false, failClear = false;

  @override
  Future<String?> read() async {
    reads++;
    if (failReads) throw StateError('storage unavailable');
    return value;
  }

  @override
  Future<void> write(String next) async {
    writeCalls++;
    if (writeCalls == failWriteAt) throw StateError('storage unavailable');
    value = next;
    writes.add(next);
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('storage unavailable');
    clears++;
    value = null;
  }
}

/// Deliberately cheap test derivation. Production always calls the native KDF.
class FakePinDeriver implements PinDeriver {
  String algorithm = AppPinController.sha256;
  int defaultCalls = 0, calls = 0, outputLength = 32;
  bool failDerive = false;
  Future<void> Function()? beforeDerive;
  final usedAlgorithms = <String>[];

  @override
  Future<String> defaultAlgorithm() async {
    defaultCalls++;
    return algorithm;
  }

  @override
  Future<Uint8List> derive(String pin, Uint8List salt, String algorithm) async {
    calls++;
    usedAlgorithms.add(algorithm);
    await beforeDerive?.call();
    if (failDerive) throw const PinException('native unavailable');
    return Uint8List.fromList(
      List.generate(
        outputLength,
        (index) =>
            salt[index % salt.length] ^
            pin.codeUnitAt(index % pin.length) ^
            (algorithm == AppPinController.sha256 ? 0x55 : 0xaa),
      ),
    );
  }
}
