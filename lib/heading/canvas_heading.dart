import 'package:characters/characters.dart';

enum CanvasHeadingSize { small, medium, large, extraLarge }

extension CanvasHeadingSizeValue on CanvasHeadingSize {
  double get fontSize => switch (this) {
    CanvasHeadingSize.small => 20,
    CanvasHeadingSize.medium => 28,
    CanvasHeadingSize.large => 40,
    CanvasHeadingSize.extraLarge => 56,
  };
}

enum CanvasHeadingBackground {
  transparent,
  white,
  yellow,
  blue,
  green,
  pink,
  purple,
}

class CanvasHeading {
  const CanvasHeading({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    required this.size,
    required this.background,
    required this.createdAt,
    required this.modifiedAt,
  });

  static const maximumTextCharacters = 80;

  final String id;
  final double x;
  final double y;
  final String text;
  final CanvasHeadingSize size;
  final CanvasHeadingBackground background;
  final DateTime createdAt;
  final DateTime modifiedAt;

  double get fontSize => size.fontSize;

  CanvasHeading copyWith({
    double? x,
    double? y,
    String? text,
    CanvasHeadingSize? size,
    CanvasHeadingBackground? background,
    DateTime? modifiedAt,
  }) {
    return CanvasHeading(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      text: text ?? this.text,
      size: size ?? this.size,
      background: background ?? this.background,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'text': text,
    'size': size.name,
    'background': background.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
  };

  factory CanvasHeading.fromJson(Map<String, dynamic> json) {
    return CanvasHeading(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      text: json['text'] as String,
      size: CanvasHeadingSize.values.byName(json['size'] as String),
      background: CanvasHeadingBackground.values.byName(
        json['background'] as String,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }

  static String? normalizeText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return null;
    }
    if (RegExp(r'[\r\n\u2028\u2029]').hasMatch(text) ||
        text.characters.length > maximumTextCharacters) {
      throw const FormatException(
        'A heading must be single-line and at most 80 characters.',
      );
    }
    return text;
  }
}
