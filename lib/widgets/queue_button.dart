import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/playback_utils.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

class QueueIconButton extends ConsumerWidget {
  final Map<String, dynamic> item;

  const QueueIconButton({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.queue_music_rounded),
      tooltip: AppLocalizations.of(context)!.addToQueue,
      onPressed: () => queueItemOnRemote(context, ref, item),
    );
  }
}

class QueueOverlayButton extends ConsumerWidget {
  final Map<String, dynamic> item;

  const QueueOverlayButton({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item['Type'] != 'Audio') {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 4,
      right: 4,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 20),
          tooltip: AppLocalizations.of(context)!.addToQueue,
          onPressed: () => queueItemOnRemote(context, ref, item),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
        ),
      ),
    );
  }
}
