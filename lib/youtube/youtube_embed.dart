class YouTubeEmbed {
  const YouTubeEmbed({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.originalUrl,
    required this.videoId,
    required this.createdAt,
    required this.modifiedAt,
    this.thumbnailAssetPath,
  });

  static const defaultWidth = 300.0;
  static const defaultHeight = 168.0;

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String originalUrl;
  final String videoId;
  final String? thumbnailAssetPath;
  final DateTime createdAt;
  final DateTime modifiedAt;

  YouTubeEmbed copyWith({
    String? id,
    double? x,
    double? y,
    DateTime? modifiedAt,
    String? thumbnailAssetPath,
  }) => YouTubeEmbed(
    id: id ?? this.id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width,
    height: height,
    originalUrl: originalUrl,
    videoId: videoId,
    thumbnailAssetPath: thumbnailAssetPath ?? this.thumbnailAssetPath,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'originalUrl': originalUrl,
      'videoId': videoId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    };
    if (thumbnailAssetPath case final path?) {
      json['thumbnailAssetPath'] = path;
    }
    return json;
  }

  factory YouTubeEmbed.fromJson(Map<String, dynamic> json) => YouTubeEmbed(
    id: json['id'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    originalUrl: json['originalUrl'] as String,
    videoId: json['videoId'] as String,
    thumbnailAssetPath: json['thumbnailAssetPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
  );
}
