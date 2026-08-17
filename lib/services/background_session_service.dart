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
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        ),
      );
    }
  }

  Future<void> setEnabled(bool enabled, {UserAccount? user}) async {
    _enabled = enabled;
    _user = user ?? _user;
    if (enabled && isSupported) {
      await _ensureInitialized();
      final androidPlugin = _notifications!.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
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

    final activeSessions = sessions.where((s) {
      return s.playableMediaTypes.isNotEmpty || s.nowPlaying != null;
    }).toList();

    final sessionCount = activeSessions.length;
    final playingCount = activeSessions.where((s) => s.nowPlaying != null).length;

    String body;
    if (sessionCount == 0) {
      body = l10n.noActiveSessions;
    } else if (playingCount == 0) {
      body = l10n.activeSessionsNonePlaying(sessionCount);
    } else {
      body = l10n.activeSessionsCountPlaying(sessionCount, playingCount);
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      l10n.backgroundMonitoringSection,
      channelDescription: l10n.backgroundMonitoringChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
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
          foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeDataSync},
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
