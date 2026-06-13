import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/remote_providers.dart';
import '../../../widgets/playback_progress_control.dart';
import '../../../widgets/smooth_animated_slider.dart';
import '../../../widgets/themed_svg_icon.dart';
import '../../../constants/jellyfin_commands.dart';
import '../../library_screen.dart';
import '../../../providers/session_provider.dart';
import 'stream_selection_sheet.dart';
import 'remote_navigation_sheet.dart';
import '../../../widgets/text_input_dialog.dart';

import 'trickplay_overlay.dart';
import '../../../utils/playback_utils.dart';
import 'remote_button.dart';
import 'basic_controls_row.dart';

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
                          Builder(
                            builder: (context) {
                              final repeatMode =
                                  session.playState?.repeatMode ?? 'RepeatNone';
                              final nextMode = switch (repeatMode) {
                                'RepeatNone' => 'RepeatAll',
                                'RepeatAll' => 'RepeatOne',
                                _ => 'RepeatNone',
                              };
                              final icon = switch (repeatMode) {
                                'RepeatOne' => Icons.repeat_one_rounded,
                                'RepeatAll' => Icons.repeat_rounded,
                                _ => Icons.repeat_rounded,
                              };
                              return RemoteIconButton(
                                icon: icon,
                                style: repeatMode != 'RepeatNone'
                                    ? IconButton.styleFrom(
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      )
                                    : null,
                                onPressed: session.canRepeat
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        ref
                                            .read(playbackProvider.notifier)
                                            .setRepeatMode(nextMode);
                                      }
                                    : null,
                              );
                            },
                          )
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
                              final lyricsAsync = ref.watch(
                                lyricsProvider((
                                  itemId: nowPlaying.id,
                                  hasLyrics: nowPlaying.hasLyrics,
                                )),
                              );
                              return lyricsAsync.when(
                                data: (lyrics) {
                                  return IconButton.filledTonal(
                                    icon: const Icon(Icons.lyrics_rounded),
                                    iconSize: 24,
                                    onPressed:
                                        nowPlaying.hasLyrics && lyrics != null
                                        ? () =>
                                              _showLyricsSheet(context, lyrics)
                                        : null,
                                  );
                                },
                                loading: () => const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                error: (_, _) => const IconButton.filledTonal(
                                  icon: Icon(Icons.lyrics_rounded),
                                  iconSize: 24,
                                  onPressed: null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (context) {
                              final isShuffle =
                                  session.playState?.playbackOrder == 'Shuffle';
                              return IconButton.filledTonal(
                                icon: isShuffle
                                    ? const Icon(Icons.shuffle_rounded)
                                    : const ThemedSvgIcon('assets/sorted.svg'),
                                iconSize: 24,
                                onPressed: session.canShuffle
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        ref
                                            .read(playbackProvider.notifier)
                                            .toggleShuffle(isShuffle);
                                      }
                                    : null,
                              );
                            },
                          ),
                        ] else
                          IconButton.filledTonal(
                            icon: const Icon(Icons.subtitles_rounded),
                            iconSize: 24,
                            onPressed: nowPlaying.hasSubtitles
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
                                onPressed: hasMultipleAudioTracks
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
                      ? Icons.volume_off
                      : Icons.volume_up,
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
                child: SmoothAnimatedSlider(
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
                  onPressed: session.canPlayOn
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LibraryScreen(),
                          ),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.video_library, size: 20),
                  label: const Text('Browse'),
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
                  label: const Text('Remote'),
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
}
