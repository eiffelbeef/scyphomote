class TrickplayManifest {
  final Map<String, Map<String, TrickplayInfo>> sources;

  TrickplayManifest(this.sources);

  factory TrickplayManifest.fromJson(Map json) => TrickplayManifest({
        for (final source in json.entries)
          source.key: {
            for (final info in (source.value as Map).entries)
              info.key: TrickplayInfo.fromJson(info.value as Map),
          },
      });

  /// Returns the highest resolution TrickplayInfo for sourceId
  TrickplayInfo? getBestTilesInfo(String sourceId) {
    final manifest = sources[sourceId];
    if (manifest == null || manifest.isEmpty) return null;

    String? maxKey;
    int maxVal = -1;

    for (final key in manifest.keys) {
      final val = int.tryParse(key) ?? 0;
      if (val > maxVal) {
        maxVal = val;
        maxKey = key;
      }
    }

    return manifest[maxKey];
  }
}

class TrickplayInfo {
  final int width;
  final int height;
  final int tileWidth;
  final int tileHeight;
  final int thumbnailCount;
  final int interval;
  final int bandwidth;

  TrickplayInfo({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.thumbnailCount,
    required this.interval,
    required this.bandwidth,
  });

  factory TrickplayInfo.fromJson(Map json) => TrickplayInfo(
    width: json['Width'],
    height: json['Height'],
    tileWidth: json['TileWidth'],
    tileHeight: json['TileHeight'],
    thumbnailCount: json['ThumbnailCount'],
    interval: json['Interval'],
    bandwidth: json['Bandwidth'],
  );

  TilePosition? getTilePosition(double seconds) {
    // interval is n ms between thumbnails.
    if (interval <= 0 || thumbnailCount <= 0 || tileWidth <= 0 || tileHeight <= 0) return null;

    final totalIndex = (seconds * 1000 / interval).floor();
    if (totalIndex < 0 || totalIndex >= thumbnailCount) return null;

    final tilesPerImage = tileWidth * tileHeight;
    final tilesIndexInImage = totalIndex % tilesPerImage;
    final tilesetIndex = totalIndex ~/ tilesPerImage;
    final xIndex = tilesIndexInImage % tileWidth;
    final yIndex = tilesIndexInImage ~/ tileWidth;

    return TilePosition(
      tilesetIndex: tilesetIndex,
      x: xIndex * width,
      y: yIndex * height,
    );
  }

  // Loosen equality checks for layout changes
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
      (other is TrickplayInfo &&
        other.width == width &&
        other.height == height &&
        other.tileWidth == tileWidth &&
        other.tileHeight == tileHeight &&
        other.interval == interval);
  }

    @override
    int get hashCode => Object.hash(width, height, tileWidth, tileHeight, interval);
}

class TilePosition {
  final int tilesetIndex;
  final int x;
  final int y;

  TilePosition({required this.tilesetIndex, required this.x, required this.y});
}
