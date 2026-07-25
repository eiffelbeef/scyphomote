import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/safe_network_image.dart';
import '../../../widgets/person_row.dart';
import '../../../widgets/external_links_section.dart';
import '../../../widgets/drag_handle.dart';
import '../../../widgets/overview_section.dart';
import '../../../widgets/marquee_text.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/remote_providers.dart';
import '../../../models/media_info.dart';
import '../../../models/media_segment.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/jellyfin_api_service.dart';
import '../../../utils/item_action_utils.dart';
import '../../../utils/logger.dart';
import '../../../utils/ui_utils.dart';
import '../../../widgets/person_details_sheet.dart';
import 'remote_button.dart';
import '../../../../l10n/app_localizations.dart';

import 'package:intl/intl.dart' hide TextDirection;

class NowPlayingSection extends ConsumerStatefulWidget {
  final Session session;
  final String? imageUrl;
  final double artworkSize;
  final double? maxWidth;

  const NowPlayingSection({
    super.key,
    required this.session,
    required this.imageUrl,
    required this.artworkSize,
    this.maxWidth,
  });

  @override
  ConsumerState<NowPlayingSection> createState() => _NowPlayingSectionState();
}

class _NowPlayingSectionState extends ConsumerState<NowPlayingSection> {
  bool _isLoadingMediaInfo = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final imageUrl = widget.imageUrl;
    final artworkSize = widget.artworkSize;
    final nowPlaying = session.nowPlaying;
    final l10n = AppLocalizations.of(context)!;
    final isFavorite = nowPlaying != null 
        ? (ref.watch(itemFavoriteProvider(nowPlaying.id)).value ?? nowPlaying.isFavorite)
        : false;

    final double fallbackRatio = UiUtils.getFallbackAspectRatio(nowPlaying?.type);
    final double aspectRatio =
        nowPlaying?.primaryImageAspectRatio ?? fallbackRatio;

    double finalWidth = artworkSize * aspectRatio;
    double finalHeight = artworkSize;

    if (widget.maxWidth != null && finalWidth > widget.maxWidth!) {
      finalWidth = widget.maxWidth!;
      finalHeight = finalWidth / aspectRatio;
    }

    Widget buildArtwork() {
      final placeholder = _buildPlaceholder(
        context,
        size: finalHeight,
        width: finalWidth,
      );

      return SafeNetworkImage(
        imageUrl: imageUrl,
        fallbackWidget: placeholder,
        width: finalWidth,
        height: finalHeight,
        borderRadius: BorderRadius.circular(12),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            buildArtwork(),

            if (nowPlaying != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.red : Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      ItemActionUtils.toggleFavorite(context, ref, nowPlaying.id, isFavorite);
                    },
                  ),
                ),
              ),


            if (nowPlaying != null && nowPlaying.isVideo)
              Consumer(
                builder: (context, ref, child) {
                  final segmentsAsync = ref.watch(
                    mediaSegmentsProvider(nowPlaying.id),
                  );
                  return segmentsAsync.maybeWhen(
                    data: (segments) {
                      final playState = session.playState;
                      final currentPos = (playState?.positionSeconds ?? 0)
                          .toInt();
                      final activeSegment = segments.firstWhere(
                        (s) => s.isActive(currentPos),
                        orElse: () => MediaSegment(
                          id: '',
                          itemId: '',
                          type: '',
                          startTicks: 0,
                          endTicks: 0,
                        ),
                      );

                      if (activeSegment.id.isEmpty || !(playState?.canSeek ?? false)) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        bottom: -8, // Positioned near bottom edge
                        right: -8, // and slightly out to the right
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(playbackProvider.notifier)
                                .seek(activeSegment.endSeconds.toInt());
                          },
                          icon: const Icon(Icons.skip_next_rounded),
                          label: Text(l10n.skipType(activeSegment.type)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            elevation: 4,
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
          ],
        ),

        const SizedBox(height: 16),

        if (nowPlaying != null) ...[
          InkWell(
            onTap: () => showMediaDetailsSheet(context, nowPlaying),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: MarqueeText(
                      text: nowPlaying.displayTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (nowPlaying.displaySubtitle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: MarqueeText(
                text: nowPlaying.displaySubtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxWidth: widget.maxWidth,
              ),
            ),

          const SizedBox(height: 8),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: InkWell(
                  onTap: session.playMethod == 'Transcode'
                      ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(l10n.playbackDetails),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.playMethod(session.playMethod == null
                                        ? l10n.none
                                        : UiUtils.getPlayMethodString(context, session.playMethod)),
                                  ),
                                  if (session.transcodeReasons != null &&
                                      session.transcodeReasons!.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.transcodeReasons,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...session.transcodeReasons!.map(
                                      (r) => Text('• $r'),
                                    ),
                                  ],
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(l10n.close),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: UiUtils.getPlayMethodColor(session.playMethod),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          UiUtils.getPlayMethodString(context, session.playMethod),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (session.playMethod == 'Transcode') ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (session.bitrate != null)
                InkWell(
                  onTap: _isLoadingMediaInfo
                      ? null
                      : () => _showMediaInfoDialog(nowPlaying.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          UiUtils.formatBitrate(session.bitrate!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (_isLoadingMediaInfo) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ] else ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ] else ...[
          Text(
            l10n.noMediaPlaying,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.useRemoteOrBrowse,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MessageButton(session: session),
        ],
      ],
    );
  }

  void _showMediaInfoDialog(String itemId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoadingMediaInfo = true);

    try {
      final info = await ref.read(playbackInfoProvider(itemId).future);

      if (!mounted) return;

      final mediaSources = info?['MediaSources'] as List?;
      if (mediaSources == null || mediaSources.isEmpty) {
        UiUtils.showErrorToast('Info', l10n.noMediaSourcesFound);
        return;
      }

      final source = mediaSources.first;
      final videoStream = (source['MediaStreams'] as List?)?.firstWhere(
        (s) => s['Type'] == 'Video',
        orElse: () => null,
      );
      final audioStream = (source['MediaStreams'] as List?)?.firstWhere(
        (s) => s['Type'] == 'Audio',
        orElse: () => null,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.mediaDetails),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(l10n.container, source['Container']),
                _infoRow(
                  l10n.size,
                  source['Size'] != null
                      ? '${(source['Size'] / 1024 / 1024).toStringAsFixed(1)} MB'
                      : null,
                ),
                const Divider(),
                if (videoStream != null) ...[
                  Text(
                    l10n.video,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _infoRow(l10n.codec, videoStream['Codec']),
                  _infoRow(
                    l10n.resolution,
                    '${videoStream['Width']}x${videoStream['Height']}',
                  ),
                  _infoRow(
                    l10n.bitrate,
                    videoStream['BitRate'] != null
                        ? UiUtils.formatBitrate(videoStream['BitRate'], forceKbps: true)
                        : null,
                  ),
                  _infoRow(
                    l10n.framerate,
                    videoStream['RealFrameRate']?.toString(),
                  ),
                  const Divider(),
                ],
                if (audioStream != null) ...[
                  Text(
                    l10n.audio,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _infoRow(l10n.codec, audioStream['Codec']),
                  _infoRow(l10n.language, audioStream['Language']),
                  _infoRow(l10n.channels, audioStream['Channels']?.toString()),
                  _infoRow(
                    l10n.bitrate,
                    audioStream['BitRate'] != null
                        ? UiUtils.formatBitrate(audioStream['BitRate'], forceKbps: true)
                        : null,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } catch (e) {
      logError('Failed to fetch media info: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMediaInfo = false);
      }
    }
  }

  Widget _infoRow(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.labelFormat(label),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

void showMediaDetailsSheet(BuildContext context, MediaInfo nowPlaying) {
    final isEpisode = nowPlaying.type == 'Episode';
    final mainItemId = nowPlaying.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final apiService = ref.read(apiServiceProvider);
            final bool isAudio = nowPlaying.type == 'Audio';
            
            // We don't need to fetch item details for the currently playing song
            final detailsAsync = isAudio 
                ? const AsyncValue<Map<String, dynamic>?>.data(null)
                : ref.watch(itemDetailsProvider(mainItemId));

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                final l10n = AppLocalizations.of(context)!;
                return detailsAsync.when(
                  data: (details) {
                    final overview = details?['Overview'] as String?;
                    final externalUrls =
                        (details?['ExternalUrls'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        [];
                    final people =
                        (details?['People'] as List?)
                            ?.map(
                              (p) => Person.fromJson(p as Map<String, dynamic>),
                            )
                            .toList() ??
                        [];

                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        const DragHandle(),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            details?['Name'] as String? ??
                                nowPlaying.displayTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: (isEpisode || isAudio)
                              ? _MediaDetailsTabs(
                                  scrollController: scrollController,
                                  tabs: isEpisode ? [
                                    (title: l10n.episodeCast, itemId: nowPlaying.id, showCastAndCrew: true),
                                    (title: l10n.seasonCast, itemId: nowPlaying.seasonId, showCastAndCrew: true),
                                    (title: l10n.showCast, itemId: nowPlaying.seriesId, showCastAndCrew: true),
                                  ] : [
                                    (title: l10n.album, itemId: nowPlaying.albumId, showCastAndCrew: false),
                                    (title: l10n.artist, itemId: nowPlaying.artistId, showCastAndCrew: false),
                                  ],
                                  apiService: apiService,
                                  onPersonTap: (id, name) => showPersonDetailSheet(context, id, name),
                                )
                              : _MediaDetailsContent(
                                  scrollController: scrollController,
                                  overview: overview,
                                  premiereDate: details?['PremiereDate'] as String?,
                                  externalUrls: externalUrls,
                                  people: people,
                                  apiService: apiService,
                                  onPersonTap: (id, name) => showPersonDetailSheet(context, id, name),
                                ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(l10n.errorLoadingCast(err.toString())),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required double size,
    required double width,
  }) {
    return Container(
      width: width,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.tv_rounded,
          size: size * 0.3,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

class _MediaDetailsContent extends StatefulWidget {
  final ScrollController scrollController;
  final String? overview;
  final String? premiereDate;
  final List<Map<String, dynamic>> externalUrls;
  final List<Person> people;
  final JellyfinApiService apiService;
  final void Function(String, String) onPersonTap;

  const _MediaDetailsContent({
    required this.scrollController,
    required this.overview,
    this.premiereDate,
    required this.externalUrls,
    required this.people,
    required this.apiService,
    required this.onPersonTap,
  });

  @override
  State<_MediaDetailsContent> createState() => _MediaDetailsContentState();
}

class _MediaDetailsContentState extends State<_MediaDetailsContent> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.premiereDate != null)
          Padding(
            padding: EdgeInsets.only(
              bottom: (widget.overview != null && widget.overview!.isNotEmpty) ? 8 : 0,
            ),
            child: _PremiereDateText(premiereDate: widget.premiereDate!),
          ),
        if (widget.overview != null && widget.overview!.isNotEmpty)
          OverviewSection(
            overview: widget.overview!,
          ),
        if (widget.externalUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          ExternalLinksSection(externalUrls: widget.externalUrls),
        ],
        if (widget.people.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.castAndCrew,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...widget.people.map(
            (person) => PersonRow(
              person: person,
              apiService: widget.apiService,
              onTap: widget.onPersonTap,
            ),
          ),
        ],
        if (widget.people.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(l10n.noCastInfo),
            ),
          ),
      ],
    );
  }
}

class _MediaDetailsTabs extends StatefulWidget {
  final ScrollController scrollController;
  final List<({String title, String? itemId, bool showCastAndCrew})> tabs;
  final JellyfinApiService apiService;
  final void Function(String, String) onPersonTap;

  const _MediaDetailsTabs({
    required this.scrollController,
    required this.tabs,
    required this.apiService,
    required this.onPersonTap,
  });

  @override
  State<_MediaDetailsTabs> createState() => _MediaDetailsTabsState();
}

class _MediaDetailsTabsState extends State<_MediaDetailsTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(_MediaDetailsTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _tabController.removeListener(_handleTabChange);
      _tabController.dispose();
      _tabController = TabController(length: widget.tabs.length, vsync: this);
      _tabController.addListener(_handleTabChange);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer(
      builder: (context, ref, child) {
        final selectedIndex = _tabController.index;
        final selectedTab = widget.tabs[selectedIndex];
        final selectedItemId = selectedTab.itemId;
        final showCastAndCrew = selectedTab.showCastAndCrew;

        final List<Person> people;
        final String? overview;
        final String? premiereDate;
        List<Map<String, dynamic>> externalUrls;
        final bool isLoading;
        final String? errorMessage;

        if (selectedItemId != null) {
          final detailsAsync = ref.watch(itemDetailsProvider(selectedItemId));
          people = detailsAsync.maybeWhen(
            data: (details) =>
                (details?['People'] as List?)
                    ?.map((p) => Person.fromJson(p as Map<String, dynamic>))
                    .toList() ??
                [],
            orElse: () => [],
          );
          overview = detailsAsync.maybeWhen(
            data: (details) => details?['Overview'] as String?,
            orElse: () => null,
          );
          premiereDate = detailsAsync.maybeWhen(
            data: (details) => details?['PremiereDate'] as String?,
            orElse: () => null,
          );
          externalUrls = detailsAsync.maybeWhen(
            data: (details) =>
                (details?['ExternalUrls'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [],
            orElse: () => [],
          );
          
          if (selectedTab.title == l10n.album) {
            externalUrls = externalUrls.where((link) {
              final name = (link['Name'] as String?)?.toLowerCase() ?? '';
              return !name.contains('artist');
            }).toList();
          }

          isLoading = detailsAsync.isLoading;
          errorMessage = detailsAsync.maybeWhen(
            error: (err, _) => err.toString(),
            orElse: () => null,
          );
        } else {
          people = [];
          overview = null;
          premiereDate = null;
          externalUrls = [];
          isLoading = false;
          errorMessage = null;
        }

        return CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                tabs: widget.tabs.map((t) => Tab(text: t.title)).toList(),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              SliverFillRemaining(
                child: Center(child: Text(l10n.errorLoadingCast(errorMessage))),
              )
            else ...[
              if (premiereDate != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _PremiereDateText(premiereDate: premiereDate),
                  ),
                ),
              if (overview != null && overview.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, premiereDate != null ? 8 : 16, 16, 0),
                    child: OverviewSection(
                      overview: overview,
                    ),
                  ),
                ),
              if (externalUrls.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ExternalLinksSection(externalUrls: externalUrls),
                  ),
                ),
              if (showCastAndCrew && people.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.castAndCrew,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => PersonRow(
                      person: people[index],
                      apiService: widget.apiService,
                      onTap: widget.onPersonTap,
                    ),
                    childCount: people.length,
                  ),
                ),
              ],
              if (showCastAndCrew && people.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Text(l10n.noCastInfo)),
                ),
            ],
          ],
        );
      },
    );
  }
}



class _PremiereDateText extends StatelessWidget {
  final String premiereDate;

  const _PremiereDateText({required this.premiereDate});

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(premiereDate);
    if (parsedDate == null) return const SizedBox.shrink();

    final formattedDate = DateFormat.yMMMd().format(parsedDate.toLocal());
    final l10n = AppLocalizations.of(context)!;

    return Text(
      '${l10n.premiered}: $formattedDate',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
    );
  }
}


