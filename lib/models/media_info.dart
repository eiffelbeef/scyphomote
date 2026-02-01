import 'trickplay.dart';

class Person {
  final String id;
  final String name;
  final String? role;
  final String? type;
  final String? primaryImageTag;

  Person({
    required this.id,
    required this.name,
    this.role,
    this.type,
    this.primaryImageTag,
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['Id'] as String,
    name: json['Name'] as String,
    role: json['Role'] as String?,
    type: json['Type'] as String?,
    primaryImageTag: json['PrimaryImageTag'] as String?,
  );
}

class MediaInfo {
  final String id;
  final String name;
  final String type;
  final String? seriesName;
  final int? season;
  final int? episode;
  final String? album;
  final String? albumArtist;
  final String? artist;
  final int? track;
  final String? albumId;
  final int? runTimeTicks;
  final bool hasLyrics;
  final bool hasSubtitles;
  final int? productionYear;
  final TrickplayManifest? trickplay;
  final List<Person>? people;

  MediaInfo({
    required this.id,
    required this.name,
    required this.type,
    this.seriesName,
    this.season,
    this.episode,
    this.album,
    this.albumArtist,
    this.artist,
    this.track,
    this.albumId,
    this.runTimeTicks,
    this.hasLyrics = false,
    this.hasSubtitles = false,
    this.productionYear,
    this.trickplay,
    this.people,
  });

  int? get durationSeconds =>
      runTimeTicks != null ? (runTimeTicks! / 10000000).floor() : null;

  bool get isVideo =>
      ['Movie', 'Episode', 'Video', 'MusicVideo'].contains(type);

  String get displayTitle {
    if (type == 'Episode' && seriesName != null) {
      final s = season?.toString().padLeft(2, '0') ?? '0';
      final e = episode?.toString().padLeft(2, '0') ?? '0';
      return '$seriesName - S${s}E$e';
    }
    return (type == 'Audio' && artist != null) ? '$artist - $name' : name;
  }

  String? get displaySubtitle {
    if (type == 'Episode') {
      return name;
    }
    if (type == 'Audio' && album != null) {
      return album;
    }
    if (type == 'Movie' && productionYear != null) {
      return productionYear.toString();
    }
    return null;
  }

  String get artworkId => (type == 'Audio' && albumId != null) ? albumId! : id;

  factory MediaInfo.fromJson(Map<String, dynamic> json) => MediaInfo(
    id: json['Id'],
    name: json['Name'],
    type: json['Type'],
    seriesName: json['SeriesName'],
    season: json['ParentIndexNumber'],
    episode: json['IndexNumber'],
    album: json['Album'],
    albumArtist: json['AlbumArtist'],
    artist: (json['Artists'] as List?)?.firstOrNull,
    track: json['IndexNumber'],
    albumId: json['AlbumId'],
    runTimeTicks: json['RunTimeTicks'],
    hasLyrics: json['HasLyrics'] ?? false,
    hasSubtitles: json['HasSubtitles'] ?? false,
    productionYear: json['ProductionYear'],
    trickplay: json['Trickplay'] != null
        ? TrickplayManifest.fromJson(json['Trickplay'])
        : null,
    people: (json['People'] as List?)
        ?.map((p) => Person.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}
