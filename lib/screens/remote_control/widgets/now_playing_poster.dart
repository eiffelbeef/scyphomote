import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants.dart';
import '../../../models/session.dart';
import '../../../models/trickplay.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/ui_utils.dart';
import '../../../widgets/safe_network_image.dart';
import 'live_trickplay_badge.dart';
import 'trickplay_fetch_mixin.dart';
import 'trickplay_tile_image.dart';

class NowPlayingPoster extends ConsumerStatefulWidget {
  final Session session;
  final String? imageUrl;
  final double artworkSize;
  final double? maxWidth;

  const NowPlayingPoster({
    super.key,
    required this.session,
    required this.imageUrl,
    required this.artworkSize,
    this.maxWidth,
  });

  @override
  ConsumerState<NowPlayingPoster> createState() => _NowPlayingPosterState();
}

class _NowPlayingPosterState extends ConsumerState<NowPlayingPoster>
    with TrickplayFetchMixin<NowPlayingPoster> {
  static const _borderRadius = BorderRadius.all(Radius.circular(12));

  TilePosition? _currentTilePosition;
  Timer? _tickerTimer;

  TrickplayInfo? get _trickplayInfo {
    final sourceId = widget.session.mediaSourceId;
    if (sourceId == null) return null;
    return widget.session.nowPlaying?.trickplay?.getBestTilesInfo(sourceId);
  }

  bool get _isLiveActive =>
      _trickplayInfo != null &&
      ref.read(settingsProvider).liveTrickplayEnabled;

  @override
  String get fetchItemId => widget.session.nowPlaying!.id;

  @override
  String get fetchMediaSourceId => widget.session.mediaSourceId!;

  @override
  TrickplayInfo get fetchInfo => _trickplayInfo!;

  @override
  void initState() {
    super.initState();
    if (_isLiveActive && AppConstants.isInForeground) {
      _syncPositionAndFetch();
    }
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant NowPlayingPoster oldWidget) {
    super.didUpdateWidget(oldWidget);

    final itemChanged =
        oldWidget.session.nowPlaying?.id != widget.session.nowPlaying?.id ||
        oldWidget.session.mediaSourceId != widget.session.mediaSourceId;

    if (itemChanged) {
      resetFetchState();
      _currentTilePosition = null;
    }

    final playStateChanged =
        oldWidget.session.isPlaying != widget.session.isPlaying;
    final posChanged =
        oldWidget.session.positionTicks != widget.session.positionTicks;

    if (_isLiveActive && (itemChanged || playStateChanged || posChanged)) {
      _syncPositionAndFetch();
    }

    if (itemChanged || playStateChanged) {
      _updateTicker();
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _updateTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    if (_isLiveActive && widget.session.isPlaying) {
      _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !AppConstants.isInForeground) return;
        _syncPositionAndFetch();
      });
    }
  }

  double get _currentSeconds =>
      widget.session.estimatedPositionTicks / 10000000.0;

  void _syncPositionAndFetch() {
    if (!_isLiveActive || !AppConstants.isInForeground) return;

    final info = _trickplayInfo;
    if (info == null) return;

    final targetPos = info.getTilePosition(_currentSeconds);
    if (targetPos == null) return;

    if (loadedTilesetIndex == targetPos.tilesetIndex) {
      if (_currentTilePosition?.x != targetPos.x ||
          _currentTilePosition?.y != targetPos.y) {
        _currentTilePosition = targetPos;
        if (mounted && imageData != null) setState(() {});
      }
    } else {
      fetchTileset(targetPos.tilesetIndex, onLoaded: () {
        _currentTilePosition = targetPos;
      });
    }
  }

  Widget _buildPlaceholder({
    required BuildContext context,
    required double size,
    required double width,
  }) {
    return Container(
      width: width,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: _borderRadius,
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

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      settingsProvider.select((s) => s.liveTrickplayEnabled),
      (prev, next) {
        if (next) {
          _syncPositionAndFetch();
        }
        _updateTicker();
      },
    );

    final nowPlaying = widget.session.nowPlaying;
    final trickplayInfo = _trickplayInfo;
    final hasTrickplay = trickplayInfo != null;
    final liveTrickplayEnabled =
        ref.watch(settingsProvider.select((s) => s.liveTrickplayEnabled));
    final isLiveActive = hasTrickplay && liveTrickplayEnabled;

    final double fallbackRatio =
        UiUtils.getFallbackAspectRatio(nowPlaying?.type);
    final double normalRatio =
        nowPlaying?.primaryImageAspectRatio ?? fallbackRatio;
    final double aspectRatio = (isLiveActive && trickplayInfo.height > 0)
        ? (trickplayInfo.width / trickplayInfo.height)
        : normalRatio;

    double finalWidth = widget.artworkSize * aspectRatio;
    double finalHeight = widget.artworkSize;

    if (widget.maxWidth != null && finalWidth > widget.maxWidth!) {
      finalWidth = widget.maxWidth!;
      finalHeight = finalWidth / aspectRatio;
    }

    Widget content;
    if (isLiveActive && imageData != null && _currentTilePosition != null) {
      content = ClipRRect(
        borderRadius: _borderRadius,
        child: SizedBox(
          width: finalWidth,
          height: finalHeight,
          child: TrickplayTileImage(
            bytes: imageData!,
            info: trickplayInfo,
            position: _currentTilePosition!,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      content = SafeNetworkImage(
        imageUrl: widget.imageUrl,
        fallbackWidget: _buildPlaceholder(
          context: context,
          size: finalHeight,
          width: finalWidth,
        ),
        width: finalWidth,
        height: finalHeight,
        borderRadius: _borderRadius,
      );
    }

    return Stack(
      children: [
        content,
        if (nowPlaying != null)
          Positioned(
            top: 8,
            right: 8,
            child: LiveTrickplayBadge(
              isLive: liveTrickplayEnabled,
              hasTrickplay: hasTrickplay,
              onToggle: () {
                ref.read(settingsProvider.notifier).toggleLiveTrickplay();
              },
            ),
          ),
      ],
    );
  }
}
