import 'package:flutter/services.dart';

abstract final class TetriPlatform {
  static const _channel = MethodChannel('dev.tetri/platform');
  static Future<void> openRepository() =>
      _channel.invokeMethod<void>('openRepository');
}
