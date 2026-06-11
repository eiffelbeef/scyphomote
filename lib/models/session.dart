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
  });

  bool get isPlaying => nowPlaying != null && !(playState?.isPaused ?? true);
  bool get isPaused => nowPlaying != null && (playState?.isPaused ?? false);

  /// Check if this session supports remote navigation commands
  bool get canUseRemote => JellyfinCommands.remoteNavigation.any(hasCapability);

  /// Check if this session supports media control commands
  bool get canControlMedia => supportsMediaControl;

  /// Check if this session supports playing content remotely (Play On)
  bool get canPlayOn => hasCapability(JellyfinCommands.displayContent);

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

    String? playMethod;
    if (json['PlayState'] != null && json['PlayState']['PlayMethod'] != null) {
      playMethod = json['PlayState']['PlayMethod'] as String;
    }

    List<String>? transcodeReasons;
    if (json['TranscodingInfo'] != null &&
        json['TranscodingInfo']['TranscodeReasons'] != null) {
      transcodeReasons = (json['TranscodingInfo']['TranscodeReasons'] as List)
          .map((e) => e.toString())
          .toList();
    }

    int? bitrate;
    if (json['NowPlayingItem'] != null) {
      bitrate = _calculateBitrate(json);
    }

    final int nowPlayingQueueSize =
        (json['NowPlayingQueue'] as List<dynamic>?)?.length ?? 0;

    return Session(
      sessionId: json['Id'] as String,
      deviceId: json['DeviceId'] as String,
      deviceName: json['DeviceName'] as String? ?? 'Unknown Device',
      clientName: json['Client'] as String? ?? 'Unknown Client',
      userId: json['UserId'] as String,
      userName: json['UserName'] as String? ?? 'Unknown User',
      isActive: json['IsActive'] as bool? ?? false,
      supportsRemoteControl: json['SupportsRemoteControl'] as bool? ?? false,
      supportsMediaControl: json['SupportsMediaControl'] as bool? ?? false,
      supportedCommands: supportedCommands,
      playableMediaTypes: playableMediaTypes,
      nowPlayingQueueSize: nowPlayingQueueSize,
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
