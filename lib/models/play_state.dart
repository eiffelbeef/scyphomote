class PlayState {
  final bool isPaused;
  final bool isMuted;
  final int? positionTicks;
  final int? volumeLevel;

  final int? subtitleStreamIndex;
  final int? audioStreamIndex;
  final String? mediaSourceId;
  final bool canSeek;
  final String? playbackOrder;
  final String? repeatMode;

  PlayState({
    required this.isPaused,
    required this.isMuted,
    this.positionTicks,
    this.volumeLevel,
    this.subtitleStreamIndex,
    this.audioStreamIndex,
    this.mediaSourceId,
    required this.canSeek,
    this.playbackOrder,
    this.repeatMode,
  });

  int? get positionSeconds =>
      positionTicks != null ? (positionTicks! / 10000000).floor() : null;

  factory PlayState.fromJson(Map<String, dynamic> json) => PlayState(
    isPaused: json['IsPaused'] as bool? ?? false,
    isMuted: json['IsMuted'] as bool? ?? false,
    positionTicks: json['PositionTicks'] as int?,
    volumeLevel: json['VolumeLevel'] as int?,
    subtitleStreamIndex: json['SubtitleStreamIndex'] as int?,
    audioStreamIndex: json['AudioStreamIndex'] as int?,
    mediaSourceId: json['MediaSourceId'] as String?,
    canSeek: json['CanSeek'] as bool? ?? false,
    playbackOrder: json['PlaybackOrder'] as String?,
    repeatMode: json['RepeatMode'] as String?,
  );
}
