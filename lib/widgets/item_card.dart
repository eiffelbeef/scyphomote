import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/jellyfin_api_service.dart';
import '../screens/item_details_screen.dart';
import '../screens/items_screen.dart';
import '../utils/playback_utils.dart';
import '../utils/ui_utils.dart';
import 'item_poster.dart';
import 'queue_button.dart';
import 'marquee_text.dart';

class ItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final JellyfinApiService apiService;
  final String? collectionType;
  final bool isMusic;

  const ItemCard({
    super.key,
    required this.item,
    required this.apiService,
    this.collectionType,
    this.isMusic = false,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = apiService.getItemImageUrl(item);
    final isFolder = item['IsFolder'] == true;
    final type = item['Type'];
    final displayYear = UiUtils.getYearString(context, item);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (type == 'Movie' || type == 'Series' || type == 'Season' || type == 'Episode' || type == 'MusicAlbum' || type == 'MusicArtist') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ItemDetailsScreen(item: item),
              ),
            );
          } else if (isFolder) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ItemsScreen(
                  title: UiUtils.getDisplayTitle(item),
                  parentId: item['Id'],
                  collectionType: collectionType,
                  parentType: type,
                ),
              ),
            );
          } else {
            playItemOnRemote(context, ref, item);
          }
        },
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
                    placeholderIcon: isMusic ? Icons.music_note_rounded : Icons.movie_rounded,
                    showPlayedIndicator: !isMusic,
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
                    text: UiUtils.getDisplayTitle(item),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (displayYear != null &&
                      (type == 'Movie' || type == 'Series'))
                    Text(
                      displayYear,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
