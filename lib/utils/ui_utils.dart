import 'package:flutter/material.dart';
import '../constants.dart';

class UiUtils {
  static void showErrorToast(
    String endpoint,
    String error, {
    String? errorCode,
  }) {
    if (!AppConstants.isInForeground) return;
    final title = errorCode != null
        ? 'Request Failed [$errorCode]: $endpoint'
        : 'Request Failed: $endpoint';

    AppConstants.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
