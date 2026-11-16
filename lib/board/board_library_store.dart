import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../note/note.dart';
import '../heading/canvas_heading.dart';
import '../shape/board_shape.dart';
import 'backup_manifest.dart';
import 'board_document.dart';
import 'board_file_persistence.dart';
import 'board_starter.dart';
import 'library_folder.dart';
import 'portable_board_naming.dart';
import 'portable_board_limits.dart';

typedef FavoriteMetadataCommitter =
    Future<void> Function(File stagedFile, File targetFile);

enum BoardTransferFailureKind {
  invalidArchive,
  unsupportedPackageVersion,
  duplicateBoard,
  missingAsset,
  fileSystem,
}

class BoardTransferException implements Exception {
  const BoardTransferException(
    this.kind,
    this.message, [
    this.cause,
    this.conflict,
  ]);

  final BoardTransferFailureKind kind;
  final String message;
  final Object? cause;
  final BoardImportConflict? conflict;

  @override
  String toString() => 'BoardTransferException($kind): $message';
}

class BoardImportConflict {
  const BoardImportConflict({required this.boardId, required this.boardName});

  final String boardId;
  final String boardName;
}

enum BoardLibraryBackupFailureKind {
  noBoards,
  unavailableBoards,
  boardExport,
  missingManifest,
  invalidManifest,
  invalidPackage,
  fileSystem,
}

class BoardLibraryBackupException implements Exception {
  const BoardLibraryBackupException(
    this.kind,
    this.message, {
    this.cause,
    this.unavailableBoardCount = 0,
  });

  final BoardLibraryBackupFailureKind kind;
  final String message;
  final Object? cause;
  final int unavailableBoardCount;

  @override
  String toString() => 'BoardLibraryBackupException($kind): $message';
}

class BoardLibraryBackupResult {
  const BoardLibraryBackupResult({
    required this.directoryPath,
    required this.folderName,
    required this.boardCount,
  });

  final String directoryPath;
  final String folderName;
  final int boardCount;
}

class BoardLibraryBackupVerificationResult {
  const BoardLibraryBackupVerificationResult({required this.boardCount});

  final int boardCount;
}

class BoardLibraryEntry {
  BoardLibraryEntry.available(BoardDocument availableBoard)
    : boardId = availableBoard.id,
      board = availableBoard,
      error = null;

  const BoardLibraryEntry.unavailable({
    required this.boardId,
    required this.error,
  }) : board = null;

  final String boardId;
  final BoardDocument? board;
  final String? error;

  bool get isAvailable => board != null;
}

abstract interface class BoardLibraryStore {
  Future<List<BoardLibraryEntry>> discover();

  Future<BoardDocument> loadBoard(String boardId);

  Future<Set<String>> favoriteBoardIds();

  Future<void> setBoardFavorite(String boardId, bool isFavorite);

  Future<LibraryFolderState> libraryFolderState();

  Future<LibraryFolder> createLibraryFolder(String name);

  Future<LibraryFolder> renameLibraryFolder(String folderId, String name);

  Future<void> deleteLibraryFolder(String folderId);

  Future<void> setBoardFolder(String boardId, String? folderId);

  Future<BoardDocument> createBoard(
    String name, {
    BoardStarter starter = BoardStarter.blank,
  });

  Future<BoardDocument> renameBoard(String boardId, String name);

  Future<BoardDocument> duplicateBoard(String boardId, String name);

  Future<void> deleteBoard(String boardId);

  Future<void> exportBoard(String boardId, String destinationPath);

  Future<BoardLibraryBackupResult> exportAllBoards(String parentDirectoryPath);

  Future<BoardLibraryBackupVerificationResult> verifyBackupFolder(
    String directoryPath,
  );

  Future<BoardDocument> importBoard(String sourcePath);

  Future<BoardDocument> importBoardAsCopy(String sourcePath, String name);

  Future<Directory> boardDirectory(String boardId);
}

class FileBoardLibraryStore implements BoardLibraryStore {
  FileBoardLibraryStore({
    Future<Directory> Function()? directoryProvider,
    String Function()? idGenerator,
    DateTime Function()? clock,
    FavoriteMetadataCommitter? favoriteMetadataCommitter,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _favoriteMetadataCommitter =
           favoriteMetadataCommitter ?? _commitFavoriteMetadata;

  static const boardsDirectoryName = 'boards';
  static const favoriteMetadataFileName = 'library_preferences.json';
  static const folderMetadataFileName = 'library_folders.json';
  static const _favoriteMetadataVersion = 1;
  static const _folderMetadataVersion = 1;
  static const packageFormatVersion = 1;
  static const portableBoardExtension = '.vasmim';
  static const legacyPortableBoardExtension = '.freeform';
  static const _legacyMigrationMarkerName = '.legacy-board-migrated';
  static const _transferStagingDirectoryName = '.transfers';
  static final _safeBoardId = RegExp(r'^[A-Za-z0-9_-]+$');
  static final _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final _canonicalAssetPath = RegExp(
    r'^assets/[A-Za-z0-9_-]+\.(png|jpe?g|gif|pdf|doc|docx|xls|xlsx|mp4|m4v|mov|mkv|avi|webm|mp3|wav|m4a|flac|ogg)$',
    caseSensitive: false,
  );

  final Future<Directory> Function() _directoryProvider;
  final String Function() _idGenerator;
  final DateTime Function() _clock;
  final FavoriteMetadataCommitter _favoriteMetadataCommitter;

  @override
  Future<LibraryFolderState> libraryFolderState() async {
    final root = await _directoryProvider();
    final file = File(
      '${root.path}${Platform.pathSeparator}$folderMetadataFileName',
    );
    final backup = File('${file.path}.backup');
    if (!await file.exists()) {
      if (await backup.exists()) {
        await backup.rename(file.path);
      } else {
        return LibraryFolderState();
      }
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['version'] != _folderMetadataVersion) {
      throw const FormatException('Library folder metadata is invalid.');
    }
    final rawFolders = decoded['folders'];
    final rawMembership = decoded['boardFolderIds'];
    if (rawFolders is! List || rawMembership is! Map) {
      throw const FormatException('Library folder metadata is invalid.');
    }
    final folders = <LibraryFolder>[];
    final ids = <String>{};
    final names = <String>{};
    for (final raw in rawFolders) {
      if (raw is! Map) {
        throw const FormatException('A Library folder is invalid.');
      }
      final folder = LibraryFolder.fromJson(Map<String, dynamic>.from(raw));
      if (!_isSafeBoardId(folder.id) ||
          !ids.add(folder.id) ||
          !names.add(folder.name.toLowerCase())) {
        throw const FormatException(
          'Library folders must have unique identities and names.',
        );
      }
      folders.add(folder);
    }
    final membership = <String, String>{};
    for (final entry in rawMembership.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          !_isSafeBoardId(entry.key as String) ||
          !ids.contains(entry.value)) {
        throw const FormatException('Library folder membership is invalid.');
      }
      membership[entry.key as String] = entry.value as String;
    }
    return LibraryFolderState(folders: folders, boardFolderIds: membership);
  }

  @override
  Future<LibraryFolder> createLibraryFolder(String name) async {
    final normalized = LibraryFolder.normalizeName(name);
    final state = await libraryFolderState();
    if (state.folders.any(
      (folder) => folder.name.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw ArgumentError.value(name, 'name', 'Folder names must be unique.');
    }
    final id = _idGenerator();
    if (!_uuidV4.hasMatch(id)) {
      throw StateError('The folder ID generator must return a UUID-v4 value.');
    }
    final now = _clock();
    final folder = LibraryFolder(
      id: id,
      name: normalized,
      createdAt: now,
      modifiedAt: now,
    );
    await _writeLibraryFolderState(
      LibraryFolderState(
        folders: [...state.folders, folder],
        boardFolderIds: state.boardFolderIds,
      ),
    );
    return folder;
  }

  @override
  Future<LibraryFolder> renameLibraryFolder(
    String folderId,
    String name,
  ) async {
    final normalized = LibraryFolder.normalizeName(name);
    final state = await libraryFolderState();
    final index = state.folders.indexWhere((folder) => folder.id == folderId);
    if (index < 0) {
      throw StateError('The Library folder no longer exists.');
    }
    if (state.folders.any(
      (folder) =>
          folder.id != folderId &&
          folder.name.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw ArgumentError.value(name, 'name', 'Folder names must be unique.');
    }
    final folders = [...state.folders];
    folders[index] = folders[index].copyWith(
      name: normalized,
      modifiedAt: _clock(),
    );
    await _writeLibraryFolderState(
      LibraryFolderState(
        folders: folders,
        boardFolderIds: state.boardFolderIds,
      ),
    );
    return folders[index];
  }

  @override
  Future<void> deleteLibraryFolder(String folderId) async {
    final state = await libraryFolderState();
    if (state.boardFolderIds.containsValue(folderId)) {
      throw StateError('Only empty Library folders can be deleted.');
    }
    final folders = state.folders
        .where((folder) => folder.id != folderId)
        .toList();
    if (folders.length == state.folders.length) {
      throw StateError('The Library folder no longer exists.');
    }
    await _writeLibraryFolderState(
      LibraryFolderState(
        folders: folders,
        boardFolderIds: state.boardFolderIds,
      ),
    );
  }

  @override
  Future<void> setBoardFolder(String boardId, String? folderId) async {
    await loadBoard(boardId);
    final state = await libraryFolderState();
    if (folderId != null &&
        !state.folders.any((folder) => folder.id == folderId)) {
      throw StateError('The Library folder no longer exists.');
    }
    final membership = {...state.boardFolderIds};
    folderId == null
        ? membership.remove(boardId)
        : membership[boardId] = folderId;
    await _writeLibraryFolderState(
      LibraryFolderState(folders: state.folders, boardFolderIds: membership),
    );
  }

  @override
  Future<BoardDocument> loadBoard(String boardId) async {
    final directory = await boardDirectory(boardId);
    final board = await _readBoard(
      File('${directory.path}${Platform.pathSeparator}board.json'),
    );
    if (board.id != boardId) {
      throw const FormatException(
        'Board identifier does not match its storage directory.',
      );
    }
    return board;
  }

  @override
  Future<Set<String>> favoriteBoardIds() async {
    final root = await _directoryProvider();
    final file = File(
      '${root.path}${Platform.pathSeparator}$favoriteMetadataFileName',
    );
    final backupFile = File('${file.path}.backup');
    if (!await file.exists()) {
      if (await backupFile.exists()) {
        await backupFile.rename(file.path);
      } else {
        return const {};
      }
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['version'] != _favoriteMetadataVersion) {
      throw const FormatException('Library preferences are invalid.');
    }
    final rawIds = decoded['favoriteBoardIds'];
    if (rawIds is! List) {
      throw const FormatException('Favorite board IDs must be a list.');
    }
    final ids = <String>{};
    for (final rawId in rawIds) {
      if (rawId is! String || !_isSafeBoardId(rawId) || !ids.add(rawId)) {
        throw const FormatException('Favorite board IDs are invalid.');
      }
    }
    return Set.unmodifiable(ids);
  }

  @override
  Future<void> setBoardFavorite(String boardId, bool isFavorite) async {
    if (!_isSafeBoardId(boardId)) {
      throw ArgumentError.value(
        boardId,
        'boardId',
        'Board identifiers must contain only letters, numbers, underscores, and hyphens.',
      );
    }
    if (isFavorite) {
      final directory = await boardDirectory(boardId);
      final board = await _readBoard(
        File('${directory.path}${Platform.pathSeparator}board.json'),
      );
      if (board.id != boardId) {
        throw const FormatException(
          'Board identifier does not match its storage directory.',
        );
      }
    }
    final ids = {...await favoriteBoardIds()};
    final changed = isFavorite ? ids.add(boardId) : ids.remove(boardId);
    if (!changed) {
      return;
    }
    await _writeFavoriteBoardIds(ids);
  }

  @override
  Future<BoardDocument> createBoard(
    String name, {
    BoardStarter starter = BoardStarter.blank,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Board names must be non-empty.');
    }
    final boardId = _idGenerator();
    if (!_uuidV4.hasMatch(boardId)) {
      throw StateError('The board ID generator must return a UUID-v4 value.');
    }
    final directory = await boardDirectory(boardId);
    if (await directory.exists()) {
      throw StateError('A board with the generated identifier already exists.');
    }
    final now = DateTime.now().toUtc();
    String nextObjectId() {
      final id = _idGenerator();
      if (!_uuidV4.hasMatch(id)) {
        throw StateError(
          'The object ID generator must return a UUID-v4 value.',
        );
      }
      return id;
    }

    final blankNoteId = starter == BoardStarter.blank ? nextObjectId() : null;
    final layout = switch (starter) {
      BoardStarter.blank => (
        labels: const <String>[],
        lefts: const <double>[],
        tops: const <double>[],
        width: 0.0,
        height: 0.0,
        headingInsetX: 0.0,
        headingInsetY: 0.0,
        headingSize: CanvasHeadingSize.small,
      ),
      BoardStarter.kanban => (
        labels: const ['To do', 'In progress', 'Done'],
        lefts: const [200.0, 760.0, 1320.0],
        tops: const [240.0, 240.0, 240.0],
        width: 480.0,
        height: 1000.0,
        headingInsetX: 120.0,
        headingInsetY: 50.0,
        headingSize: CanvasHeadingSize.large,
      ),
      BoardStarter.eisenhower => (
        labels: const [
          'Important + urgent',
          'Important + not urgent',
          'Not important + urgent',
          'Not important + not urgent',
        ],
        lefts: const [200.0, 1040.0, 200.0, 1040.0],
        tops: const [240.0, 240.0, 840.0, 840.0],
        width: 760.0,
        height: 520.0,
        headingInsetX: 80.0,
        headingInsetY: 45.0,
        headingSize: CanvasHeadingSize.small,
      ),
      BoardStarter.swot => (
        labels: const ['Strengths', 'Weaknesses', 'Opportunities', 'Threats'],
        lefts: const [200.0, 1040.0, 200.0, 1040.0],
        tops: const [240.0, 240.0, 840.0, 840.0],
        width: 760.0,
        height: 520.0,
        headingInsetX: 80.0,
        headingInsetY: 45.0,
        headingSize: CanvasHeadingSize.medium,
      ),
      BoardStarter.campaignBrief => (
        labels: const [
          'Goal',
          'Audience',
          'Message',
          'Channels',
          'Schedule',
          'Measures',
        ],
        lefts: const [160.0, 700.0, 1240.0, 160.0, 700.0, 1240.0],
        tops: const [180.0, 180.0, 180.0, 660.0, 660.0, 660.0],
        width: 460.0,
        height: 400.0,
        headingInsetX: 40.0,
        headingInsetY: 35.0,
        headingSize: CanvasHeadingSize.large,
      ),
    };
    final panelShapeIds = [
      for (var i = 0; i < layout.labels.length; i++) nextObjectId(),
    ];
    final panelHeadingIds = [
      for (var i = 0; i < layout.labels.length; i++) nextObjectId(),
    ];
    await _ensureNonFavorite(boardId);
    await _ensureUnfiled(boardId);
    final board = BoardDocument(
      id: boardId,
      name: trimmedName,
      createdAt: now,
      modifiedAt: now,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: switch (starter) {
        BoardStarter.blank => 1,
        BoardStarter.campaignBrief => 0.4,
        _ => 0.5,
      },
      notes: blankNoteId == null
          ? const []
          : [
              Note(
                id: blankNoteId,
                x: 320,
                y: 240,
                width: 260,
                height: 170,
                text: '',
                createdAt: now,
                modifiedAt: now,
              ),
            ],
      shapes: [
        for (var i = 0; i < panelShapeIds.length; i++)
          BoardShape(
            id: panelShapeIds[i],
            type: BoardShapeType.roundedRectangle,
            x: layout.lefts[i],
            y: layout.tops[i],
            width: layout.width,
            height: layout.height,
            outlineColorValue: 0xFF778DA8,
            outlineWidth: 4,
            createdAt: now,
            modifiedAt: now,
          ),
      ],
      headings: [
        for (var i = 0; i < panelHeadingIds.length; i++)
          CanvasHeading(
            id: panelHeadingIds[i],
            x: layout.lefts[i] + layout.headingInsetX,
            y: layout.tops[i] + layout.headingInsetY,
            text: layout.labels[i],
            size: layout.headingSize,
            background: CanvasHeadingBackground.transparent,
            createdAt: now,
            modifiedAt: now,
          ),
      ],
      isSnappingEnabled: true,
    );
    await directory.create(recursive: true);
    try {
      await _writeBoard(directory, board);
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
    return board;
  }

  @override
  Future<BoardDocument> renameBoard(String boardId, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Board names must be non-empty.');
    }
    final directory = await boardDirectory(boardId);
    final board = await _readBoard(
      File('${directory.path}${Platform.pathSeparator}board.json'),
    );
    if (board.id != boardId) {
      throw const FormatException(
        'Board identifier does not match its storage directory.',
      );
    }
    final renamed = board.copyWith(
      name: trimmedName,
      modifiedAt: DateTime.now().toUtc(),
    );
    await _writeBoard(directory, renamed);
    return renamed;
  }

  @override
  Future<BoardDocument> duplicateBoard(String boardId, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Board names must be non-empty.');
    }

    Directory? stagingDirectory;
    try {
      final sourceDirectory = await boardDirectory(boardId);
      final source = await _readBoard(
        File('${sourceDirectory.path}${Platform.pathSeparator}board.json'),
      );
      if (source.id != boardId) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The stored board identity does not match its directory.',
        );
      }

      final assets = <String, File>{};
      for (final assetPathValue in [
        ...source.images.map((image) => image.assetPath),
        ...source.attachments.map((attachment) => attachment.assetPath),
        ...source.attachments
            .map((attachment) => attachment.previewAssetPath)
            .whereType<String>(),
        ...source.youTubeEmbeds
            .map((embed) => embed.thumbnailAssetPath)
            .whereType<String>(),
      ]) {
        final assetPath = assetPathValue.replaceAll('\\', '/');
        if (!_canonicalAssetPath.hasMatch(assetPath)) {
          throw const BoardTransferException(
            BoardTransferFailureKind.invalidArchive,
            'The board contains a non-canonical managed asset path.',
          );
        }
        final asset = File(
          '${sourceDirectory.path}${Platform.pathSeparator}'
          '${assetPath.replaceAll('/', Platform.pathSeparator)}',
        );
        if (await FileSystemEntity.type(asset.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw BoardTransferException(
            BoardTransferFailureKind.missingAsset,
            'A referenced managed image is missing: $assetPath',
          );
        }
        assets[assetPath] = asset;
      }

      final duplicateId = _idGenerator();
      if (!_uuidV4.hasMatch(duplicateId)) {
        throw StateError('The board ID generator must return a UUID-v4 value.');
      }
      final targetDirectory = await boardDirectory(duplicateId);
      if (await targetDirectory.exists()) {
        throw const BoardTransferException(
          BoardTransferFailureKind.duplicateBoard,
          'A board with the generated identity already exists.',
        );
      }
      await _ensureNonFavorite(duplicateId);
      await _ensureUnfiled(duplicateId);

      final now = DateTime.now().toUtc();
      final duplicate = BoardDocument(
        id: duplicateId,
        name: trimmedName,
        createdAt: now,
        modifiedAt: now,
        viewportX: source.viewportX,
        viewportY: source.viewportY,
        viewportZoom: source.viewportZoom,
        notes: source.notes,
        connectors: source.connectors,
        images: source.images,
        scenes: source.scenes,
        headings: source.headings,
        attachments: source.attachments,
        youTubeEmbeds: source.youTubeEmbeds,
        shapes: source.shapes,
        shapeLayers: source.shapeLayers,
        groups: source.groups,
        isSnappingEnabled: source.isSnappingEnabled,
        paperTone: source.paperTone,
        lockedObjectIds: source.lockedObjectIds,
      );

      final root = await _directoryProvider();
      final transfersDirectory = Directory(
        '${root.path}${Platform.pathSeparator}$_transferStagingDirectoryName',
      );
      await transfersDirectory.create(recursive: true);
      stagingDirectory = await transfersDirectory.createTemp('duplicate-');
      await _writeBoard(stagingDirectory, duplicate);
      for (final entry in assets.entries) {
        final target = File(
          '${stagingDirectory.path}${Platform.pathSeparator}'
          '${entry.key.replaceAll('/', Platform.pathSeparator)}',
        );
        await target.parent.create(recursive: true);
        await entry.value.copy(target.path);
        await _verifyFileCrc(target, await _calculateFileCrc(entry.value));
      }

      if (await targetDirectory.exists()) {
        throw const BoardTransferException(
          BoardTransferFailureKind.duplicateBoard,
          'A board with the generated identity already exists.',
        );
      }
      await targetDirectory.parent.create(recursive: true);
      await stagingDirectory.rename(targetDirectory.path);
      stagingDirectory = null;
      return duplicate;
    } on BoardTransferException {
      rethrow;
    } on FileSystemException catch (error) {
      throw BoardTransferException(
        BoardTransferFailureKind.fileSystem,
        'The board could not be duplicated.',
        error,
      );
    } finally {
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    // Read metadata before deleting, but only change membership after removal
    // succeeds. A locked file must not unfile/unfavorite a surviving Board.
    final favoriteIds = {...await favoriteBoardIds()};
    final folderState = await libraryFolderState();
    final directory = await boardDirectory(boardId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    if (favoriteIds.remove(boardId)) {
      await _writeFavoriteBoardIds(favoriteIds);
    }
    if (folderState.boardFolderIds.containsKey(boardId)) {
      final membership = {...folderState.boardFolderIds}..remove(boardId);
      await _writeLibraryFolderState(
        LibraryFolderState(
          folders: folderState.folders,
          boardFolderIds: membership,
        ),
      );
    }
  }

  @override
  Future<void> exportBoard(String boardId, String destinationPath) async {
    Directory? stagingDirectory;
    ZipFileEncoder? encoder;
    var encoderClosed = false;
    try {
      final sourceDirectory = await boardDirectory(boardId);
      final board = await _readBoard(
        File('${sourceDirectory.path}${Platform.pathSeparator}board.json'),
      );
      if (board.id != boardId) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The stored board identity does not match its directory.',
        );
      }

      final assets = <String, File>{};
      for (final assetPathValue in [
        ...board.images.map((image) => image.assetPath),
        ...board.attachments.map((attachment) => attachment.assetPath),
        ...board.attachments
            .map((attachment) => attachment.previewAssetPath)
            .whereType<String>(),
        ...board.youTubeEmbeds
            .map((embed) => embed.thumbnailAssetPath)
            .whereType<String>(),
      ]) {
        final assetPath = assetPathValue.replaceAll('\\', '/');
        if (!_canonicalAssetPath.hasMatch(assetPath)) {
          throw const BoardTransferException(
            BoardTransferFailureKind.invalidArchive,
            'The board contains a non-canonical managed asset path.',
          );
        }
        final asset = File(
          '${sourceDirectory.path}${Platform.pathSeparator}'
          '${assetPath.replaceAll('/', Platform.pathSeparator)}',
        );
        final entityType = await FileSystemEntity.type(
          asset.path,
          followLinks: false,
        );
        if (entityType != FileSystemEntityType.file) {
          throw BoardTransferException(
            BoardTransferFailureKind.missingAsset,
            'A referenced managed image is missing: $assetPath',
          );
        }
        assets[assetPath] = asset;
      }

      final documentBytes = utf8.encode(jsonEncode(board.toJson())).length;
      var totalBytes = documentBytes;
      if (assets.length + 2 > PortableBoardLimits.maximumEntries ||
          documentBytes > PortableBoardLimits.maximumJsonBytes) {
        throw const FormatException('Board exceeds portable export limits.');
      }
      for (final asset in assets.values) {
        final size = await asset.length();
        totalBytes += size;
        if (size > PortableBoardLimits.maximumEntryBytes ||
            totalBytes >
                PortableBoardLimits.maximumPackageBytes - 1024 * 1024) {
          throw const FormatException('Board exceeds portable export limits.');
        }
      }
      final destination = File(_portablePath(destinationPath)).absolute;
      if (!await destination.parent.exists()) {
        throw const BoardTransferException(
          BoardTransferFailureKind.fileSystem,
          'The selected export directory does not exist.',
        );
      }
      stagingDirectory = await destination.parent.createTemp('.vasmim-export-');
      final stagedArchive = File(
        '${stagingDirectory.path}${Platform.pathSeparator}board.vasmim',
      );
      encoder = ZipFileEncoder();
      encoder.create(stagedArchive.path);

      final manifest = const JsonEncoder.withIndent('  ').convert({
        'packageFormatVersion': packageFormatVersion,
        'boardId': board.id,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
      });
      encoder.addArchiveFile(ArchiveFile.string('manifest.json', manifest));
      encoder.addArchiveFile(
        ArchiveFile.string(
          'board.json',
          const JsonEncoder.withIndent('  ').convert(board.toJson()),
        ),
      );
      for (final entry in assets.entries) {
        await encoder.addFile(entry.value, entry.key);
      }
      await encoder.close();
      encoderClosed = true;

      await stagedArchive.copy(destination.path);
    } on BoardTransferException {
      rethrow;
    } on FileSystemException catch (error) {
      throw BoardTransferException(
        BoardTransferFailureKind.fileSystem,
        'The portable board could not be written.',
        error,
      );
    } catch (error) {
      throw BoardTransferException(
        BoardTransferFailureKind.invalidArchive,
        'The board could not be packaged safely.',
        error,
      );
    } finally {
      if (encoder != null && !encoderClosed) {
        try {
          await encoder.close();
        } catch (_) {
          // Preserve the original failure while releasing the output handle.
        }
      }
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<BoardLibraryBackupResult> exportAllBoards(
    String parentDirectoryPath,
  ) async {
    Directory? stagingDirectory;
    try {
      final entries = await discover();
      final unavailableCount = entries
          .where((entry) => !entry.isAvailable)
          .length;
      if (unavailableCount != 0) {
        throw BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.unavailableBoards,
          '$unavailableCount unavailable board(s) prevent a complete export.',
          unavailableBoardCount: unavailableCount,
        );
      }
      final boards = entries.map((entry) => entry.board!).toList();
      if (boards.isEmpty) {
        throw const BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.noBoards,
          'There are no available boards to export.',
        );
      }

      final trimmedParentPath = parentDirectoryPath.trim();
      final parentDirectory = Directory(trimmedParentPath).absolute;
      if (trimmedParentPath.isEmpty ||
          await FileSystemEntity.type(
                parentDirectory.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.directory) {
        throw const BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.fileSystem,
          'The selected backup directory does not exist.',
        );
      }

      stagingDirectory = await parentDirectory.createTemp('.vasmim-backup-');
      final manifestEntries = <BackupManifestEntry>[];
      for (final board in boards) {
        final fileName = portableBoardBackupFileName(board.name, board.id);
        final stagedPackage = File(
          '${stagingDirectory.path}${Platform.pathSeparator}$fileName',
        );
        try {
          await exportBoard(board.id, stagedPackage.path);
        } on BoardTransferException catch (error) {
          throw BoardLibraryBackupException(
            BoardLibraryBackupFailureKind.boardExport,
            'The complete board export could not be created.',
            cause: error,
          );
        }
        manifestEntries.add(
          BackupManifestEntry(
            boardId: board.id,
            fileName: fileName,
            sha256: await _fileSha256(stagedPackage),
          ),
        );
      }
      final manifest = BackupManifest(
        createdAt: _clock(),
        entries: manifestEntries,
      );
      await File(
        '${stagingDirectory.path}${Platform.pathSeparator}$backupManifestFileName',
      ).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
        flush: true,
      );

      final baseFolderName = libraryBackupFolderName(_clock());
      var folderName = baseFolderName;
      var suffix = 2;
      var finalDirectory = Directory(
        '${parentDirectory.path}${Platform.pathSeparator}$folderName',
      );
      while (await finalDirectory.exists()) {
        folderName = '$baseFolderName ($suffix)';
        suffix += 1;
        finalDirectory = Directory(
          '${parentDirectory.path}${Platform.pathSeparator}$folderName',
        );
      }

      final published = await stagingDirectory.rename(finalDirectory.path);
      stagingDirectory = null;
      return BoardLibraryBackupResult(
        directoryPath: published.path,
        folderName: folderName,
        boardCount: boards.length,
      );
    } on BoardLibraryBackupException {
      rethrow;
    } on FileSystemException catch (error) {
      throw BoardLibraryBackupException(
        BoardLibraryBackupFailureKind.fileSystem,
        'The complete board export could not be written.',
        cause: error,
      );
    } finally {
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<BoardLibraryBackupVerificationResult> verifyBackupFolder(
    String directoryPath,
  ) async {
    try {
      final trimmedPath = directoryPath.trim();
      final directory = Directory(trimmedPath).absolute;
      if (trimmedPath.isEmpty ||
          await FileSystemEntity.type(directory.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        throw const BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.fileSystem,
          'The selected backup folder does not exist.',
        );
      }
      final immediate = await directory.list(followLinks: false).toList();
      final files = <String, File>{};
      for (final entity in immediate) {
        if (entity is! File ||
            await FileSystemEntity.type(entity.path, followLinks: false) !=
                FileSystemEntityType.file) {
          throw const BoardLibraryBackupException(
            BoardLibraryBackupFailureKind.invalidManifest,
            'The backup folder contains an unexpected item.',
          );
        }
        files[_fileName(entity.path)] = entity;
      }
      final manifestFile = files[backupManifestFileName];
      if (manifestFile == null) {
        throw const BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.missingManifest,
          'This backup folder cannot be verified because it has no manifest.',
        );
      }
      if (await manifestFile.length() > PortableBoardLimits.maximumJsonBytes) {
        throw const FormatException('Backup manifest is too large.');
      }
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map) {
        throw const BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.invalidManifest,
          'The backup manifest is invalid.',
        );
      }
      final manifest = BackupManifest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final expected = {
        backupManifestFileName,
        ...manifest.entries.map((entry) => entry.fileName),
      };
      if (files.keys.toSet().length != files.length ||
          files.keys.toSet().difference(expected).isNotEmpty ||
          expected.difference(files.keys.toSet()).isNotEmpty) {
        throw const BoardLibraryBackupException(
          BoardLibraryBackupFailureKind.invalidManifest,
          'The backup folder does not match its manifest.',
        );
      }
      for (final entry in manifest.entries) {
        final file = files[entry.fileName]!;
        if (await _fileSha256(file) != entry.sha256) {
          throw BoardLibraryBackupException(
            BoardLibraryBackupFailureKind.invalidPackage,
            'The backup package ${entry.fileName} has changed.',
          );
        }
        final board = await _validatePortableBoardForBackup(file);
        if (board.id != entry.boardId ||
            portableBoardBackupFileName(board.name, board.id) !=
                entry.fileName) {
          throw BoardLibraryBackupException(
            BoardLibraryBackupFailureKind.invalidPackage,
            'The backup package ${entry.fileName} does not match its manifest.',
          );
        }
      }
      return BoardLibraryBackupVerificationResult(
        boardCount: manifest.entries.length,
      );
    } on BoardLibraryBackupException {
      rethrow;
    } on FormatException catch (error) {
      throw BoardLibraryBackupException(
        BoardLibraryBackupFailureKind.invalidManifest,
        'The backup manifest is invalid.',
        cause: error,
      );
    } on FileSystemException catch (error) {
      throw BoardLibraryBackupException(
        BoardLibraryBackupFailureKind.fileSystem,
        'The backup folder could not be verified.',
        cause: error,
      );
    } catch (error) {
      throw BoardLibraryBackupException(
        BoardLibraryBackupFailureKind.invalidPackage,
        'A backup package is invalid.',
        cause: error,
      );
    }
  }

  @override
  Future<BoardDocument> importBoard(String sourcePath) =>
      _importPortableBoard(sourcePath);

  @override
  Future<BoardDocument> importBoardAsCopy(String sourcePath, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Board names must be non-empty.');
    }
    return _importPortableBoard(sourcePath, copyName: trimmedName);
  }

  Future<BoardDocument> _importPortableBoard(
    String sourcePath, {
    String? copyName,
  }) async {
    InputFileStream? input;
    Directory? stagingDirectory;
    try {
      final lowerSourcePath = sourcePath.toLowerCase();
      if (!lowerSourcePath.endsWith(portableBoardExtension) &&
          !lowerSourcePath.endsWith(legacyPortableBoardExtension)) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'Portable boards must use .vasmim; legacy .freeform packages are also supported.',
        );
      }
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw const BoardTransferException(
          BoardTransferFailureKind.fileSystem,
          'The selected portable board does not exist.',
        );
      }

      input = InputFileStream(source.path);
      final archive = PortableBoardLimits.decode(input);
      input.setPosition(0);
      final directory = ZipDirectory()..read(input);
      final headers = directory.fileHeaders;
      final headerNames = headers.map((header) => header.filename).toList();
      if (headerNames.toSet().length != headerNames.length ||
          headers.any((header) => (header.generalPurposeBitFlag & 0x1) != 0)) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board contains duplicate or encrypted entries.',
        );
      }
      final entries = <String, ArchiveFile>{};
      for (final entry in archive) {
        final name = entry.name;
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            !_isCanonicalArchivePath(name) ||
            entries.containsKey(name)) {
          throw const BoardTransferException(
            BoardTransferFailureKind.invalidArchive,
            'The portable board contains an unsafe or duplicate entry.',
          );
        }
        entries[name] = entry;
      }

      final manifestEntry = entries['manifest.json'];
      final boardEntry = entries['board.json'];
      if (manifestEntry == null || boardEntry == null) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board is missing its manifest or board document.',
        );
      }
      final manifest = _decodeJsonEntry(manifestEntry);
      final version = manifest['packageFormatVersion'];
      if (version != packageFormatVersion) {
        throw BoardTransferException(
          BoardTransferFailureKind.unsupportedPackageVersion,
          'Unsupported portable-board package version: $version',
        );
      }
      final manifestBoardId = manifest['boardId'];
      if (manifestBoardId is! String || !_isSafeBoardId(manifestBoardId)) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board has an unsafe identity.',
        );
      }
      final exportedAt = manifest['exportedAt'];
      final exportedTimestamp = exportedAt is String
          ? DateTime.tryParse(exportedAt)
          : null;
      if (exportedTimestamp == null ||
          !exportedTimestamp.isUtc ||
          !exportedAt.endsWith('Z')) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board has an invalid export timestamp.',
        );
      }

      final boardJson = _decodeJsonEntry(boardEntry);
      final board = BoardDocument.fromJson(boardJson);
      if (board.id != manifestBoardId) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The manifest and board document identities do not match.',
        );
      }

      final expectedAssets = <String>{};
      for (final assetPathValue in [
        ...board.images.map((image) => image.assetPath),
        ...board.attachments.map((attachment) => attachment.assetPath),
        ...board.attachments
            .map((attachment) => attachment.previewAssetPath)
            .whereType<String>(),
        ...board.youTubeEmbeds
            .map((embed) => embed.thumbnailAssetPath)
            .whereType<String>(),
      ]) {
        final assetPath = assetPathValue.replaceAll('\\', '/');
        if (!_canonicalAssetPath.hasMatch(assetPath)) {
          throw const BoardTransferException(
            BoardTransferFailureKind.invalidArchive,
            'The board contains a non-canonical managed asset path.',
          );
        }
        expectedAssets.add(assetPath);
      }
      final allowedEntries = {'manifest.json', 'board.json', ...expectedAssets};
      final missingAssets = expectedAssets.difference(entries.keys.toSet());
      if (missingAssets.isNotEmpty) {
        throw BoardTransferException(
          BoardTransferFailureKind.missingAsset,
          'A referenced managed image is missing: ${missingAssets.first}',
        );
      }
      if (entries.keys.toSet().difference(allowedEntries).isNotEmpty) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board contains an unexpected file.',
        );
      }

      final originalTargetDirectory = await boardDirectory(board.id);
      final hasIdentityConflict = await originalTargetDirectory.exists();
      if (copyName == null && hasIdentityConflict) {
        throw BoardTransferException(
          BoardTransferFailureKind.duplicateBoard,
          'A board with this permanent identity already exists.',
          null,
          BoardImportConflict(boardId: board.id, boardName: board.name),
        );
      }
      if (copyName != null && !hasIdentityConflict) {
        throw const BoardTransferException(
          BoardTransferFailureKind.duplicateBoard,
          'The board identity no longer conflicts with local storage.',
        );
      }

      var boardToPublish = board;
      var targetDirectory = originalTargetDirectory;
      if (copyName != null) {
        final copyId = _idGenerator();
        if (!_uuidV4.hasMatch(copyId)) {
          throw StateError(
            'The board ID generator must return a UUID-v4 value.',
          );
        }
        targetDirectory = await boardDirectory(copyId);
        if (await targetDirectory.exists()) {
          throw const BoardTransferException(
            BoardTransferFailureKind.duplicateBoard,
            'A board with the generated identity already exists.',
          );
        }
        final now = DateTime.now().toUtc();
        boardToPublish = BoardDocument(
          id: copyId,
          name: copyName,
          createdAt: now,
          modifiedAt: now,
          viewportX: board.viewportX,
          viewportY: board.viewportY,
          viewportZoom: board.viewportZoom,
          notes: board.notes,
          connectors: board.connectors,
          images: board.images,
          scenes: board.scenes,
          headings: board.headings,
          attachments: board.attachments,
          youTubeEmbeds: board.youTubeEmbeds,
          shapes: board.shapes,
          shapeLayers: board.shapeLayers,
          groups: board.groups,
          isSnappingEnabled: board.isSnappingEnabled,
          paperTone: board.paperTone,
          lockedObjectIds: board.lockedObjectIds,
        );
      }
      await _ensureNonFavorite(boardToPublish.id);
      await _ensureUnfiled(boardToPublish.id);

      final root = await _directoryProvider();
      final transfersDirectory = Directory(
        '${root.path}${Platform.pathSeparator}$_transferStagingDirectoryName',
      );
      await transfersDirectory.create(recursive: true);
      stagingDirectory = await transfersDirectory.createTemp(
        copyName == null ? 'import-' : 'import-copy-',
      );
      await _writeBoard(stagingDirectory, boardToPublish);
      for (final assetPath in expectedAssets) {
        final entry = entries[assetPath]!;
        final target = File(
          '${stagingDirectory.path}${Platform.pathSeparator}'
          '${assetPath.replaceAll('/', Platform.pathSeparator)}',
        );
        await target.parent.create(recursive: true);
        final output = OutputFileStream(target.path);
        try {
          entry.writeContent(LimitedArchiveOutput(output, entry.size));
        } finally {
          output.closeSync();
        }
        await _verifyFileCrc(target, entry.crc32);
      }

      if (await targetDirectory.exists()) {
        if (copyName == null) {
          throw BoardTransferException(
            BoardTransferFailureKind.duplicateBoard,
            'A board with this permanent identity already exists.',
            null,
            BoardImportConflict(boardId: board.id, boardName: board.name),
          );
        }
        throw const BoardTransferException(
          BoardTransferFailureKind.duplicateBoard,
          'A board with the generated identity already exists.',
        );
      }
      await targetDirectory.parent.create(recursive: true);
      await stagingDirectory.rename(targetDirectory.path);
      stagingDirectory = null;
      return boardToPublish;
    } on BoardTransferException {
      rethrow;
    } on FileSystemException catch (error) {
      throw BoardTransferException(
        BoardTransferFailureKind.fileSystem,
        'The portable board could not be imported.',
        error,
      );
    } catch (error) {
      throw BoardTransferException(
        BoardTransferFailureKind.invalidArchive,
        'The selected file is not a valid portable board.',
        error,
      );
    } finally {
      if (input != null) {
        await input.close();
      }
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<BoardDocument> _validatePortableBoardForBackup(File source) async {
    InputFileStream? input;
    try {
      input = InputFileStream(source.path);
      final archive = PortableBoardLimits.decode(input);
      input.setPosition(0);
      final directory = ZipDirectory()..read(input);
      final headers = directory.fileHeaders;
      final headerNames = headers.map((header) => header.filename).toList();
      if (headerNames.toSet().length != headerNames.length ||
          headers.any((header) => (header.generalPurposeBitFlag & 0x1) != 0)) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board contains duplicate or encrypted entries.',
        );
      }
      final entries = <String, ArchiveFile>{};
      for (final entry in archive) {
        final name = entry.name;
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            !_isCanonicalArchivePath(name) ||
            entries.containsKey(name)) {
          throw const BoardTransferException(
            BoardTransferFailureKind.invalidArchive,
            'The portable board contains an unsafe or duplicate entry.',
          );
        }
        entries[name] = entry;
      }

      final manifestEntry = entries['manifest.json'];
      final boardEntry = entries['board.json'];
      if (manifestEntry == null || boardEntry == null) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board is missing its manifest or board document.',
        );
      }
      final manifest = _decodeJsonEntry(manifestEntry);
      final version = manifest['packageFormatVersion'];
      if (version != packageFormatVersion) {
        throw BoardTransferException(
          BoardTransferFailureKind.unsupportedPackageVersion,
          'Unsupported portable-board package version: $version',
        );
      }
      final manifestBoardId = manifest['boardId'];
      if (manifestBoardId is! String || !_isSafeBoardId(manifestBoardId)) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board has an unsafe identity.',
        );
      }
      final exportedAt = manifest['exportedAt'];
      final exportedTimestamp = exportedAt is String
          ? DateTime.tryParse(exportedAt)
          : null;
      if (exportedTimestamp == null ||
          !exportedTimestamp.isUtc ||
          !exportedAt.endsWith('Z')) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board has an invalid export timestamp.',
        );
      }
      final board = BoardDocument.fromJson(_decodeJsonEntry(boardEntry));
      if (board.id != manifestBoardId) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The manifest and board document identities do not match.',
        );
      }
      final expectedAssets = <String>{};
      for (final assetPathValue in [
        ...board.images.map((image) => image.assetPath),
        ...board.attachments.map((attachment) => attachment.assetPath),
        ...board.attachments
            .map((attachment) => attachment.previewAssetPath)
            .whereType<String>(),
        ...board.youTubeEmbeds
            .map((embed) => embed.thumbnailAssetPath)
            .whereType<String>(),
      ]) {
        final assetPath = assetPathValue.replaceAll('\\', '/');
        if (!_canonicalAssetPath.hasMatch(assetPath)) {
          throw const BoardTransferException(
            BoardTransferFailureKind.invalidArchive,
            'The board contains a non-canonical managed asset path.',
          );
        }
        expectedAssets.add(assetPath);
      }
      final allowedEntries = {'manifest.json', 'board.json', ...expectedAssets};
      final missingAssets = expectedAssets.difference(entries.keys.toSet());
      if (missingAssets.isNotEmpty) {
        throw BoardTransferException(
          BoardTransferFailureKind.missingAsset,
          'A referenced managed image is missing: ${missingAssets.first}',
        );
      }
      if (entries.keys.toSet().difference(allowedEntries).isNotEmpty) {
        throw const BoardTransferException(
          BoardTransferFailureKind.invalidArchive,
          'The portable board contains an unexpected file.',
        );
      }
      return board;
    } finally {
      if (input != null) {
        await input.close();
      }
    }
  }

  @override
  Future<List<BoardLibraryEntry>> discover() async {
    final root = await _directoryProvider();
    String? legacyMigrationError;
    try {
      await _migrateLegacyBoard(root);
    } catch (_) {
      legacyMigrationError =
          'Legacy board data could not be migrated and remains in its original location.';
    }
    final boardsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}$boardsDirectoryName',
    );
    final entries = <BoardLibraryEntry>[];
    if (legacyMigrationError != null) {
      entries.add(
        BoardLibraryEntry.unavailable(
          boardId: 'legacy-board',
          error: legacyMigrationError,
        ),
      );
    }
    if (!await boardsDirectory.exists()) {
      return entries;
    }
    await for (final entity in boardsDirectory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final boardId = _fileName(entity.path);
      if (!_isSafeBoardId(boardId)) {
        entries.add(
          BoardLibraryEntry.unavailable(
            boardId: boardId,
            error: 'Board storage directory has an unsafe identifier.',
          ),
        );
        continue;
      }
      try {
        final board = await _readBoard(
          File('${entity.path}${Platform.pathSeparator}board.json'),
        );
        if (board.id != boardId) {
          throw const FormatException(
            'Board identifier does not match its storage directory.',
          );
        }
        entries.add(BoardLibraryEntry.available(board));
      } catch (_) {
        entries.add(
          BoardLibraryEntry.unavailable(
            boardId: boardId,
            error: 'Board data is unavailable or invalid.',
          ),
        );
      }
    }

    entries.sort((left, right) {
      final leftBoard = left.board;
      final rightBoard = right.board;
      if (leftBoard != null && rightBoard != null) {
        final modifiedOrder = rightBoard.modifiedAt.compareTo(
          leftBoard.modifiedAt,
        );
        return modifiedOrder != 0
            ? modifiedOrder
            : left.boardId.compareTo(right.boardId);
      }
      if (leftBoard != null) {
        return -1;
      }
      if (rightBoard != null) {
        return 1;
      }
      return left.boardId.compareTo(right.boardId);
    });
    return entries;
  }

  @override
  Future<Directory> boardDirectory(String boardId) async {
    if (!_isSafeBoardId(boardId)) {
      throw ArgumentError.value(
        boardId,
        'boardId',
        'Board identifiers must contain only letters, numbers, underscores, and hyphens.',
      );
    }
    final root = await _directoryProvider();
    return Directory(
      '${root.path}${Platform.pathSeparator}$boardsDirectoryName'
      '${Platform.pathSeparator}$boardId',
    );
  }

  Future<void> _migrateLegacyBoard(Directory root) async {
    final migrationMarker = File(
      '${root.path}${Platform.pathSeparator}$_legacyMigrationMarkerName',
    );
    if (await migrationMarker.exists()) {
      return;
    }
    final legacyBoardFile = File(
      '${root.path}${Platform.pathSeparator}board.json',
    );
    if (!await legacyBoardFile.exists()) {
      return;
    }

    final board = await _readBoard(legacyBoardFile);
    if (!_isSafeBoardId(board.id)) {
      throw const FormatException(
        'Legacy board identifier is unsafe for board-directory storage.',
      );
    }
    final targetDirectory = await boardDirectory(board.id);
    final targetBoardFile = File(
      '${targetDirectory.path}${Platform.pathSeparator}board.json',
    );
    if (await targetBoardFile.exists()) {
      final existing = await _readBoard(targetBoardFile);
      if (existing.id != board.id) {
        throw const FormatException(
          'Existing migrated board has an unexpected identifier.',
        );
      }
      await _verifyBoardAssets(targetDirectory, existing);
      await migrationMarker.writeAsString(board.id, flush: true);
      return;
    }

    if (await targetDirectory.exists()) {
      throw const FileSystemException(
        'Board migration target already exists without a board document.',
      );
    }

    await targetDirectory.create(recursive: true);
    try {
      await legacyBoardFile.copy(targetBoardFile.path);
      final legacyAssets = Directory(
        '${root.path}${Platform.pathSeparator}assets',
      );
      if (await legacyAssets.exists()) {
        await _copyDirectory(
          legacyAssets,
          Directory('${targetDirectory.path}${Platform.pathSeparator}assets'),
        );
      }
      final migrated = await _readBoard(targetBoardFile);
      if (migrated.id != board.id) {
        throw const FormatException(
          'Migrated board identifier changed during migration.',
        );
      }
      await _verifyBoardAssets(targetDirectory, migrated);
      await migrationMarker.writeAsString(board.id, flush: true);
    } catch (_) {
      if (await targetDirectory.exists()) {
        await targetDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  static Future<BoardDocument> _readBoard(File file) async {
    final result = await BoardFilePersistence.read(file);
    if (result == null) {
      throw const FileSystemException('Board document is missing.');
    }
    return result.board;
  }

  static Map<String, dynamic> _decodeJsonEntry(ArchiveFile entry) {
    if (entry.size > PortableBoardLimits.maximumJsonBytes) {
      throw const FormatException(
        'Portable Board JSON exceeds the 32 MiB limit.',
      );
    }
    final output = OutputMemoryStream();
    entry.writeContent(LimitedArchiveOutput(output, entry.size));
    final bytes = output.getBytes();
    if (entry.crc32 != getCrc32(bytes)) {
      throw const BoardTransferException(
        BoardTransferFailureKind.invalidArchive,
        'A portable-board entry failed its integrity check.',
      );
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const BoardTransferException(
        BoardTransferFailureKind.invalidArchive,
        'Portable-board JSON entries must contain objects.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> _verifyFileCrc(File file, int? expectedCrc) async {
    final crc = await _calculateFileCrc(file);
    if (expectedCrc == null || crc != expectedCrc) {
      throw const BoardTransferException(
        BoardTransferFailureKind.invalidArchive,
        'A portable-board entry failed its integrity check.',
      );
    }
  }

  static Future<int> _calculateFileCrc(File file) async {
    final handle = await file.open();
    var crc = 0;
    try {
      while (true) {
        final bytes = await handle.read(64 * 1024);
        if (bytes.isEmpty) {
          break;
        }
        crc = getCrc32(bytes, crc);
      }
    } finally {
      await handle.close();
    }
    return crc;
  }

  static Future<String> _fileSha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString().toUpperCase();

  static bool _isCanonicalArchivePath(String path) {
    if (path.isEmpty ||
        path.contains('\\') ||
        path.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      return false;
    }
    final segments = path.split('/');
    return segments.every(
      (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
    );
  }

  static String _portablePath(String path) {
    final trimmed = path.trim();
    if (trimmed.toLowerCase().endsWith(portableBoardExtension)) {
      return trimmed;
    }
    return '$trimmed$portableBoardExtension';
  }

  static Future<void> _verifyBoardAssets(
    Directory directory,
    BoardDocument board,
  ) async {
    for (final image in board.images) {
      final asset = File(
        '${directory.path}${Platform.pathSeparator}'
        '${image.assetPath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await asset.exists()) {
        throw FormatException(
          'Migrated board asset is missing: ${image.assetPath}',
        );
      }
    }
    for (final attachment in board.attachments) {
      final asset = File(
        '${directory.path}${Platform.pathSeparator}'
        '${attachment.assetPath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await asset.exists() ||
          await asset.length() != attachment.byteSize) {
        throw FormatException(
          'Migrated board attachment is missing or changed: ${attachment.assetPath}',
        );
      }
      final previewPath = attachment.previewAssetPath;
      if (previewPath != null) {
        final preview = File(
          '${directory.path}${Platform.pathSeparator}'
          '${previewPath.replaceAll('/', Platform.pathSeparator)}',
        );
        if (!await preview.exists()) {
          throw FormatException(
            'Migrated attachment preview is missing: $previewPath',
          );
        }
      }
    }
    for (final embed in board.youTubeEmbeds) {
      final thumbnailPath = embed.thumbnailAssetPath;
      if (thumbnailPath == null) continue;
      final asset = File(
        '${directory.path}${Platform.pathSeparator}'
        '${thumbnailPath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await asset.exists()) {
        throw FormatException(
          'Migrated YouTube thumbnail is missing: $thumbnailPath',
        );
      }
    }
  }

  static Future<void> _writeBoard(
    Directory directory,
    BoardDocument board,
  ) async {
    final file = File('${directory.path}${Platform.pathSeparator}board.json');
    await BoardFilePersistence.write(file, board);
  }

  Future<void> _writeFavoriteBoardIds(Set<String> ids) async {
    final root = await _directoryProvider();
    await root.create(recursive: true);
    final stagingDirectory = await root.createTemp('.favorites-');
    try {
      final stagedFile = File(
        '${stagingDirectory.path}${Platform.pathSeparator}'
        '$favoriteMetadataFileName',
      );
      final sortedIds = ids.toList()..sort();
      const encoder = JsonEncoder.withIndent('  ');
      await stagedFile.writeAsString(
        encoder.convert({
          'version': _favoriteMetadataVersion,
          'favoriteBoardIds': sortedIds,
        }),
        flush: true,
      );
      final targetFile = File(
        '${root.path}${Platform.pathSeparator}$favoriteMetadataFileName',
      );
      await _favoriteMetadataCommitter(stagedFile, targetFile);
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _writeLibraryFolderState(LibraryFolderState state) async {
    final root = await _directoryProvider();
    await root.create(recursive: true);
    final stagingDirectory = await root.createTemp('.folders-');
    try {
      final stagedFile = File(
        '${stagingDirectory.path}${Platform.pathSeparator}$folderMetadataFileName',
      );
      await stagedFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'version': _folderMetadataVersion,
          'folders': state.folders.map((folder) => folder.toJson()).toList(),
          'boardFolderIds': state.boardFolderIds,
        }),
        flush: true,
      );
      await _commitFavoriteMetadata(
        stagedFile,
        File('${root.path}${Platform.pathSeparator}$folderMetadataFileName'),
      );
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _ensureNonFavorite(String boardId) async {
    final ids = {...await favoriteBoardIds()};
    if (ids.remove(boardId)) {
      await _writeFavoriteBoardIds(ids);
    }
  }

  Future<void> _ensureUnfiled(String boardId) async {
    final state = await libraryFolderState();
    if (!state.boardFolderIds.containsKey(boardId)) {
      return;
    }
    final membership = {...state.boardFolderIds}..remove(boardId);
    await _writeLibraryFolderState(
      LibraryFolderState(folders: state.folders, boardFolderIds: membership),
    );
  }

  static Future<void> _commitFavoriteMetadata(
    File stagedFile,
    File targetFile,
  ) async {
    final backupFile = File('${targetFile.path}.backup');
    var movedExisting = false;
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    if (await targetFile.exists()) {
      await targetFile.rename(backupFile.path);
      movedExisting = true;
    }
    try {
      await stagedFile.rename(targetFile.path);
      if (movedExisting && await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      if (movedExisting && await backupFile.exists()) {
        await backupFile.rename(targetFile.path);
      }
      rethrow;
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = _fileName(entity.path);
      if (entity is File) {
        await entity.copy('${target.path}${Platform.pathSeparator}$name');
      } else if (entity is Directory) {
        await _copyDirectory(
          entity,
          Directory('${target.path}${Platform.pathSeparator}$name'),
        );
      }
    }
  }

  static bool _isSafeBoardId(String boardId) {
    return boardId.isNotEmpty && _safeBoardId.hasMatch(boardId);
  }

  static String _fileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }
}
