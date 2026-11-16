import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/board_file_persistence.dart';
import 'package:vasmim/board/board_store.dart';

void main() {
  late Directory root;
  late File file;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_save_test_');
    file = File('${root.path}/board.json');
  });
  tearDown(() async => root.delete(recursive: true));

  test('retains the previous valid revision after replacement', () async {
    await BoardFilePersistence.write(file, _board('First'));
    await BoardFilePersistence.write(file, _board('Second'));
    expect((await BoardFilePersistence.read(file))!.board.name, 'Second');
    expect(
      (await BoardFilePersistence.read(
        File('${file.path}.backup'),
      ))!.board.name,
      'First',
    );
  });

  test(
    'replacement failure preserves the exact primary and a valid backup',
    () async {
      await BoardFilePersistence.write(file, _board('First'));
      final original = await file.readAsBytes();
      await expectLater(
        BoardFilePersistence.write(
          file,
          _board('Second'),
          committer: (_, _) async =>
              throw const FileSystemException('Disk failure'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsBytes(), original);
      expect(
        (await BoardFilePersistence.read(
          File('${file.path}.backup'),
        ))!.board.name,
        'First',
      );
      expect(await root.list().where((e) => e is Directory).isEmpty, isTrue);
    },
  );

  test(
    'recovers a previous revision and preserves unreadable primary on next save',
    () async {
      await BoardFilePersistence.write(file, _board('First'));
      await BoardFilePersistence.write(file, _board('Second'));
      await file.writeAsString('{interrupted');
      final store = FileBoardStore.scoped(
        boardDirectoryProvider: () async => root,
      );
      expect((await store.load())!.name, 'First');
      expect(store.recoveredFromBackup, isTrue);
      expect(await file.readAsString(), '{interrupted');
      await store.save(_board('Recovered edits'));
      expect((await store.load())!.name, 'Recovered edits');
      final preserved = await root
          .list()
          .where((e) => e.path.contains('.unreadable-'))
          .cast<File>()
          .single;
      expect(await preserved.readAsString(), '{interrupted');
    },
  );

  test('missing primary uses the validated backup', () async {
    await BoardFilePersistence.write(file, _board('First'));
    await BoardFilePersistence.write(file, _board('Second'));
    await file.delete();
    final recovered = await BoardFilePersistence.read(file);
    expect(recovered!.recovered, isTrue);
    expect(recovered.board.name, 'First');
  });

  test(
    'an interrupted replacement with a missing primary recovers the last saved bytes',
    () async {
      await BoardFilePersistence.write(file, _board('Original'));
      final original = await file.readAsBytes();
      await expectLater(
        BoardFilePersistence.write(
          file,
          _board('Interrupted'),
          committer: (_, target) async {
            await target.delete();
            throw const FileSystemException('Interrupted replacement');
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect((await BoardFilePersistence.read(file))!.board.name, 'Original');
      expect(await File('${file.path}.backup').readAsBytes(), original);
    },
  );

  test(
    'concurrent writers are serialized and preserve the preceding revision',
    () async {
      await BoardFilePersistence.write(file, _board('First'));
      final started = Completer<void>();
      final release = Completer<void>();
      final second = BoardFilePersistence.write(
        file,
        _board('Second'),
        committer: (staged, target) async {
          started.complete();
          await release.future;
          await staged.rename(target.path);
        },
      );
      final third = BoardFilePersistence.write(file, _board('Third'));
      await started.future;
      expect((await BoardFilePersistence.read(file))!.board.name, 'First');
      release.complete();
      await Future.wait([second, third]);
      expect((await BoardFilePersistence.read(file))!.board.name, 'Third');
      expect(
        (await BoardFilePersistence.read(
          File('${file.path}.backup'),
        ))!.board.name,
        'Second',
      );
    },
  );

  test(
    'unreadable primary without a backup cannot be overwritten by save',
    () async {
      await file.writeAsString('{original');
      await expectLater(
        BoardFilePersistence.write(file, _board('New')),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{original');
    },
  );

  test('a scoped missing existing Board does not become a new Board', () async {
    final store = FileBoardStore.scoped(
      boardDirectoryProvider: () async => root,
    );
    await expectLater(store.load(), throwsA(isA<FileSystemException>()));
    expect(await file.exists(), isFalse);
  });

  test('rejects a replacement with a different permanent identity', () async {
    await BoardFilePersistence.write(file, _board('Original'));
    await expectLater(
      BoardFilePersistence.write(file, _board('Other', id: 'other')),
      throwsFormatException,
    );
    expect((await BoardFilePersistence.read(file))!.board.name, 'Original');
  });
}

BoardDocument _board(String name, {String id = 'board'}) => BoardDocument(
  id: id,
  name: name,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  viewportX: 0,
  viewportY: 0,
  viewportZoom: 1,
  notes: const [],
);
