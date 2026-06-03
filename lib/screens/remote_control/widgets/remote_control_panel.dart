import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/playback_provider.dart';
import 'now_playing_section.dart';
import 'playback_controls_section.dart';
import 'basic_controls_row.dart';

class RemoteControlPanel extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final bool showBottomButtons;
  final bool isDrawer;
  final ValueListenable<double>? dragExtent;
  final Widget? miniControls;
  final double minExtent;

  const RemoteControlPanel({
    super.key,
    this.scrollController,
    this.showBottomButtons = true,
    this.isDrawer = false,
    this.dragExtent,
    this.miniControls,
    this.minExtent = 0.12,
  });

  @override
  ConsumerState<RemoteControlPanel> createState() => _RemoteControlPanelState();
}

class _RemoteControlPanelState extends ConsumerState<RemoteControlPanel> {
  double? _dragVolume;
  double? _optimisticSeek;
  double? _optimisticVolume;
  int? _lastServerSeek;
  int? _lastServerVolume;

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.selectedSession;

    if (session == null) {
      return const Center(child: Text("No session selected"));
    }

    final nowPlaying = session.nowPlaying;
    final playState = session.playState;
    final isPaused = playState?.isPaused ?? true;
    final duration = nowPlaying?.durationSeconds ?? 0;

    final currentServerSeek = playState?.positionSeconds ?? 0;
    final currentServerVolume = playState?.volumeLevel ?? 0;

    if (_optimisticSeek != null) {
      if (_lastServerSeek != null && currentServerSeek != _lastServerSeek) {
        _optimisticSeek = null;
      }
    }
    _lastServerSeek = currentServerSeek;

    if (_optimisticVolume != null) {
      if (_lastServerVolume != null && currentServerVolume != _lastServerVolume) {
        _optimisticVolume = null;
      }
    }
    _lastServerVolume = currentServerVolume;

    final currentVolume = _dragVolume ?? _optimisticVolume ?? currentServerVolume.toDouble();

    String? imageUrl;
    if (nowPlaying != null) {
      final apiService = ref.read(apiServiceProvider);
      imageUrl = apiService.getArtworkUrl(
        nowPlaying.artworkId,
        'Primary',
        maxWidth: 500,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedHeights = 60 + 80 + 40 + 100 + 70 + 60 + 80 + 150;
        final availableForArtwork = constraints.maxHeight - fixedHeights;
        final artworkSize = availableForArtwork.clamp(120.0, 500.0);

        final child = Padding(
          padding: EdgeInsets.fromLTRB(
            24.0,
            16.0,
            24.0,
            16.0 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisAlignment: widget.scrollController == null
                ? MainAxisAlignment.spaceEvenly
                : MainAxisAlignment.start,
            children: [
              if (widget.isDrawer) ...[
                BasicControlsRow(session: session, isPaused: isPaused),
                const SizedBox(height: 16),
              ],
              NowPlayingSection(
                session: session,
                imageUrl: imageUrl,
                artworkSize: artworkSize,
                maxWidth: constraints.maxWidth - 48.0,
              ),
              if (widget.scrollController != null) const SizedBox(height: 24),
              PlaybackControlsSection(
                session: session,
                currentPositionSeconds: (_optimisticSeek ?? currentServerSeek).toInt(),
                durationSeconds: duration,
                isPaused: isPaused,
                currentVolume: currentVolume,
                availableWidth: constraints.maxWidth - 48.0,
                showBottomButtons: widget.showBottomButtons,
                showBasicControls: !widget.isDrawer,
                onSeek: (value) {
                  setState(() {
                    _optimisticSeek = value;
                  });
                },
                onSeekEnd: (value) {
                  HapticFeedback.lightImpact();
                  ref.read(playbackProvider.notifier).seek(value.toInt());
                  setState(() {
                    _optimisticSeek = value;
                  });
                },
                onVolumeChanged: (value) => setState(() => _dragVolume = value),
                onVolumeChangeEnd: (value) {
                  HapticFeedback.lightImpact();
                  ref.read(playbackProvider.notifier).setVolume(value.toInt());
                  setState(() {
                    _dragVolume = null;
                    _optimisticVolume = value;
                  });
                },
              ),
            ],
          ),
        );

        Widget content = child;
        if (widget.dragExtent != null) {
          content = ValueListenableBuilder<double>(
            valueListenable: widget.dragExtent!,
            builder: (context, extent, _) {
              final isCollapsed = extent <= widget.minExtent + 0.08;
              
              if (widget.miniControls != null) {
                return Stack(
                  children: [
                    Opacity(
                      opacity: ((extent - widget.minExtent) / (0.9 - widget.minExtent)).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: isCollapsed,
                        child: child,
                      ),
                    ),
                    if (extent < widget.minExtent + 0.28)
                      Opacity(
                        opacity: (1 - ((extent - widget.minExtent) / 0.1)).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: !isCollapsed,
                          child: widget.miniControls!,
                        ),
                      ),
                  ],
                );
              }

              return IgnorePointer(
                ignoring: isCollapsed,
                child: child,
              );
            },
          );
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: CustomScrollView(
            controller: widget.scrollController,
            physics: widget.scrollController == null
                ? const AlwaysScrollableScrollPhysics()
                : null,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: content,
              ),
            ],
          ),
        );
      },
    );
  }
}
