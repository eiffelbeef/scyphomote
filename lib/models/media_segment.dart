class MediaSegment {
  final String id;
  final String itemId;
  final String type;
  final int startTicks;
  final int endTicks;

  MediaSegment({
    required this.id,
    required this.itemId,
    required this.type,
    required this.startTicks,
    required this.endTicks,
  });

  factory MediaSegment.fromJson(Map<String, dynamic> json) {
    return MediaSegment(
      id: json['Id'] as String,
      itemId: json['ItemId'] as String,
      type: json['Type'] as String,
      startTicks: json['StartTicks'] as int? ?? 0,
      endTicks: json['EndTicks'] as int? ?? 0,
    );
  }

  double get startSeconds => startTicks / 10000000;
  double get endSeconds => endTicks / 10000000;

  bool isActive(int positionSeconds) {
    return positionSeconds >= startSeconds && positionSeconds < endSeconds;
  }
}
