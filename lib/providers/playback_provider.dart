import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/jellyfin_api_service.dart';
import 'auth_provider.dart';
import 'session_provider.dart';
import '../models/media_segment.dart';
import '../models/user_account.dart';
import '../models/session.dart';
import '../constants/jellyfin_commands.dart';

class PlaybackNotifier extends Notifier<void> {
  late JellyfinApiService _apiService;

  @override
  void build() {
    _apiService = ref.watch(apiServiceProvider);
  }

  Future<T?> _withSession<T>(
    Future<T> Function(UserAccount user, Session session) action, {
    bool refreshAfter = false,
    String? errorMessage,
  }) async {
    final authState = ref.read(authProvider);
    final sessionState = ref.read(sessionProvider);
    final user = authState.currentUser;
    final session = sessionState.selectedSession;

    if (user == null || session == null) return null;

    try {
      final result = await action(user, session);
      if (refreshAfter) {
        await Future.delayed(const Duration(milliseconds: 500));
        ref.read(sessionProvider.notifier).fetchSessions();
      }
      return result;
    } catch (e) {
      throw Exception('${errorMessage ?? "Playback command failed"}: $e');
    }
  }

  Future<void> play() => _withSession(
    (user, session) => _apiService.unpause(session.sessionId),
    refreshAfter: true,
    errorMessage: 'Failed to play',
  );

  Future<void> pause() => _withSession(
    (user, session) => _apiService.pause(session.sessionId),
    refreshAfter: true,
    errorMessage: 'Failed to pause',
  );

  Future<void> playPause() => _withSession(
    (user, session) => _apiService.playPause(session.sessionId),
    refreshAfter: true,
    errorMessage: 'Failed to toggle play/pause',
  );

  Future<void> stop() => _withSession(
    (user, session) => _apiService.stop(session.sessionId),
    refreshAfter: true,
    errorMessage: 'Failed to stop',
  );

  Future<void> seek(int positionSeconds) => _withSession(
    (user, session) => _apiService.seek(
      session.sessionId,
      positionSeconds,
      controllingUserId: user.userId,
    ),
    refreshAfter: true,
    errorMessage: 'Failed to seek',
  );

  Future<void> setVolume(int volume) => _withSession(
    (user, session) => _apiService.setVolume(session.sessionId, volume),
    errorMessage: 'Failed to set volume',
  );

  Future<void> sendCommand(String command, {Map<String, dynamic>? arguments, bool refreshAfter = false}) =>
      _withSession(
        (user, session) => _apiService.sendCommand(
          session.sessionId,
          command,
          arguments: arguments,
        ),
        refreshAfter: refreshAfter,
        errorMessage: 'Failed to send command',
      );

  Future<void> sendPlayingCommand(String command) => _withSession(
    (user, session) =>
        _apiService.sendPlayingCommand(session.sessionId, command),
    refreshAfter: true,
    errorMessage: 'Failed to send playing command',
  );

  Future<void> rewind() => sendPlayingCommand(JellyfinCommands.rewind);
      Future<void> fastForward() =>
      sendPlayingCommand(JellyfinCommands.fastForward);

  Future<void> toggleMute() => _withSession(
    (user, session) async {
      if (session.playState?.isMuted ?? false) {
        await _apiService.unmute(session.sessionId);
      } else {
        await _apiService.mute(session.sessionId);
      }
    },
    refreshAfter: true,
    errorMessage: 'Failed to toggle mute',
  );

  Future<void> toggleShuffle(bool isCurrentlyShuffle) => _withSession(
    (user, session) {
      final isEmby = user.isEmby;
      return _apiService.sendCommand(
        session.sessionId,
        isEmby ? 'SetShuffle' : JellyfinCommands.setShuffleQueue,
        arguments: isEmby
            ? {'Shuffle': !isCurrentlyShuffle}
            : {'ShuffleMode': isCurrentlyShuffle ? 'Sorted' : 'Shuffle'},
      );
    },
    refreshAfter: true,
    errorMessage: 'Failed to toggle shuffle',
  );

  Future<void> setRepeatMode(String nextMode) => _withSession(
    (user, session) => _apiService.sendCommand(
      session.sessionId,
      JellyfinCommands.setRepeatMode,
      arguments: {'RepeatMode': nextMode},
    ),
    refreshAfter: true,
    errorMessage: 'Failed to set repeat mode',
  );

  Future<void> setSubtitleStreamIndex(int index) => _withSession(
    (user, session) =>
        _apiService.setSubtitleStreamIndex(session.sessionId, index),
    refreshAfter: true,
    errorMessage: 'Failed to set subtitle stream index',
  );

  Future<void> sendDisplayMessage(
    String header,
    String text, {
    int timeoutMs = 5000,
  }) => _withSession(
    (user, session) => _apiService.sendDisplayMessage(
      session.sessionId,
      header,
      text,
      timeoutMs: timeoutMs,
    ),
    errorMessage: 'Failed to send display message',
  );

  Future<void> sendString(String text) => _withSession(
    (user, session) => _apiService.sendString(session.sessionId, text),
    errorMessage: 'Failed to send string',
  );

  Future<void> setAudioStreamIndex(int index) => _withSession(
    (user, session) =>
        _apiService.setAudioStreamIndex(session.sessionId, index),
    refreshAfter: true,
    errorMessage: 'Failed to set audio stream index',
  );
}

final playbackProvider = NotifierProvider<PlaybackNotifier, void>(
  PlaybackNotifier.new,
);

final mediaSegmentsProvider = FutureProvider.family<List<MediaSegment>, String>(
  (ref, itemId) async {
    // Keep cached result in memory
    ref.keepAlive();

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final apiService = ref.read(apiServiceProvider);

    if (user == null || user.isEmby) return [];

    try {
      final segmentsJson = await apiService.getMediaSegments(itemId);

      return segmentsJson.map((json) => MediaSegment.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  },
);
