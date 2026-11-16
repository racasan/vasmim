import 'package:crypto/crypto.dart';

const backupManifestFileName = 'backup_manifest.json';
const backupManifestFormatVersion = 1;

class BackupManifest {
  BackupManifest({
    required this.createdAt,
    required List<BackupManifestEntry> entries,
  }) : entries = List.unmodifiable(entries) {
    _validate(createdAt, this.entries);
  }

  final DateTime createdAt;
  final List<BackupManifestEntry> entries;

  Map<String, Object> toJson() => {
    'backupFormatVersion': backupManifestFormatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'boards': entries.map((entry) => entry.toJson()).toList(),
  };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    if (json['backupFormatVersion'] != backupManifestFormatVersion) {
      throw const FormatException('Unsupported backup manifest version.');
    }
    final timestamp = json['createdAt'];
    final createdAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
    final rawEntries = json['boards'];
    if (createdAt == null ||
        !createdAt.isUtc ||
        !timestamp.endsWith('Z') ||
        rawEntries is! List) {
      throw const FormatException('The backup manifest is invalid.');
    }
    return BackupManifest(
      createdAt: createdAt,
      entries: [
        for (final rawEntry in rawEntries)
          BackupManifestEntry.fromJson(
            Map<String, dynamic>.from(rawEntry as Map),
          ),
      ],
    );
  }

  static void _validate(DateTime createdAt, List<BackupManifestEntry> entries) {
    if (!createdAt.isUtc || entries.isEmpty) {
      throw const FormatException('The backup manifest is invalid.');
    }
    final ids = <String>{};
    final names = <String>{};
    for (final entry in entries) {
      if (!ids.add(entry.boardId) || !names.add(entry.fileName)) {
        throw const FormatException(
          'The backup manifest has duplicate entries.',
        );
      }
    }
  }
}

class BackupManifestEntry {
  const BackupManifestEntry({
    required this.boardId,
    required this.fileName,
    required this.sha256,
  }) : assert(boardId.length > 0);

  final String boardId;
  final String fileName;
  final String sha256;

  Map<String, Object> toJson() => {
    'boardId': boardId,
    'fileName': fileName,
    'sha256': sha256,
  };

  factory BackupManifestEntry.fromJson(Map<String, dynamic> json) {
    final boardId = json['boardId'];
    final fileName = json['fileName'];
    final sha256 = json['sha256'];
    if (boardId is! String ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(boardId) ||
        fileName is! String ||
        !RegExp(r'^[^\\/]+--[A-Za-z0-9_-]+\.vasmim$').hasMatch(fileName) ||
        !fileName.endsWith('--$boardId.vasmim') ||
        sha256 is! String ||
        !RegExp(r'^[A-F0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException(
        'The backup manifest contains an invalid entry.',
      );
    }
    return BackupManifestEntry(
      boardId: boardId,
      fileName: fileName,
      sha256: sha256,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BackupManifestEntry &&
      boardId == other.boardId &&
      fileName == other.fileName &&
      sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(boardId, fileName, sha256);
}

String uppercaseSha256(List<int> bytes) =>
    sha256.convert(bytes).toString().toUpperCase();
