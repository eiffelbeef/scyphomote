import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/jellyfin_api_service.dart';
import '../services/background_session_service.dart';
import '../services/media_control_service.dart';
import '../constants.dart';
import '../utils/screen_service.dart';
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
  StreamSubscription<String>? _screenSubscription;

  @override
  SessionState build() {
    _apiService = ref.watch(apiServiceProvider);

    // Recreate the notifier when the active user changes.
    // This resets the state to 'loading' and triggers a fresh fetch.
    ref.watch(authProvider.select((s) => s.currentUser?.userId));

    // Listen for screen unlock events to refresh sessions immediately
    if (!kIsWeb && Platform.isAndroid) {
      _screenSubscription?.cancel();
      _screenSubscription = ScreenService.onScreenEvent.listen((event) {
        if (event == 'screen_on' || event == 'unlocked') {
          final settings = ref.read(settingsProvider);
          if (settings.backgroundMonitoringEnabled || AppConstants.isInForeground) {
            fetchSessions();
          }
        }
      });
    }

    // React to settings changes or session selection to update polling
    ref.listen(settingsProvider, (previous, next) {
      if (previous != null) {
        final filterChanged =
            previous.hideOtherUsersSessions != next.hideOtherUsersSessions ||
            previous.showNonMediaCapableSessions != next.showNonMediaCapableSessions;
        final pollingChanged =
            previous.playerRefreshRate != next.playerRefreshRate ||
            previous.deviceListAutoRefresh != next.deviceListAutoRefresh ||
            previous.deviceListRefreshRate != next.deviceListRefreshRate ||
            previous.backgroundMonitoringEnabled != next.backgroundMonitoringEnabled ||
            previous.backgroundMonitoringRefreshRate != next.backgroundMonitoringRefreshRate;

        if (filterChanged) {
          fetchSessions();
        } else if (pollingChanged) {
          _startPolling(fetchImmediately: false);
        }
      }
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
      _screenSubscription?.cancel();
    });

    Future.microtask(() => _startPolling(fetchImmediately: true));
    return SessionState();
  }

  void _startPolling({bool fetchImmediately = false}) {
    _pollTimer?.cancel();

    final settings = ref.read(settingsProvider);
    final isPlayerMode = state.selectedSession != null;

    int? interval;
    if (AppConstants.isInForeground) {
      if (isPlayerMode) {
        interval = settings.playerRefreshRate;
      } else if (settings.deviceListAutoRefresh) {
        interval = settings.deviceListRefreshRate;
      }
    } else if (settings.backgroundMonitoringEnabled) {
      interval = settings.backgroundMonitoringRefreshRate;
    }

    if (fetchImmediately && AppConstants.isInForeground) {
      fetchSessions();
    }

    if (interval != null) {
      _pollTimer = Timer.periodic(Duration(seconds: interval), (_) async {
        final currentSettings = ref.read(settingsProvider);
        if (AppConstants.isInForeground || currentSettings.backgroundMonitoringEnabled) {
          final isInteractive = await ScreenService.isScreenInteractive();
          if (isInteractive) {
            fetchSessions();
          }
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
      final allSessions = await _apiService.getSessions();

      final isAdmin = ref.read(authProvider).currentUser?.isAdmin ?? false;
      final showNonMediaCapable = isAdmin && ref.read(settingsProvider).showNonMediaCapableSessions;

      final sessions = allSessions.where((s) {
        if (s.clientName == AppConstants.appName) return false;
        if (showNonMediaCapable) return true;
        return s.playableMediaTypes.isNotEmpty || s.nowPlaying != null;
      }).toList();

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

      if (!kIsWeb && Platform.isAndroid) {
        SessionNotificationService().updateSessions(allSessions);
        MediaControlService().updateSessions(allSessions, _apiService);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch sessions: $e',
      );
    }
  }

  void selectSession(Session session) {
    state = state.copyWith(selectedSession: session);
    _startPolling(fetchImmediately: true);
  }

  void deselectSession() {
    state = state.copyWith(clearSelectedSession: true);
    _startPolling(fetchImmediately: true);
  }

  void refreshSessionPolling() {
    _startPolling(fetchImmediately: true);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
