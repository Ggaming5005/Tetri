import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tetri/core/app_pin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const deriver = DevicePinDeriver();
  final salt = Uint8List.fromList(List.generate(16, (i) => i));
  final vectors = [
    (
      '1234',
      AppPinController.sha256,
      '9f39d9c71c22c4c459bc2cbacc6d74e2184185d671d91f0a34a6834413a0849d',
    ),
    (
      '0007',
      AppPinController.sha256,
      'a3cb8c512256eef33e6bfc93604d8174bee03c380b40580246f425526fae91c8',
    ),
    (
      '1234',
      AppPinController.sha1,
      'f156a834d84afa2d04ec120f6bdda0a3a15a576f1e652c55142c6996acd1700b',
    ),
  ];
  var result = 'Native PIN checks passed';
  try {
    if (await deriver.defaultAlgorithm() != AppPinController.sha256) {
      throw StateError('Wrong default algorithm');
    }
    for (final vector in vectors) {
      final hash = await deriver.derive(vector.$1, salt, vector.$2);
      final hex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (hex != vector.$3) throw StateError('Known vector mismatch');
    }
    try {
      await deriver.derive('12345', salt, AppPinController.sha256);
      throw StateError('Native invalid-input check missing');
    } on PlatformException catch (error) {
      if (error.code != 'pin_invalid_input') rethrow;
    }
  } catch (error) {
    result = 'Native PIN check failed: $error';
  }
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(result))),
    ),
  );
}
