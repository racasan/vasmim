import 'package:characters/characters.dart';

class ShapeLayer {
  ShapeLayer({
    required this.id,
    required this.name,
    required List<String> shapeIds,
    required this.createdAt,
    required this.modifiedAt,
    this.isVisible = true,
    this.opacity = 1,
  }) : shapeIds = List.unmodifiable(shapeIds);

  static const maximumNameCharacters = 80;
  static const supportedOpacities = <double>[0.25, 0.5, 0.75, 1];

  final String id;
  final String name;
  final List<String> shapeIds;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isVisible;
  final double opacity;

  factory ShapeLayer.defaultForBoard({
    required String boardId,
    required Iterable<String> shapeIds,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) {
    return ShapeLayer(
      id: 'shape-layer-$boardId',
      name: 'Shape layer 1',
      shapeIds: shapeIds.toList(),
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
  }

  static String normalizeName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.characters.length > maximumNameCharacters ||
        RegExp(r'[\r\n\u2028\u2029]').hasMatch(normalized)) {
      throw const FormatException(
        'A shape layer name must be single-line and between 1 and 80 characters.',
      );
    }
    return normalized;
  }

  ShapeLayer copyWith({
    String? name,
    List<String>? shapeIds,
    DateTime? modifiedAt,
    bool? isVisible,
    double? opacity,
  }) {
    return ShapeLayer(
      id: id,
      name: name ?? this.name,
      shapeIds: shapeIds ?? this.shapeIds,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'shapeIds': shapeIds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'isVisible': isVisible,
    'opacity': opacity,
  };

  factory ShapeLayer.fromJson(
    Map<String, dynamic> json, {
    bool readVisibility = true,
    bool readOpacity = true,
  }) {
    return ShapeLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      shapeIds: [for (final value in json['shapeIds'] as List) value as String],
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
      isVisible: readVisibility ? json['isVisible'] as bool : true,
      opacity: readOpacity ? (json['opacity'] as num).toDouble() : 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShapeLayer &&
      other.id == id &&
      other.name == name &&
      _sameStrings(other.shapeIds, shapeIds) &&
      other.createdAt == createdAt &&
      other.modifiedAt == modifiedAt &&
      other.isVisible == isVisible &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(shapeIds),
    createdAt,
    modifiedAt,
    isVisible,
    opacity,
  );

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
