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
      final localDeviceId = await HomeWidget.getWidgetData<String>(
        'widget_local_device_id',
      );
      final localDeviceName = await HomeWidget.getWidgetData<String>(
        'widget_local_device_name',
      );
      final serverUrl = await HomeWidget.getWidgetData<String>(
        'widget_server_url',
      );
      final accessToken = await HomeWidget.getWidgetData<String>(
        'widget_access_token',
      );
      final sessionId = uri.queryParameters['session_id'];

      if (localDeviceId == null ||
          serverUrl == null ||
          accessToken == null ||
          sessionId == null) {
        logError(
          'Missing widget configuration data (localDeviceId: ${localDeviceId != null}, serverUrl: ${serverUrl != null}, token: ${accessToken != null}, sessionId: ${sessionId != null}).',
        );
        return;
      }

      final apiService = JellyfinApiService();
      apiService.setDeviceId(localDeviceId);
      apiService.setDeviceName(localDeviceName ?? 'Scyphomote');
      apiService.setCredentials(serverUrl, accessToken);

      logDebug('Sending widget command: $command to session: $sessionId');

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

  static Future<void> pinWidget({
    required String serverUrl,
    required String accessToken,
    required String localDeviceId,
    required String localDeviceName,
    required String clientDeviceId,
    required String clientDeviceName,
    required String sessionId,
  }) async {
    if (!isWidgetSupported) return;

    // Save configuration for background tasks
    await HomeWidget.saveWidgetData<String>('widget_server_url', serverUrl);
    await HomeWidget.saveWidgetData<String>('widget_access_token', accessToken);
    await HomeWidget.saveWidgetData<String>(
      'widget_local_device_id',
      localDeviceId,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_local_device_name',
      localDeviceName,
    );

    // Save session-specific data as pending (to be adopted by the next added widget)
    await HomeWidget.saveWidgetData<String>(
      'widget_client_device_id',
      clientDeviceId,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_pending_device_name',
      clientDeviceName,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_pending_session_id',
      sessionId,
    );

    await HomeWidget.updateWidget(name: 'RemoteWidgetProvider');
    await HomeWidget.requestPinWidget(name: 'RemoteWidgetProvider');
  }

  static Future<void> syncPremiumStatus(bool isPremium) async {
    if (!isWidgetSupported) return;
    await HomeWidget.saveWidgetData<bool>('is_premium', isPremium);
    await HomeWidget.updateWidget(name: 'RemoteWidgetProvider');
  }
}
