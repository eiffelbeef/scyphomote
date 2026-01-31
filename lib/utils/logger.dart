import 'package:flutter/foundation.dart';

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
