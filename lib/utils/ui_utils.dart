import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../constants.dart';

extension ThemeSystemUiExtension on ThemeData {
  SystemUiOverlayStyle get bottomSystemUiOverlayStyleOnBackground {
    return SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );
  }

  SystemUiOverlayStyle get bottomSystemUiOverlayStyleOverScrolled {
    return SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarContrastEnforced: true,
    );
  }
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

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

  static void showSnackBar(BuildContext? context, String message) {
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  static double getBottomPaddingForDrawer(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.selectedSession;
    if (session == null || session.nowPlaying == null) {
      return 0.0;
    }
    return AppConstants.remoteDrawerMinHeight + MediaQuery.paddingOf(context).bottom;
  }
}
