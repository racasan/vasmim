import 'package:file_selector/file_selector.dart';

export 'portable_board_naming.dart' show portableBoardSuggestedName;

typedef BoardImportPathPicker = Future<String?> Function();
typedef BoardExportPathPicker = Future<String?> Function(String suggestedName);
typedef BoardBackupDirectoryPicker = Future<String?> Function();
typedef BoardBackupVerificationDirectoryPicker = Future<String?> Function();

const _vasmimPortableBoardType = XTypeGroup(
  label: 'Vasmim portable boards (*.vasmim)',
  extensions: ['vasmim'],
);

const _legacyFreeformPortableBoardType = XTypeGroup(
  label: 'Legacy Freeform boards (*.freeform)',
  extensions: ['freeform'],
);

Future<String?> pickPortableBoardImportPath() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      _vasmimPortableBoardType,
      _legacyFreeformPortableBoardType,
    ],
  );
  return file?.path;
}

Future<String?> pickPortableBoardExportPath(String suggestedName) async {
  final location = await getSaveLocation(
    acceptedTypeGroups: const [_vasmimPortableBoardType],
    suggestedName: suggestedName,
    confirmButtonText: 'Export',
  );
  final path = location?.path;
  if (path == null || path.toLowerCase().endsWith('.vasmim')) {
    return path;
  }
  return '$path.vasmim';
}

Future<String?> pickBoardBackupDirectoryPath() =>
    getDirectoryPath(confirmButtonText: 'Export all boards');

Future<String?> pickBoardBackupVerificationDirectoryPath() =>
    getDirectoryPath(confirmButtonText: 'Verify backup folder');
