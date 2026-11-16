import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/board_paper_tone.dart';
import 'package:vasmim/board/board_library_store.dart';
import 'package:vasmim/board/board_store.dart';
import 'package:vasmim/board/board_starter.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/image/image_asset_store.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_text_link.dart';
import 'package:vasmim/scene/scene.dart';
import 'package:vasmim/shape/board_shape.dart';
import 'package:vasmim/shape/shape_layer.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_library_test_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('persists favorite IDs outside unchanged board documents', () async {
    final boardA = _board(id: 'board-a', name: 'Board A');
    final boardB = _board(id: 'board-b', name: 'Board B');
    await _writeStoredBoard(root, boardA);
    await _writeStoredBoard(root, boardB);
    final boardFile = File(
      '${root.path}${Platform.pathSeparator}boards'
      '${Platform.pathSeparator}board-a${Platform.pathSeparator}board.json',
    );
    final boardJsonBefore = await boardFile.readAsString();
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    await store.setBoardFavorite('board-b', true);
    await store.setBoardFavorite('board-a', true);

    expect(await store.favoriteBoardIds(), {'board-a', 'board-b'});
    expect(await boardFile.readAsString(), boardJsonBefore);
    final metadataFile = File(
      '${root.path}${Platform.pathSeparator}'
      '${FileBoardLibraryStore.favoriteMetadataFileName}',
    );
    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    expect(metadata['version'], 1);
    expect(metadata['favoriteBoardIds'], ['board-a', 'board-b']);
    await metadataFile.rename('${metadataFile.path}.backup');
    final restarted = FileBoardLibraryStore(
      directoryProvider: () async => root,
    );
    expect(await restarted.favoriteBoardIds(), {'board-a', 'board-b'});
    expect(await metadataFile.exists(), isTrue);
  });

  test('removes a deleted board from favorite metadata', () async {
    await _writeStoredBoard(root, _board(id: 'board-a', name: 'Board A'));
    await _writeStoredBoard(root, _board(id: 'board-b', name: 'Board B'));
    final store = FileBoardLibraryStore(directoryProvider: () async => root);
    await store.setBoardFavorite('board-a', true);
    await store.setBoardFavorite('board-b', true);

    await store.deleteBoard('board-a');

    expect(await store.favoriteBoardIds(), {'board-b'});
  });

  test(
    'persists flat folders and exact Board membership across restart',
    () async {
      await _writeStoredBoard(root, _board(id: 'board-a', name: 'Compiler'));
      await _writeStoredBoard(root, _board(id: 'board-b', name: 'Holiday'));
      const folderId = '123e4567-e89b-42d3-a456-426614174088';
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        idGenerator: () => folderId,
        clock: () => DateTime.utc(2026, 9, 17),
      );

      final folder = await store.createLibraryFolder(' Programming ');
      await store.setBoardFolder('board-a', folder.id);

      final restarted = FileBoardLibraryStore(
        directoryProvider: () async => root,
      );
      final state = await restarted.libraryFolderState();
      expect(state.folders.single.name, 'Programming');
      expect(state.boardFolderIds, {'board-a': folderId});
      expect((await restarted.loadBoard('board-a')).name, 'Compiler');
      expect((await restarted.loadBoard('board-b')).name, 'Holiday');
    },
  );

  test(
    'renames folders, protects populated deletion, and cleans deleted Boards',
    () async {
      await _writeStoredBoard(root, _board(id: 'board-a', name: 'Compiler'));
      const folderId = '123e4567-e89b-42d3-a456-426614174089';
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        idGenerator: () => folderId,
        clock: () => DateTime.utc(2026, 9, 17),
      );
      final folder = await store.createLibraryFolder('Programming');
      await store.setBoardFolder('board-a', folder.id);

      await expectLater(store.deleteLibraryFolder(folder.id), throwsStateError);
      await store.renameLibraryFolder(folder.id, 'Development');
      await store.deleteBoard('board-a');
      expect((await store.libraryFolderState()).boardFolderIds, isEmpty);
      await store.deleteLibraryFolder(folder.id);
      expect((await store.libraryFolderState()).folders, isEmpty);
    },
  );

  test('failed favorite commit preserves the previous metadata', () async {
    await _writeStoredBoard(root, _board(id: 'board-a', name: 'Board A'));
    await _writeStoredBoard(root, _board(id: 'board-b', name: 'Board B'));
    final store = FileBoardLibraryStore(directoryProvider: () async => root);
    await store.setBoardFavorite('board-a', true);
    final failingStore = FileBoardLibraryStore(
      directoryProvider: () async => root,
      favoriteMetadataCommitter: (stagedFile, targetFile) async {
        throw const FileSystemException('simulated commit failure');
      },
    );

    await expectLater(
      failingStore.setBoardFavorite('board-b', true),
      throwsA(isA<FileSystemException>()),
    );

    expect(await store.favoriteBoardIds(), {'board-a'});
    expect(
      await root
          .list()
          .where((entity) => entity.path.contains('.favorites-'))
          .toList(),
      isEmpty,
    );
  });

  test('reused stale IDs start non-favorite when duplicating', () async {
    const duplicateId = '123e4567-e89b-42d3-a456-426614174000';
    await _writeStoredBoard(
      root,
      _board(id: duplicateId, name: 'Former Board'),
    );
    final initialStore = FileBoardLibraryStore(
      directoryProvider: () async => root,
    );
    await initialStore.setBoardFavorite(duplicateId, true);
    await (await initialStore.boardDirectory(
      duplicateId,
    )).delete(recursive: true);
    await _writeStoredBoard(root, _board(id: 'source-board', name: 'Source'));
    final duplicateStore = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () => duplicateId,
    );

    final duplicate = await duplicateStore.duplicateBoard(
      'source-board',
      'Copy',
    );

    expect(duplicate.id, duplicateId);
    expect(await duplicateStore.favoriteBoardIds(), isEmpty);
  });

  test(
    'duplicate and portable import as copy preserve Board paper tone',
    () async {
      final source = _board(
        id: 'tone-source',
        name: 'Tone source',
      ).copyWith(paperTone: BoardPaperTone.blue);
      await _writeStoredBoard(root, source);
      var nextId = 0;
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        idGenerator: () =>
            '123e4567-e89b-42d3-a456-${(426614174000 + nextId++).toString()}',
      );

      final duplicate = await store.duplicateBoard(source.id, 'Duplicate');
      expect(duplicate.paperTone, BoardPaperTone.blue);
      expect(
        (await store.loadBoard(duplicate.id)).paperTone,
        BoardPaperTone.blue,
      );

      final package = File('${root.path}${Platform.pathSeparator}tone.vasmim');
      await store.exportBoard(source.id, package.path);
      final imported = await store.importBoardAsCopy(package.path, 'Imported');
      expect(imported.paperTone, BoardPaperTone.blue);
      expect(
        (await store.loadBoard(imported.id)).paperTone,
        BoardPaperTone.blue,
      );
    },
  );

  test(
    'discovers valid boards in modification order with identity tie-break',
    () async {
      final older = _board(
        id: 'board-z',
        name: 'Older',
        modifiedAt: DateTime.utc(2026, 8, 12),
      );
      final newerB = _board(
        id: 'board-b',
        name: 'Newer B',
        modifiedAt: DateTime.utc(2026, 8, 13),
      );
      final newerA = _board(
        id: 'board-a',
        name: 'Newer A',
        modifiedAt: DateTime.utc(2026, 8, 13),
      );
      await _writeStoredBoard(root, older);
      await _writeStoredBoard(root, newerB);
      await _writeStoredBoard(root, newerA);

      final entries = await FileBoardLibraryStore(
        directoryProvider: () async => root,
      ).discover();

      expect(entries.map((entry) => entry.boardId), [
        'board-a',
        'board-b',
        'board-z',
      ]);
      expect(entries.every((entry) => entry.isAvailable), isTrue);
    },
  );

  test('loads only the requested current board document for preview', () async {
    final original = _board(id: 'board-a', name: 'Original');
    final untouched = _board(id: 'board-b', name: 'Untouched');
    await _writeStoredBoard(root, original);
    await _writeStoredBoard(root, untouched);
    final store = FileBoardLibraryStore(directoryProvider: () async => root);
    final discovered = await store.discover();
    expect(
      discovered.singleWhere((entry) => entry.boardId == 'board-a').board!.name,
      'Original',
    );

    await _writeStoredBoard(root, _board(id: 'board-a', name: 'Current'));

    expect((await store.loadBoard('board-a')).name, 'Current');
    expect((await store.loadBoard('board-b')).name, 'Untouched');
    final boardAFile = File(
      '${root.path}${Platform.pathSeparator}boards'
      '${Platform.pathSeparator}board-a${Platform.pathSeparator}board.json',
    );
    await boardAFile.writeAsString('{invalid json');
    await expectLater(store.loadBoard('board-a'), throwsA(anything));
    expect((await store.loadBoard('board-b')).name, 'Untouched');
  });

  test('isolates corrupt and mismatched boards from healthy boards', () async {
    await _writeStoredBoard(root, _board(id: 'healthy-board', name: 'Healthy'));
    final corruptDirectory = Directory(
      '${root.path}${Platform.pathSeparator}boards'
      '${Platform.pathSeparator}corrupt-board',
    );
    await corruptDirectory.create(recursive: true);
    await File(
      '${corruptDirectory.path}${Platform.pathSeparator}board.json',
    ).writeAsString('{broken');
    await _writeStoredBoard(
      root,
      _board(id: 'different-id', name: 'Mismatch'),
      directoryId: 'mismatched-board',
    );

    final entries = await FileBoardLibraryStore(
      directoryProvider: () async => root,
    ).discover();

    expect(entries.first.boardId, 'healthy-board');
    expect(entries.first.isAvailable, isTrue);
    expect(entries.where((entry) => !entry.isAvailable), hasLength(2));
    expect(
      entries
          .where((entry) => !entry.isAvailable)
          .map((entry) => entry.boardId),
      containsAll(['corrupt-board', 'mismatched-board']),
    );
  });

  test(
    'copies a legacy board and managed assets without deleting originals',
    () async {
      final assetDirectory = Directory(
        '${root.path}${Platform.pathSeparator}assets',
      );
      await assetDirectory.create();
      final legacyAsset = File(
        '${assetDirectory.path}${Platform.pathSeparator}legacy.png',
      );
      await legacyAsset.writeAsBytes([1, 2, 3, 4]);
      final legacyBoard = _board(
        id: 'legacy-board',
        name: 'Accepted board',
        images: [
          BoardImage(
            id: 'image-1',
            x: 100,
            y: 200,
            width: 320,
            height: 180,
            assetPath: 'assets/legacy.png',
            originalFileName: 'legacy.png',
            pixelWidth: 1920,
            pixelHeight: 1080,
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
          ),
        ],
      );
      final legacyBoardFile = File(
        '${root.path}${Platform.pathSeparator}board.json',
      );
      await legacyBoardFile.writeAsString(jsonEncode(legacyBoard.toJson()));

      final entries = await FileBoardLibraryStore(
        directoryProvider: () async => root,
      ).discover();

      expect(entries.single.board!.toJson(), legacyBoard.toJson());
      final migratedDirectory = Directory(
        '${root.path}${Platform.pathSeparator}boards'
        '${Platform.pathSeparator}legacy-board',
      );
      expect(
        await File(
          '${migratedDirectory.path}${Platform.pathSeparator}board.json',
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          '${migratedDirectory.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}legacy.png',
        ).readAsBytes(),
        [1, 2, 3, 4],
      );
      expect(await legacyBoardFile.exists(), isTrue);
      expect(await legacyAsset.exists(), isTrue);
    },
  );

  test(
    'rolls back an incomplete migration and preserves legacy data',
    () async {
      final legacyBoard = _board(
        id: 'legacy-board',
        name: 'Missing asset board',
        images: [
          BoardImage(
            id: 'image-1',
            x: 100,
            y: 200,
            width: 320,
            height: 180,
            assetPath: 'assets/missing.png',
            originalFileName: 'missing.png',
            pixelWidth: 1920,
            pixelHeight: 1080,
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
          ),
        ],
      );
      final legacyBoardFile = File(
        '${root.path}${Platform.pathSeparator}board.json',
      );
      await legacyBoardFile.writeAsString(jsonEncode(legacyBoard.toJson()));
      final store = FileBoardLibraryStore(directoryProvider: () async => root);

      final entries = await store.discover();

      expect(await legacyBoardFile.exists(), isTrue);
      expect(entries.single.isAvailable, isFalse);
      expect(entries.single.boardId, 'legacy-board');
      expect(
        await Directory(
          '${root.path}${Platform.pathSeparator}boards'
          '${Platform.pathSeparator}legacy-board',
        ).exists(),
        isFalse,
      );
    },
  );

  test('rejects unsafe board identifiers at the storage boundary', () async {
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    await expectLater(store.boardDirectory('../outside'), throwsArgumentError);
    await expectLater(store.boardDirectory(r'C:\outside'), throwsArgumentError);
  });

  test('does not resurrect a migrated legacy board after deletion', () async {
    final legacyBoard = _board(id: 'legacy-board', name: 'Legacy');
    final legacyBoardFile = File(
      '${root.path}${Platform.pathSeparator}board.json',
    );
    await legacyBoardFile.writeAsString(jsonEncode(legacyBoard.toJson()));
    final store = FileBoardLibraryStore(directoryProvider: () async => root);

    expect((await store.discover()).single.boardId, 'legacy-board');
    await store.deleteBoard('legacy-board');

    expect(await store.discover(), isEmpty);
    expect(await legacyBoardFile.exists(), isTrue);
  });

  test('scoped document stores never read or write another board', () async {
    final library = FileBoardLibraryStore(directoryProvider: () async => root);
    final boardAStore = FileBoardStore.scoped(
      boardDirectoryProvider: () => library.boardDirectory('board-a'),
    );
    final boardBStore = FileBoardStore.scoped(
      boardDirectoryProvider: () => library.boardDirectory('board-b'),
    );
    final boardA = _board(id: 'board-a', name: 'Board A');
    final boardB = _board(id: 'board-b', name: 'Board B');

    await boardAStore.save(boardA);
    await boardBStore.save(boardB);

    expect((await boardAStore.load())!.toJson(), boardA.toJson());
    expect((await boardBStore.load())!.toJson(), boardB.toJson());
  });

  test(
    'scoped asset stores resolve the same path inside different boards',
    () async {
      final library = FileBoardLibraryStore(
        directoryProvider: () async => root,
      );
      final boardAAssets = FileImageAssetStore.scoped(
        boardDirectoryProvider: () => library.boardDirectory('board-a'),
      );
      final boardBAssets = FileImageAssetStore.scoped(
        boardDirectoryProvider: () => library.boardDirectory('board-b'),
      );

      final resolvedA = await boardAAssets.resolve('assets/image.png');
      final resolvedB = await boardBAssets.resolve('assets/image.png');

      expect(resolvedA.path, isNot(resolvedB.path));
      expect(resolvedA.path, contains('board-a'));
      expect(resolvedB.path, contains('board-b'));
    },
  );

  test('creates, renames, and deletes one isolated board', () async {
    const generatedBoardId = '123e4567-e89b-42d3-a456-426614174000';
    final generatedIds = [
      generatedBoardId,
      '123e4567-e89b-42d3-b456-426614174001',
    ];
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () => generatedIds.removeAt(0),
    );

    final created = await store.createBoard('  Personal Plan  ');

    expect(created.id, generatedBoardId);
    expect(created.name, 'Personal Plan');
    expect(created.notes, hasLength(1));
    expect(created.notes.single.id, '123e4567-e89b-42d3-b456-426614174001');
    expect(created.isSnappingEnabled, isTrue);
    final renamed = await store.renameBoard(created.id, 'Main Plan');
    expect(renamed.id, created.id);
    expect(renamed.name, 'Main Plan');
    expect(renamed.notes.single.toJson(), created.notes.single.toJson());
    expect(renamed.isSnappingEnabled, isTrue);
    expect(
      renamed.modifiedAt.compareTo(created.modifiedAt),
      greaterThanOrEqualTo(0),
    );

    await store.deleteBoard(created.id);

    expect(await store.discover(), isEmpty);
  });

  test('creates a blank Kanban starter from ordinary Board objects', () async {
    var nextId = 0;
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () =>
          '123e4567-e89b-42d3-a456-${(426614174000 + nextId++).toString()}',
    );

    final board = await store.createBoard(
      'Campaign flow',
      starter: BoardStarter.kanban,
    );
    expect(board.name, 'Campaign flow');
    expect(board.notes, isEmpty);
    expect(board.shapes, hasLength(3));
    expect(
      board.shapes.every(
        (shape) => shape.type == BoardShapeType.roundedRectangle,
      ),
      isTrue,
    );
    expect(board.headings.map((heading) => heading.text), [
      'To do',
      'In progress',
      'Done',
    ]);
    expect(
      board.shapeLayers.single.shapeIds,
      board.shapes.map((shape) => shape.id),
    );
    expect(board.viewportZoom, 0.5);
    expect(board.isSnappingEnabled, isTrue);

    final directory = await store.boardDirectory(board.id);
    final reopened = BoardDocument.fromJson(
      jsonDecode(
            await File(
              '${directory.path}${Platform.pathSeparator}board.json',
            ).readAsString(),
          )
          as Map<String, dynamic>,
    );
    expect(reopened.toJson(), board.toJson());
  });

  test('creates and reopens an empty Eisenhower matrix', () async {
    var nextId = 0;
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () =>
          '123e4567-e89b-42d3-a456-${(426614174000 + nextId++).toString()}',
    );

    final board = await store.createBoard(
      'Priorities',
      starter: BoardStarter.eisenhower,
    );
    expect(board.notes, isEmpty);
    expect(board.shapes, hasLength(4));
    expect(board.shapes.map((shape) => (shape.x, shape.y)), [
      (200.0, 240.0),
      (1040.0, 240.0),
      (200.0, 840.0),
      (1040.0, 840.0),
    ]);
    expect(
      board.shapes.every(
        (shape) =>
            shape.type == BoardShapeType.roundedRectangle &&
            shape.width == 760 &&
            shape.height == 520,
      ),
      isTrue,
    );
    expect(board.headings.map((heading) => heading.text), [
      'Important + urgent',
      'Important + not urgent',
      'Not important + urgent',
      'Not important + not urgent',
    ]);
    expect(
      board.shapeLayers.single.shapeIds,
      board.shapes.map((shape) => shape.id),
    );
    expect(board.viewportZoom, 0.5);
    expect(board.isSnappingEnabled, isTrue);

    final reopened = await store.loadBoard(board.id);
    expect(reopened.toJson(), board.toJson());
  });

  test('creates and reopens an empty SWOT matrix', () async {
    var nextId = 0;
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () =>
          '123e4567-e89b-42d3-a456-${(426614174000 + nextId++).toString()}',
    );

    final board = await store.createBoard(
      'Campaign review',
      starter: BoardStarter.swot,
    );
    expect(board.notes, isEmpty);
    expect(board.shapes, hasLength(4));
    expect(board.shapes.map((shape) => (shape.x, shape.y)), [
      (200.0, 240.0),
      (1040.0, 240.0),
      (200.0, 840.0),
      (1040.0, 840.0),
    ]);
    expect(board.headings.map((heading) => heading.text), [
      'Strengths',
      'Weaknesses',
      'Opportunities',
      'Threats',
    ]);
    expect(
      board.shapeLayers.single.shapeIds,
      board.shapes.map((shape) => shape.id),
    );
    expect(board.viewportZoom, 0.5);
    expect(board.isSnappingEnabled, isTrue);
    expect((await store.loadBoard(board.id)).toJson(), board.toJson());
  });

  test('creates and reopens an empty campaign brief', () async {
    var nextId = 0;
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () =>
          '123e4567-e89b-42d3-a456-${(426614174000 + nextId++).toString()}',
    );

    final board = await store.createBoard(
      'Launch campaign',
      starter: BoardStarter.campaignBrief,
    );
    expect(board.notes, isEmpty);
    expect(board.shapes, hasLength(6));
    expect(board.shapes.map((shape) => (shape.x, shape.y)), [
      (160.0, 180.0),
      (700.0, 180.0),
      (1240.0, 180.0),
      (160.0, 660.0),
      (700.0, 660.0),
      (1240.0, 660.0),
    ]);
    expect(
      board.shapes.every(
        (shape) =>
            shape.type == BoardShapeType.roundedRectangle &&
            shape.width == 460 &&
            shape.height == 400,
      ),
      isTrue,
    );
    expect(board.headings.map((heading) => heading.text), [
      'Goal',
      'Audience',
      'Message',
      'Channels',
      'Schedule',
      'Measures',
    ]);
    expect(
      board.shapeLayers.single.shapeIds,
      board.shapes.map((shape) => shape.id),
    );
    expect(board.viewportZoom, 0.4);
    expect(board.isSnappingEnabled, isTrue);
    expect((await store.loadBoard(board.id)).toJson(), board.toJson());
  });

  test('rejects non-UUID identities generated for a new board', () async {
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () => 'not-a-uuid',
    );

    await expectLater(store.createBoard('Invalid'), throwsStateError);
    expect(await store.discover(), isEmpty);
  });

  test(
    'duplicates complete board state and assets under an independent identity',
    () async {
      const duplicateId = '123e4567-e89b-42d3-a456-426614174000';
      final source = _board(
        id: 'source-board',
        name: 'Source',
        notes: [
          Note(
            id: 'note-1',
            x: 120,
            y: 240,
            width: 260,
            height: 170,
            text: 'Preserve me',
            title: 'Release plan',
            emphasis: const [NoteEmphasisRange(start: 0, end: 8, bold: true)],
            links: const [
              NoteTextLinkRange(
                start: 9,
                end: 11,
                destination: 'https://example.com',
              ),
            ],
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
            color: NoteColor.blue,
          ),
        ],
        images: [
          BoardImage(
            id: 'image-1',
            x: 40,
            y: 80,
            width: 320,
            height: 180,
            assetPath: 'assets/shared.png',
            originalFileName: 'source.png',
            pixelWidth: 1920,
            pixelHeight: 1080,
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
          ),
        ],
        connectors: [
          Connector(
            id: 'connector-1',
            objectAId: 'note-1',
            objectBId: 'image-1',
            label: 'illustrated by',
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
          ),
        ],
        shapes: [
          BoardShape(
            id: 'shape-1',
            type: BoardShapeType.predefinedProcess,
            x: 20,
            y: 30,
            width: 500,
            height: 300,
            heading: const ShapeHeading(text: 'Planning area'),
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
          ),
        ],
        shapeLayers: [
          ShapeLayer(
            id: 'shape-layer-background',
            name: 'Background',
            shapeIds: const ['shape-1'],
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
            isVisible: false,
            opacity: 0.25,
          ),
          ShapeLayer(
            id: 'shape-layer-overlay',
            name: 'Overlay',
            shapeIds: const [],
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
            opacity: 0.75,
          ),
        ],
        scenes: [
          Scene(
            id: '123e4567-e89b-42d3-a456-426614174099',
            name: 'Overview',
            x: 90,
            y: 120,
            zoom: 0.8,
            createdAt: DateTime.utc(2026, 8, 12),
            modifiedAt: DateTime.utc(2026, 8, 13),
          ),
        ],
      );
      await _writeStoredBoard(root, source);
      final sourceDirectory = Directory(
        '${root.path}${Platform.pathSeparator}boards'
        '${Platform.pathSeparator}${source.id}',
      );
      final sourceBoardFile = File(
        '${sourceDirectory.path}${Platform.pathSeparator}board.json',
      );
      final sourceAsset = File(
        '${sourceDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      await sourceAsset.parent.create(recursive: true);
      await sourceAsset.writeAsBytes([1, 3, 3, 7]);
      final sourceJsonBefore = await sourceBoardFile.readAsString();
      final store = FileBoardLibraryStore(
        directoryProvider: () async => root,
        idGenerator: () => duplicateId,
      );

      final duplicate = await store.duplicateBoard(
        source.id,
        '  Alternative Roadmap  ',
      );

      expect(duplicate.id, duplicateId);
      expect(duplicate.name, 'Alternative Roadmap');
      expect(duplicate.createdAt, duplicate.modifiedAt);
      expect(duplicate.createdAt.isAfter(source.modifiedAt), isTrue);
      expect(duplicate.viewportX, source.viewportX);
      expect(duplicate.viewportY, source.viewportY);
      expect(duplicate.viewportZoom, source.viewportZoom);
      expect(duplicate.isSnappingEnabled, source.isSnappingEnabled);
      expect(
        duplicate.notes.map((note) => note.toJson()),
        source.notes.map((note) => note.toJson()),
      );
      expect(
        duplicate.connectors.map((connector) => connector.toJson()),
        source.connectors.map((connector) => connector.toJson()),
      );
      expect(
        duplicate.images.map((image) => image.toJson()),
        source.images.map((image) => image.toJson()),
      );
      expect(
        duplicate.scenes.map((scene) => scene.toJson()),
        source.scenes.map((scene) => scene.toJson()),
      );
      expect(
        duplicate.shapes.map((shape) => shape.toJson()),
        source.shapes.map((shape) => shape.toJson()),
      );
      expect(
        duplicate.shapeLayers.map((layer) => layer.toJson()),
        source.shapeLayers.map((layer) => layer.toJson()),
      );
      final duplicateDirectory = await store.boardDirectory(duplicateId);
      final duplicateAsset = File(
        '${duplicateDirectory.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}shared.png',
      );
      expect(duplicateAsset.path, isNot(sourceAsset.path));
      expect(await duplicateAsset.readAsBytes(), [1, 3, 3, 7]);
      await duplicateAsset.writeAsBytes([9, 9]);
      expect(await sourceAsset.readAsBytes(), [1, 3, 3, 7]);
      expect(await sourceBoardFile.readAsString(), sourceJsonBefore);

      await store.deleteBoard(duplicate.id);
      expect(await sourceBoardFile.readAsString(), sourceJsonBefore);
      expect(await sourceAsset.readAsBytes(), [1, 3, 3, 7]);
    },
  );

  test('publishes no duplicate when a referenced asset is missing', () async {
    const duplicateId = '123e4567-e89b-42d3-a456-426614174000';
    final source = _board(
      id: 'source-board',
      name: 'Source',
      images: [
        BoardImage(
          id: 'image-1',
          x: 40,
          y: 80,
          width: 320,
          height: 180,
          assetPath: 'assets/missing.png',
          originalFileName: 'missing.png',
          pixelWidth: 1920,
          pixelHeight: 1080,
          createdAt: DateTime.utc(2026, 8, 12),
          modifiedAt: DateTime.utc(2026, 8, 13),
        ),
      ],
    );
    await _writeStoredBoard(root, source);
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () => duplicateId,
    );

    await expectLater(
      store.duplicateBoard(source.id, 'Copy'),
      throwsA(
        isA<BoardTransferException>().having(
          (error) => error.kind,
          'kind',
          BoardTransferFailureKind.missingAsset,
        ),
      ),
    );

    expect(await (await store.boardDirectory(duplicateId)).exists(), isFalse);
    expect((await store.discover()).single.board!.id, source.id);
  });

  test('publishes no duplicate from an invalid source document', () async {
    const duplicateId = '123e4567-e89b-42d3-a456-426614174000';
    final sourceDirectory = Directory(
      '${root.path}${Platform.pathSeparator}boards'
      '${Platform.pathSeparator}corrupt-board',
    );
    await sourceDirectory.create(recursive: true);
    final sourceFile = File(
      '${sourceDirectory.path}${Platform.pathSeparator}board.json',
    );
    await sourceFile.writeAsString('{not valid json');
    final store = FileBoardLibraryStore(
      directoryProvider: () async => root,
      idGenerator: () => duplicateId,
    );

    await expectLater(
      store.duplicateBoard('corrupt-board', 'Copy'),
      throwsA(anything),
    );

    expect(await sourceFile.readAsString(), '{not valid json');
    expect(await (await store.boardDirectory(duplicateId)).exists(), isFalse);
    final entry = (await store.discover()).single;
    expect(entry.boardId, 'corrupt-board');
    expect(entry.isAvailable, isFalse);
  });

  test(
    'deleting one board leaves another board and its assets unchanged',
    () async {
      final library = FileBoardLibraryStore(
        directoryProvider: () async => root,
      );
      final boardA = _board(id: 'board-a', name: 'Board A');
      final boardB = _board(id: 'board-b', name: 'Board B');
      await _writeStoredBoard(root, boardA);
      await _writeStoredBoard(root, boardB);
      final boardBAsset = File(
        '${root.path}${Platform.pathSeparator}boards'
        '${Platform.pathSeparator}board-b${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}keep.png',
      );
      await boardBAsset.parent.create(recursive: true);
      await boardBAsset.writeAsBytes([4, 3, 2, 1]);

      await library.deleteBoard('board-a');

      final entries = await library.discover();
      expect(entries.single.board!.toJson(), boardB.toJson());
      expect(await boardBAsset.readAsBytes(), [4, 3, 2, 1]);
    },
  );
}

BoardDocument _board({
  required String id,
  required String name,
  DateTime? modifiedAt,
  List<Note> notes = const [],
  List<Connector> connectors = const [],
  List<BoardImage> images = const [],
  List<Scene> scenes = const [],
  List<BoardShape> shapes = const [],
  List<ShapeLayer>? shapeLayers,
}) {
  final createdAt = DateTime.utc(2026, 8, 12);
  return BoardDocument(
    id: id,
    name: name,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: notes,
    connectors: connectors,
    images: images,
    scenes: scenes,
    shapes: shapes,
    shapeLayers: shapeLayers,
  );
}

Future<void> _writeStoredBoard(
  Directory root,
  BoardDocument board, {
  String? directoryId,
}) async {
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}boards'
    '${Platform.pathSeparator}${directoryId ?? board.id}',
  );
  await directory.create(recursive: true);
  await File(
    '${directory.path}${Platform.pathSeparator}board.json',
  ).writeAsString(jsonEncode(board.toJson()));
}
