import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = Provider<ValueNotifier<ThemeMode>>((ref) {
  final preference = ThemePreference(const FlutterSecureStorage());
  ref.onDispose(preference.dispose);
  unawaited(preference.load());
  return preference;
});

class ThemePreference extends ValueNotifier<ThemeMode> {
  ThemePreference(this.storage) : super(ThemeMode.system);
  final FlutterSecureStorage storage;
  bool _changed = false;
  bool _disposed = false;
  Future<void> _write = Future.value();

  Future<void> load() async {
    try {
      final saved = await storage.read(key: 'tetri.theme');
      if (_disposed || _changed) return;
      super.value =
          ThemeMode.values.where((mode) => mode.name == saved).firstOrNull ??
          ThemeMode.system;
    } catch (_) {
      // A preference read failure leaves the system theme available.
    }
  }

  @override
  set value(ThemeMode mode) {
    _changed = true;
    super.value = mode;
    _write = _write
        .then((_) => storage.write(key: 'tetri.theme', value: mode.name))
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
