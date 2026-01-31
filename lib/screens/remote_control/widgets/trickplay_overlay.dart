import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';
import '../../../providers/auth_provider.dart';
import '../../../models/trickplay.dart';

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

class _TrickplayOverlayState extends ConsumerState<TrickplayOverlay> {
  Uint8List? _imageData;
  double _displayedSeconds = 0;
  int? _loadedTilesetIndex;
  int? _inFlightTilesetIndex;
  final Set<int> _failedIndices = {};

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  @override
  void didUpdateWidget(covariant TrickplayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds ||
        oldWidget.itemId != widget.itemId ||
        oldWidget.info != widget.info) {
      _fetchImage();
    }
  }

  Future<void> _fetchImage() async {
    final targetPosition = widget.info.getTilePosition(widget.seconds);
    if (targetPosition == null) return;

    final targetIndex = targetPosition.tilesetIndex;

    if (_imageData != null && _loadedTilesetIndex == targetIndex) {
      if (mounted) setState(() => _displayedSeconds = widget.seconds);
      return;
    }

    if (_inFlightTilesetIndex == targetIndex ||
        _failedIndices.contains(targetIndex)) {
      return;
    }

    try {
      _inFlightTilesetIndex = targetIndex;
      final user = ref.read(authProvider).currentUser;
      if (user == null) return;

      final data = await ref
          .read(apiServiceProvider)
          .getTrickplayTileImage(
            widget.itemId,
            widget.mediaSourceId,
            widget.info.width,
            targetIndex,
          );

      if (mounted) {
        if (data != null) {
          setState(() {
            _imageData = data;
            _loadedTilesetIndex = targetIndex;
            _displayedSeconds = widget.seconds;
            _failedIndices.remove(targetIndex);
          });
        } else {
          setState(() => _failedIndices.add(targetIndex));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _failedIndices.add(targetIndex));
    } finally {
      _inFlightTilesetIndex = null;
    }
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
    if (targetPosition == null || _failedIndices.contains(targetPosition.tilesetIndex)) {
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
              child: (_imageData != null && displayPosition != null)
                  ? Image.memory(
                      _imageData!,
                      fit: BoxFit.none,
                      alignment: _getAlignment(displayPosition),
                      gaplessPlayback: true,
                    )
                  : const SizedBox.shrink(),
            ),
            if (_inFlightTilesetIndex != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
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

  Alignment _getAlignment(TilePosition pos) {
    final double maxX = (widget.info.width * (widget.info.tileWidth - 1))
        .toDouble();
    final double maxY = (widget.info.height * (widget.info.tileHeight - 1))
        .toDouble();
    return Alignment(
      maxX > 0 ? -1.0 + 2.0 * (pos.x / maxX) : 0.0,
      maxY > 0 ? -1.0 + 2.0 * (pos.y / maxY) : 0.0,
    );
  }
}
