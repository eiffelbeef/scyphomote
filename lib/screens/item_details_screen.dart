import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/remote_providers.dart';
import '../providers/settings_provider.dart';

import '../models/media_info.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/overview_section.dart';
import '../widgets/person_card.dart';
import '../widgets/person_details_sheet.dart';
import '../widgets/item_poster.dart';
import '../widgets/music_track_tile.dart';
import '../widgets/item_card.dart';
import '../widgets/episode_row.dart';
import '../widgets/external_links_section.dart';
import '../widgets/remote_control_drawer.dart';
import '../utils/playback_utils.dart';
import '../utils/item_action_utils.dart';
import '../utils/ui_utils.dart';
import '../widgets/collapsible_section.dart';

class ItemDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  late final ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 50 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailsAsync = ref.watch(itemDetailsProvider(widget.item['Id']));
    
    final isPlayedAsync = ref.watch(itemPlayedProvider(widget.item['Id']));
    final isFavoriteAsync = ref.watch(itemFavoriteProvider(widget.item['Id']));

    final isPlayed = isPlayedAsync.value ?? widget.item['UserData']?['Played'] ?? false;
    final isFavorite = isFavoriteAsync.value ?? widget.item['UserData']?['IsFavorite'] ?? false;
    final overview = detailsAsync.value?['Overview'] as String? ?? widget.item['Overview'] as String?;
    
    final displayYear = UiUtils.getYearString(context, widget.item);

    final type = widget.item['Type'] as String?;
    final title = widget.item['Name'] as String? ?? 'Unknown';
    final apiService = ref.read(apiServiceProvider);
    final childrenAsync = ref.watch(itemChildrenProvider((
      itemId: widget.item['Id'],
      type: widget.item['Type'],
    )));

    final backdropUrl = widget.item['BackdropImageTags'] != null &&
            (widget.item['BackdropImageTags'] as List).isNotEmpty
        ? apiService.getArtworkUrl(widget.item['Id'], 'Backdrop', maxWidth: 1000)
        : null;

    final posterUrl = apiService.getItemImageUrl(widget.item);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? Colors.red : Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              ItemActionUtils.toggleFavorite(context, ref, widget.item['Id'], isFavorite);
            },
          ),
          if (type == 'Movie' || type == 'Episode' || type == 'Series' || type == 'Season')
            IconButton(
              icon: Icon(
                isPlayed ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                color: isPlayed ? Colors.green : Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                ItemActionUtils.togglePlayedStatus(context, ref, widget.item['Id'], isPlayed);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (backdropUrl != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 400,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.3,
                    child: SafeNetworkImage(
                      imageUrl: backdropUrl,
                      fit: BoxFit.cover,
                      fallbackWidget: const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
              ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: AspectRatio(
                          aspectRatio: UiUtils.getItemAspectRatio(widget.item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ItemPoster(
                              imageUrl: posterUrl,
                              userData: widget.item['UserData'],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (displayYear != null)
                              Text(
                                displayYear,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final userData = widget.item['UserData'] as Map<String, dynamic>?;
                                final playbackPositionTicks = userData?['PlaybackPositionTicks'] as int? ?? 0;
                                final hasResume = playbackPositionTicks > 0 && (type == 'Movie' || type == 'Episode');

                                return Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: [
                                    if (hasResume) ...[
                                      FilledButton.icon(
                                        icon: const Icon(Icons.play_arrow_rounded),
                                        label: Text(l10n.resumeFrom(formatDuration(playbackPositionTicks ~/ 10000000))),
                                        onPressed: () => playItemOnRemote(context, ref, widget.item, resume: true),
                                      ),
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.replay_rounded),
                                        label: Text(l10n.play),
                                        onPressed: () => playItemOnRemote(context, ref, widget.item, resume: false),
                                      ),
                                    ] else
                                      FilledButton.icon(
                                        icon: const Icon(Icons.play_arrow_rounded),
                                        label: Text(l10n.play),
                                        onPressed: () => playItemOnRemote(context, ref, widget.item, resume: false),
                                      ),
                                    if (type == 'Series' || type == 'Season' || type == 'MusicAlbum' || type == 'MusicArtist')
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.shuffle_rounded),
                                        label: Text(l10n.shuffle),
                                        onPressed: () => playItemOnRemote(context, ref, widget.item, playCommand: 'PlayShuffle'),
                                      ),
                                    if (type == 'MusicAlbum' || type == 'MusicArtist' || type == 'Audio')
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.queue_music_rounded),
                                        label: Text(type == 'MusicAlbum' ? l10n.addAlbumToQueue : l10n.addToQueue),
                                        onPressed: () => queueItemOnRemote(context, ref, widget.item),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (overview != null && overview.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: OverviewSection(
                  overview: overview,
                ),
              ),
            ),
          detailsAsync.when(
            data: (details) {
              final people = (details?['People'] as List?)
                      ?.map((p) => Person.fromJson(p as Map<String, dynamic>))
                      .toList() ??
                  [];
              final externalUrls = (details?['ExternalUrls'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];

              final isCastAndCrewExpanded = ref.watch(settingsProvider).castAndCrewExpanded;
              final isExternalLinksExpanded = ref.watch(settingsProvider).externalLinksExpanded;

              if (people.isEmpty && externalUrls.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (externalUrls.isNotEmpty)
                    CollapsibleSection(
                      title: l10n.externalLinks,
                      isCollapsible: true,
                      isExpanded: isExternalLinksExpanded,
                      onToggle: () {
                        ref.read(settingsProvider.notifier).setExternalLinksExpanded(!isExternalLinksExpanded);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ExternalLinksSection(externalUrls: externalUrls),
                      ),
                    ),
                  if (people.isNotEmpty)
                    CollapsibleSection(
                      title: l10n.castAndCrew,
                      isCollapsible: true,
                      isExpanded: isCastAndCrewExpanded,
                      onToggle: () {
                        ref.read(settingsProvider.notifier).setCastAndCrewExpanded(!isCastAndCrewExpanded);
                      },
                      child: SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          itemCount: people.length,
                          itemBuilder: (context, index) {
                            return PersonCard(
                              person: people[index],
                              apiService: apiService,
                              onTap: (id, name) {
                                showPersonDetailSheet(context, id, name);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ]),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(err.toString()))),
            ),
          ),
          ...childrenAsync.when(
            data: (children) {
              if (children.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

              if (type == 'Series' || type == 'MusicArtist') {
                return [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: ref.watch(settingsProvider).libraryItemsPerRow,
                        childAspectRatio: UiUtils.getItemAspectRatio(children.firstOrNull),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final season = children[index];
                          return ItemCard(item: season, apiService: apiService);
                        },
                        childCount: children.length,
                      ),
                    ),
                  ),
                ];
              } else if (type == 'Season' || type == 'MusicAlbum') {
                return [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final episode = children[index];
                        Widget child;
                        if (episode['Type'] == 'Audio') {
                          child = MusicTrackTile(item: episode);
                        } else {
                          child = EpisodeRow(item: episode, apiService: apiService);
                        }

                        if (index > 0 && episode['Type'] == 'Audio') {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Divider(height: 1),
                              child,
                            ],
                          );
                        }
                        return child;
                      },
                      childCount: children.length,
                    ),
                  ),
                ];
              }
              return [const SliverToBoxAdapter(child: SizedBox.shrink())];
            },
            loading: () => [
              const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
              ),
            ],
            error: (err, stack) => [
              SliverToBoxAdapter(
                child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(err.toString()))),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
          if (_isScrolled)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          const RemoteControlDrawer(),
        ],
      ),
    );
  }



}
