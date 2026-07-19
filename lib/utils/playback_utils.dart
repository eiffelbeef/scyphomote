import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/playback_provider.dart';
import '../models/session.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'ui_utils.dart';

Future<void> playItemOnRemote(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> item, {
  String playCommand = 'PlayNow',
  bool resume = true,
}) async {
  final user = ref.read(authProvider).currentUser;
  final session = ref.read(sessionProvider).selectedSession;
  final itemId = item['Id'] as String;

  if (user == null || session == null) {
    UiUtils.showSnackBar(
      context,
      AppLocalizations.of(context)!.noActiveSessionSelected,
    );
    return;
  }

  try {
    final apiService = ref.read(apiServiceProvider);
    final userData = item['UserData'] as Map<String, dynamic>?;
    final startPositionTicks = resume ? (userData?['PlaybackPositionTicks'] as int?) : null;

    UiUtils.showSnackBar(context, 'Attempting to start playback...');

    await apiService.playTo(
      session.sessionId,
      itemId,
      startPositionTicks: startPositionTicks,
      playCommand: playCommand,
    );

    await Future.delayed(const Duration(seconds: 1));
    await ref.read(sessionProvider.notifier).fetchSessions();

  } catch (e) {
    if (!context.mounted) return;

    UiUtils.showSnackBar(context, 'Failed to play: $e');
  }
}

Future<void> queueItemOnRemote(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> item,
) async {
  final session = ref.read(sessionProvider).selectedSession;

  if (session == null) {
    // Call playItemOnRemote just to show the "no active session" snackbar
    return playItemOnRemote(context, ref, item);
  }

  try {
    UiUtils.showSnackBar(context, 'Adding to queue...');
    await ref.read(playbackProvider.notifier).addToQueue(item);
  } catch (e) {
    if (!context.mounted) return;
    UiUtils.showSnackBar(context, 'Failed to add to queue: $e');
  }
}

bool isEpisodeNearEnd(Session session) {
  final nowPlaying = session.nowPlaying;

  if (nowPlaying?.type != 'Episode') return false;

  final runtimeTicks = nowPlaying?.runTimeTicks ?? 0;
  final runtimeSeconds = runtimeTicks ~/ 10000000;

  // Must be at least 10 minutes long
  if (runtimeSeconds < 600) return false;

  final positionTicks = session.estimatedPositionTicks;
  final positionSeconds = positionTicks ~/ 10000000;
  final secondsFromEnd = runtimeSeconds - positionSeconds;

  // Determine threshold based on total runtime
  int threshold = 30; // Default for 10-40 mins
  if (runtimeSeconds >= 3000) {
    // 50 mins
    threshold = 40;
  } else if (runtimeSeconds >= 2400) {
    // 40 mins
    threshold = 35;
  }

  return secondsFromEnd <= threshold && secondsFromEnd > 0;
}
