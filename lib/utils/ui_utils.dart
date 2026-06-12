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

  static double getItemAspectRatio(Map<String, dynamic>? item) {
    if (item != null && item['PrimaryImageAspectRatio'] != null) {
      final ratio = (item['PrimaryImageAspectRatio'] as num).toDouble();
      if (ratio > 0) return ratio;
    }

    return getFallbackAspectRatio(item?['Type'] as String?);
  }

  static double getFallbackAspectRatio(String? type) {
    final t = type?.toLowerCase() ?? '';
    if (t == 'movie' ||
        t == 'movies' ||
        t == 'tvshows' ||
        t == 'series' ||
        t == 'season' ||
        t == 'seasons' ||
        t == 'person' ||
        t == 'people' ||
        t == 'boxset') {
      return 2 / 3;
    } else if (t == 'music' ||
        t == 'musicalbum' ||
        t == 'audio' ||
        t == 'artist' ||
        t == 'musicvideo') {
      return 1.0;
    }

    return 16 / 9;
  }

  static String? mapToMediaType(String? type) {
    switch (type?.toLowerCase()) {
      case 'movie':
      case 'movies':
      case 'tvshows':
      case 'series':
      case 'season':
      case 'episode':
      case 'musicvideo':
      case 'musicvideos':
      case 'homevideos':
      case 'video':
      case 'boxset':
      case 'boxsets':
      case 'trailer':
      case 'trailers':
      case 'livetvchannel':
      case 'playlist':
        return 'Video';
      case 'audio':
      case 'music':
      case 'song':
      case 'musicalbum':
        return 'Audio';
      case 'book':
      case 'books':
        return 'Book';
      case 'photo':
      case 'photos':
      case 'photoalbum':
        return 'Photo';
      default:
        return null;
    }
  }
}
