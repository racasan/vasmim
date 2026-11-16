import 'package:characters/characters.dart';

const _unchangedBoardImageCaption = Object();

class BoardImage {
  BoardImage({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.assetPath,
    required this.originalFileName,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.createdAt,
    required this.modifiedAt,
    String? caption,
  }) : caption = normalizeCaption(caption);

  static const maximumCaptionCharacters = 80;

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String assetPath;
  final String originalFileName;
  final String? caption;
  final int pixelWidth;
  final int pixelHeight;
  final DateTime createdAt;
  final DateTime modifiedAt;

  bool get isGif => assetPath.toLowerCase().endsWith('.gif');

  BoardImage copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    DateTime? modifiedAt,
    Object? caption = _unchangedBoardImageCaption,
  }) {
    return BoardImage(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      assetPath: assetPath,
      originalFileName: originalFileName,
      caption: identical(caption, _unchangedBoardImageCaption)
          ? this.caption
          : caption as String?,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'assetPath': assetPath,
      'originalFileName': originalFileName,
      'pixelWidth': pixelWidth,
      'pixelHeight': pixelHeight,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    };
    final caption = this.caption;
    if (caption != null) {
      json['caption'] = caption;
    }
    return json;
  }

  factory BoardImage.fromJson(
    Map<String, dynamic> json, {
    bool readCaption = true,
  }) {
    return BoardImage(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      assetPath: json['assetPath'] as String,
      originalFileName: json['originalFileName'] as String,
      caption: readCaption ? _captionFromJson(json) : null,
      pixelWidth: json['pixelWidth'] as int,
      pixelHeight: json['pixelHeight'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }

  static String? normalizeCaption(String? rawCaption) {
    if (rawCaption == null) {
      return null;
    }
    final caption = rawCaption.trim();
    if (caption.isEmpty) {
      return null;
    }
    if (RegExp(r'[\r\n\u2028\u2029]').hasMatch(caption) ||
        caption.characters.length > maximumCaptionCharacters) {
      throw const FormatException(
        'An image caption must be single-line and at most 80 characters.',
      );
    }
    return caption;
  }

  static String? _captionFromJson(Map<String, dynamic> json) {
    final rawCaption = json['caption'];
    if (rawCaption == null) {
      return null;
    }
    if (rawCaption is! String) {
      throw const FormatException('An image caption must be a string.');
    }
    final caption = normalizeCaption(rawCaption);
    if (caption != rawCaption) {
      throw const FormatException(
        'An image caption must be trimmed and non-empty.',
      );
    }
    return caption;
  }
}
