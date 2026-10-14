import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trickplay.dart';
import 'trickplay_fetch_mixin.dart';
import 'trickplay_tile_image.dart';

class TrickplayOverlay extends ConsumerStatefulWidget {
  final double seconds;
  final TrickplayInfo info;
  final String itemId;
  final String mediaSourceId;
  final double availableWidth;
  final double thumbCenter;

  const TrickplayOverlay({
    super.key,
    required this.seconds,
    required this.info,
    required this.itemId,
    required this.mediaSourceId,
    required this.availableWidth,
    required this.thumbCenter,
  });

  @override
  ConsumerState<TrickplayOverlay> createState() => _TrickplayOverlayState();
}

class _TrickplayOverlayState extends ConsumerState<TrickplayOverlay>
    with TrickplayFetchMixin<TrickplayOverlay> {
  double _displayedSeconds = 0;

  @override
  String get fetchItemId => widget.itemId;
  @override
  String get fetchMediaSourceId => widget.mediaSourceId;
  @override
  TrickplayInfo get fetchInfo => widget.info;

  @override
  void initState() {
    super.initState();
    _requestTile();
  }

  @override
  void didUpdateWidget(covariant TrickplayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds ||
        oldWidget.itemId != widget.itemId ||
        oldWidget.info != widget.info) {
      _requestTile();
    }
  }

  void _requestTile() {
    final targetPosition = widget.info.getTilePosition(widget.seconds);
    if (targetPosition == null) return;
    final targetIndex = targetPosition.tilesetIndex;
    if (imageData != null && loadedTilesetIndex == targetIndex) {
      // Tileset already loaded — just advance the displayed position.
      if (mounted) setState(() => _displayedSeconds = widget.seconds);
      return;
    }
    // Pass onLoaded so _displayedSeconds is set atomically with imageData.
    fetchTileset(targetIndex, onLoaded: () => _displayedSeconds = widget.seconds);
  }

  @override
  Widget build(BuildContext context) {
    final double halfWidth = widget.info.width / 2;
    final double leftEdge = widget.thumbCenter - halfWidth;
    final double rightEdge = widget.thumbCenter + halfWidth;

    double shift = 0;
    if (leftEdge < 0) {
      shift = -leftEdge;
    } else if (rightEdge > widget.availableWidth) {
      shift = widget.availableWidth - rightEdge;
    }

    final targetPosition = widget.info.getTilePosition(widget.seconds);
    if (targetPosition == null ||
        failedIndices.contains(targetPosition.tilesetIndex)) {
      return const SizedBox.shrink();
    }

    final displayPosition = widget.info.getTilePosition(_displayedSeconds);

    return Transform.translate(
      offset: Offset(shift, 0),
      child: Container(
        width: widget.info.width.toDouble(),
        height: widget.info.height.toDouble(),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (imageData != null && displayPosition != null)
                  ? TrickplayTileImage(
                      bytes: imageData!,
                      info: widget.info,
                      position: displayPosition,
                      fit: BoxFit.none,
                    )
                  : const SizedBox.shrink(),
            ),
            if (inFlightTilesetIndex != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
