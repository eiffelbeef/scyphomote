class JellyfinCommands {
  // Playback commands
  static const String play = 'Unpause';
  static const String pause = 'Pause';
  static const String playPause = 'PlayPause';
  static const String stop = 'Stop';
  static const String nextTrack = 'NextTrack';
  static const String previousTrack = 'PreviousTrack';
  static const String rewind = 'Rewind';
  static const String fastForward = 'FastForward';

  // Navigation commands
  static const String moveUp = 'MoveUp';
  static const String moveDown = 'MoveDown';
  static const String moveLeft = 'MoveLeft';
  static const String moveRight = 'MoveRight';
  static const String select = 'Select';
  static const String back = 'Back';
  static const String goHome = 'GoHome';
  static const String goToSettings = 'GoToSettings';

  // Channel commands
  static const String channelUp = 'ChannelUp';
  static const String channelDown = 'ChannelDown';

  // Display commands
  static const String displayMessage = 'DisplayMessage';
  static const String sendString = 'SendString';

  // Audio/Video commands
  static const String setAudioStreamIndex = 'SetAudioStreamIndex';
  static const String setSubtitleStreamIndex = 'SetSubtitleStreamIndex';
  static const String toggleFullscreen = 'ToggleFullscreen';

  // Volume commands
  static const String setVolume = 'SetVolume';
  static const String mute = 'Mute';
  static const String unmute = 'Unmute';
  static const String toggleMute = 'ToggleMute';

  // Seek commands
  static const String seek = 'Seek';

  /// Remote navigation capability group
  static const List<String> remoteNavigation = [
    goHome,
    goToSettings,
    sendString,
    moveUp,
    moveDown,
    moveLeft,
    moveRight,
    select,
    back,
  ];

  static const List<String> mediaControl = [
    play,
    pause,
    playPause,
    stop,
    nextTrack,
    previousTrack,
    rewind,
    fastForward,
    seek,
  ];
}
