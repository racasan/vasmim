class Scene {
  const Scene({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.zoom,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final double zoom;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Scene copyWith({String? name, DateTime? modifiedAt}) {
    return Scene(
      id: id,
      name: name ?? this.name,
      x: x,
      y: y,
      zoom: zoom,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'name': name,
      'x': x,
      'y': y,
      'zoom': zoom,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    };
  }

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'] as String,
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      zoom: (json['zoom'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }
}
