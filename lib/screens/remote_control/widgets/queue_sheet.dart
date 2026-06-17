import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:scyphomote/l10n/app_localizations.dart';
import '../../../models/media_info.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/queue_provider.dart';
import '../../../providers/session_provider.dart';
import 'playback_mode_buttons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({super.key});

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  bool _showPreviousItems = false;

  Widget _buildItem(MediaInfo item, int index, bool isPlaying, bool isReorderable, Map<String, MediaInfo>? bulkDetails) {
    final apiService = ref.read(apiServiceProvider);
    
    final l10n = AppLocalizations.of(context)!;
    
    // Fallback to bulk fetched details if available
    final detailedItem = bulkDetails?[item.id] ?? item;
    
    final itemName = detailedItem.name ?? l10n.loading;
    final subtitle = detailedItem.album ?? detailedItem.artist;
    final imageUrl = apiService.getArtworkUrl(detailedItem.artworkId, 'Primary', maxWidth: 100, tag: detailedItem.resolvedPrimaryImageTag);

    return Material(
      key: ValueKey(item.playlistItemId ?? item.id),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ListTile(
          tileColor: isPlaying ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
          title: Text(
            itemName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isPlaying ? FontWeight.bold : null,
              color: isPlaying ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: subtitle != null ? Text(
            subtitle, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
          ) : null,
          leading: isPlaying
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: const PlayingIndicator(),
                )
              : (detailedItem.resolvedPrimaryImageTag != null)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          width: 48,
                          height: 48,
                          child: const Icon(Icons.music_note_rounded),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          width: 48,
                          height: 48,
                          child: const Icon(Icons.music_note_rounded),
                        ),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.music_note_rounded),
                    ),
          trailing: isReorderable ? ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator_rounded),
          ) : null,
          onTap: () {
            if (item.playlistItemId != null && !isPlaying) {
              HapticFeedback.lightImpact();
              ref.read(playbackProvider.notifier).jumpToPlaylistItem(item.playlistItemId!);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).selectedSession;
    if (session == null) {
      return const SizedBox();
    }

    final bulkDetails = ref.watch(queueDetailsProvider);

    final queue = session.nowPlayingQueue ?? [];
    int currentIndex = session.currentQueueIndex;
    
    final previousItems = queue.sublist(0, currentIndex);
    final upcomingItems = queue.sublist(currentIndex);
    
    final listLength = _showPreviousItems ? queue.length : upcomingItems.length;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Queue',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      RepeatButton(session: session),
                      const SizedBox(width: 8),
                      ShuffleButton(session: session),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  if (!_showPreviousItems && previousItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showPreviousItems = true),
                          icon: const Icon(Icons.history),
                          label: Text('Show Previous Items (${previousItems.length})'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  SliverReorderableList(
                    itemCount: listLength,
                    itemBuilder: (context, index) {
                      final itemIndex = _showPreviousItems ? index : index + currentIndex;
                      final item = queue[itemIndex];
                      final isPlaying = itemIndex == currentIndex;
                      return _buildItem(item, index, isPlaying, true, bulkDetails);
                    },
                    onReorderItem: (oldIndex, newIndex) {
                      if (oldIndex == newIndex) return;
                      
                      final actualOldIndex = _showPreviousItems ? oldIndex : oldIndex + currentIndex;
                      final actualNewIndex = _showPreviousItems ? newIndex : newIndex + currentIndex;
                      
                      final item = queue[actualOldIndex];
                      if (item.playlistItemId == null) return;
                      
                      HapticFeedback.lightImpact();
                      
                      ref.read(playbackProvider.notifier).movePlaylistItem(item.playlistItemId!, actualNewIndex);
                    },
                  ),
                ],
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}

class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({super.key});

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = (math.sin(_controller.value * 2 * math.pi + index * 1.5) + 1) / 2;
              return Container(
                width: 4,
                height: 4 + val * 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
