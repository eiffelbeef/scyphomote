import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItemPoster extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic>? userData;
  final IconData placeholderIcon;
  final BoxFit fit;

  const ItemPoster({
    super.key,
    required this.imageUrl,
    this.userData,
    this.placeholderIcon = Icons.movie,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          placeholder: (context, url) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(child: Icon(placeholderIcon)),
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image)),
          ),
        ),
        // Playback status overlays
        if (userData != null) ...[
          // Playback status badges
          () {
            final unplayedCount = userData!['UnplayedItemCount'] as int?;
            final isPlayed = userData!['Played'] == true;

            if (unplayedCount == null && !isPlayed) {
              return const SizedBox.shrink();
            }

            final showCount = unplayedCount != null && unplayedCount > 0;

            return Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: showCount ? 8 : 4,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: showCount
                    ? Text(
                        unplayedCount.toString(),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 16,
                      ),
              ),
            );
          }(),
          // Progress bar
          if (userData!['PlayedPercentage'] != null &&
              userData!['PlayedPercentage'] > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: userData!['PlayedPercentage'] / 100.0,
                backgroundColor: Colors.black26,
                color: Theme.of(context).colorScheme.primary,
                minHeight: 4,
              ),
            ),
        ],
      ],
    );
  }
}
