import 'package:flutter/foundation.dart';
import 'media_info.dart';
import 'play_state.dart';
import '../constants/jellyfin_commands.dart';

class Session {
  final String sessionId;
  final String deviceId;
  final String deviceName;
  final String clientName;
  final bool isActive;
  final bool supportsRemoteControl;
  final bool supportsMediaControl;
  final List<String> supportedCommands;
  final List<String> playableMediaTypes;
  final int nowPlayingQueueSize;
  final List<MediaInfo>? nowPlayingQueue;
  final MediaInfo? nowPlaying;
  final PlayState? playState;
  final String? playMethod;
  final List<String>? transcodeReasons;
  final int? bitrate;
  final String userId;
  final String userName;
  final String? applicationVersion;
  final DateTime? lastActivityDate;
  final String? remoteEndPoint;
  final DateTime localFetchTime;

  Session({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.clientName,
    required this.isActive,
    required this.supportsRemoteControl,
    required this.supportsMediaControl,
    required this.supportedCommands,
    required this.playableMediaTypes,
    required this.nowPlayingQueueSize,
    this.nowPlayingQueue,
    this.nowPlaying,
    this.playState,
    this.playMethod,
    this.transcodeReasons,
    this.bitrate,
    required this.userId,
    required this.userName,
    this.applicationVersion,
    this.lastActivityDate,
    this.remoteEndPoint,
    required this.localFetchTime,
  });

  bool get isPlaying => nowPlaying != null && !(playState?.isPaused ?? true);
  bool get isPaused => nowPlaying != null && (playState?.isPaused ?? false);

  /// Returns the estimated accurate position in ticks, factoring in time elapsed since last fetch
  int get estimatedPositionTicks {
    if (playState?.positionTicks == null) return 0;
    if (isPaused || nowPlaying == null) return playState!.positionTicks!;
    
    final elapsedMs = DateTime.now().difference(localFetchTime).inMilliseconds;
    return playState!.positionTicks! + (elapsedMs * 10000);
  }

  /// Returns the index of the currently playing item in the nowPlayingQueue.
  int get currentQueueIndex {
    final index = nowPlayingQueue?.indexWhere((item) => 
        item.playlistItemId == nowPlaying?.playlistItemId || 
        (nowPlaying?.playlistItemId == null && item.id == nowPlaying?.id)
    ) ?? -1;
    return index == -1 ? 0 : index;
  }

  /// Check if this session supports remote navigation commands
  bool get canUseRemote => JellyfinCommands.remoteNavigation.any(hasCapability);

  /// Check if this session supports displaying views (think movie page, season page etc)
  bool get canDisplayContent => hasCapability(JellyfinCommands.displayContent);

  /// Check if this session supports displaying messages
  bool get canDisplayMessages => hasCapability(JellyfinCommands.displayMessage);

  /// Check if this session supports shuffling
  bool get canShuffle =>
      hasCapability(JellyfinCommands.setShuffleQueue) ||
      hasCapability('SetShuffle');

  /// Check if this session supports repeat
  bool get canRepeat => hasCapability(JellyfinCommands.setRepeatMode);

  factory Session.fromJson(Map<String, dynamic> json) {
    final List<String> supportedCommands =
        (json['SupportedCommands'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final List<String> playableMediaTypes =
        (json['PlayableMediaTypes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final playMethod = json['PlayState']?['PlayMethod'] as String?;

    final transcodeReasons = (json['TranscodingInfo']?['TranscodeReasons'] as List?)
        ?.map((e) => e.toString())
        .toList();

    int? bitrate;
    if (json['NowPlayingItem'] != null) {
      bitrate = _calculateBitrate(json);
    }

    final List<MediaInfo> nowPlayingQueue = [];
    final queueItems = json['NowPlayingQueue'] as List<dynamic>?;
    final Set<String> usedPlaylistItemIds = {};

    if (queueItems != null) {
      for (int i = 0; i < queueItems.length; i++) {
        var qItem = queueItems[i];
        try {
          if (qItem is Map<String, dynamic>) {
             final itemData = Map<String, dynamic>.from(qItem);
             
             // Guarantee required fields so MediaInfo.fromJson never throws
             itemData['Id'] = itemData['Id']?.toString() ?? itemData['PlaylistItemId']?.toString() ?? 'fallback-id-$i';
             itemData['Type'] ??= 'Audio';
             
             // Guarantee completely unique PlaylistItemId for ReorderableListView
             var playlistItemId = itemData['PlaylistItemId']?.toString() ?? '${itemData['Id']}-$i';
             if (usedPlaylistItemIds.contains(playlistItemId)) {
                playlistItemId = '$playlistItemId-$i'; // Force uniqueness if server sends duplicates
             }
             usedPlaylistItemIds.add(playlistItemId);
             itemData['PlaylistItemId'] = playlistItemId;

             nowPlayingQueue.add(MediaInfo.fromJson(itemData));
          }
        } catch (e) {
          debugPrint('Failed to parse queue item: $e');
        }
      }
    }

    final int nowPlayingQueueSize = queueItems?.length ?? 0;

    return Session(
      sessionId: json['Id'] as String,
      deviceId: json['DeviceId'] as String,
      deviceName: json['DeviceName'] as String? ?? 'Unknown Device',
      clientName: json['Client'] as String? ?? 'Unknown Client',
      userId: json['UserId'] as String? ?? '',
      userName: json['UserName'] as String? ?? 'Unknown User',
      isActive: json['IsActive'] as bool? ?? false,
      supportsRemoteControl: json['SupportsRemoteControl'] as bool? ?? false,
      supportsMediaControl: json['SupportsMediaControl'] as bool? ?? false,
      supportedCommands: supportedCommands,
      playableMediaTypes: playableMediaTypes,
      nowPlayingQueueSize: nowPlayingQueueSize,
      nowPlayingQueue: nowPlayingQueue,
      nowPlaying: json['NowPlayingItem'] != null
          ? MediaInfo.fromJson(json['NowPlayingItem'] as Map<String, dynamic>)
          : null,
      playState: json['PlayState'] != null
          ? PlayState.fromJson(json['PlayState'] as Map<String, dynamic>)
          : null,
      playMethod: playMethod,
      transcodeReasons: transcodeReasons,
      bitrate: bitrate,
      applicationVersion: json['ApplicationVersion'] as String?,
      lastActivityDate: json['LastActivityDate'] != null
          ? DateTime.tryParse(json['LastActivityDate'] as String)
          : null,
      remoteEndPoint: json['RemoteEndPoint'] as String?,
      localFetchTime: DateTime.now(),
    );
  }

  static int? _calculateBitrate(Map<String, dynamic> json) {
    try {
      final nowPlaying = json['NowPlayingItem'] as Map<String, dynamic>;
      final mediaStreams = nowPlaying['MediaStreams'] as List<dynamic>?;

      if (mediaStreams == null) return null;

      final type = nowPlaying['Type'] as String?;

      if (type == 'Audio') {
        // For Audio items, just get the first Audio stream bitrate
        final audioStream = mediaStreams.firstWhere(
          (s) => s['Type'] == 'Audio' && s['BitRate'] != null,
          orElse: () => null,
        );
        return audioStream != null ? audioStream['BitRate'] as int? : null;
      }

      final playState = json['PlayState'] as Map<String, dynamic>?;
      final audioStreamIndex = playState?['AudioStreamIndex'] as int?;

      int totalBitrate = 0;

      for (final stream in mediaStreams) {
        final s = stream as Map<String, dynamic>;
        final streamType = s['Type'] as String?;
        final index = s['Index'] as int?;
        final bitrate = s['BitRate'] as int?;

        if (bitrate == null) continue;

        if (streamType == 'Video') {
          totalBitrate += bitrate;
        } else if (streamType == 'Audio' && index == audioStreamIndex) {
          totalBitrate += bitrate;
        }
      }

      return totalBitrate > 0 ? totalBitrate : null;
    } catch (e) {
      return null;
    }
  }

  bool hasCapability(String command) {
    return supportedCommands.contains(command);
  }

  void Function()? ifCapable(String command, void Function() action) {
    return hasCapability(command) ? action : null;
  }

  void Function()? ifAllCapable(List<String> commands, void Function() action) {
    for (final command in commands) {
      if (!hasCapability(command)) return null;
    }
    return action;
  }

  void Function(T)? ifCapableValue<T>(String command, void Function(T) action) {
    return hasCapability(command) ? action : null;
  }
}
