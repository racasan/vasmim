import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/backup_manifest.dart';

void main() {
  test('round-trips a canonical version-one backup manifest', () {
    final manifest = BackupManifest(
      createdAt: DateTime.utc(2026, 9, 7, 12),
      entries: [
        BackupManifestEntry(
          boardId: 'board-a',
          fileName: 'Project--board-a.vasmim',
          sha256: 'A' * 64,
        ),
      ],
    );

    final restored = BackupManifest.fromJson(manifest.toJson());

    expect(restored.createdAt, manifest.createdAt);
    expect(restored.entries, manifest.entries);
  });

  test('rejects unsafe, duplicate, and non-canonical manifest entries', () {
    Map<String, Object> manifestWith(List<Object> entries) => {
      'backupFormatVersion': 1,
      'createdAt': DateTime.utc(2026, 9, 7).toIso8601String(),
      'boards': entries,
    };

    expect(
      () => BackupManifest.fromJson(
        manifestWith([
          {
            'boardId': 'board-a',
            'fileName': '../outside.vasmim',
            'sha256': 'A' * 64,
          },
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => BackupManifest.fromJson(
        manifestWith([
          {
            'boardId': 'board-a',
            'fileName': 'One--board-a.vasmim',
            'sha256': 'A' * 64,
          },
          {
            'boardId': 'board-a',
            'fileName': 'Two--board-a.vasmim',
            'sha256': 'B' * 64,
          },
        ]),
      ),
      throwsFormatException,
    );
  });
}
