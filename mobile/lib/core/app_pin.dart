import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'strings_pin.dart';

abstract interface class AppPinStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureAppPinStore implements AppPinStore {
  SecureAppPinStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'tetri.appPin';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: key);
}

abstract interface class PinDeriver {
  Future<String> defaultAlgorithm();
  Future<Uint8List> derive(String pin, Uint8List salt, String algorithm);
}

class DevicePinDeriver implements PinDeriver {
  const DevicePinDeriver();
  static const _channel = MethodChannel('dev.tetri/pin');

  @override
  Future<String> defaultAlgorithm() async {
    final algorithm = await _channel.invokeMethod<String>('defaultAlgorithm');
    if (algorithm == null) throw const PinException(PinStrings.unavailable);
    return algorithm;
  }

  @override
  Future<Uint8List> derive(String pin, Uint8List salt, String algorithm) async {
    final bytes = await _channel.invokeMethod<Uint8List>('derive', {
      'pin': pin,
      'salt': salt,
      'algorithm': algorithm,
    });
    if (bytes == null) throw const PinException(PinStrings.unavailable);
    return bytes;
  }
}

class PinException implements Exception {
  const PinException(this.message, {this.retryAt});
  final String message;
  final DateTime? retryAt;

  @override
  String toString() => message;
}

/// The session layer authorizes creation, clearing and biometric attempt resets.
class AppPinController {
  AppPinController({
    required this.store,
    required this.deriver,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const pinLength = 4;
  static const saltLength = 16;
  static const hashLength = 32;
  static const attemptsBeforeCooldown = 5;
  static const hardAttemptLimit = 10;
  static const initialCooldown = Duration(seconds: 30);
  static const maximumCooldown = Duration(minutes: 15);
  static const sha256 = 'pbkdf2-sha256';
  static const sha1 = 'pbkdf2-sha1';

  final AppPinStore store;
  final PinDeriver deriver;
  final DateTime Function() _now;

  // All controllers share the same secure-storage key, including recreated ones.
  static Future<void> _operations = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> isEnabled() => _serialized(() async => await _read() != null);

  Future<void> create(String pin) => _serialized(() async {
    _validatePin(pin);
    final String algorithm;
    final Uint8List salt;
    try {
      algorithm = await deriver.defaultAlgorithm();
      if (!_supported(algorithm)) {
        throw const PinException(PinStrings.unavailable);
      }
      final random = Random.secure();
      salt = Uint8List.fromList(
        List.generate(saltLength, (_) => random.nextInt(256)),
      );
    } catch (_) {
      throw const PinException(PinStrings.unavailable);
    }
    final hash = await _derive(pin, salt, algorithm);
    await _write(
      _PinRecord(
        salt: salt,
        hash: hash,
        algorithm: algorithm,
        failures: 0,
        lastAttempt: null,
        blockedUntil: null,
      ),
    );
  });

  Future<void> verify(String pin) => _serialized(() async {
    _validatePin(pin);
    final record = await _read();
    if (record == null) throw const PinException(PinStrings.notConfigured);
    if (record.failures >= hardAttemptLimit) {
      throw const PinException(PinStrings.attemptLimit);
    }
    final now = _now().toUtc();
    if (record.blockedUntil != null && now.isBefore(record.blockedUntil!)) {
      throw PinException(PinStrings.cooldown, retryAt: record.blockedUntil);
    }
    if (record.lastAttempt != null && now.isBefore(record.lastAttempt!)) {
      throw PinException(PinStrings.clockChanged, retryAt: record.lastAttempt);
    }
    final failures = record.failures + 1;
    final wait = _cooldown(failures);
    final reserved = record.attempts(
      failures,
      now,
      wait == Duration.zero ? null : now.add(wait),
    );
    // A crash or native failure must consume the attempt, so reserve before KDF.
    await _write(reserved);
    final candidate = await _derive(pin, record.salt, record.algorithm);
    final matches = _equalHash(record.hash, candidate);
    candidate.fillRange(0, candidate.length, 0);
    if (matches) {
      // A failed reset write never grants access, even when the PIN matched.
      await _write(record.attempts(0, now, null));
      return;
    }
    if (failures >= hardAttemptLimit) {
      throw const PinException(PinStrings.attemptLimit);
    }
    throw PinException(
      wait == Duration.zero ? PinStrings.incorrect : PinStrings.cooldown,
      retryAt: reserved.blockedUntil,
    );
  });

  /// Only the session's successful biometric path may call this method.
  Future<void> resetAttempts() => _serialized(() async {
    final record = await _read();
    if (record != null) await _write(record.attempts(0, _now().toUtc(), null));
  });

  Future<void> clear() => _serialized(() async {
    try {
      await store.clear();
    } catch (_) {
      throw const PinException(PinStrings.storageUnavailable);
    }
  });

  static void _validatePin(String pin) {
    if (pin.length != pinLength || !RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      throw const PinException(PinStrings.invalidFormat);
    }
  }

  static bool _supported(String algorithm) =>
      algorithm == sha256 || algorithm == sha1;

  static Duration _cooldown(int failures) {
    if (failures < attemptsBeforeCooldown) return Duration.zero;
    final seconds =
        initialCooldown.inSeconds * (1 << (failures - attemptsBeforeCooldown));
    return Duration(seconds: min(seconds, maximumCooldown.inSeconds));
  }

  Future<Uint8List> _derive(
    String pin,
    Uint8List salt,
    String algorithm,
  ) async {
    try {
      final hash = await deriver.derive(
        pin,
        Uint8List.fromList(salt),
        algorithm,
      );
      if (hash.length != hashLength) {
        throw const PinException(PinStrings.unavailable);
      }
      return Uint8List.fromList(hash);
    } catch (_) {
      throw const PinException(PinStrings.unavailable);
    }
  }

  static bool _equalHash(Uint8List expected, Uint8List actual) {
    var difference = 0;
    for (var index = 0; index < hashLength; index++) {
      difference |= expected[index] ^ actual[index];
    }
    return difference == 0;
  }

  Future<_PinRecord?> _read() async {
    final String? encoded;
    try {
      encoded = await store.read();
    } catch (_) {
      throw const PinException(PinStrings.storageUnavailable);
    }
    if (encoded == null) return null;
    try {
      return _PinRecord.decode(encoded);
    } catch (_) {
      throw const PinException(PinStrings.corruptRecord);
    }
  }

  Future<void> _write(_PinRecord record) async {
    try {
      await store.write(record.encode());
    } catch (_) {
      throw const PinException(PinStrings.storageUnavailable);
    }
  }
}

final class _PinRecord {
  const _PinRecord({
    required this.salt,
    required this.hash,
    required this.algorithm,
    required this.failures,
    required this.lastAttempt,
    required this.blockedUntil,
  });

  final Uint8List salt, hash;
  final String algorithm;
  final int failures;
  final DateTime? lastAttempt, blockedUntil;
  static const _fields = {
    'version',
    'salt',
    'hash',
    'algorithm',
    'failures',
    'lastAttempt',
    'blockedUntil',
  };

  _PinRecord attempts(
    int failures,
    DateTime lastAttempt,
    DateTime? blockedUntil,
  ) => _PinRecord(
    salt: salt,
    hash: hash,
    algorithm: algorithm,
    failures: failures,
    lastAttempt: lastAttempt,
    blockedUntil: blockedUntil,
  );

  String encode() => jsonEncode({
    'version': 1,
    'salt': base64Encode(salt),
    'hash': base64Encode(hash),
    'algorithm': algorithm,
    'failures': failures,
    'lastAttempt': lastAttempt?.toIso8601String(),
    'blockedUntil': blockedUntil?.toIso8601String(),
  });

  factory _PinRecord.decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic> ||
        value.length != _fields.length ||
        !value.keys.toSet().containsAll(_fields) ||
        value['version'] != 1 ||
        value['version'] is! int ||
        value['algorithm'] is! String ||
        !AppPinController._supported(value['algorithm'] as String) ||
        value['failures'] is! int) {
      throw const FormatException('Invalid PIN record');
    }
    final failures = value['failures'] as int;
    final lastAttempt = _date(value['lastAttempt']);
    final blockedUntil = _date(value['blockedUntil']);
    if (failures < 0 ||
        failures > AppPinController.hardAttemptLimit ||
        (failures > 0 && lastAttempt == null) ||
        (failures < AppPinController.attemptsBeforeCooldown &&
            blockedUntil != null) ||
        (failures >= AppPinController.attemptsBeforeCooldown &&
            blockedUntil == null) ||
        (blockedUntil != null &&
            blockedUntil !=
                lastAttempt!.add(AppPinController._cooldown(failures)))) {
      throw const FormatException('Invalid PIN attempts');
    }
    return _PinRecord(
      salt: _bytes(value['salt'], AppPinController.saltLength),
      hash: _bytes(value['hash'], AppPinController.hashLength),
      algorithm: value['algorithm'] as String,
      failures: failures,
      lastAttempt: lastAttempt,
      blockedUntil: blockedUntil,
    );
  }

  static Uint8List _bytes(Object? encoded, int length) {
    if (encoded is! String) throw const FormatException('Invalid PIN bytes');
    final decoded = base64Decode(encoded);
    if (decoded.length != length || base64Encode(decoded) != encoded) {
      throw const FormatException('Invalid PIN bytes');
    }
    return decoded;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Invalid PIN timestamp');
    final parsed = DateTime.parse(value);
    if (!parsed.isUtc || parsed.toIso8601String() != value) {
      throw const FormatException('Invalid PIN timestamp');
    }
    return parsed;
  }
}
