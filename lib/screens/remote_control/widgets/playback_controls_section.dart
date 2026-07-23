import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/remote_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/playback_progress_control.dart';
import '../../../widgets/smooth_animated_slider.dart';
import '../../../constants/jellyfin_commands.dart';
import '../../library_screen.dart';
import '../../../providers/session_provider.dart';
import 'stream_selection_sheet.dart';
import 'remote_navigation_sheet.dart';
import '../../../widgets/text_input_dialog.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'trickplay_overlay.dart';
import '../../../utils/playback_utils.dart';
import 'remote_button.dart';
import 'basic_controls_row.dart';
import 'queue_sheet.dart';
import 'playback_mode_buttons.dart';

class PlaybackControlsSection extends ConsumerWidget {
  final Session session;
  final int currentPositionSeconds;
  final int durationSeconds;
  final bool isPaused;
  final double currentVolume;
  final double availableWidth;
  final Function(double) onSeek;
  final Function(double) onSeekEnd;
  final Function(double) onVolumeChanged;
  final Function(double) onVolumeChangeEnd;
  final bool showBottomButtons;
  final bool showBasicControls;
  const PlaybackControlsSection({
    super.key,
    required this.session,
    required this.currentPositionSeconds,
    required this.durationSeconds,
    required this.isPaused,
    required this.currentVolume,
    this.availableWidth = 0,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    this.showBottomButtons = true,
    this.showBasicControls = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlaying = session.nowPlaying;
    final playState = session.playState;
    final l10n = AppLocalizations.of(context)!;
    final useVolumeToolbar = ref.watch(settingsProvider).useVolumeToolbar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progression (Only if playing)
        if (nowPlaying != null && durationSeconds > 0) ...[
          PlaybackProgressControl(
            currentPositionSeconds: currentPositionSeconds,
            durationSeconds: durationSeconds,
            isPlaying: !isPaused,
            interactable: session.playState?.canSeek ?? false,
            width: availableWidth,
            onSeek: (val) => onSeek(val.toDouble()),
            onSeekEnd: (val) => onSeekEnd(val.toDouble()),
            overlayBuilder: (context, value, thumbCenter) {
              final sourceId = session.playState?.mediaSourceId;
              if (sourceId == null) return const SizedBox();

              final info = nowPlaying.trickplay?.getBestTilesInfo(sourceId);
              if (info == null) return const SizedBox();

              return TrickplayOverlay(
                seconds: value,
                info: info,
                itemId: nowPlaying.id,
                mediaSourceId: sourceId,
                availableWidth: availableWidth,
                thumbCenter: thumbCenter,
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        if (nowPlaying != null) ...[
          // Playback Icons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBasicControls) ...[
                BasicControlsRow(
                  session: session,
                  isPaused: isPaused,
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (nowPlaying.type == 'Audio')
                          RepeatButton(session: session)
                        else
                          RemoteIconButton(
                            icon: Icons.fullscreen_rounded,
                            onPressed: session.ifCapable(
                              JellyfinCommands.toggleFullscreen,
                              () => ref
                                  .read(playbackProvider.notifier)
                                  .sendCommand(
                                    JellyfinCommands.toggleFullscreen,
                                  ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        if (nowPlaying.type == 'Audio')
                          IconButton.filledTonal(
                            icon: const Icon(Icons.queue_music_rounded),
                            iconSize: 24,
                            onPressed: () => _showQueueSheet(context),
                          )
                        else
                          MessageButton(session: session),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final isEnding = isEpisodeNearEnd(session);
                      final isStopEnabled = session.supportsRemoteControl;
                      final hasNext = session.nowPlayingQueueSize > 1;
                      final showHighlight = isEnding && !hasNext;

                      return IconButton.filledTonal(
                        icon: const Icon(Icons.stop_rounded),
                        iconSize: 24,
                        onPressed: isStopEnabled
                            ? () {
                                HapticFeedback.mediumImpact();
                                ref.read(playbackProvider.notifier).stop();
                              }
                            : null,
                        style: showHighlight
                            ? IconButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (nowPlaying.type == 'Audio') ...[
                          Consumer(
                            builder: (context, ref, child) {
                              return IconButton.filledTonal(
                                icon: const Icon(Icons.lyrics_rounded),
                                iconSize: 24,
                                onPressed: nowPlaying.hasLyrics
                                  ? () => _fetchAndShowLyrics(context, ref, nowPlaying.id)
                                  : null,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          ShuffleButton(session: session),
                        ] else
                          IconButton.filledTonal(
                            icon: const Icon(Icons.subtitles_rounded),
                            iconSize: 24,
                            onPressed: (nowPlaying.hasSubtitles && session.supportsRemoteControl)
                                ? session.ifCapable(
                                    JellyfinCommands.setSubtitleStreamIndex,
                                    () => _showSubtitlePicker(context, ref),
                                  )
                                : null,
                          ),
                        if (nowPlaying.type != 'Audio') ...[
                          const SizedBox(width: 12),
                          Consumer(
                            builder: (context, ref, child) {
                              final itemDetailsAsync = ref.watch(
                                itemDetailsProvider(nowPlaying.id),
                              );
                              final hasMultipleAudioTracks =
                                  itemDetailsAsync.whenOrNull(
                                    data: (details) {
                                      if (details == null) return false;
                                      final streams =
                                          details['MediaStreams'] as List? ??
                                          [];
                                      return streams
                                              .where(
                                                (s) => s['Type'] == 'Audio',
                                              )
                                              .length >
                                          1;
                                    },
                                  ) ??
                                  false;
                              return IconButton.filledTonal(
                                icon: const Icon(Icons.audiotrack_rounded),
                                iconSize: 24,
                                onPressed: (hasMultipleAudioTracks && session.supportsRemoteControl)
                                    ? session.ifCapable(
                                        JellyfinCommands.setAudioStreamIndex,
                                        () =>
                                            _showAudioTrackPicker(context, ref),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Volume Controls
        if (nowPlaying != null)
          Row(
            children: [
              IconButton(
                icon: Icon(
                  playState?.isMuted == true
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                ),
                onPressed: session.ifAllCapable(
                  [JellyfinCommands.mute, JellyfinCommands.unmute],
                  () {
                    HapticFeedback.mediumImpact();
                    ref.read(playbackProvider.notifier).toggleMute();
                  },
                ),
              ),
              Expanded(
                child: useVolumeToolbar
                    ? Center(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_down_rounded, size: 20),
                                onPressed: session.ifCapable(
                                  JellyfinCommands.volumeDown,
                                  () {
                                    HapticFeedback.lightImpact();
                                    ref.read(playbackProvider.notifier).sendCommand(JellyfinCommands.volumeDown, refreshAfter: true);
                                  }
                                ),
                              ),
                              TextButton(
                                onPressed: session.ifCapable(
                                  JellyfinCommands.setVolume,
                                  () async {
                                    TextInputDialog.show(
                                      context: context,
                                      title: l10n.volume,
                                      initialText: currentVolume.toInt().toString(),
                                      labelText: l10n.volumeLabel,
                                      keyboardType: TextInputType.number,
                                      onSend: (message) {
                                        final vol = int.tryParse(message);
                                        if (vol != null && vol >= 0 && vol <= 100) {
                                          onVolumeChangeEnd(vol.toDouble());
                                        }
                                      },
                                    );
                                  },
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(80, 40),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  '${currentVolume.toInt()}%',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, size: 20),
                                onPressed: session.ifCapable(
                                  JellyfinCommands.volumeUp,
                                  () {
                                    HapticFeedback.lightImpact();
                                    ref.read(playbackProvider.notifier).sendCommand(JellyfinCommands.volumeUp, refreshAfter: true);
                                  }
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SmoothAnimatedSlider(
                        value: currentVolume.clamp(0, 100),
                        min: 0,
                        max: 100,
                        width: availableWidth,
                        onChanged: session.ifCapableValue(
                          JellyfinCommands.setVolume,
                          onVolumeChanged,
                        ),
                        onChangeEnd: session.ifCapableValue(
                          JellyfinCommands.setVolume,
                          (value) {
                            onVolumeChangeEnd(value);
                          },
                        ),
                      ),
              ),
              if (useVolumeToolbar)
                const SizedBox(width: 48),
            ],
          ),

        const SizedBox(height: 16),

        // Browse & Remote Buttons
        if (showBottomButtons)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.tonalIcon(
                  onPressed: session.supportsMediaControl
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LibraryScreen(),
                          ),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.video_library_rounded, size: 20),
                  label: Text(l10n.browse),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: FilledButton.tonalIcon(
                  onPressed: session.canUseRemote
                      ? () => _showRemoteSheet(context, ref)
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.gamepad_rounded, size: 20),
                  label: Text(l10n.remote),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _showSubtitlePicker(BuildContext context, WidgetRef ref) {
    final nowPlaying = session.nowPlaying;
    if (nowPlaying == null) return;

    ref.read(sessionProvider.notifier).fetchSessions();

    showModalBottomSheet(
      context: context,
      builder: (context) => StreamSelectionSheet(
        itemId: nowPlaying.id,
        streamType: 'Subtitle',
        title: 'Select Subtitle',
      ),
    );
  }

  void _showAudioTrackPicker(BuildContext context, WidgetRef ref) {
    final nowPlaying = session.nowPlaying;
    if (nowPlaying == null) return;

    ref.read(sessionProvider.notifier).fetchSessions();

    showModalBottomSheet(
      context: context,
      builder: (context) => StreamSelectionSheet(
        itemId: nowPlaying.id,
        streamType: 'Audio',
        title: 'Select Audio Track',
      ),
    );
  }

  void _fetchAndShowLyrics(BuildContext context, WidgetRef ref, String itemId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final lyrics = await apiService.getLyrics(itemId);
      
      if (context.mounted) {
        Navigator.pop(context); // close loading
        if (lyrics != null) {
          _showLyricsSheet(context, lyrics);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No lyrics found')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load lyrics: $e')));
      }
    }
  }

  void _showLyricsSheet(BuildContext context, Map<String, dynamic> lyricsData) {
    final metadata = lyricsData['Metadata'] ?? {};
    final lyrics = lyricsData['Lyrics'] as List? ?? [];
    final title = metadata['Title'] ?? 'Lyrics';
    final artist = metadata['Artist'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (artist != null)
                        Text(
                          artist,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: lyrics.length,
                    itemBuilder: (context, index) {
                      final line = lyrics[index];
                      final text = line['Text'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          text,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInputDialog(BuildContext context, WidgetRef ref) {
    TextInputDialog.show(
      context: context,
      title: 'Keyboard Input',
      labelText: 'Text',
      hintText: 'Type something to send...',
      onSend: (text) {
        ref.read(playbackProvider.notifier).sendString(text);
      },
    );
  }

  void _showRemoteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RemoteNavigationSheet(
        session: session,
        onShowKeyboard: () {
          // Delay slightly to allow sheet to close
          Future.delayed(const Duration(milliseconds: 200), () {
            if (context.mounted) {
              _showInputDialog(context, ref);
            }
          });
        },
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QueueSheet(),
    );
  }
}

