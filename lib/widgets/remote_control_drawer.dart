import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../screens/remote_control/widgets/remote_control_panel.dart';
import '../screens/remote_control/widgets/basic_controls_row.dart';

class RemoteControlDrawer extends ConsumerStatefulWidget {
  const RemoteControlDrawer({super.key});

  @override
  ConsumerState<RemoteControlDrawer> createState() =>
      _RemoteControlDrawerState();
}

class _RemoteControlDrawerState extends ConsumerState<RemoteControlDrawer> {
  final ValueNotifier<double> _dragExtent = ValueNotifier<double>(0.12);

  @override
  void dispose() {
    _dragExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.selectedSession;

    // Don't show drawer if nothing is playing or paused
    if (session == null || session.nowPlaying == null) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final minExtent = ((120.0 + bottomPadding) / screenHeight).clamp(0.05, 0.5);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        _dragExtent.value = notification.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: minExtent,
        minChildSize: minExtent,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // A small drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _dragExtent,
                    builder: (context, extent, child) {
                      final isPaused = session.playState?.isPaused ?? true;

                      return RemoteControlPanel(
                        scrollController: scrollController,
                        showBottomButtons: false,
                        isDrawer: false, // Use normal layout
                        dragExtent: _dragExtent, // Pass extent
                        minExtent: minExtent,
                        miniControls: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 8.0,
                              left: 24.0,
                              right: 16.0,
                            ),
                            child: Builder(
                              builder: (context) {
                                String? imageUrl;
                                if (session.nowPlaying != null) {
                                  final apiService = ref.read(
                                    apiServiceProvider,
                                  );
                                  imageUrl = apiService.getArtworkUrl(
                                    session.nowPlaying!.artworkId,
                                    'Primary',
                                    maxWidth: 100,
                                  );
                                }

                                return Row(
                                  children: [
                                    if (imageUrl != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                width: 48,
                                                height: 48,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                child: const Icon(
                                                  Icons.music_note,
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                                width: 48,
                                                height: 48,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                child: const Icon(
                                                  Icons.music_note,
                                                ),
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            session.nowPlaying?.name ?? '',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (session.nowPlaying?.seriesName != null ||
                                              session.nowPlaying?.artist != null ||
                                              session.nowPlaying?.productionYear != null)
                                            Text(
                                              session.nowPlaying?.seriesName ??
                                                  session.nowPlaying?.artist ??
                                                  session.nowPlaying?.productionYear?.toString() ??
                                                  '',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    BasicControlsRow(
                                      session: session,
                                      isPaused: isPaused,
                                      drawerMode: true,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
