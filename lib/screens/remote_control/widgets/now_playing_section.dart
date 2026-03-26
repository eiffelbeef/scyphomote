import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/marquee_text.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/remote_providers.dart';
import '../../../models/media_info.dart';
import '../../../models/media_segment.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/logger.dart';
import '../../../utils/ui_utils.dart';
import 'remote_button.dart';
import '../../../../l10n/app_localizations.dart';

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: artworkSize,
                  height: artworkSize,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      _buildPlaceholder(context, size: artworkSize),
                  errorWidget: (context, url, error) =>
                      _buildPlaceholder(context, size: artworkSize),
                ),
              )
            else
              _buildPlaceholder(context, size: artworkSize),

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

                      if (activeSegment.id.isEmpty) {
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
                          icon: const Icon(Icons.skip_next),
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
            onTap: nowPlaying.isVideo
                ? () => _showCastAndCrew(nowPlaying.seriesId ?? nowPlaying.id)
                : null,
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
                      maxWidth: widget.maxWidth,
                    ),
                  ),
                  if (nowPlaying.isVideo)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.info_outline,
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
            InkWell(
              onTap: nowPlaying.type == 'Episode'
                  ? () => _showCastAndCrew(nowPlaying.id)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: MarqueeText(
                        text: nowPlaying.displaySubtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxWidth: widget.maxWidth,
                      ),
                    ),
                    if (nowPlaying.type == 'Episode')
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.playbackDetails),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.playMethod(session.playMethod ?? l10n.none),
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
                  },
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
                            color: session.playMethod == 'Transcode'
                                ? Colors.orange
                                : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.playMethod == 'Transcode'
                              ? l10n.transcoding
                              : l10n.directPlay,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
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
                          '${(session.bitrate! / 1000000).toStringAsFixed(1)} Mbps',
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
                            Icons.info_outline,
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
                        ? '${(videoStream['BitRate'] / 1000).toStringAsFixed(1)} kbps'
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
                        ? '${(audioStream['BitRate'] / 1000).toStringAsFixed(1)} kbps'
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

  void _showCastAndCrew(String itemId) async {
    final nowPlaying = widget.session.nowPlaying;
    if (nowPlaying == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final apiService = ref.read(apiServiceProvider);
            final detailsAsync = ref.watch(itemDetailsProvider(itemId));

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                final l10n = AppLocalizations.of(context)!;
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        l10n.castAndCrew,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: detailsAsync.when(
                        data: (details) {
                          final people = (details != null
                              ? (details['People'] as List?)
                                        ?.map(
                                          (p) => Person.fromJson(
                                            p as Map<String, dynamic>,
                                          ),
                                        )
                                        .toList() ??
                                    []
                              : []);

                          if (people.isEmpty) {
                            return Center(child: Text(l10n.noCastInfo));
                          }

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: people.length,
                            itemBuilder: (context, index) {
                              final person = people[index];
                              final imageUrl = person.primaryImageTag != null
                                  ? apiService.getArtworkUrl(
                                      person.id,
                                      'Primary',
                                      maxWidth: 200,
                                      tag: person.primaryImageTag,
                                    )
                                  : null;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              width: 80,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    width: 80,
                                                    height: 120,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 32,
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
                                                    width: 80,
                                                    height: 120,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 32,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              width: 80,
                                              height: 120,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons.person,
                                                size: 32,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            person.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          if (person.role != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              person.role!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text(l10n.errorLoadingCast(err.toString())),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, {double size = 300}) {
    return Container(
      width: size,
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
}
