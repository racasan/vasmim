class BoardGroup {
  BoardGroup({
    required this.id,
    required Iterable<String> memberIds,
    required this.isVisible,
    this.name,
    required this.createdAt,
    required this.modifiedAt,
  }) : memberIds = List.unmodifiable(memberIds);

  final String id;
  final List<String> memberIds;
  final bool isVisible;
  final String? name;
  final DateTime createdAt;
  final DateTime modifiedAt;

  BoardGroup copyWith({
    Iterable<String>? memberIds,
    bool? isVisible,
    String? name,
    bool clearName = false,
    DateTime? modifiedAt,
  }) {
    return BoardGroup(
      id: id,
      memberIds: memberIds ?? this.memberIds,
      isVisible: isVisible ?? this.isVisible,
      name: clearName ? null : name ?? this.name,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'memberIds': memberIds,
    'isVisible': isVisible,
    'name': ?name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
  };

  factory BoardGroup.fromJson(
    Map<String, dynamic> json, {
    bool readName = true,
  }) {
    final memberIds = json['memberIds'];
    if (memberIds is! List) {
      throw const FormatException('Group member IDs must be a list.');
    }
    return BoardGroup(
      id: json['id'] as String,
      memberIds: memberIds.cast<String>(),
      isVisible: json['isVisible'] as bool,
      name: readName ? json['name'] as String? : null,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }
}
