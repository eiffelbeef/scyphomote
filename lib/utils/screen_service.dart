import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenService {
  static const _methodChannel = MethodChannel('com.eiffelbeef.scyphomote/screen');
  static const _eventChannel = EventChannel('com.eiffelbeef.scyphomote/screen_events');

  static Stream<String>? _eventStream;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<bool> isScreenInteractive() async {
    if (!isSupported) return true;
    try {
      final bool? isInteractive = await _methodChannel.invokeMethod('isScreenInteractive');
      return isInteractive ?? true;
    } catch (_) {
      return true;
    }
  }

  static Stream<String> get onScreenEvent {
    if (!isSupported) return const Stream.empty();
    _eventStream ??= _eventChannel.receiveBroadcastStream().cast<String>();
    return _eventStream!;
  }
}
