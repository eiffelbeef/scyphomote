import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

void logDebug(Object? object) {
  if (kDebugMode) {
    debugPrint('DEBUG: ${object?.toString()}');
  }
}

void logError(Object? object) {
  if (kDebugMode) {
    debugPrint('ERROR: ${object?.toString()}');
  }
}

class CrashLog {
  static const String _fileName = 'crash_log.txt';
  static const int _maxBytes = 64 * 1024; // 64 KB

  static File? _file;

  static Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/$_fileName');
    return _file!;
  }

  static Future<void> record(Object error, [StackTrace? stackTrace]) async {
    try {
      final file = await _getFile();
      final timestamp = DateTime.now().toIso8601String();
      final buffer = StringBuffer()
        ..writeln('[$timestamp]')
        ..writeln(error.toString());
      if (stackTrace != null) {
        // Keep only first 8 frames to avoid bloat
        final frames = stackTrace.toString().split('\n').take(8).join('\n');
        buffer.writeln(frames);
      }
      buffer.writeln('---');

      await file.writeAsString(buffer.toString(), mode: FileMode.append);

      // Truncate if too large: keep the newest half
      final length = await file.length();
      if (length > _maxBytes) {
        final content = await file.readAsString();
        final half = content.length ~/ 2;
        // Cut at the next entry boundary after the midpoint
        final cutIndex = content.indexOf('\n---\n', half);
        if (cutIndex > 0) {
          await file.writeAsString(content.substring(cutIndex + 5));
        }
      }
    } catch (_) {
      // Never let logging itself crash the app
    }
  }

  static Future<String> read() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return '';
  }

  /// Clear the crash log file.
  static Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
