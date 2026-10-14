import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../models/trickplay.dart';

/// Renders a single trickplay thumbnail extracted from a sprite sheet.
class TrickplayTileImage extends StatelessWidget {
  final Uint8List bytes;
  final TrickplayInfo info;
  final TilePosition position;
  final BoxFit fit;

  const TrickplayTileImage({
    super.key,
    required this.bytes,
    required this.info,
    required this.position,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final double maxX = (info.width * (info.tileWidth - 1)).toDouble();
    final double maxY = (info.height * (info.tileHeight - 1)).toDouble();
    final alignment = Alignment(
      maxX > 0 ? -1.0 + 2.0 * (position.x / maxX) : 0.0,
      maxY > 0 ? -1.0 + 2.0 * (position.y / maxY) : 0.0,
    );

    final tileBox = SizedBox(
      width: info.width.toDouble(),
      height: info.height.toDouble(),
      child: ClipRect(
        child: Image.memory(
          bytes,
          fit: BoxFit.none,
          alignment: alignment,
          gaplessPlayback: true,
        ),
      ),
    );

    if (fit == BoxFit.none) {
      return tileBox;
    }

    return FittedBox(
      fit: fit,
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      child: tileBox,
    );
  }
}
