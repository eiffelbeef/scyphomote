import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../constants.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

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

  static double getFallbackAspectRatio(String? type) => switch (type?.toLowerCase()) {
        'movie' ||
        'movies' ||
        'tvshows' ||
        'series' ||
        'season' ||
        'seasons' ||
        'person' ||
        'people' ||
        'boxset' =>
          2 / 3,
        'music' || 'musicalbum' || 'audio' || 'artist' || 'musicvideo' => 1.0,
        _ => 16 / 9,
      };

  static String? mapToMediaType(String? type) => switch (type?.toLowerCase()) {
        'movie' ||
        'movies' ||
        'tvshows' ||
        'series' ||
        'season' ||
        'episode' ||
        'musicvideo' ||
        'musicvideos' ||
        'homevideos' ||
        'video' ||
        'boxset' ||
        'boxsets' ||
        'trailer' ||
        'trailers' ||
        'livetvchannel' ||
        'playlist' =>
          'Video',
        'audio' || 'music' || 'song' || 'musicalbum' => 'Audio',
        'book' || 'books' => 'Book',
        'photo' || 'photos' || 'photoalbum' => 'Photo',
        _ => null,
      };

  static String getDisplayTitle(Map<String, dynamic> item) {
    final title = item['Name'] as String? ?? 'Unknown';
    final index = item['IndexNumber'];
    final type = item['Type'];
    
    if (index != null && (type == 'Episode' || type == 'Audio' || item.containsKey('AlbumId'))) {
      return '$index. $title';
    }
    return title;
  }

  static String? getYearString(BuildContext context, Map<String, dynamic> item) {
    final year = item['ProductionYear'];
    if (year == null) return null;

    if (item['Type'] != 'Series') return year.toString();

    final endYear = DateTime.tryParse(item['EndDate']?.toString() ?? '')?.year;
    final ended = item['Status'] == 'Ended';
    
    if (ended && endYear != null && endYear != year) return '$year-$endYear';
    return ended ? '$year' : '$year-${AppLocalizations.of(context)!.present}';
  }

  static Color getPlayMethodColor(String? playMethod) {
    return switch (playMethod) {
      'Transcode' => Colors.orange,
      'DirectStream' => Colors.blue,
      _ => Colors.green,
    };
  }

  static String getPlayMethodString(BuildContext context, String? playMethod) {
    final l10n = AppLocalizations.of(context)!;
    return switch (playMethod) {
      'Transcode' => l10n.transcoding,
      'DirectStream' => l10n.directStream,
      _ => l10n.directPlay,
    };
  }

  static String formatBitrate(num bps, {bool forceKbps = false}) {
    if (bps <= 0) return '0 kbps';
    if (forceKbps || bps < 1000000) {
      return '${(bps / 1000).round()} kbps';
    }
    double mbps = bps / 1000000;
    return '${mbps.toStringAsFixed(mbps.truncateToDouble() == mbps ? 0 : 1)} Mbps';
  }
}
