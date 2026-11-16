class Connector {
  const Connector({
    required this.id,
    required this.objectAId,
    required this.objectBId,
    this.label,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String id;
  final String objectAId;
  final String objectBId;
  final String? label;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Connector copyWith({
    String? label,
    bool clearLabel = false,
    DateTime? modifiedAt,
  }) {
    return Connector(
      id: id,
      objectAId: objectAId,
      objectBId: objectBId,
      label: clearLabel ? null : label ?? this.label,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'objectAId': objectAId,
      'objectBId': objectBId,
      'label': ?label,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    };
  }

  factory Connector.fromJson(
    Map<String, dynamic> json, {
    bool legacyNoteEndpoints = false,
    bool readLabel = true,
  }) {
    return Connector(
      id: json['id'] as String,
      objectAId: json[legacyNoteEndpoints ? 'noteAId' : 'objectAId'] as String,
      objectBId: json[legacyNoteEndpoints ? 'noteBId' : 'objectBId'] as String,
      label: readLabel ? json['label'] as String? : null,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }
}
