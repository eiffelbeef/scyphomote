import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

Future<void> playItemOnRemote(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> item,
) async {
  final user = ref.read(authProvider).currentUser;
  final session = ref.read(sessionProvider).selectedSession;
  final itemId = item['Id'] as String;

  if (user == null || session == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No active session selected')));
    return;
  }

  try {
    final apiService = ref.read(apiServiceProvider);
    final userData = item['UserData'] as Map<String, dynamic>?;
    final startPositionTicks = userData?['PlaybackPositionTicks'] as int?;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Starting playback...')));

    await apiService.playTo(
      session.sessionId,
      itemId,
      startPositionTicks: startPositionTicks,
    );

    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) {
      return route.settings.name == '/remote';
    });
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to play: $e')));
  }
}
