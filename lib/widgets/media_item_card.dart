import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'item_poster.dart';
import 'marquee_text.dart';
import 'queue_button.dart';

class MediaItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final String imageUrl;
  final VoidCallback onTap;
  final String? collectionType;

  const MediaItemCard({
    super.key,
    required this.item,
    required this.imageUrl,
    required this.onTap,
    this.collectionType,
  });

  String _getTitle() {
    final type = item['Type'] as String?;
    if (type == 'Episode') {
      return item['SeriesName'] as String? ?? item['Name'] as String;
    }
    return item['Name'] as String;
  }

  String? _getSubtitle() {
    final type = item['Type'] as String?;

    if (type == 'Episode') {
      final seasonNum = item['ParentIndexNumber'] as int?;
      final episodeNum = item['IndexNumber'] as int?;
      final episodeName = item['Name'] as String;

      if (seasonNum != null && episodeNum != null) {
        final seasonStr = seasonNum.toString().padLeft(2, '0');
        final episodeStr = episodeNum.toString().padLeft(2, '0');
        return 'S${seasonStr}E$episodeStr - $episodeName';
      }
      return episodeName;
    }

    if (type == 'Movie' || type == 'Series') {
      final year = item['ProductionYear'] as int?;
      if (year != null) {
        return year.toString();
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _getSubtitle();

    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ItemPoster(
                      imageUrl: imageUrl,
                      userData: item['UserData'],
                      placeholderIcon: collectionType == 'music'
                          ? Icons.music_note
                          : Icons.movie_rounded,
                      showPlayedIndicator: collectionType != 'music' && item['Type'] != 'Audio',
                    ),
                    QueueOverlayButton(item: item),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarqueeText(
                      text: _getTitle(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
