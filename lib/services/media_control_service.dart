import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/jellyfin_api_service.dart';
import '../providers/auth_provider.dart';

import '../providers/settings_provider.dart';
import '../providers/session_provider.dart';

class MediaControlService {
  static final MediaControlService _instance = MediaControlService._();
  factory MediaControlService() => _instance;
  MediaControlService._();

  static const MethodChannel _channel = MethodChannel('com.eiffelbeef.scyphomote/media_controls');
  bool _isInitialized = false;
  WidgetRef? _ref;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  void init(WidgetRef ref) {
    if (!isSupported) return;
    _ref = ref;
    if (!_isInitialized) {
      _isInitialized = true;
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onMediaCommand') {
      final args = call.arguments as Map?;
      if (args == null) return;

      final sessionId = args['sessionId'] as String?;
      final command = args['command'] as String?;

      if (sessionId == null || command == null || _ref == null) return;

      final apiService = _ref!.read(apiServiceProvider);
      final sessionState = _ref!.read(sessionProvider);
      final targetSession = sessionState.sessions
          .where((s) => s.sessionId == sessionId)
          .firstOrNull;

      if (targetSession == null) return;

      try {
        switch (command) {
          case 'playPause':
            await apiService.sendPlayingCommand(sessionId, 'PlayPause');
            break;
          case 'next':
            await apiService.sendPlayingCommand(sessionId, 'NextTrack');
            break;
          case 'previous':
            await apiService.sendPlayingCommand(sessionId, 'PreviousTrack');
            break;
          case 'stop':
            await apiService.sendPlayingCommand(sessionId, 'Stop');
            break;
          case 'seek':
            final positionMs = args['positionMs'] as num?;
            if (positionMs != null) {
              await apiService.seek(sessionId, positionMs.toInt() ~/ 1000);
            }
            break;
        }
      } catch (e) {
        debugPrint('Error executing media command $command: $e');
      }

      await Future.delayed(const Duration(milliseconds: 400));
      _ref?.read(sessionProvider.notifier).fetchSessions();
    }
  }

  Future<void> updateSessions(List<Session> sessions, JellyfinApiService apiService) async {
    if (!isSupported) return;

    final currentUser = _ref?.read(authProvider).currentUser;
    final settings = _ref?.read(settingsProvider);

    final activeSessions = sessions.getActiveSessions(
      currentUserId: currentUser?.userId,
      hideOtherUsersSessions: settings?.hideOtherUsersSessions ?? false,
    );

    final sessionDataList = activeSessions.map((session) {
      final nowPlaying = session.nowPlaying;
      final isPlaying = session.isPlaying;

      String? artworkUrl;
      if (nowPlaying != null) {
        final tag = nowPlaying.resolvedPrimaryImageTag;
        if (tag != null) {
          artworkUrl = apiService.getArtworkUrl(nowPlaying.artworkId, 'Primary', maxWidth: 600, tag: tag);
        }
      }

      final title = nowPlaying?.displayTitle.isNotEmpty == true
          ? nowPlaying!.displayTitle
          : session.deviceName;
      final subtitle = nowPlaying?.displaySubtitle ?? session.clientName;

      final supportsRemoteControl = session.supportsRemoteControl;
      final canPlayPause = supportsRemoteControl;
      final canNext = supportsRemoteControl;
      final canPrevious = supportsRemoteControl;
      final canStop = supportsRemoteControl;
      final canSeek = session.playState?.canSeek ?? false;

      return {
        'sessionId': session.sessionId,
        'deviceName': session.deviceName,
        'title': title,
        'artist': subtitle,
        'album': session.deviceName,
        'isPlaying': isPlaying,
        'artworkUrl': artworkUrl,
        'positionMs': (session.playState?.positionTicks ?? 0) ~/ 10000,
        'durationMs': (nowPlaying?.runTimeTicks ?? 0) ~/ 10000,
        'supportsRemoteControl': supportsRemoteControl,
        'canPlayPause': canPlayPause,
        'canNext': canNext,
        'canPrevious': canPrevious,
        'canStop': canStop,
        'canSeek': canSeek,
      };
    }).toList();

    try {
      await _channel.invokeMethod('updateSessions', {'sessions': sessionDataList});
    } catch (_) {}
  }
}
