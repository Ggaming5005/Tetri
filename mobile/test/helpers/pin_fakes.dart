import 'dart:typed_data';

import 'package:tetri/core/app_pin.dart';

class MemoryPinStore implements AppPinStore {
  String? value;
  Future<void> Function()? beforeWrite;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    await beforeWrite?.call();
    value = next;
  }

  @override
  Future<void> clear() async => value = null;
}

// Session tests isolate orchestration; native KDF vectors are checked separately.
class FakePinDeriver implements PinDeriver {
  Future<void> Function()? beforeDerive;
  @override
  Future<String> defaultAlgorithm() async => AppPinController.sha256;
  @override
  Future<Uint8List> derive(String pin, Uint8List salt, String algorithm) async {
    await beforeDerive?.call();
    return Uint8List.fromList(
      List.generate(
        AppPinController.hashLength,
        (index) =>
            pin.codeUnitAt(index % pin.length) ^
            salt[index % salt.length] ^
            index,
      ),
    );
  }
}
