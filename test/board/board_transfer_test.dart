import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/backup_manifest.dart';
import 'package:vasmim/board/board_library_store.dart';
import 'package:vasmim/board/board_store.dart';
import 'package:vasmim/attachment/board_attachment.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/group/board_group.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_text_link.dart';
import 'package:vasmim/scene/scene.dart';
import 'package:vasmim/shape/board_shape.dart';
import 'package:vasmim/shape/shape_layer.dart';
import 'package:vasmim/youtube/youtube_embed.dart';

import '../image/animated_gif_fixture.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_transfer_test_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'round trips a complete board and deduplicates shared managed assets',
    () async {
      final board = _completeBoard();
      final boardDirectory = await _writeStoredBoard(root, board);
      final asset = File(
        '${boardDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      await asset.parent.create(recursive: true);
      await asset.writeAsBytes(_pngLikeBytes);
      final store = FileBoardLibraryStore(directoryProvider: () async => root);
      final boardBeforeExport = await File(
        '${boardDirectory.path}${Platform.pathSeparator}board.json',
      ).readAsString();

      await store.exportBoard(board.id, '${root.path}/portable-snapshot');

      final portableFile = File('${root.path}/portable-snapshot.vasmim');
      expect(await portableFile.exists(), isTrue);
      expect(
        await File(
          '${boardDirectory.path}${Platform.pathSeparator}board.json',
        ).readAsString(),
        boardBeforeExport,
      );
      expect(await asset.readAsBytes(), _pngLikeBytes);
      final archive = ZipDecoder().decodeBytes(
        await portableFile.readAsBytes(),
      );
      expect(
        archive.map((entry) => entry.name),
        containsAllInOrder([
          'manifest.json',
          'board.json',
          'assets/shared.png',
        ]),
      );
      expect(
        archive.where((entry) => entry.name == 'assets/shared.png'),
        hasLength(1),
      );

      await expectLater(
        store.importBoard(portableFile.path),
        _throwsTransferKind(BoardTransferFailureKind.duplicateBoard),
      );
      expect((await store.discover()).single.board!.toJson(), board.toJson());

      await store.deleteBoard(board.id);
      final imported = await store.importBoard(portableFile.path);

      expect(imported.toJson(), board.toJson());
      final importedDirectory = await store.boardDirectory(board.id);
      expect(
        await File(
          '${importedDirectory.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}shared.png',
        ).readAsBytes(),
        _pngLikeBytes,
      );
      final reopened = await FileBoardStore.scoped(
        boardDirectoryProvider: () async => importedDirectory,
      ).load();
      expect(reopened!.toJson(), board.toJson());
    },
  );

  test('portable export carries an attachment preview asset', () async {
    final time = DateTime.utc(2026, 9, 9);
    final board = BoardDocument(
      id: 'attachment-preview-board',
      name: 'Attachment preview',
      createdAt: time,
      modifiedAt: time,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      attachments: [
        BoardAttachment(
          id: 'attachment-1',
          x: 10,
          y: 20,
          width: 300,
          height: 112,
          assetPath: 'assets/reference.pdf',
          originalFileName: 'reference.pdf',
          kind: AttachmentKind.pdf,
          byteSize: 8,
          previewAssetPath: 'assets/reference-preview.jpg',
          createdAt: time,
          modifiedAt: time,
        ),
      ],
    );
    final directory = await _writeStoredBoard(root, board);
    final assets = Directory('${directory.path}/assets');
    await assets.create(recursive: true);
    await File(
      '${assets.path}/reference.pdf',
    ).writeAsBytes(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
    await File(
      '${assets.path}/reference-preview.jpg',
    ).writeAsBytes(<int>[9, 8, 7]);
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    await store.exportBoard(board.id, '${root.path}/attachment-preview');

    final archive = ZipDecoder().decodeBytes(
      await File('${root.path}/attachment-preview.vasmim').readAsBytes(),
    );
    expect(
      archive.map((entry) => entry.name),
      containsAll(<String>[
        'assets/reference.pdf',
        'assets/reference-preview.jpg',
      ]),
    );
  });

  test('portable export and import preserve a managed GIF', () async {
    final time = DateTime.utc(2026, 9, 24);
    final board = BoardDocument(
      id: 'gif-board',
      name: 'Animated reference',
      createdAt: time,
      modifiedAt: time,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      images: [
        BoardImage(
          id: 'gif-image',
          x: 10,
          y: 20,
          width: 200,
          height: 120,
          assetPath: 'assets/animation.gif',
          originalFileName: 'animation.gif',
          pixelWidth: 2,
          pixelHeight: 2,
          createdAt: time,
          modifiedAt: time,
        ),
      ],
    );
    final directory = await _writeStoredBoard(root, board);
    final asset = File('${directory.path}/assets/animation.gif');
    await asset.parent.create(recursive: true);
    await asset.writeAsBytes(twoFrameGif);
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    await store.exportBoard(board.id, '${root.path}/gif-portable');
    final portable = File('${root.path}/gif-portable.vasmim');
    final archive = ZipDecoder().decodeBytes(await portable.readAsBytes());
    expect(
      archive.map((entry) => entry.name),
      contains('assets/animation.gif'),
    );

    await store.deleteBoard(board.id);
    final imported = await store.importBoard(portable.path);
    expect(imported.images.single.assetPath, 'assets/animation.gif');
    final importedDirectory = await store.boardDirectory(board.id);
    expect(
      await File(
        '${importedDirectory.path}/assets/animation.gif',
      ).readAsBytes(),
      twoFrameGif,
    );
  });

  test('portable export and import preserve managed audio', () async {
    final time = DateTime.utc(2026, 9, 24);
    final board = BoardDocument(
      id: 'audio-board',
      name: 'Voice memo',
      createdAt: time,
      modifiedAt: time,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      attachments: [
        BoardAttachment(
          id: 'memo',
          x: 10,
          y: 20,
          width: 300,
          height: 112,
          assetPath: 'assets/memo.mp3',
          originalFileName: 'memo.mp3',
          kind: AttachmentKind.audio,
          byteSize: 7,
          createdAt: time,
          modifiedAt: time,
        ),
      ],
    );
    final directory = await _writeStoredBoard(root, board);
    final bytes = <int>[0x49, 0x44, 0x33, 0x04, 0, 0, 0];
    final asset = File('${directory.path}/assets/memo.mp3');
    await asset.parent.create(recursive: true);
    await asset.writeAsBytes(bytes);
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    await store.exportBoard(board.id, '${root.path}/audio-portable');
    final portable = File('${root.path}/audio-portable.vasmim');
    final archive = ZipDecoder().decodeBytes(await portable.readAsBytes());
    expect(archive.map((entry) => entry.name), contains('assets/memo.mp3'));

    await store.deleteBoard(board.id);
    final imported = await store.importBoard(portable.path);
    expect(imported.attachments.single.kind, AttachmentKind.audio);
    final importedDirectory = await store.boardDirectory(board.id);
    expect(
      await File('${importedDirectory.path}/assets/memo.mp3').readAsBytes(),
      bytes,
    );
  });

  test('refuses export when a referenced asset is missing', () async {
    final board = _completeBoard();
    await _writeStoredBoard(root, board);
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    await expectLater(
      store.exportBoard(board.id, '${root.path}/missing.vasmim'),
      _throwsTransferKind(BoardTransferFailureKind.missingAsset),
    );

    expect(await File('${root.path}/missing.vasmim').exists(), isFalse);
  });

  test(
    'imports a legacy .freeform version-1 board and normalizes current format',
    () async {
      const boardId = 'legacy-portable-board';
      final timestamp = DateTime.utc(2026, 8, 12).toIso8601String();
      final boardJson = <String, Object>{
        'formatVersion': 1,
        'board': {
          'id': boardId,
          'name': 'Legacy Portable',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
        'viewport': {'x': 11, 'y': 22, 'zoom': 1.25},
        'notes': <Object>[],
      };
      final portable = File('${root.path}/legacy.freeform');
      await _writePortable(
        portable,
        manifestBoardId: boardId,
        boardJson: boardJson,
      );
      final store = FileBoardLibraryStore(directoryProvider: () async => root);

      final imported = await store.importBoard(portable.path);

      expect(imported.id, boardId);
      final directory = await store.boardDirectory(boardId);
      final stored =
          jsonDecode(
                await File(
                  '${directory.path}${Platform.pathSeparator}board.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(stored['formatVersion'], BoardDocument.currentFormatVersion);
    },
  );

  test(
    'rejects malformed, unsafe, and unsupported packages atomically',
    () async {
      final store = FileBoardLibraryStore(directoryProvider: () async => root);
      final malformed = File('${root.path}/malformed.vasmim');
      await malformed.writeAsString('not a zip');
      await expectLater(
        store.importBoard(malformed.path),
        _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
      );

      final unsupported = File('${root.path}/unsupported.vasmim');
      await _writePortable(
        unsupported,
        manifestBoardId: 'unsupported-board',
        boardJson: _simpleBoardJson('unsupported-board'),
        packageVersion: 99,
      );
      await expectLater(
        store.importBoard(unsupported.path),
        _throwsTransferKind(BoardTransferFailureKind.unsupportedPackageVersion),
      );

      final unsafe = File('${root.path}/unsafe.vasmim');
      await _writePortable(
        unsafe,
        manifestBoardId: 'unsafe-board',
        boardJson: _simpleBoardJson('unsafe-board'),
        extraEntries: {
          '../outside.txt': [1, 2, 3],
        },
      );
      await expectLater(
        store.importBoard(unsafe.path),
        _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
      );

      expect(await store.discover(), isEmpty);
      final transferDirectory = Directory('${root.path}/.transfers');
      if (await transferDirectory.exists()) {
        expect(await transferDirectory.list().toList(), isEmpty);
      }
    },
  );

  test(
    'rejects identity disagreement, unexpected files, and missing assets',
    () async {
      final store = FileBoardLibraryStore(directoryProvider: () async => root);
      final mismatch = File('${root.path}/mismatch.vasmim');
      await _writePortable(
        mismatch,
        manifestBoardId: 'manifest-board',
        boardJson: _simpleBoardJson('document-board'),
      );
      await expectLater(
        store.importBoard(mismatch.path),
        _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
      );

      final unexpected = File('${root.path}/unexpected.vasmim');
      await _writePortable(
        unexpected,
        manifestBoardId: 'unexpected-board',
        boardJson: _simpleBoardJson('unexpected-board'),
        extraEntries: {
          'extra.txt': [1],
        },
      );
      await expectLater(
        store.importBoard(unexpected.path),
        _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
      );

      final missing = File('${root.path}/missing-asset.vasmim');
      await _writePortable(
        missing,
        manifestBoardId: 'missing-asset-board',
        boardJson: _completeBoard(id: 'missing-asset-board').toJson(),
      );
      await expectLater(
        store.importBoard(missing.path),
        _throwsTransferKind(BoardTransferFailureKind.missingAsset),
      );
      expect(await store.discover(), isEmpty);
    },
  );

  test('rejects duplicate, linked, encrypted, and corrupt entries', () async {
    final store = FileBoardLibraryStore(directoryProvider: () async => root);
    final boardJson = _simpleBoardJson('hostile-board');

    final duplicate = File('${root.path}/duplicate.vasmim');
    await _writeDuplicateArchive(duplicate, [
      ArchiveFile.string('manifest.json', _manifestJson('hostile-board')),
      ArchiveFile.string('board.json', jsonEncode(boardJson)),
      ArchiveFile.string('board.json', jsonEncode(boardJson)),
    ]);
    await expectLater(
      store.importBoard(duplicate.path),
      _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
    );

    final linked = File('${root.path}/linked.vasmim');
    await _writeArchive(linked, [
      ArchiveFile.string('manifest.json', _manifestJson('hostile-board')),
      ArchiveFile.string('board.json', jsonEncode(boardJson)),
      ArchiveFile.string('assets/link.png', '../outside.png')..mode = 0xA1FF,
    ]);
    await expectLater(
      store.importBoard(linked.path),
      _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
    );

    final encrypted = File('${root.path}/encrypted.vasmim');
    final encryptedArchive = Archive()
      ..addFile(
        ArchiveFile.string('manifest.json', _manifestJson('hostile-board')),
      )
      ..addFile(ArchiveFile.string('board.json', jsonEncode(boardJson)));
    await encrypted.writeAsBytes(
      ZipEncoder(password: 'secret').encode(encryptedArchive),
    );
    await expectLater(
      store.importBoard(encrypted.path),
      _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
    );

    final corrupt = File('${root.path}/corrupt-crc.vasmim');
    await _writePortable(
      corrupt,
      manifestBoardId: 'hostile-board',
      boardJson: boardJson,
    );
    final corruptBytes = await corrupt.readAsBytes();
    final localHeader = _indexOfSignature(corruptBytes, const [
      0x50,
      0x4b,
      0x03,
      0x04,
    ]);
    expect(localHeader, isNonNegative);
    corruptBytes[localHeader + 14] ^= 0xff;
    await corrupt.writeAsBytes(corruptBytes);
    await expectLater(
      store.importBoard(corrupt.path),
      _throwsTransferKind(BoardTransferFailureKind.invalidArchive),
    );

    expect(await store.discover(), isEmpty);
  });

  test(
    'imports a validated identity conflict as an independent atomic copy',
    () async {
      const copyId = '123e4567-e89b-42d3-a456-426614174036';
      final board = _completeBoard();
      final boardDirectory = await _writeStoredBoard(root, board);
      final sourceAsset = File(
        '${boardDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      await sourceAsset.parent.create(recursive: true);
      await sourceAsset.writeAsBytes(_pngLikeBytes);
      var generatedIds = 0;
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        idGenerator: () {
          generatedIds += 1;
          return copyId;
        },
      );
      final portable = File('${root.path}/conflict.vasmim');
      await store.exportBoard(board.id, portable.path);
      await store.setBoardFavorite(board.id, true);

      BoardTransferException? conflict;
      try {
        await store.importBoard(portable.path);
      } on BoardTransferException catch (error) {
        conflict = error;
      }

      expect(conflict?.kind, BoardTransferFailureKind.duplicateBoard);
      expect(conflict?.conflict?.boardId, board.id);
      expect(conflict?.conflict?.boardName, board.name);
      expect(generatedIds, 0);

      final copied = await store.importBoardAsCopy(
        portable.path,
        '  Recovered Project  ',
      );

      expect(generatedIds, 1);
      expect(copied.id, copyId);
      expect(copied.name, 'Recovered Project');
      expect(copied.createdAt, copied.modifiedAt);
      expect(copied.createdAt, isNot(board.createdAt));
      expect(copied.viewportX, board.viewportX);
      expect(copied.viewportY, board.viewportY);
      expect(copied.viewportZoom, board.viewportZoom);
      final copiedJson = copied.toJson();
      final sourceJson = board.toJson();
      expect(copiedJson['viewport'], sourceJson['viewport']);
      expect(copiedJson['notes'], sourceJson['notes']);
      expect(copiedJson['images'], sourceJson['images']);
      expect(copiedJson['connectors'], sourceJson['connectors']);
      expect(copiedJson['scenes'], sourceJson['scenes']);
      expect((await store.loadBoard(board.id)).toJson(), board.toJson());
      expect(await store.favoriteBoardIds(), {board.id});

      final copyDirectory = await store.boardDirectory(copyId);
      final copiedAsset = File(
        '${copyDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      expect(await copiedAsset.readAsBytes(), _pngLikeBytes);
      await sourceAsset.writeAsBytes([..._pngLikeBytes, 99]);
      expect(await copiedAsset.readAsBytes(), _pngLikeBytes);
      expect(
        (await store.discover()).where((entry) => entry.isAvailable),
        hasLength(2),
      );
      final transfers = Directory(
        '${root.path}${Platform.pathSeparator}.transfers',
      );
      expect(
        await transfers.exists() ? await transfers.list().toList() : const [],
        isEmpty,
      );
    },
  );

  test(
    'copy import requires a live conflict and preserves state on ID collision',
    () async {
      const copyId = '123e4567-e89b-42d3-a456-426614174036';
      final board = _completeBoard();
      final boardDirectory = await _writeStoredBoard(root, board);
      final asset = File(
        '${boardDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      await asset.parent.create(recursive: true);
      await asset.writeAsBytes(_pngLikeBytes);
      var generatedIds = 0;
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        idGenerator: () {
          generatedIds += 1;
          return copyId;
        },
      );
      final portable = File('${root.path}/copy-guard.vasmim');
      await store.exportBoard(board.id, portable.path);

      await store.deleteBoard(board.id);
      await expectLater(
        store.importBoardAsCopy(portable.path, 'No conflict'),
        _throwsTransferKind(BoardTransferFailureKind.duplicateBoard),
      );
      expect(generatedIds, 0);
      expect(await store.discover(), isEmpty);

      await _writeStoredBoard(root, board);
      final collision = _completeBoard(id: copyId).copyWith(name: 'Collision');
      await _writeStoredBoard(root, collision);
      await expectLater(
        store.importBoardAsCopy(portable.path, 'Recovered'),
        _throwsTransferKind(BoardTransferFailureKind.duplicateBoard),
      );
      expect(generatedIds, 1);
      expect((await store.loadBoard(board.id)).toJson(), board.toJson());
      expect((await store.loadBoard(copyId)).name, 'Collision');
      final transfers = Directory(
        '${root.path}${Platform.pathSeparator}.transfers',
      );
      expect(
        await transfers.exists() ? await transfers.list().toList() : const [],
        isEmpty,
      );
    },
  );

  test(
    'exports every board into one collision-safe atomically published folder',
    () async {
      final first = _completeBoard().copyWith(name: 'Shared Name');
      final second = _completeBoard(
        id: 'second-portable-board',
      ).copyWith(name: 'Shared Name');
      for (final board in [first, second]) {
        final directory = await _writeStoredBoard(root, board);
        final asset = File(
          '${directory.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}shared.png',
        );
        await asset.parent.create(recursive: true);
        await asset.writeAsBytes(_pngLikeBytes);
      }
      final target = await Directory('${root.path}/backup-target').create();
      await Directory(
        '${target.path}${Platform.pathSeparator}'
        'Vasmim Backup 2026-08-30 142530Z',
      ).create();
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        clock: () => DateTime.utc(2026, 8, 30, 14, 25, 30),
      );

      final result = await store.exportAllBoards(target.path);

      expect(result.boardCount, 2);
      expect(result.folderName, 'Vasmim Backup 2026-08-30 142530Z (2)');
      final published = Directory(result.directoryPath);
      expect(await published.exists(), isTrue);
      final packageNames = await published
          .list()
          .map((entry) => entry.uri.pathSegments.last)
          .toSet();
      expect(packageNames, {
        'Shared Name--portable-board.vasmim',
        'Shared Name--second-portable-board.vasmim',
        backupManifestFileName,
      });
      final manifest = BackupManifest.fromJson(
        jsonDecode(
              await File(
                '${published.path}${Platform.pathSeparator}$backupManifestFileName',
              ).readAsString(),
            )
            as Map<String, dynamic>,
      );
      expect(manifest.entries.map((entry) => entry.fileName).toSet(), {
        'Shared Name--portable-board.vasmim',
        'Shared Name--second-portable-board.vasmim',
      });
      for (final packageName in manifest.entries.map(
        (entry) => entry.fileName,
      )) {
        final archive = ZipDecoder().decodeBytes(
          await File(
            '${published.path}${Platform.pathSeparator}$packageName',
          ).readAsBytes(),
        );
        expect(
          archive.map((entry) => entry.name),
          containsAll(['manifest.json', 'board.json', 'assets/shared.png']),
        );
      }
      expect(
        (await target.list().toList()).where(
          (entry) => entry.uri.pathSegments.last.startsWith('.vasmim-backup-'),
        ),
        isEmpty,
      );
      expect(
        (await store.discover()).where((entry) => entry.isAvailable),
        hasLength(2),
      );
    },
  );

  test(
    'complete export refuses unavailable boards and cleans a failed staging set',
    () async {
      final target = await Directory('${root.path}/backup-target').create();
      final brokenDirectory = await Directory(
        '${root.path}${Platform.pathSeparator}boards'
        '${Platform.pathSeparator}broken-board',
      ).create(recursive: true);
      await File(
        '${brokenDirectory.path}${Platform.pathSeparator}board.json',
      ).writeAsString('{not-json');
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        clock: () => DateTime.utc(2026, 8, 30, 14, 25, 30),
      );

      await expectLater(
        store.exportAllBoards(target.path),
        _throwsBackupKind(BoardLibraryBackupFailureKind.unavailableBoards),
      );
      expect(await target.list().toList(), isEmpty);

      await brokenDirectory.delete(recursive: true);
      await _writeStoredBoard(root, _completeBoard(id: 'missing-asset-board'));
      await expectLater(
        store.exportAllBoards(target.path),
        _throwsBackupKind(BoardLibraryBackupFailureKind.boardExport),
      );
      expect(await target.list().toList(), isEmpty);
    },
  );

  test(
    'verifies a complete backup read-only and rejects altered inventory or packages',
    () async {
      final board = _completeBoard();
      final boardDirectory = await _writeStoredBoard(root, board);
      final asset = File(
        '${boardDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      await asset.parent.create(recursive: true);
      await asset.writeAsBytes(_pngLikeBytes);
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        clock: () => DateTime.utc(2026, 9, 7, 12),
      );
      final target = await Directory('${root.path}/backup-target').create();
      final backup = await store.exportAllBoards(target.path);
      final boardBeforeVerification = await File(
        '${boardDirectory.path}${Platform.pathSeparator}board.json',
      ).readAsString();

      final verified = await store.verifyBackupFolder(backup.directoryPath);

      expect(verified.boardCount, 1);
      expect(
        await File(
          '${boardDirectory.path}${Platform.pathSeparator}board.json',
        ).readAsString(),
        boardBeforeVerification,
      );
      expect((await store.discover()).single.board!.toJson(), board.toJson());

      final published = Directory(backup.directoryPath);
      final extraFile = File(
        '${published.path}${Platform.pathSeparator}unexpected.txt',
      );
      await extraFile.writeAsString('unexpected');
      await expectLater(
        store.verifyBackupFolder(published.path),
        _throwsBackupKind(BoardLibraryBackupFailureKind.invalidManifest),
      );
      await extraFile.delete();

      final manifestFile = File(
        '${published.path}${Platform.pathSeparator}$backupManifestFileName',
      );
      final manifest = BackupManifest.fromJson(
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
      );
      final entry = manifest.entries.single;
      final packageFile = File(
        '${published.path}${Platform.pathSeparator}${entry.fileName}',
      );
      final corrupted = await packageFile.readAsBytes();
      corrupted[0] = corrupted[0] ^ 0xFF;
      await packageFile.writeAsBytes(corrupted, flush: true);
      await expectLater(
        store.verifyBackupFolder(published.path),
        _throwsBackupKind(BoardLibraryBackupFailureKind.invalidPackage),
      );
      final rehashedManifest = BackupManifest(
        createdAt: manifest.createdAt,
        entries: [
          BackupManifestEntry(
            boardId: entry.boardId,
            fileName: entry.fileName,
            sha256: uppercaseSha256(corrupted),
          ),
        ],
      );
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(rehashedManifest.toJson()),
        flush: true,
      );

      await expectLater(
        store.verifyBackupFolder(published.path),
        _throwsBackupKind(BoardLibraryBackupFailureKind.invalidPackage),
      );
      expect(
        await File(
          '${boardDirectory.path}${Platform.pathSeparator}board.json',
        ).readAsString(),
        boardBeforeVerification,
      );
    },
  );

  test(
    'reports a legacy backup folder without a manifest distinctly',
    () async {
      final legacyFolder = await Directory(
        '${root.path}/legacy-backup',
      ).create();
      await File(
        '${legacyFolder.path}${Platform.pathSeparator}'
        'old-board--old-board.vasmim',
      ).writeAsBytes([1, 2, 3]);
      final store = FileBoardLibraryStore(directoryProvider: () async => root);

      await expectLater(
        store.verifyBackupFolder(legacyFolder.path),
        _throwsBackupKind(BoardLibraryBackupFailureKind.missingManifest),
      );
      expect(await legacyFolder.list().toList(), hasLength(1));
    },
  );
}

Matcher _throwsTransferKind(BoardTransferFailureKind kind) {
  return throwsA(
    isA<BoardTransferException>().having((error) => error.kind, 'kind', kind),
  );
}

Matcher _throwsBackupKind(BoardLibraryBackupFailureKind kind) {
  return throwsA(
    isA<BoardLibraryBackupException>().having(
      (error) => error.kind,
      'kind',
      kind,
    ),
  );
}

BoardDocument _completeBoard({String id = 'portable-board'}) {
  final createdAt = DateTime.utc(2026, 8, 12, 10);
  final modifiedAt = DateTime.utc(2026, 8, 13, 11);
  final notes = [
    Note(
      id: 'note-a',
      x: 100,
      y: 200,
      width: 260,
      height: 170,
      text: 'Portable idea',
      title: 'Release plan',
      emphasis: const [NoteEmphasisRange(start: 0, end: 8, underline: true)],
      links: const [
        NoteTextLinkRange(
          start: 9,
          end: 13,
          destination: 'https://example.com/portable',
        ),
      ],
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    ),
    Note(
      id: 'note-b',
      x: 500,
      y: 350,
      width: 300,
      height: 190,
      text: 'Connected idea',
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    ),
  ];
  BoardImage image(String imageId, double x) => BoardImage(
    id: imageId,
    x: x,
    y: 600,
    width: 320,
    height: 180,
    assetPath: 'assets/shared.png',
    originalFileName: 'source.png',
    pixelWidth: 1920,
    pixelHeight: 1080,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );
  return BoardDocument(
    id: id,
    name: 'Portable Project',
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    viewportX: 412.5,
    viewportY: -91.25,
    viewportZoom: 1.4,
    notes: notes,
    connectors: [
      Connector(
        id: 'connector-a-b',
        objectAId: 'note-a',
        objectBId: 'note-b',
        label: 'supports',
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
      Connector(
        id: 'connector-note-image',
        objectAId: 'note-b',
        objectBId: 'image-a',
        label: 'illustrated by',
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
      Connector(
        id: 'connector-images',
        objectAId: 'image-a',
        objectBId: 'image-b',
        label: 'compare',
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
    ],
    images: [image('image-a', 100), image('image-b', 460)],
    youTubeEmbeds: [
      YouTubeEmbed(
        id: 'youtube-a',
        x: 850,
        y: 600,
        width: 300,
        height: 168,
        originalUrl: 'https://youtu.be/dQw4w9WgXcQ',
        videoId: 'dQw4w9WgXcQ',
        thumbnailAssetPath: 'assets/shared.png',
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
    ],
    headings: [
      CanvasHeading(
        id: 'heading-a',
        x: 80,
        y: 80,
        text: 'Portable section',
        size: CanvasHeadingSize.extraLarge,
        background: CanvasHeadingBackground.blue,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
    ],
    shapes: [
      BoardShape(
        id: 'shape-a',
        type: BoardShapeType.database,
        x: 40,
        y: 40,
        width: 900,
        height: 760,
        lineStartsAtTopLeft: true,
        lineReversed: false,
        fillColorValue: 0xFFBBDEFB,
        fillOpacity: 0.2,
        outlineColorValue: 0xFF37474F,
        outlineWidth: 2,
        heading: const ShapeHeading(text: 'Portable visual area'),
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
    ],
    shapeLayers: [
      ShapeLayer(
        id: 'portable-background',
        name: 'Background',
        shapeIds: const ['shape-a'],
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        isVisible: false,
        opacity: 0.25,
      ),
      ShapeLayer(
        id: 'portable-directions',
        name: 'Directions',
        shapeIds: const [],
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        opacity: 0.75,
      ),
    ],
    scenes: [
      Scene(
        id: '123e4567-e89b-42d3-a456-426614174000',
        name: 'Overview',
        x: 412.5,
        y: -91.25,
        zoom: 1.4,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
    ],
    groups: [
      BoardGroup(
        id: 'portable-selection-set',
        memberIds: const ['note-a', 'heading-a', 'shape-a'],
        isVisible: false,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      ),
    ],
  );
}

Map<String, Object> _simpleBoardJson(String boardId) {
  final timestamp = DateTime.utc(2026, 8, 12).toIso8601String();
  return {
    'formatVersion': 4,
    'board': {
      'id': boardId,
      'name': 'Portable',
      'createdAt': timestamp,
      'modifiedAt': timestamp,
    },
    'viewport': {'x': 0, 'y': 0, 'zoom': 1},
    'notes': <Object>[],
    'connectors': <Object>[],
    'images': <Object>[],
    'scenes': <Object>[],
  };
}

Future<Directory> _writeStoredBoard(Directory root, BoardDocument board) async {
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}boards'
    '${Platform.pathSeparator}${board.id}',
  );
  await directory.create(recursive: true);
  await File(
    '${directory.path}${Platform.pathSeparator}board.json',
  ).writeAsString(jsonEncode(board.toJson()));
  return directory;
}

Future<void> _writePortable(
  File file, {
  required String manifestBoardId,
  required Map<String, Object> boardJson,
  int packageVersion = 1,
  Map<String, List<int>> extraEntries = const {},
}) async {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'packageFormatVersion': packageVersion,
          'boardId': manifestBoardId,
          'exportedAt': DateTime.utc(2026, 8, 15).toIso8601String(),
        }),
      ),
    )
    ..addFile(ArchiveFile.string('board.json', jsonEncode(boardJson)));
  for (final entry in extraEntries.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  final bytes = ZipEncoder().encode(archive);
  await file.writeAsBytes(bytes);
}

Future<void> _writeArchive(File file, List<ArchiveFile> files) async {
  final archive = Archive();
  for (final entry in files) {
    archive.addFile(entry);
  }
  await file.writeAsBytes(ZipEncoder().encode(archive));
}

Future<void> _writeDuplicateArchive(File file, List<ArchiveFile> files) async {
  final encoder = ZipFileEncoder()..create(file.path);
  for (final entry in files) {
    encoder.addArchiveFile(entry);
  }
  await encoder.close();
}

String _manifestJson(String boardId) => jsonEncode({
  'packageFormatVersion': 1,
  'boardId': boardId,
  'exportedAt': DateTime.utc(2026, 8, 15).toIso8601String(),
});

int _indexOfSignature(List<int> bytes, List<int> signature) {
  for (var index = 0; index <= bytes.length - signature.length; index += 1) {
    var matches = true;
    for (var offset = 0; offset < signature.length; offset += 1) {
      if (bytes[index + offset] != signature[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return index;
    }
  }
  return -1;
}

const _pngLikeBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  1,
  2,
  3,
  4,
];
