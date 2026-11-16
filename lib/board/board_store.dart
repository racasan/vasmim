import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'board_document.dart';
import 'board_file_persistence.dart';

abstract interface class BoardStore {
  Future<BoardDocument?> load();

  Future<void> save(BoardDocument board);
}

class FileBoardStore implements BoardStore {
  FileBoardStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
      _requiresExisting = false;

  final Future<Directory> Function() _directoryProvider;
  final bool _requiresExisting;
  bool recoveredFromBackup = false;

  FileBoardStore.scoped({
    required Future<Directory> Function() boardDirectoryProvider,
  }) : _directoryProvider = boardDirectoryProvider,
       _requiresExisting = true;

  Future<File> _boardFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}board.json');
  }

  @override
  Future<BoardDocument?> load() async {
    final file = await _boardFile();
    final result = await BoardFilePersistence.read(file);
    if (result == null && _requiresExisting) {
      throw const FileSystemException(
        'The existing Board document is missing.',
      );
    }
    recoveredFromBackup = result?.recovered ?? false;
    return result?.board;
  }

  @override
  Future<void> save(BoardDocument board) async {
    final file = await _boardFile();
    await BoardFilePersistence.write(file, board);
  }
}
