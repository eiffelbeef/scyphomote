import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/session.dart';
import '../models/user_account.dart';
import '../constants.dart';
import '../utils/logger.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

class SessionNotificationService {
  static final SessionNotificationService _instance = SessionNotificationService._();
  factory SessionNotificationService() => _instance;
  SessionNotificationService._();

  FlutterLocalNotificationsPlugin? _notifications;
  bool _enabled = false;
  UserAccount? _user;

  static const String _channelId = 'session_monitor';
  static const int _notificationId = 9000;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<void> _ensureInitialized() async {
    if (_notifications != null || !isSupported) return;
    _notifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _notifications!.initialize(settings: const InitializationSettings(android: androidInit));

    final l10n = await _getL10n();

    final androidPlugin = _notifications!.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          l10n.backgroundMonitoringSection,
          description: l10n.backgroundMonitoringChannelDescription,
          importance: Importance.min,
          playSound: false,
          enableVibration: false,
        ),
      );
    }
  }

  Future<void> setEnabled(bool enabled, {UserAccount? user}) async {
    _user = user ?? _user;
    if (_enabled == enabled) return;
    _enabled = enabled;

    if (enabled && isSupported) {
      await _ensureInitialized();
      final androidPlugin = _notifications!.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission().catchError((e) => null);
    } else if (!enabled) {
      await _dismiss();
    }
  }

  Future<AppLocalizations> _getL10n() async {
    final context = AppConstants.navigatorKey.currentContext;
    if (context != null) return AppLocalizations.of(context)!;
    return AppLocalizations.delegate.load(PlatformDispatcher.instance.locale);
  }

  Future<void> updateSessions(List<Session> sessions) async {
    if (!_enabled || !isSupported) return;

    final l10n = await _getL10n();

    await _ensureInitialized();
    if (_notifications == null) return;

    final relevantSessions = sessions.where((s) {
      return s.playableMediaTypes.isNotEmpty || s.nowPlaying != null;
    }).toList();

    final sessionCount = relevantSessions.length;
    final playingCount = relevantSessions.where((s) => s.isPlaying).length;
    final pausedCount = relevantSessions.where((s) => s.isPaused).length;
    final activeCount = playingCount + pausedCount;

    final body = activeCount == 0
        ? l10n.idleSessionsCount(sessionCount)
        : l10n.activeSessionsStatus(sessionCount, playingCount, pausedCount);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      l10n.backgroundMonitoringSection,
      channelDescription: l10n.backgroundMonitoringChannelDescription,
      importance: Importance.min,
      priority: Priority.min,
      ongoing: true,
      autoCancel: false,
      silent: true,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      icon: '@mipmap/launcher_icon',
    );

    final title = _user?.userServerDisplayName ?? AppConstants.appName;

    final androidPlugin = _notifications!.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      try {
        await androidPlugin.startForegroundService(
          id: _notificationId,
          title: title,
          body: body,
          notificationDetails: androidDetails,
          foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeConnectedDevice},
        );
      } on PlatformException catch (e, stackTrace) {
        debugPrint('PlatformException starting foreground service: $e. Falling back to standard notification.');
        CrashLog.record(e, stackTrace);
        await _notifications!.show(
          id: _notificationId,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(android: androidDetails),
        );
      }
    } else {
      await _notifications!.show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    }
  }

  Future<void> _dismiss() async {
    if (_notifications == null) return;
    final androidPlugin = _notifications!.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.stopForegroundService();
    }
    await _notifications!.cancel(id: _notificationId);
  }
}
