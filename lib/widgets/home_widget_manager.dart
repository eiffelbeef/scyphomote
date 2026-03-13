import 'dart:io';
import 'package:home_widget/home_widget.dart';
import '../services/jellyfin_api_service.dart';
import '../utils/logger.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;

  final isPremium = await HomeWidget.getWidgetData<bool>('is_premium') ?? false;
  if (!isPremium) {
    logError('Attempted to use widget without premium unlock.');
    return;
  }

  if (uri.host == 'widget_command') {
    final command = uri.pathSegments.first;
    logDebug('Widget command received: $command');

    try {
      final deviceId = await HomeWidget.getWidgetData<String>(
        'widget_device_id',
      );
      final serverUrl = await HomeWidget.getWidgetData<String>(
        'widget_server_url',
      );
      final accessToken = await HomeWidget.getWidgetData<String>(
        'widget_access_token',
      );
      String? sessionId = uri.queryParameters['session_id'];

      sessionId ??= await HomeWidget.getWidgetData<String>('widget_session_id');

      if (deviceId == null ||
          serverUrl == null ||
          accessToken == null ||
          sessionId == null) {
        logError(
          'Missing widget configuration data (deviceId, serverUrl, token, sessionId).',
        );
        return;
      }

      final apiService = JellyfinApiService();
      apiService.setCredentials(serverUrl, accessToken);

      switch (command) {
        case 'up':
          await apiService.sendCommand(sessionId, 'MoveUp');
          break;
        case 'down':
          await apiService.sendCommand(sessionId, 'MoveDown');
          break;
        case 'left':
          await apiService.sendCommand(sessionId, 'MoveLeft');
          break;
        case 'right':
          await apiService.sendCommand(sessionId, 'MoveRight');
          break;
        case 'ok':
          await apiService.sendCommand(sessionId, 'Select');
          break;
        case 'play_pause':
          await apiService.playPause(sessionId);
          break;
        case 'stop':
          await apiService.stop(sessionId);
          break;
        case 'back':
          await apiService.sendCommand(sessionId, 'Back');
          break;
        default:
          logError('Unknown widget command: $command');
      }
    } catch (e) {
      logError('Error executing widget background task: $e');
    }
  }
}

class HomeWidgetManager {
  static bool get isWidgetSupported =>
      //Platform.isAndroid || Platform.isIOS;
      Platform.isAndroid;

  static Future<void> init() async {
    if (!isWidgetSupported) return;
    // Register the background callback
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }

  static Future<void> saveSettingsToWidget(
    String serverUrl,
    String accessToken,
  ) async {
    if (!isWidgetSupported) return;
    await HomeWidget.saveWidgetData<String>('widget_server_url', serverUrl);
    await HomeWidget.saveWidgetData<String>('widget_access_token', accessToken);
    await HomeWidget.updateWidget(name: 'RemoteWidgetProvider');
  }

  static Future<void> pinWidget(
    String deviceId,
    String deviceName,
    String sessionId,
  ) async {
    if (!isWidgetSupported) return;
    await HomeWidget.saveWidgetData<String>('widget_device_id', deviceId);
    await HomeWidget.saveWidgetData<String>('widget_device_name', deviceName);
    await HomeWidget.saveWidgetData<String>('widget_session_id', sessionId);

    await HomeWidget.updateWidget(name: 'RemoteWidgetProvider');

    await HomeWidget.requestPinWidget(name: 'RemoteWidgetProvider');
  }

  static Future<void> syncPremiumStatus(bool isPremium) async {
    if (!isWidgetSupported) return;
    await HomeWidget.saveWidgetData<bool>('is_premium', isPremium);
    await HomeWidget.updateWidget(name: 'RemoteWidgetProvider');
  }
}
