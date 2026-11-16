import 'dart:io';

import 'package:flutter/material.dart';

import '../attachment/attachment_asset_store.dart';
import '../canvas/canvas_experiment.dart';
import '../canvas/cross_board_clipboard.dart';
import '../canvas/canvas_initial_target.dart';
import '../image/image_asset_store.dart';
import '../image/clipboard_image_reader.dart';
import '../image/image_path_picker.dart';
import '../help/vasmim_help_dialog.dart';
import 'board_name_dialog.dart';
import 'board_document.dart';
import 'board_library_store.dart';
import 'board_preview_dialog.dart';
import 'board_store.dart';
import 'board_starter.dart';
import 'board_transfer_picker.dart';
import 'library_connector_search.dart';
import 'library_folder.dart';
import 'library_heading_search.dart';
import 'library_image_search.dart';
import 'library_note_search.dart';
import 'library_note_search_dialog.dart';
import 'library_scene_search.dart';
import 'library_shape_search.dart';
import 'library_search_target.dart';

enum _BoardSortOrder { newestFirst, oldestFirst }

enum _BoardAction {
  preview,
  favorite,
  moveToFolder,
  rename,
  duplicate,
  export,
  findInExplorer,
  delete,
}

class BoardLibraryScreen extends StatefulWidget {
  const BoardLibraryScreen({
    required this.libraryStore,
    this.editorBuilder,
    this.importPicker,
    this.exportPicker,
    this.backupDirectoryPicker,
    this.backupVerificationDirectoryPicker,
    this.explorerLauncher,
    this.clipboardImageReader = const UnavailableClipboardImageReader(),
    this.crossBoardClipboard,
    this.isDarkMode = false,
    this.onToggleDarkMode,
    super.key,
  });

  final BoardLibraryStore libraryStore;
  final Widget Function(
    BoardDocument board,
    bool showBlankCanvasPriming,
    CanvasInitialTarget? initialTarget,
    VoidCallback onReturn,
  )?
  editorBuilder;
  final BoardImportPathPicker? importPicker;
  final BoardExportPathPicker? exportPicker;
  final BoardBackupDirectoryPicker? backupDirectoryPicker;
  final BoardBackupVerificationDirectoryPicker?
  backupVerificationDirectoryPicker;
  final Future<void> Function(Directory directory)? explorerLauncher;
  final ClipboardImageReader clipboardImageReader;
  final CrossBoardClipboard? crossBoardClipboard;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  @override
  State<BoardLibraryScreen> createState() => _BoardLibraryScreenState();
}

class _BoardLibraryScreenState extends State<BoardLibraryScreen> {
  final CrossBoardClipboard _ownedCrossBoardClipboard = CrossBoardClipboard();
  CrossBoardClipboard get _crossBoardClipboard =>
      widget.crossBoardClipboard ?? _ownedCrossBoardClipboard;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  List<BoardLibraryEntry> _entries = const [];
  Set<String> _favoriteBoardIds = const {};
  List<LibraryFolder> _folders = const [];
  Map<String, String> _boardFolderIds = const {};
  String? _selectedFolderId;
  BoardDocument? _openBoard;
  CanvasInitialTarget? _initialTarget;
  bool _showBlankCanvasPriming = false;
  bool _isLoading = true;
  bool _isTransferring = false;
  bool _isUpdatingFavorite = false;
  bool _isPreviewLoading = false;
  bool _isFindingObject = false;
  String _searchQuery = '';
  _BoardSortOrder _sortOrder = _BoardSortOrder.newestFirst;
  String? _error;
  String? _folderError;

  bool get _isBusy =>
      _isTransferring ||
      _isUpdatingFavorite ||
      _isPreviewLoading ||
      _isFindingObject;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'Library search');
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<BoardLibraryEntry> get _filteredEntries {
    final query = _searchQuery.trim().toLowerCase();
    final folderEntries = _selectedFolderId == null
        ? _entries
        : _entries.where((entry) {
            final assigned = _boardFolderIds[entry.boardId];
            return _selectedFolderId == '_unfiled'
                ? assigned == null
                : assigned == _selectedFolderId;
          }).toList();
    final matchingEntries = query.isEmpty
        ? folderEntries.toList()
        : folderEntries.where((entry) {
            final board = entry.board;
            final searchableText = board?.name ?? entry.boardId;
            return searchableText.toLowerCase().contains(query);
          }).toList();
    final availableEntriesById = {
      for (final entry in matchingEntries)
        if (entry.board != null) entry.boardId: entry,
    };
    final orderedBoards = LibraryNoteSearch.orderBoards(
      availableEntriesById.values.map((entry) => entry.board!),
      favoriteBoardIds: _favoriteBoardIds,
      newestFirst: _sortOrder == _BoardSortOrder.newestFirst,
    );
    return [
      for (final board in orderedBoards) availableEntriesById[board.id]!,
      ...matchingEntries.where((entry) => entry.board == null),
    ];
  }

  List<BoardDocument> get _orderedHealthyBoards =>
      LibraryNoteSearch.orderBoards(
        _entries
            .where((entry) => entry.board != null)
            .map((entry) => entry.board!),
        favoriteBoardIds: _favoriteBoardIds,
        newestFirst: _sortOrder == _BoardSortOrder.newestFirst,
      );

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _showFindAcrossBoards() async {
    final target = await showDialog<LibrarySearchTarget>(
      context: context,
      builder: (context) => LibrarySearchDialog(
        orderedBoards: List.unmodifiable(_orderedHealthyBoards),
      ),
    );
    if (!mounted) {
      return;
    }
    if (target == null) {
      _searchFocusNode.requestFocus();
      return;
    }
    setState(() => _isFindingObject = true);
    try {
      final currentBoard = await widget.libraryStore.loadBoard(target.boardId);
      if (!mounted) {
        return;
      }
      final isCurrentTarget = switch (target.type) {
        LibrarySearchTargetType.note => LibraryNoteSearch.isCurrentTarget(
          currentBoard,
          target,
        ),
        LibrarySearchTargetType.image => LibraryImageSearch.isCurrentTarget(
          currentBoard,
          target,
        ),
        LibrarySearchTargetType.heading => LibraryHeadingSearch.isCurrentTarget(
          currentBoard,
          target,
        ),
        LibrarySearchTargetType.shape => LibraryShapeSearch.isCurrentTarget(
          currentBoard,
          target,
        ),
        LibrarySearchTargetType.connector =>
          LibraryConnectorSearch.isCurrentTarget(currentBoard, target),
        LibrarySearchTargetType.scene => LibrarySceneSearch.isCurrentTarget(
          currentBoard,
          target,
        ),
      };
      if (!isCurrentTarget) {
        throw StateError('The selected search result is stale.');
      }
      setState(() {
        _openBoard = currentBoard;
        _initialTarget = switch (target.type) {
          LibrarySearchTargetType.note => CanvasInitialTarget.note(
            target.objectId,
          ),
          LibrarySearchTargetType.image => CanvasInitialTarget.image(
            target.objectId,
          ),
          LibrarySearchTargetType.heading => CanvasInitialTarget.heading(
            target.objectId,
          ),
          LibrarySearchTargetType.shape => CanvasInitialTarget.shape(
            target.objectId,
          ),
          LibrarySearchTargetType.connector => CanvasInitialTarget.connector(
            target.objectId,
          ),
          LibrarySearchTargetType.scene => CanvasInitialTarget.scene(
            target.objectId,
          ),
        };
        _showBlankCanvasPriming = false;
      });
    } catch (_) {
      if (mounted) {
        _showTransferMessage(
          'Could not open that search result. Try searching again.',
        );
        _searchFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isFindingObject = false);
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await widget.libraryStore.discover();
      final storedFavoriteIds = await widget.libraryStore.favoriteBoardIds();
      LibraryFolderState folderState;
      String? folderError;
      try {
        folderState = await widget.libraryStore.libraryFolderState();
      } catch (_) {
        folderState = LibraryFolderState();
        folderError =
            'Folder organization could not be loaded. Boards remain available.';
      }
      final healthyBoardIds = {
        for (final entry in entries)
          if (entry.board != null) entry.boardId,
      };
      if (mounted) {
        setState(() {
          _entries = entries;
          _favoriteBoardIds = {
            for (final boardId in storedFavoriteIds)
              if (healthyBoardIds.contains(boardId)) boardId,
          };
          _folders = folderState.folders;
          _folderError = folderError;
          _boardFolderIds = {
            for (final entry in folderState.boardFolderIds.entries)
              if (healthyBoardIds.contains(entry.key)) entry.key: entry.value,
          };
          if (_selectedFolderId != null &&
              _selectedFolderId != '_unfiled' &&
              !_folders.any((folder) => folder.id == _selectedFolderId)) {
            _selectedFolderId = null;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load the board library';
        });
      }
    }
  }

  Future<String?> _askForName({BoardDocument? board}) {
    return showDialog<String>(
      context: context,
      builder: (context) => BoardNameDialog(initialName: board?.name),
    );
  }

  Future<void> _createBoard({BoardStarter starter = BoardStarter.blank}) async {
    final folderId = _newBoardFolderId;
    final name = await _askForName();
    if (name == null || !mounted) {
      return;
    }
    try {
      final board = await widget.libraryStore.createBoard(
        name,
        starter: starter,
      );
      if (folderId != null) {
        await widget.libraryStore.setBoardFolder(board.id, folderId);
      }
      if (mounted) {
        setState(() {
          _openBoard = board;
          _initialTarget = null;
          _showBlankCanvasPriming = starter == BoardStarter.blank;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not create the board');
      }
    }
  }

  String? get _newBoardFolderId {
    if (_selectedFolderId == '_unfiled') return null;
    if (_selectedFolderId != null) return _selectedFolderId;
    LibraryFolder? latest;
    for (final folder in _folders) {
      if (latest == null || !folder.createdAt.isBefore(latest.createdAt)) {
        latest = folder;
      }
    }
    return latest?.id;
  }

  Future<void> _renameBoard(BoardDocument board) async {
    final name = await _askForName(board: board);
    if (name == null || name == board.name || !mounted) {
      return;
    }
    try {
      await widget.libraryStore.renameBoard(board.id, name);
      await _reload();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not rename the board');
      }
    }
  }

  Future<void> _duplicateBoard(BoardDocument board) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => BoardNameDialog(
        initialName: 'Copy of ${board.name}',
        purpose: BoardNameDialogPurpose.duplicate,
      ),
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() => _isTransferring = true);
    try {
      final duplicate = await widget.libraryStore.duplicateBoard(
        board.id,
        name,
      );
      if (mounted) {
        setState(() {
          _openBoard = duplicate;
          _initialTarget = null;
          _showBlankCanvasPriming = false;
        });
      }
    } on BoardTransferException catch (error) {
      if (mounted) {
        _showTransferMessage(_transferErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not duplicate the board');
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  Future<void> _deleteBoard(BoardDocument board) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete “${board.name}”?'),
            content: const Text(
              'This permanently deletes this board, its canvas content, scenes, '
              'and all managed images, documents, audio, and movies. '
              'Export a backup first if you may need it again. Other boards are not changed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('confirm-delete-board-button'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete board'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.libraryStore.deleteBoard(board.id);
      await _reload();
    } catch (_) {
      await _reload();
      if (mounted) {
        _showTransferMessage(
          'Could not finish deleting this Board. Close any '
          'files opened from it, check folder access, then try again.',
        );
      }
    }
  }

  Future<void> _exportBoard(BoardDocument board) async {
    final picker = widget.exportPicker ?? pickPortableBoardExportPath;
    final destinationPath = await picker(
      portableBoardSuggestedName(board.name),
    );
    if (destinationPath == null || !mounted) {
      return;
    }
    setState(() => _isTransferring = true);
    try {
      await widget.libraryStore.exportBoard(board.id, destinationPath);
      if (mounted) {
        _showTransferMessage('Exported “${board.name}”');
      }
    } on BoardTransferException catch (error) {
      if (mounted) {
        _showTransferMessage(_transferErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not export the board');
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  Future<void> _findBoardInExplorer(BoardDocument board) async {
    try {
      final directory = await widget.libraryStore.boardDirectory(board.id);
      final boardFile = File(
        '${directory.path}${Platform.pathSeparator}board.json',
      );
      if (!boardFile.existsSync()) {
        throw const FileSystemException('Board file is missing.');
      }
      final launcher = widget.explorerLauncher ?? _openDirectoryInExplorer;
      await launcher(directory);
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not find the Board in Explorer.');
      }
    }
  }

  Future<void> _openDirectoryInExplorer(Directory directory) async {
    await Process.start('explorer.exe', [
      directory.path,
    ], mode: ProcessStartMode.detached);
  }

  Future<void> _exportAllBoards() async {
    setState(() => _isTransferring = true);
    try {
      final entries = await widget.libraryStore.discover();
      if (!mounted) {
        return;
      }
      final unavailableCount = entries
          .where((entry) => !entry.isAvailable)
          .length;
      if (unavailableCount != 0) {
        final noun = unavailableCount == 1 ? 'board' : 'boards';
        _showTransferMessage(
          '$unavailableCount unavailable $noun prevents a complete export.',
        );
        return;
      }
      if (!entries.any((entry) => entry.isAvailable)) {
        return;
      }

      final picker =
          widget.backupDirectoryPicker ?? pickBoardBackupDirectoryPath;
      final parentDirectoryPath = await picker();
      if (parentDirectoryPath == null || !mounted) {
        return;
      }
      final result = await widget.libraryStore.exportAllBoards(
        parentDirectoryPath,
      );
      if (mounted) {
        final noun = result.boardCount == 1 ? 'board' : 'boards';
        _showTransferMessage(
          'Exported ${result.boardCount} $noun to ${result.folderName}.',
        );
      }
    } on BoardLibraryBackupException catch (error) {
      if (mounted) {
        _showTransferMessage(_backupErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('The complete board export could not be created.');
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  Future<void> _verifyBackupFolder() async {
    setState(() => _isTransferring = true);
    try {
      final picker =
          widget.backupVerificationDirectoryPicker ??
          pickBoardBackupVerificationDirectoryPath;
      final directoryPath = await picker();
      if (directoryPath == null || !mounted) {
        return;
      }
      final result = await widget.libraryStore.verifyBackupFolder(
        directoryPath,
      );
      if (mounted) {
        final noun = result.boardCount == 1 ? 'board' : 'boards';
        _showTransferMessage(
          'Verified ${result.boardCount} $noun in the backup folder.',
        );
      }
    } on BoardLibraryBackupException catch (error) {
      if (mounted) {
        _showTransferMessage(_backupVerificationErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('The backup folder could not be verified.');
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  Future<void> _handleBoardAction(BoardDocument board, _BoardAction action) {
    switch (action) {
      case _BoardAction.preview:
        return _previewBoard(board);
      case _BoardAction.favorite:
        return _toggleBoardFavorite(board);
      case _BoardAction.moveToFolder:
        return _moveBoardToFolder(board);
      case _BoardAction.rename:
        return _renameBoard(board);
      case _BoardAction.duplicate:
        return _duplicateBoard(board);
      case _BoardAction.export:
        return _exportBoard(board);
      case _BoardAction.findInExplorer:
        return _findBoardInExplorer(board);
      case _BoardAction.delete:
        return _deleteBoard(board);
    }
  }

  Future<String?> _askForFolderName({String initialName = ''}) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _FolderNameDialog(initialName: initialName),
    );
  }

  Future<void> _createFolder() async {
    final name = await _askForFolderName();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    try {
      final folder = await widget.libraryStore.createLibraryFolder(name);
      await _reload();
      if (mounted) {
        setState(() => _selectedFolderId = folder.id);
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage(
          'Could not create that folder. Use a unique name.',
        );
      }
    }
  }

  Future<void> _renameSelectedFolder() async {
    final folder = _folders
        .where((folder) => folder.id == _selectedFolderId)
        .firstOrNull;
    if (folder == null) {
      return;
    }
    final name = await _askForFolderName(initialName: folder.name);
    if (name == null || name.isEmpty || name == folder.name || !mounted) return;
    try {
      await widget.libraryStore.renameLibraryFolder(folder.id, name);
      await _reload();
    } catch (_) {
      if (mounted) {
        _showTransferMessage(
          'Could not rename that folder. Use a unique name.',
        );
      }
    }
  }

  Future<void> _deleteSelectedFolder() async {
    final folder = _folders
        .where((folder) => folder.id == _selectedFolderId)
        .firstOrNull;
    if (folder == null) {
      return;
    }
    try {
      await widget.libraryStore.deleteLibraryFolder(folder.id);
      if (mounted) {
        setState(() => _selectedFolderId = null);
      }
      await _reload();
    } catch (_) {
      if (mounted) {
        _showTransferMessage(
          'Move every Board out before deleting this folder.',
        );
      }
    }
  }

  Future<void> _moveBoardToFolder(BoardDocument board) async {
    final folderId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Move “${board.name}”'),
        children: [
          SimpleDialogOption(
            key: const ValueKey('move-board-unfiled'),
            onPressed: () => Navigator.of(context).pop('_unfiled'),
            child: const ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('Unfiled'),
            ),
          ),
          for (final folder in _folders)
            SimpleDialogOption(
              key: ValueKey('move-board-folder-${folder.id}'),
              onPressed: () => Navigator.of(context).pop(folder.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
              ),
            ),
        ],
      ),
    );
    if (folderId == null || !mounted) return;
    try {
      await widget.libraryStore.setBoardFolder(
        board.id,
        folderId == '_unfiled' ? null : folderId,
      );
      await _reload();
    } catch (_) {
      if (mounted) _showTransferMessage('Could not move the Board.');
    }
  }

  Future<void> _previewBoard(BoardDocument board) async {
    setState(() => _isPreviewLoading = true);
    try {
      final currentBoard = await widget.libraryStore.loadBoard(board.id);
      if (!mounted) {
        return;
      }
      final shouldOpen =
          await showDialog<bool>(
            context: context,
            builder: (context) => BoardPreviewDialog(board: currentBoard),
          ) ??
          false;
      if (shouldOpen && mounted) {
        setState(() {
          _openBoard = currentBoard;
          _initialTarget = null;
          _showBlankCanvasPriming = false;
        });
      } else if (mounted) {
        _searchFocusNode.requestFocus();
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not preview the board');
        _searchFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
      }
    }
  }

  Future<void> _toggleBoardFavorite(BoardDocument board) async {
    final shouldBeFavorite = !_favoriteBoardIds.contains(board.id);
    setState(() => _isUpdatingFavorite = true);
    try {
      await widget.libraryStore.setBoardFavorite(board.id, shouldBeFavorite);
      if (mounted) {
        setState(() {
          _favoriteBoardIds = {
            ..._favoriteBoardIds.where((boardId) => boardId != board.id),
            if (shouldBeFavorite) board.id,
          };
        });
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not update favorite');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingFavorite = false);
      }
    }
  }

  Future<void> _importBoard() async {
    final picker = widget.importPicker ?? pickPortableBoardImportPath;
    final sourcePath = await picker();
    if (sourcePath == null || !mounted) {
      return;
    }
    setState(() => _isTransferring = true);
    BoardImportConflict? conflict;
    try {
      final board = await widget.libraryStore.importBoard(sourcePath);
      if (mounted) {
        setState(() {
          _openBoard = board;
          _initialTarget = null;
          _showBlankCanvasPriming = false;
        });
      }
    } on BoardTransferException catch (error) {
      if (mounted) {
        if (error.kind == BoardTransferFailureKind.duplicateBoard &&
            error.conflict != null) {
          conflict = error.conflict;
        } else {
          _showTransferMessage(_transferErrorMessage(error));
        }
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not import the portable board');
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
    if (conflict != null && mounted) {
      await _offerImportAsCopy(sourcePath, conflict);
    }
  }

  Future<void> _offerImportAsCopy(
    String sourcePath,
    BoardImportConflict conflict,
  ) async {
    final shouldImportAsCopy = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Board already exists'),
        content: Text(
          '“${conflict.boardName}” already exists in this Library. '
          'The existing board will not be changed. You can import the '
          'portable board as an independent copy with a new identity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('import-as-copy-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import as copy'),
          ),
        ],
      ),
    );
    if (shouldImportAsCopy != true || !mounted) {
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (context) => BoardNameDialog(
        initialName: '${conflict.boardName} copy',
        purpose: BoardNameDialogPurpose.importCopy,
      ),
    );
    if (name == null || !mounted) {
      return;
    }

    setState(() => _isTransferring = true);
    try {
      final board = await widget.libraryStore.importBoardAsCopy(
        sourcePath,
        name,
      );
      if (mounted) {
        setState(() {
          _openBoard = board;
          _initialTarget = null;
          _showBlankCanvasPriming = false;
        });
      }
    } on BoardTransferException catch (error) {
      if (mounted) {
        _showTransferMessage(_transferErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showTransferMessage('Could not import the portable board as a copy');
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  void _showTransferMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _transferErrorMessage(BoardTransferException error) {
    return switch (error.kind) {
      BoardTransferFailureKind.duplicateBoard =>
        'This board already exists. No boards were changed.',
      BoardTransferFailureKind.unsupportedPackageVersion =>
        'This portable board was created by an unsupported version.',
      BoardTransferFailureKind.missingAsset =>
        'The portable board is missing a managed image.',
      BoardTransferFailureKind.invalidArchive =>
        'The selected file is not a valid portable board.',
      BoardTransferFailureKind.fileSystem =>
        'The portable board could not be read or written.',
    };
  }

  static String _backupErrorMessage(BoardLibraryBackupException error) {
    return switch (error.kind) {
      BoardLibraryBackupFailureKind.noBoards =>
        'There are no available boards to export.',
      BoardLibraryBackupFailureKind.unavailableBoards => () {
        final count = error.unavailableBoardCount;
        final noun = count == 1 ? 'board' : 'boards';
        return '$count unavailable $noun prevents a complete export.';
      }(),
      BoardLibraryBackupFailureKind.boardExport =>
        'A board could not be packaged, so no complete export was created.',
      BoardLibraryBackupFailureKind.missingManifest =>
        'The selected folder does not contain a backup manifest.',
      BoardLibraryBackupFailureKind.invalidManifest =>
        'The backup manifest is invalid.',
      BoardLibraryBackupFailureKind.invalidPackage =>
        'A backup package is invalid.',
      BoardLibraryBackupFailureKind.fileSystem =>
        'The complete board export could not be written.',
    };
  }

  static String _backupVerificationErrorMessage(
    BoardLibraryBackupException error,
  ) {
    return switch (error.kind) {
      BoardLibraryBackupFailureKind.missingManifest =>
        'The selected folder does not contain a backup manifest.',
      BoardLibraryBackupFailureKind.invalidManifest =>
        'The backup folder does not match a valid manifest.',
      BoardLibraryBackupFailureKind.invalidPackage =>
        'A backup package could not be verified.',
      BoardLibraryBackupFailureKind.fileSystem =>
        'The selected backup folder could not be read.',
      BoardLibraryBackupFailureKind.noBoards ||
      BoardLibraryBackupFailureKind.unavailableBoards ||
      BoardLibraryBackupFailureKind.boardExport =>
        'The backup folder could not be verified.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final openBoard = _openBoard;
    if (openBoard != null) {
      final editorBuilder = widget.editorBuilder;
      if (editorBuilder != null) {
        return editorBuilder(
          openBoard,
          _showBlankCanvasPriming,
          _initialTarget,
          () {
            setState(() {
              _openBoard = null;
              _initialTarget = null;
              _showBlankCanvasPriming = false;
            });
            _reload();
          },
        );
      }
      return FutureBuilder(
        future: widget.libraryStore.boardDirectory(openBoard.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Could not open Board folder')),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Check that the Library folder is available.'),
                    FilledButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _openBoard = null),
                      child: const Text('Return to Library'),
                    ),
                  ],
                ),
              ),
            );
          }
          final directory = snapshot.data;
          if (directory == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return CanvasExperiment(
            key: ValueKey('board-editor-${openBoard.id}'),
            boardStore: FileBoardStore.scoped(
              boardDirectoryProvider: () async => directory,
            ),
            imageAssetStore: FileImageAssetStore.scoped(
              boardDirectoryProvider: () async => directory,
            ),
            attachmentAssetStore: FileAttachmentAssetStore.scoped(
              boardDirectoryProvider: () async => directory,
            ),
            imagePicker: pickImagePath,
            clipboardImageReader: widget.clipboardImageReader,
            crossBoardClipboard: _crossBoardClipboard,
            isDarkMode: widget.isDarkMode,
            onToggleDarkMode: widget.onToggleDarkMode,
            initialTarget: _initialTarget,
            showBlankCanvasPriming: _showBlankCanvasPriming,
            onReturnToLibrary: () {
              setState(() {
                _openBoard = null;
                _initialTarget = null;
                _showBlankCanvasPriming = false;
              });
              _reload();
            },
          );
        },
      );
    }

    final filteredEntries = _filteredEntries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vasmim Library'),
        actions: [
          IconButton(
            key: const ValueKey('library-help-button'),
            tooltip: 'Help and shortcuts',
            onPressed: () => showVasmimHelp(context),
            icon: const Icon(Icons.help_outline),
          ),
          if (widget.onToggleDarkMode != null)
            IconButton(
              key: const ValueKey('library-appearance-toggle'),
              tooltip: widget.isDarkMode ? 'Use light mode' : 'Use dark mode',
              onPressed: widget.onToggleDarkMode,
              icon: Icon(
                widget.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          if (_isTransferring || _isFindingObject)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              key: const ValueKey('export-all-boards-button'),
              tooltip: 'Export all boards...',
              onPressed:
                  _isLoading ||
                      _isUpdatingFavorite ||
                      !_entries.any((entry) => entry.isAvailable)
                  ? null
                  : _exportAllBoards,
              icon: const Icon(Icons.folder_copy_outlined),
            ),
            IconButton(
              key: const ValueKey('verify-backup-folder-button'),
              tooltip: 'Verify backup folder...',
              onPressed: _isLoading || _isUpdatingFavorite
                  ? null
                  : _verifyBackupFolder,
              icon: const Icon(Icons.verified_outlined),
            ),
            IconButton(
              key: const ValueKey('import-board-button'),
              tooltip: 'Import portable board',
              onPressed: _isLoading || _isUpdatingFavorite
                  ? null
                  : _importBoard,
              icon: const Icon(Icons.file_open_outlined),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                if (_folderError != null)
                  MaterialBanner(
                    key: const ValueKey('library-folder-error'),
                    content: Text(_folderError!),
                    actions: [
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    key: const ValueKey('board-search-field'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Search boards',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey('clear-board-search'),
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              key: const ValueKey('library-folder-selector'),
                              children: [
                                ChoiceChip(
                                  key: const ValueKey('folder-all'),
                                  label: Text(
                                    'All Boards (${_entries.where((entry) => entry.isAvailable).length})',
                                  ),
                                  selected: _selectedFolderId == null,
                                  onSelected: (_) =>
                                      setState(() => _selectedFolderId = null),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  key: const ValueKey('folder-unfiled'),
                                  label: Text(
                                    'Unfiled (${_entries.where((entry) => entry.isAvailable && !_boardFolderIds.containsKey(entry.boardId)).length})',
                                  ),
                                  selected: _selectedFolderId == '_unfiled',
                                  onSelected: (_) => setState(
                                    () => _selectedFolderId = '_unfiled',
                                  ),
                                ),
                                for (final folder in _folders) ...[
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    key: ValueKey('folder-${folder.id}'),
                                    label: Text(
                                      '${folder.name} (${_boardFolderIds.values.where((id) => id == folder.id).length})',
                                    ),
                                    selected: _selectedFolderId == folder.id,
                                    onSelected: (_) => setState(
                                      () => _selectedFolderId = folder.id,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('create-folder-button'),
                          tooltip: 'New folder',
                          onPressed: _isBusy ? null : _createFolder,
                          icon: const Icon(Icons.create_new_folder_outlined),
                        ),
                        if (_selectedFolderId != null &&
                            _selectedFolderId != '_unfiled')
                          PopupMenuButton<String>(
                            key: const ValueKey('selected-folder-actions'),
                            tooltip: 'Folder actions',
                            onSelected: (value) => value == 'rename'
                                ? _renameSelectedFolder()
                                : _deleteSelectedFolder(),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename folder'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete empty folder'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('find-note-across-boards-button'),
                        onPressed: _isBusy ? null : _showFindAcrossBoards,
                        icon: const Icon(Icons.manage_search),
                        label: const Text('Find across boards'),
                      ),
                      if (_folders.isEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('create-folder-button'),
                          onPressed: _isBusy ? null : _createFolder,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('New folder'),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<_BoardSortOrder>(
                      key: const ValueKey('board-time-sort'),
                      segments: const [
                        ButtonSegment(
                          value: _BoardSortOrder.newestFirst,
                          icon: Icon(Icons.arrow_downward),
                          label: Text('Newest first'),
                        ),
                        ButtonSegment(
                          value: _BoardSortOrder.oldestFirst,
                          icon: Icon(Icons.arrow_upward),
                          label: Text('Oldest first'),
                        ),
                      ],
                      selected: {_sortOrder},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _sortOrder = selection.single);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Text(
                            'No boards yet. Create one to start thinking.',
                          ),
                        )
                      : filteredEntries.isEmpty
                      ? const Center(
                          child: Text('No boards match your search.'),
                        )
                      : ListView.builder(
                          key: const ValueKey('board-list'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            final board = entry.board;
                            if (board == null) {
                              return ListTile(
                                key: ValueKey(
                                  'unavailable-board-${entry.boardId}',
                                ),
                                leading: const Icon(
                                  Icons.warning_amber_outlined,
                                ),
                                title: Text(entry.boardId),
                                subtitle: Text(
                                  entry.error ?? 'Board unavailable',
                                ),
                              );
                            }
                            final isFavorite = _favoriteBoardIds.contains(
                              board.id,
                            );
                            return Card(
                              child: SizedBox(
                                height: 64,
                                child: ListTile(
                                  key: ValueKey('board-${board.id}'),
                                  leading: BoardLibraryThumbnail(board: board),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: GestureDetector(
                                          onDoubleTap: _isBusy
                                              ? null
                                              : () => _renameBoard(board),
                                          child: Text(board.name),
                                        ),
                                      ),
                                      if (isFavorite) ...[
                                        const SizedBox(width: 6),
                                        Semantics(
                                          key: ValueKey(
                                            'favorite-indicator-${board.id}',
                                          ),
                                          label: 'Favorite',
                                          child: const ExcludeSemantics(
                                            child: Icon(Icons.star, size: 18),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Modified ${_formatDate(board.modifiedAt)}',
                                  ),
                                  onTap: _isBusy
                                      ? null
                                      : () => setState(() {
                                          _openBoard = board;
                                          _initialTarget = null;
                                          _showBlankCanvasPriming = false;
                                        }),
                                  trailing: PopupMenuButton<_BoardAction>(
                                    key: ValueKey('board-actions-${board.id}'),
                                    enabled: !_isBusy,
                                    requestFocus: true,
                                    tooltip: 'Board actions for ${board.name}',
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (action) =>
                                        _handleBoardAction(board, action),
                                    itemBuilder: (context) {
                                      final errorColor = Theme.of(
                                        context,
                                      ).colorScheme.error;
                                      return [
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-preview-${board.id}',
                                          ),
                                          value: _BoardAction.preview,
                                          child: const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.preview_outlined,
                                            ),
                                            title: Text('Preview board'),
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-move-${board.id}',
                                          ),
                                          value: _BoardAction.moveToFolder,
                                          child: const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.drive_file_move_outline,
                                            ),
                                            title: Text('Move to folder...'),
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-favorite-${board.id}',
                                          ),
                                          value: _BoardAction.favorite,
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              isFavorite
                                                  ? Icons.star
                                                  : Icons.star_border,
                                            ),
                                            title: Text(
                                              isFavorite
                                                  ? 'Remove from favorites'
                                                  : 'Add to favorites',
                                            ),
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-rename-${board.id}',
                                          ),
                                          value: _BoardAction.rename,
                                          child: const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Icons.edit_outlined),
                                            title: Text('Rename'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-duplicate-${board.id}',
                                          ),
                                          value: _BoardAction.duplicate,
                                          child: const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.copy_all_outlined,
                                            ),
                                            title: Text('Duplicate'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-export-${board.id}',
                                          ),
                                          value: _BoardAction.export,
                                          child: const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.file_download_outlined,
                                            ),
                                            title: Text('Export'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-find-in-explorer-${board.id}',
                                          ),
                                          value: _BoardAction.findInExplorer,
                                          child: const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.folder_open_outlined,
                                            ),
                                            title: Text('Find in Explorer'),
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          key: ValueKey(
                                            'board-action-delete-${board.id}',
                                          ),
                                          value: _BoardAction.delete,
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            iconColor: errorColor,
                                            textColor: errorColor,
                                            title: const Text('Delete'),
                                          ),
                                        ),
                                      ];
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                key: const ValueKey('create-kanban-board-button'),
                leadingIcon: const Icon(Icons.view_column_outlined),
                onPressed: () => _createBoard(starter: BoardStarter.kanban),
                child: const _StarterMenuLabel(
                  title: 'Kanban',
                  description: 'To do, In progress, Done',
                ),
              ),
              MenuItemButton(
                key: const ValueKey('create-eisenhower-board-button'),
                leadingIcon: const Icon(Icons.grid_view_outlined),
                onPressed: () => _createBoard(starter: BoardStarter.eisenhower),
                child: const _StarterMenuLabel(
                  title: 'Eisenhower Matrix',
                  description: 'Important and urgent priorities',
                ),
              ),
              MenuItemButton(
                key: const ValueKey('create-swot-board-button'),
                leadingIcon: const Icon(Icons.window_outlined),
                onPressed: () => _createBoard(starter: BoardStarter.swot),
                child: const _StarterMenuLabel(
                  title: 'SWOT matrix',
                  description: 'Strengths, Weaknesses, Opportunities, Threats',
                ),
              ),
              MenuItemButton(
                key: const ValueKey('create-campaign-brief-board-button'),
                leadingIcon: const Icon(Icons.campaign_outlined),
                onPressed: () =>
                    _createBoard(starter: BoardStarter.campaignBrief),
                child: const _StarterMenuLabel(
                  title: 'Campaign brief',
                  description:
                      'Goal, audience, message, channels, schedule, measures',
                ),
              ),
            ],
            builder: (context, controller, child) => FilledButton.tonalIcon(
              key: const ValueKey('create-starter-board-menu'),
              onPressed: _isLoading || _isBusy
                  ? null
                  : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Starter board'),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            key: const ValueKey('create-board-button'),
            onPressed: _isLoading || _isBusy ? null : _createBoard,
            icon: const Icon(Icons.add),
            label: const Text('New board'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StarterMenuLabel extends StatelessWidget {
  const _StarterMenuLabel({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialName.isEmpty ? 'New folder' : 'Rename folder'),
    content: TextField(
      key: const ValueKey('folder-name-field'),
      controller: _controller,
      autofocus: true,
      maxLength: LibraryFolder.maximumNameCharacters,
      onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      decoration: const InputDecoration(labelText: 'Folder name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('confirm-folder-name-button'),
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: Text(widget.initialName.isEmpty ? 'Create folder' : 'Rename'),
      ),
    ],
  );
}
