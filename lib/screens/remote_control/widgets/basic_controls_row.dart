import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../constants/jellyfin_commands.dart';
import '../../../utils/playback_utils.dart';
import 'remote_button.dart';

class BasicControlsRow extends ConsumerWidget {
  final Session session;
  final bool isPaused;
  final bool drawerMode;

  const BasicControlsRow({
    super.key,
    required this.session,
    required this.isPaused,
    this.drawerMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        RemoteIconButton(
          icon: Icons.skip_previous_rounded,
          iconSize: 28.0,
          onPressed:
              (session.nowPlayingQueueSize > 1 && session.supportsRemoteControl)
              ? () => ref
                    .read(playbackProvider.notifier)
                    .sendPlayingCommand(JellyfinCommands.previousTrack)
              : null,
        ),
        if (!drawerMode) ...[
          const SizedBox(width: 12.0),
          RemoteIconButton(
            icon: Icons.fast_rewind_rounded,
            iconSize: 28.0,
            onPressed: session.supportsRemoteControl
                ? () => ref.read(playbackProvider.notifier).rewind()
                : null,
          ),
        ],
        const SizedBox(width: 12.0),
        IconButton.filled(
          icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          iconSize: 40.0,
          style: IconButton.styleFrom(padding: const EdgeInsets.all(12.0)),
          onPressed: session.supportsRemoteControl
              ? () {
                  HapticFeedback.mediumImpact();
                  ref.read(playbackProvider.notifier).playPause();
                }
              : null,
        ),
        if (!drawerMode) ...[
          const SizedBox(width: 12.0),
          RemoteIconButton(
            icon: Icons.fast_forward_rounded,
            iconSize: 28.0,
            onPressed: session.supportsRemoteControl
                ? () => ref.read(playbackProvider.notifier).fastForward()
                : null,
          ),
        ],
        const SizedBox(width: 12.0),
        Builder(
          builder: (context) {
            final isEnding = isEpisodeNearEnd(session);
            final isNextEnabled =
                session.nowPlayingQueueSize > 1 &&
                session.supportsRemoteControl;
            final showHighlight = isEnding && isNextEnabled;

            return RemoteIconButton(
              icon: Icons.skip_next_rounded,
              iconSize: 28.0,
              onPressed: isNextEnabled
                  ? () => ref
                        .read(playbackProvider.notifier)
                        .sendPlayingCommand(JellyfinCommands.nextTrack)
                  : null,
              style: showHighlight
                  ? IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }
}
