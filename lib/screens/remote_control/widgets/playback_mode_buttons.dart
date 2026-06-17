import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../widgets/themed_svg_icon.dart';

class RepeatButton extends ConsumerWidget {
  final Session session;
  final bool useTonal;

  const RepeatButton({
    super.key,
    required this.session,
    this.useTonal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeatMode = session.playState?.repeatMode ?? 'RepeatNone';
    final nextMode = switch (repeatMode) {
      'RepeatNone' => 'RepeatAll',
      'RepeatAll' => 'RepeatOne',
      _ => 'RepeatNone',
    };
    
    final isSelected = repeatMode != 'RepeatNone';

    final iconWidget = switch (repeatMode) {
      'RepeatOne' => const Icon(Icons.repeat_one_rounded),
      'RepeatAll' => const Icon(Icons.repeat_rounded),
      _ => const ThemedSvgIcon('assets/repeat_off.svg'),
    };

    if (useTonal) {
      return IconButton.filledTonal(
        icon: iconWidget,
        iconSize: 20,
        style: isSelected
            ? IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              )
            : null,
        onPressed: session.canRepeat
            ? () {
                HapticFeedback.lightImpact();
                ref.read(playbackProvider.notifier).setRepeatMode(nextMode);
              }
            : null,
      );
    }

    return IconButton.filledTonal(
      icon: iconWidget,
      style: isSelected ? IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
      ) : null,
      onPressed: session.canRepeat
          ? () {
              HapticFeedback.lightImpact();
              ref.read(playbackProvider.notifier).setRepeatMode(nextMode);
            }
          : null,
    );
  }
}

class ShuffleButton extends ConsumerWidget {
  final Session session;
  final bool useTonal;

  const ShuffleButton({
    super.key,
    required this.session,
    this.useTonal = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShuffle = session.playState?.playbackOrder == 'Shuffle';
    final iconSize = useTonal ? 20.0 : 24.0;
    
    final style = useTonal && isShuffle
        ? IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          )
        : null;

    final iconWidget = isShuffle
        ? Icon(Icons.shuffle_rounded, size: iconSize)
        : ThemedSvgIcon('assets/sorted.svg', size: iconSize);

    return useTonal
        ? IconButton.filledTonal(
            icon: iconWidget,
            iconSize: iconSize,
            style: style,
            onPressed: session.canShuffle
                ? () {
                    HapticFeedback.lightImpact();
                    ref.read(playbackProvider.notifier).toggleShuffle(isShuffle);
                  }
                : null,
          )
        : IconButton(
            icon: iconWidget,
            iconSize: iconSize,
            style: style,
            onPressed: session.canShuffle
                ? () {
                    HapticFeedback.lightImpact();
                    ref.read(playbackProvider.notifier).toggleShuffle(isShuffle);
                  }
                : null,
          );
  }
}
