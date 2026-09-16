import '../constants.dart';

/// Builds a sanitized, RFC-compliant `Authorization` header for MediaBrowser (Jellyfin/Emby).
String buildMediaBrowserAuthHeader({
  required String deviceName,
  required String deviceId,
  String? clientName,
  String? version,
  String? token,
}) {
  final encodedClient = Uri.encodeComponent(clientName ?? AppConstants.appName);
  final encodedDevice = Uri.encodeComponent(deviceName);
  final encodedDeviceId = Uri.encodeComponent(deviceId);
  final encodedVersion = Uri.encodeComponent(version ?? AppConstants.appVersion);
  final tokenPart = token ?? '';
  return 'MediaBrowser Client="$encodedClient", Device="$encodedDevice", DeviceId="$encodedDeviceId", Version="$encodedVersion", Token="$tokenPart"';
}
