import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/jellyfin_api_service.dart';
import '../models/media_info.dart';
import '../utils/playback_utils.dart';
import '../utils/ui_utils.dart';
import '../screens/remote_control/widgets/now_playing_section.dart';
import 'item_poster.dart';

class EpisodeRow extends ConsumerWidget {
  final Map<String, dynamic> item;
  final JellyfinApiService apiService;

  const EpisodeRow({
    super.key,
    required this.item,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = apiService.getItemImageUrl(item);
    final runTimeTicks = item['RunTimeTicks'] as int?;
    final overview = item['Overview'] as String?;

    return InkWell(
      onTap: () => playItemOnRemote(context, ref, item),
      onLongPress: () {
        final media = MediaInfo.fromJson(item);
        showMediaDetailsSheet(context, media);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: AspectRatio(
                aspectRatio: UiUtils.getItemAspectRatio(item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: ItemPoster(
                    imageUrl: imageUrl,
                    userData: item['UserData'],
                    placeholderIcon: Icons.movie_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: UiUtils.getDisplayTitle(item),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (runTimeTicks != null)
                          TextSpan(
                            text: '  •  ${formatDuration(runTimeTicks ~/ 10000000)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (overview != null && overview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
