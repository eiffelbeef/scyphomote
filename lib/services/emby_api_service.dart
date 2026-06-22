import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/user_account.dart';
import '../constants.dart';
import '../utils/logger.dart';

class EmbyApiService {
  final Dio _connectDio = Dio(BaseOptions(
    baseUrl: 'https://connect.emby.media/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<Map<String, String>> authenticateEmbyConnect(String username, String password) async {
    final response = await _connectDio.post(
      'service/user/authenticate',
      data: {'nameOrEmail': username, 'rawpw': password},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Application': '${AppConstants.appName}/${AppConstants.appVersion}',
        },
      ),
    );
    final data = response.data is String ? jsonDecode(response.data as String) : response.data;
    return {
      'ConnectAccessToken': data['AccessToken'] as String,
      'ConnectUserId': data['User']['Id'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> getEmbyConnectServers(String connectUserId, String connectToken) async {
    final response = await _connectDio.get(
      'service/servers?userId=$connectUserId',
      options: Options(
        headers: {
          'X-Application': '${AppConstants.appName}/${AppConstants.appVersion}',
          'X-Connect-UserToken': connectToken,
        },
      ),
    );
    final data = response.data is String ? jsonDecode(response.data as String) : response.data;
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<UserAccount> exchangeEmbyConnectToken(
    Map<String, dynamic> server,
    String connectUserId,
    String connectToken,
    String deviceId,
    String deviceName,
  ) async {
    final accessKey = server['AccessKey'] as String;
    String url = server['Url'] as String;
    final serverUrl = url.endsWith('/') ? url : '$url/';

    final dio = Dio(BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.options.headers['Authorization'] = 'MediaBrowser Client="${AppConstants.appName}", Device="$deviceName", DeviceId="$deviceId", Version="${AppConstants.appVersion}", Token="$accessKey"';

    final response = await dio.get(
      'Connect/Exchange',
      queryParameters: {'format': 'json', 'ConnectUserId': connectUserId},
    );
    final data = response.data is String ? jsonDecode(response.data as String) : response.data;
    final accessToken = data['AccessToken'] as String;
    final localUserId = data['LocalUserId'] as String;

    dio.options.headers['Authorization'] = 'MediaBrowser Client="${AppConstants.appName}", Device="$deviceName", DeviceId="$deviceId", Version="${AppConstants.appVersion}", Token="$accessToken"';

    final userResponse = await dio.get('Users/$localUserId');
    final username = userResponse.data['Name'] as String;
    final serverId = userResponse.data['ServerId'] as String;

    String? profileImageBase64;
    try {
      final imageResponse = await dio.get(
        'Users/$localUserId/Images/Primary',
        queryParameters: {'tag': userResponse.data['PrimaryImageTag']},
        options: Options(responseType: ResponseType.bytes),
      );
      if (imageResponse.data != null) {
        profileImageBase64 = base64Encode(imageResponse.data as List<int>);
      }
    } on DioException catch (e) {
      logError('Failed to fetch profile image: ${e.message}');
    } catch (e) {
      logError('Unexpected error fetching profile image: $e');
    }

    return UserAccount(
      userId: localUserId,
      username: username,
      serverUrl: url,
      accessToken: accessToken,
      serverId: serverId,
      profileImageBase64: profileImageBase64,
      isAdmin: userResponse.data['Policy']?['IsAdministrator'] as bool? ?? false,
      isEmby: true,
      embyConnectAccessToken: connectToken,
      embyConnectUserId: connectUserId,
      embySystemId: server['SystemId'] as String,
    );
  }

  Future<Response?> resolveDynamicUrlAndRetry(
    DioException err,
    String connectUserId,
    String connectAccessToken,
    String systemId,
    Dio originalDio,
    void Function(String)? onUrlUpdated,
  ) async {
    final servers = await getEmbyConnectServers(connectUserId, connectAccessToken);
    final server = servers.firstWhere((s) => s['SystemId'] == systemId, orElse: () => {});
    if (server.isNotEmpty) {
      final newUrl = server['Url'] as String;
      final newBaseUrl = newUrl.endsWith('/') ? newUrl : '$newUrl/';
      if (newBaseUrl != originalDio.options.baseUrl) {
        originalDio.options.baseUrl = newBaseUrl;
        onUrlUpdated?.call(newBaseUrl);
        return await originalDio.request(
          err.requestOptions.path,
          cancelToken: err.requestOptions.cancelToken,
          data: err.requestOptions.data,
          onReceiveProgress: err.requestOptions.onReceiveProgress,
          onSendProgress: err.requestOptions.onSendProgress,
          queryParameters: err.requestOptions.queryParameters,
          options: Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
          ),
        );
      }
    }
    return null;
  }
}
