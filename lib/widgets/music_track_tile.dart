import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/ui_utils.dart';
import '../utils/playback_utils.dart';
import 'queue_button.dart';
import '../models/media_info.dart';
import '../screens/remote_control/widgets/now_playing_section.dart';

class MusicTrackTile extends ConsumerWidget {
  final Map<String, dynamic> item;

  const MusicTrackTile({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runTimeTicks = item['RunTimeTicks'] as int?;
    String? duration;
    if (runTimeTicks != null) {
      final totalSeconds = runTimeTicks ~/ 10000000;
      duration = formatDuration(totalSeconds);
    }

    return ListTile(
      leading: const Icon(Icons.music_note_rounded),
      title: Text(UiUtils.getDisplayTitle(item)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (duration != null) ...[
            Text(
              duration,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
          QueueIconButton(item: item),
        ],
      ),
      onTap: () => playItemOnRemote(context, ref, item),
      onLongPress: () {
        final media = MediaInfo.fromJson(item);
        showMediaDetailsSheet(context, media);
      },
    );
  }
}
