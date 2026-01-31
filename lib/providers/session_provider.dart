import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/jellyfin_api_service.dart';
import '../constants.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

class SessionState {
  final List<Session> sessions;
  final Session? selectedSession;
  final bool isLoading;
  final String? error;

  SessionState({
    this.sessions = const [],
    this.selectedSession,
    this.isLoading = true,
    this.error,
  });

  SessionState copyWith({
    List<Session>? sessions,
    Session? selectedSession,
    bool clearSelectedSession = false,
    bool? isLoading,
    String? error,
  }) {
    return SessionState(
      sessions: sessions ?? this.sessions,
      selectedSession: clearSelectedSession
          ? null
          : (selectedSession ?? this.selectedSession),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  late JellyfinApiService _apiService;
  Timer? _pollTimer;

  @override
  SessionState build() {
    _apiService = ref.watch(apiServiceProvider);

    // Recreate the notifier when the active user changes.
    // This resets the state to 'loading' and triggers a fresh fetch.
    ref.watch(authProvider.select((s) => s.currentUser?.userId));

    // React to settings changes or session selection to update polling
    ref.listen(settingsProvider, (previous, next) {
      if (previous != null) {
        final pollingChanged =
            previous.playerRefreshRate != next.playerRefreshRate ||
            previous.deviceListAutoRefresh != next.deviceListAutoRefresh ||
            previous.deviceListRefreshRate != next.deviceListRefreshRate;

        if (pollingChanged) {
          _startPolling();
        }
      }
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    Future.microtask(() => _startPolling());
    return SessionState();
  }

  void _startPolling() {
    _pollTimer?.cancel();

    final settings = ref.read(settingsProvider);
    final isPlayerMode = state.selectedSession != null;

    int? interval;
    if (isPlayerMode) {
      interval = settings.playerRefreshRate;
    } else {
      if (settings.deviceListAutoRefresh) {
        interval = settings.deviceListRefreshRate;
      } else {
        // Auto refresh disabled for list mode
        interval = null;
      }
    }

    // Always fetch once immediately if app is foregrounded
    fetchSessions();

    if (interval != null) {
      _pollTimer = Timer.periodic(Duration(seconds: interval), (_) {
        if (AppConstants.isInForeground) {
          fetchSessions();
        } else {
          logDebug(
            'Skipping scheduled fetchSessions because app is not in foreground',
          );
        }
      });
    }
  }

  Future<void> fetchSessions() async {
    final authState = ref.read(authProvider);
    final user = authState.currentUser;

    if (user == null) {
      state = SessionState();
      return;
    }

    try {
      final allSessions = await _apiService.getSessions(
        deviceId: state.selectedSession?.deviceId,
        activeWithinSeconds: AppConstants.sessionActivityThreshold,
      );

      final sessions = allSessions
          .where((s) => s.clientName != AppConstants.appName)
          .toList();

      Session? updatedSelectedSession;
      if (state.selectedSession != null) {
        try {
          updatedSelectedSession = sessions.firstWhere(
            (s) => s.sessionId == state.selectedSession!.sessionId,
          );
        } catch (e) {
          updatedSelectedSession = null;
        }
      }

      state = SessionState(
        sessions: sessions,
        selectedSession: updatedSelectedSession,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch sessions: $e',
      );
    }
  }

  void selectSession(Session session) {
    state = state.copyWith(selectedSession: session);
    _startPolling();
  }

  void deselectSession() {
    state = state.copyWith(clearSelectedSession: true);
    _startPolling();
  }

  void refreshSessionPolling() {
    _startPolling();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
