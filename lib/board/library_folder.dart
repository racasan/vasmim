import 'package:characters/characters.dart';

class LibraryFolder {
  LibraryFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
  }) {
    validateName(name);
  }

  static const maximumNameCharacters = 80;

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;

  LibraryFolder copyWith({String? name, DateTime? modifiedAt}) => LibraryFolder(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
  );

  static String normalizeName(String value) {
    final name = value.trim();
    validateName(name);
    return name;
  }

  static void validateName(String name) {
    if (name.isEmpty ||
        name != name.trim() ||
        name.characters.length > maximumNameCharacters ||
        RegExp(r'[\r\n\u2028\u2029]').hasMatch(name)) {
      throw const FormatException(
        'Folder names must be trimmed, single-line, non-empty, and at most 80 characters.',
      );
    }
  }
}

class LibraryFolderState {
  LibraryFolderState({
    Iterable<LibraryFolder> folders = const [],
    Map<String, String> boardFolderIds = const {},
  }) : folders = List.unmodifiable(folders),
       boardFolderIds = Map.unmodifiable(boardFolderIds);

  final List<LibraryFolder> folders;
  final Map<String, String> boardFolderIds;
}
