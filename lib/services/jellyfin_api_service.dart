import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/lru_cache.dart';
import '../models/user_account.dart';
import '../models/session.dart';
import '../constants.dart';
import '../utils/ui_utils.dart';
import '../utils/logger.dart';

class JellyfinApiService {
  final Dio _dio = Dio();
  JellyfinApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          logDebug(
            'HTTP → ${options.method} ${options.uri}  headers=${options.headers} params=${options.queryParameters}',
          );
          handler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          logDebug(
            'HTTP ← ${response.requestOptions.method} ${response.requestOptions.uri}  status=${response.statusCode}',
          );
          handler.next(response);
        },
        onError: (DioException err, ErrorInterceptorHandler handler) {
          try {
            logError(
              'HTTP !!! ${err.requestOptions.method} ${err.requestOptions.uri}  error=${err.message} status=${err.response?.statusCode}',
            );
          } catch (_) {
            logError('HTTP !!! error building log for DioException');
          }
          handler.next(err);
        },
      ),
    );
  }
  String _deviceId = '';
  String _deviceName = '';
  String? _accessToken;
  final String _clientName = AppConstants.appName;
  String get _version => AppConstants.appVersion;

  final LruCache<String, Uint8List> _trickplayCache = LruCache(maxEntries: 50);

  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  void setDeviceName(String deviceName) {
    _deviceName = deviceName;
  }

  void setCredentials(String serverUrl, String accessToken) {
    _dio.options.baseUrl = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
    _dio.options.headers['Authorization'] = _buildAuthHeader(accessToken);
  }

  void clearCredentials() {
    _dio.options.baseUrl = '';
    _dio.options.headers.remove('Authorization');
  }

  String get deviceId => _deviceId;

  String _buildAuthHeader(String? accessToken) {
    final token = accessToken ?? _accessToken ?? '';
    return 'MediaBrowser Token="$token", Client="$_clientName", Device="$_deviceName", DeviceId="$_deviceId", Version="$_version"';
  }

  Future<UserAccount> authenticate(
    String serverUrl,
    String username,
    String password,
  ) async {
    _dio.options.baseUrl = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';

    try {
      final response = await _dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
        options: Options(headers: {'Authorization': _buildAuthHeader('')}),
      );

      return UserAccount(
        userId: response.data['User']['Id'] as String,
        username: response.data['User']['Name'] as String,
        serverUrl: serverUrl,
        accessToken: response.data['AccessToken'] as String,
        serverId: response.data['ServerId'] as String,
      );
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  Future<List<Session>> getSessions({
    String? deviceId,
    int? activeWithinSeconds,
  }) async {
    final data = await _getRequest(
      'Sessions',
      queryParameters: {
        if (deviceId != null) 'DeviceId': deviceId,
        if (activeWithinSeconds != null)
          'ActiveWithinSeconds': activeWithinSeconds,
      },
      errorMessage: 'Failed to fetch sessions',
    );

    return (data as List)
        .map((json) => Session.fromJson(json as Map<String, dynamic>))
        .where((session) => session.deviceId != _deviceId)
        .toList();
  }

  Future<void> _postSessionRequest(
    String sessionId,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? errorMessage,
  }) async {
    await _postRequest(
      'Sessions/$sessionId/$path',
      data: data,
      queryParameters: queryParameters,
      errorMessage: errorMessage ?? 'Request failed',
    );
  }

  Future<dynamic> _postRequest(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? errorMessage,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return response.data;
    } catch (e) {
      _handleRequestException(e, path, errorMessage);
    }
  }

  Future<dynamic> _getRequest(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? errorMessage,
    Options? options,
  }) async {
    final requestOptions = options ?? Options();

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: requestOptions,
      );
      return response.data;
    } catch (e) {
      _handleRequestException(e, path, errorMessage);
    }
  }

  Future<Uint8List?> getTrickplayTileImage(
    String itemId,
    String mediaSourceId,
    int width,
    int index,
  ) async {
    final cacheKey = '${itemId}_${mediaSourceId}_${width}_$index';
    final cached = _trickplayCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _getRequest(
        'Videos/$itemId/Trickplay/$width/$index.jpg',
        queryParameters: {'MediaSourceId': mediaSourceId},
        options: Options(responseType: ResponseType.bytes),
      );
      if (data is List<int>) {
        final bytes = Uint8List.fromList(data);
        _trickplayCache.put(cacheKey, bytes);
        return bytes;
      }
    } catch (e) {
      logError('Failed to fetch trickplay tile $cacheKey: $e');
    }
    return null;
  }

  Never _handleRequestException(Object e, String path, String? errorMessage) {
    String errorMsg = errorMessage ?? e.toString();
    String? errorCode;

    if (e is DioException) {
      errorCode = e.response?.statusCode?.toString();
      if (e.response?.data != null && e.response?.data is String) {
        errorMsg = e.response?.data as String;
      }
    }

    UiUtils.showErrorToast(path, errorMsg, errorCode: errorCode);
    if (errorMessage == null) throw e;
    throw Exception('$errorMessage: $e');
  }

  Future<void> playMedia(String sessionId, String mediaId) async {
    await _postSessionRequest(
      sessionId,
      'Playing',
      data: {
        'ItemIds': [mediaId],
        'PlayCommand': 'PlayNow',
      },
      errorMessage: 'Failed to play media',
    );
  }

  Future<void> pause(String sessionId) async {
    await sendPlayingCommand(sessionId, 'Pause');
  }

  Future<void> unpause(String sessionId) async {
    await sendPlayingCommand(sessionId, 'Unpause');
  }

  Future<void> playPause(String sessionId) async {
    await sendPlayingCommand(sessionId, 'PlayPause');
  }

  Future<void> stop(String sessionId) async {
    await sendPlayingCommand(sessionId, 'Stop');
  }

  Future<void> sendPlayingCommand(String sessionId, String command) async {
    await _postSessionRequest(
      sessionId,
      'Playing/$command',
      errorMessage: 'Failed to send playing command $command',
    );
  }

  Future<void> sendCommand(
    String sessionId,
    String command, {
    Map<String, dynamic>? arguments,
  }) async {
    await _postSessionRequest(
      sessionId,
      'Command',
      data: {'Name': command, 'Arguments': arguments ?? {}},
      errorMessage: 'Failed to send command $command',
    );
  }

  Future<void> setSubtitleStreamIndex(String sessionId, int index) async {
    await sendCommand(
      sessionId,
      'SetSubtitleStreamIndex',
      arguments: {'Index': index.toString()},
    );
  }

  Future<void> sendDisplayMessage(
    String sessionId,
    String header,
    String text, {
    int timeoutMs = 5000,
  }) async {
    await _postSessionRequest(
      sessionId,
      'Message',
      data: {'Header': header, 'Text': text, 'TimeoutMs': timeoutMs},
      errorMessage: 'Failed to send display message',
    );
  }

  Future<void> sendString(String sessionId, String text) async {
    await sendCommand(sessionId, 'SendString', arguments: {'String': text});
  }

  Future<void> setAudioStreamIndex(String sessionId, int index) async {
    await sendCommand(
      sessionId,
      'SetAudioStreamIndex',
      arguments: {'Index': index.toString()},
    );
  }

  Future<void> seek(
    String sessionId,
    int positionSeconds, {
    String? controllingUserId,
  }) async {
    final positionTicks = positionSeconds * 10000000;
    await _postSessionRequest(
      sessionId,
      'Playing/Seek',
      queryParameters: {
        'SeekPositionTicks': positionTicks,
        if (controllingUserId != null) 'ControllingUserId': controllingUserId,
      },
      errorMessage: 'Failed to seek',
    );
  }

  Future<void> setVolume(String sessionId, int volume) async {
    await sendCommand(sessionId, 'SetVolume', arguments: {'Volume': volume});
  }

  Future<void> mute(String sessionId) async {
    await sendCommand(sessionId, 'Mute');
  }

  Future<void> unmute(String sessionId) async {
    await sendCommand(sessionId, 'Unmute');
  }

  Future<void> playTo(
    String sessionId,
    String itemId, {
    int? startPositionTicks,
  }) async {
    await _postSessionRequest(
      sessionId,
      'Playing',
      queryParameters: {
        'ItemIds': itemId,
        'PlayCommand': 'PlayNow',
        if (startPositionTicks != null)
          'StartPositionTicks': startPositionTicks.toString(),
      },
      errorMessage: 'Failed to play item',
    );
  }

  Future<List<Map<String, dynamic>>> getViews(String userId) async {
    final data = await _getRequest(
      'Users/$userId/Views',
      errorMessage: 'Failed to fetch views',
    );

    return (data['Items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getItems(
    String userId, {
    String? parentId,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    String? includeItemTypes,
    bool recursive = false,
  }) async {
    final queryParams = <String, dynamic>{
      if (parentId != null) 'ParentId': parentId,
      if (sortBy != null) 'SortBy': sortBy,
      if (sortOrder != null) 'SortOrder': sortOrder,
      if (includeItemTypes != null) 'IncludeItemTypes': includeItemTypes,
      if (searchTerm != null && searchTerm.isNotEmpty) ...{
        'SearchTerm': searchTerm,
        'Recursive': true,
      } else if (recursive) ...{
        'Recursive': true,
      },
      if (sortBy == null && searchTerm == null) ...{
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      },
      'Fields': 'IndexNumber,ParentIndexNumber',
    };

    final data = await _getRequest(
      'Users/$userId/Items',
      queryParameters: queryParams,
      errorMessage: 'Failed to fetch items',
    );

    return (data['Items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getResumeItems(String userId) async {
    final data = await _getRequest(
      'Users/$userId/Items/Resume',
      queryParameters: {
        'Limit': 12,
        'Recursive': true,
        'Fields': 'PrimaryImageAspectRatio',
        'ImageTypeLimit': 1,
        'EnableImageTypes': 'Primary,Thumb',
        'EnableTotalRecordCount': false,
        'MediaTypes': 'Video',
      },
      errorMessage: 'Failed to fetch resume items',
    );

    return (data['Items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getNextUpItems(String userId) async {
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    final cutoffDate = oneYearAgo.toUtc().toIso8601String();

    final data = await _getRequest(
      'Shows/NextUp',
      queryParameters: {
        'Limit': 24,
        'Fields': 'PrimaryImageAspectRatio,DateCreated,Path,MediaSourceCount',
        'UserId': userId,
        'ImageTypeLimit': 1,
        'EnableImageTypes': 'Primary,Thumb',
        'EnableTotalRecordCount': false,
        'DisableFirstEpisode': false,
        'NextUpDateCutoff': cutoffDate,
        'EnableResumable': false,
        'EnableRewatching': false,
      },
      errorMessage: 'Failed to fetch next up items',
    );

    return (data['Items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>?> getLyrics(String itemId) async {
    try {
      return await _getRequest('Audio/$itemId/Lyrics') as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getPlaybackInfo(
    String userId,
    String itemId,
  ) async {
    final data = await _postRequest(
      'Items/$itemId/PlaybackInfo',
      queryParameters: {'UserId': userId},
      errorMessage: 'Failed to fetch playback info',
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getItemDetails(
    String userId,
    String itemId,
  ) async {
    final data = await _getRequest(
      'Users/$userId/Items/$itemId',
      errorMessage: 'Failed to fetch item details',
    );
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMediaSegments(String itemId) async {
    try {
      final data = await _getRequest('MediaSegments/$itemId');

      return (data['Items'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }

  String getArtworkUrl(
    String itemId,
    String imageType, {
    int maxWidth = 500,
    String? tag,
  }) {
    final baseUrl = _dio.options.baseUrl;
    var url = '${baseUrl}Items/$itemId/Images/$imageType?maxWidth=$maxWidth';
    if (tag != null) {
      url += '&tag=$tag';
    }
    return url;
  }

  Future<String?> downloadUserImage(
    String userId, {
    String format = 'Webp',
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        'UserImage',
        queryParameters: {'userId': userId, 'format': format},
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        return base64Encode(response.data!);
      }
    } catch (e) {
      logError('Failed to download user image for $userId: $e');
    }
    return null;
  }
}
