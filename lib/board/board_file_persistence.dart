import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'board_document.dart';

typedef BoardFileCommitter = Future<void> Function(File staged, File target);

class BoardFileRead {
  const BoardFileRead(this.board, {this.recovered = false});

  final BoardDocument board;
  final bool recovered;
}

/// A primary document and one validated previous revision, on the same volume.
/// A failed replacement leaves the previous revision available at .backup.
class BoardFilePersistence {
  static const maximumDocumentBytes = 32 * 1024 * 1024;
  static final _writes = <String, Future<void>>{};

  static Future<BoardDocument> _decode(File file) async {
    if (await file.length() > maximumDocumentBytes) {
      throw const FormatException('Board document exceeds the 32 MiB limit.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Board document must contain a JSON object.');
    }
    return BoardDocument.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<BoardFileRead?> read(File file) async {
    final backup = File('${file.path}.backup');
    if (!await file.exists() && !await backup.exists()) return null;
    try {
      return BoardFileRead(await _decode(file));
    } catch (_) {
      // Do not change either file on read. A bad primary is retained on save.
      if (!await backup.exists()) rethrow;
      return BoardFileRead(await _decode(backup), recovered: true);
    }
  }

  static Future<void> write(
    File file,
    BoardDocument board, {
    BoardFileCommitter? committer,
  }) {
    final key = Platform.isWindows
        ? file.absolute.path.toLowerCase()
        : file.absolute.path;
    final previous = _writes[key] ?? Future<void>.value();
    final operation = previous
        .catchError((Object _) {})
        .then((_) => _write(file, board, committer: committer));
    _writes[key] = operation;
    void completed() {
      if (identical(_writes[key], operation)) _writes.remove(key);
    }

    unawaited(
      operation.then(
        (_) => completed(),
        onError: (Object _, StackTrace _) => completed(),
      ),
    );
    return operation;
  }

  static Future<void> _write(
    File file,
    BoardDocument board, {
    BoardFileCommitter? committer,
  }) async {
    final text = const JsonEncoder.withIndent('  ').convert(board.toJson());
    if (utf8.encode(text).length > maximumDocumentBytes) {
      throw const FormatException('Board document exceeds the 32 MiB limit.');
    }
    await file.parent.create(recursive: true);
    final staging = await file.parent.createTemp('.board-save-');
    final staged = File('${staging.path}${Platform.pathSeparator}board.json');
    try {
      final previous = await read(file);
      if (previous != null && previous.board.id != board.id) {
        throw const FormatException(
          'Cannot replace a different Board identity.',
        );
      }
      await staged.writeAsString(text, flush: true);
      // Keep a validated previous revision before replacing the primary.
      if (previous != null && !previous.recovered) {
        final stagedBackup = File(
          '${staging.path}${Platform.pathSeparator}previous.json',
        );
        await file.copy(stagedBackup.path);
        await stagedBackup.rename('${file.path}.backup');
      } else if (previous?.recovered == true && await file.exists()) {
        // Preserve the unreadable file for diagnosis; never overwrite it.
        await file.rename(
          '${file.path}.unreadable-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      if (committer != null) {
        await committer(staged, file);
      } else {
        await staged.rename(file.path);
      }
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}
