import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/appearance/app_appearance_store.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/board_paper_tone.dart';
import 'package:vasmim/board/board_library_screen.dart';
import 'package:vasmim/board/board_library_store.dart';
import 'package:vasmim/board/library_folder.dart';
import 'package:vasmim/board/board_preview_dialog.dart';
import 'package:vasmim/board/board_store.dart';
import 'package:vasmim/board/board_starter.dart';
import 'package:vasmim/board/board_transfer_picker.dart';
import 'package:vasmim/canvas/canvas_experiment.dart';
import 'package:vasmim/canvas/canvas_initial_target.dart';
import 'package:vasmim/canvas/canvas_overview_map.dart';
import 'package:vasmim/canvas/canvas_paper_painter.dart';
import 'package:vasmim/canvas/cross_board_clipboard.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/connector/connector_geometry.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/group/board_group.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/image/image_asset_store.dart';
import 'package:vasmim/image/interactive_board_image.dart';
import 'package:vasmim/note/editable_note.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/main.dart';
import 'package:vasmim/scene/scene.dart';

void main() {
  const boardId = '123e4567-e89b-42d3-a456-426614174000';

  testWidgets('failed deletion explains the error and retains the Board', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Keep me')],
    );
    store.deleteFailure = const FileSystemException('File locked');
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await _chooseBoardAction(tester, boardId, 'delete');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-board-button')));
    await tester.pumpAndSettle();
    expect(find.text('Keep me'), findsOneWidget);
    expect(
      find.textContaining('Could not finish deleting this Board'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'directory lookup failure offers retry and return instead of a spinner',
    (tester) async {
      final store = _MemoryBoardLibraryStore(
        boards: [_board(id: boardId, name: 'Unavailable folder')],
      );
      await tester.pumpWidget(
        MaterialApp(home: BoardLibraryScreen(libraryStore: store)),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getBottomLeft(find.byKey(const ValueKey('board-$boardId'))) +
            const Offset(100, -10),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not open Board folder'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open Board folder'), findsOneWidget);
      await tester.tap(find.text('Return to Library'));
      await tester.pumpAndSettle();
      expect(find.text('Vasmim Library'), findsOneWidget);
    },
  );

  testWidgets('Library Help opens offline guidance and closes without edits', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Help and shortcuts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-help-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vasmim-help-dialog')), findsOneWidget);
    expect(find.text('Create a Board'), findsOneWidget);
    await tester.tap(find.text('Keep safe'));
    await tester.pumpAndSettle();
    expect(find.text('Back up the Library'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-help-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vasmim-help-dialog')), findsNothing);
    expect(store.lastCreatedStarter, isNull);
  });

  testWidgets('starter menu exposes four layouts and closes without creation', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Kanban'), findsOneWidget);
    expect(find.text('To do, In progress, Done'), findsOneWidget);
    expect(find.text('Eisenhower Matrix'), findsOneWidget);
    expect(find.text('Important and urgent priorities'), findsOneWidget);
    expect(find.text('SWOT matrix'), findsOneWidget);
    expect(
      find.text('Strengths, Weaknesses, Opportunities, Threats'),
      findsOneWidget,
    );
    expect(find.text('Campaign brief'), findsOneWidget);
    expect(
      find.text('Goal, audience, message, channels, schedule, measures'),
      findsOneWidget,
    );
    for (final key in [
      'create-kanban-board-button',
      'create-eisenhower-board-button',
      'create-swot-board-button',
      'create-campaign-brief-board-button',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThanOrEqualTo(600));
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, isNull);
    expect(find.byKey(const ValueKey('create-board-button')), findsOneWidget);
  });

  testWidgets('creates a Kanban starter only after a name is confirmed', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    bool? showedBlankPriming;
    await tester.pumpWidget(
      _testApp(store, onEditorOpened: (value) => showedBlankPriming = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-kanban-board-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, isNull);

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-kanban-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Release work',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, BoardStarter.kanban);
    expect(showedBlankPriming, isFalse);
    expect(find.text('Editing Release work'), findsOneWidget);
  });

  testWidgets('creates an Eisenhower starter only after a name is confirmed', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    bool? showedBlankPriming;
    await tester.pumpWidget(
      _testApp(store, onEditorOpened: (value) => showedBlankPriming = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('create-eisenhower-board-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, isNull);

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('create-eisenhower-board-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Priorities',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, BoardStarter.eisenhower);
    expect(showedBlankPriming, isFalse);
    expect(find.text('Editing Priorities'), findsOneWidget);
  });

  testWidgets('creates a SWOT starter only after a name is confirmed', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    bool? showedBlankPriming;
    await tester.pumpWidget(
      _testApp(store, onEditorOpened: (value) => showedBlankPriming = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-swot-board-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, isNull);

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-swot-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Campaign review',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, BoardStarter.swot);
    expect(showedBlankPriming, isFalse);
    expect(find.text('Editing Campaign review'), findsOneWidget);
  });

  testWidgets('creates a campaign brief only after a name is confirmed', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    bool? showedBlankPriming;
    await tester.pumpWidget(
      _testApp(store, onEditorOpened: (value) => showedBlankPriming = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('create-campaign-brief-board-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, isNull);

    await tester.tap(find.byKey(const ValueKey('create-starter-board-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('create-campaign-brief-board-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Launch campaign',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    expect(store.lastCreatedStarter, BoardStarter.campaignBrief);
    expect(showedBlankPriming, isFalse);
    expect(find.text('Editing Launch campaign'), findsOneWidget);
  });

  testWidgets('switches the Library between persisted light and dark mode', (
    tester,
  ) async {
    final appearance = MemoryAppAppearanceStore();
    await tester.pumpWidget(
      MainApp(
        boardLibraryStore: _MemoryBoardLibraryStore(),
        appearanceStore: appearance,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(BoardLibraryScreen))).brightness,
      Brightness.light,
    );
    await tester.tap(find.byKey(const ValueKey('library-appearance-toggle')));
    await tester.pumpAndSettle();
    expect(await appearance.readDarkMode(), isTrue);
    expect(
      Theme.of(tester.element(find.byType(BoardLibraryScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('keeps copied Notes across the real Library transition', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 21, 21);
    final clipboard = CrossBoardClipboard();
    final store = _MemoryBoardLibraryStore(
      boards: [
        BoardDocument(
          id: 'board-a',
          name: 'Board A',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'source-note',
              x: 100,
              y: 100,
              width: 260,
              height: 170,
              text: 'Carry me',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
            Note(
              id: 'source-note-2',
              x: 420,
              y: 180,
              width: 240,
              height: 160,
              text: 'Keep me together',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
        BoardDocument(
          id: 'board-b',
          name: 'Board B',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
        ),
      ],
    );
    await tester.pumpWidget(
      _testApp(
        store,
        crossBoardClipboard: clipboard,
        editorBuilder: (board, _, initialTarget, onReturn) => CanvasExperiment(
          key: ValueKey('editor-${board.id}'),
          boardStore: _LibraryBackedBoardStore(store, board.id),
          imageAssetStore: _NoopImageAssetStore(),
          imagePicker: () async => null,
          imageViewBuilder: (_) => const SizedBox(),
          initialTarget: initialTarget,
          onReturnToLibrary: onReturn,
          crossBoardClipboard: clipboard,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('board-board-a')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-source-note')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-source-note-2')),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();

    expect(clipboard.hasPayload, isTrue);
    expect(
      find.text('Copied 2 objects for this and other Boards.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('return-to-library-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('board-board-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    final destination = await store.loadBoard('board-b');
    expect(destination.notes, hasLength(2));
    expect(
      destination.notes.map((note) => note.text),
      containsAll(['Carry me', 'Keep me together']),
    );
    expect(destination.groups, hasLength(1));
    expect(
      destination.groups.single.memberIds.toSet(),
      destination.notes.map((note) => note.id).toSet(),
    );
  });

  testWidgets('keeps one copied Image across the real Library transition', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 22, 14);
    final clipboard = CrossBoardClipboard();
    final imageAssets = _CrossBoardImageAssetStore();
    final sourceImage = BoardImage(
      id: 'library-source-image',
      x: 120,
      y: 160,
      width: 300,
      height: 180,
      assetPath: 'assets/source.png',
      originalFileName: 'Library source.png',
      pixelWidth: 1,
      pixelHeight: 1,
      caption: 'Library transition',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final store = _MemoryBoardLibraryStore(
      boards: [
        BoardDocument(
          id: 'image-board-a',
          name: 'Image Board A',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
          images: [sourceImage],
        ),
        BoardDocument(
          id: 'image-board-b',
          name: 'Image Board B',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
        ),
      ],
    );
    await tester.pumpWidget(
      _testApp(
        store,
        crossBoardClipboard: clipboard,
        editorBuilder: (board, _, initialTarget, onReturn) => CanvasExperiment(
          key: ValueKey('editor-${board.id}'),
          boardStore: _LibraryBackedBoardStore(store, board.id),
          imageAssetStore: imageAssets,
          imagePicker: () async => null,
          imageViewBuilder: (_) => const SizedBox(),
          initialTarget: initialTarget,
          onReturnToLibrary: onReturn,
          crossBoardClipboard: clipboard,
          crossBoardImageSnapshotCapturer:
              ({required image, required sourceFile}) async =>
                  CrossBoardImageSnapshot.fromValidatedBytes(
                    image: image,
                    bytes: _libraryOnePixelPng,
                  ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('board-image-board-a')));
    await tester.pumpAndSettle();
    tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .onSelect();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    expect(clipboard.payload!.image, isNotNull);

    await tester.tap(find.byKey(const ValueKey('return-to-library-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('board-image-board-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    final destination = await store.loadBoard('image-board-b');
    expect(destination.images, hasLength(1));
    expect(destination.images.single.id, isNot('library-source-image'));
    expect(destination.images.single.assetPath, 'assets/library-copy.png');
    expect(destination.images.single.caption, 'Library transition');
    expect(imageAssets.importByteCalls, 1);
    expect(imageAssets.receivedBytes, orderedEquals(_libraryOnePixelPng));
  });

  testWidgets('creates, opens, returns to, renames, and deletes a board', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    final primingStates = <bool>[];
    await tester.pumpWidget(_testApp(store, onEditorOpened: primingStates.add));
    await tester.pumpAndSettle();

    expect(find.text('Vasmim Library'), findsOneWidget);
    expect(find.textContaining('No boards yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      ' Personal Plan ',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();

    expect(find.text('Editing Personal Plan'), findsOneWidget);
    expect(primingStates.last, isTrue);
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();
    expect(find.text('Personal Plan'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('favorite-indicator-$boardId')),
      findsNothing,
    );

    await _chooseBoardAction(tester, boardId, 'rename');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Main Plan',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    expect(find.text('Main Plan'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('board-$boardId')));
    await tester.pumpAndSettle();
    expect(find.text('Editing Main Plan'), findsOneWidget);
    expect(primingStates.last, isFalse);
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();
    await _chooseBoardAction(tester, boardId, 'delete');
    await tester.pumpAndSettle();
    expect(find.text('Delete “Main Plan”?'), findsOneWidget);
    expect(
      find.textContaining('Other boards are not changed.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-delete-board-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No boards yet'), findsOneWidget);
  });

  testWidgets('creates a folder, moves a Board, and filters exact membership', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: 'board-a', name: 'Compiler'),
        _board(id: 'board-b', name: 'Holiday'),
      ],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-folder-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      'Programming',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-folder-name-button')));
    await tester.pumpAndSettle();

    final folder = store._folders.single;
    expect(find.byKey(ValueKey('folder-${folder.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-list')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('folder-all')));
    await tester.pumpAndSettle();
    await _chooseBoardAction(tester, 'board-a', 'move');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('move-board-folder-${folder.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('folder-${folder.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Compiler'), findsOneWidget);
    expect(find.text('Holiday'), findsNothing);
    expect(store._boardFolderIds, {'board-a': folder.id});
  });

  testWidgets('creates a new Board in the selected project folder', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-folder-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('folder-name-field')),
      'UI design',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-folder-name-button')));
    await tester.pumpAndSettle();
    final folder = store._folders.single;

    await tester.tap(find.byKey(const ValueKey('create-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'New mockup',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    expect(store._boardFolderIds[boardId], folder.id);
  });

  for (final starter in [BoardStarter.blank, BoardStarter.kanban]) {
    for (final view in ['older-folder', 'all', 'unfiled']) {
      testWidgets('creates $starter in the destination for $view', (
        tester,
      ) async {
        final store = _MemoryBoardLibraryStore(
          boards: [_board(id: 'existing-board', name: 'Existing project')],
        );
        final older = await store.createLibraryFolder('Older');
        final latest = await store.createLibraryFolder('Latest');
        await store.setBoardFolder('existing-board', older.id);
        await tester.pumpWidget(_testApp(store));
        await tester.pumpAndSettle();

        // Visit the latest folder first, then deliberately change destinations.
        await tester.tap(find.byKey(ValueKey('folder-${latest.id}')));
        await tester.pumpAndSettle();
        final destinationKey = view == 'older-folder'
            ? 'folder-${older.id}'
            : 'folder-$view';
        await tester.tap(find.byKey(ValueKey(destinationKey)));
        await tester.pumpAndSettle();
        if (view == 'older-folder') {
          await tester.tap(find.byKey(const ValueKey('board-existing-board')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('test-return-button')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(find.byKey(ValueKey('folder-${older.id}')))
                .selected,
            isTrue,
          );
        }

        if (starter == BoardStarter.blank) {
          await tester.tap(find.byKey(const ValueKey('create-board-button')));
        } else {
          await tester.tap(
            find.byKey(const ValueKey('create-starter-board-menu')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('create-kanban-board-button')),
          );
        }
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('board-name-field')),
          'New project',
        );
        await tester.tap(
          find.byKey(const ValueKey('confirm-board-name-button')),
        );
        await tester.pumpAndSettle();
        final expectedFolderId = switch (view) {
          'older-folder' => older.id,
          'all' => latest.id,
          _ => null,
        };
        expect(store._boardFolderIds[boardId], expectedFolderId);
        expect(store.lastCreatedStarter, starter);

        await tester.tap(find.byKey(const ValueKey('test-return-button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey(
              expectedFolderId == null
                  ? 'folder-unfiled'
                  : 'folder-$expectedFolderId',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('board-$boardId')), findsOneWidget);
        expect(store._boardFolderIds['existing-board'], older.id);
      });
    }
  }

  testWidgets('double-clicking a Library Board name opens rename', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'rename-target', name: 'Mockup')],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mockup'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Mockup'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board-name-field')), findsOneWidget);
    expect(find.text('Editing Mockup'), findsNothing);
  });

  testWidgets('malformed folder metadata leaves healthy Boards available', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'board-a', name: 'Compiler')],
      folderFailure: const FormatException('bad folders'),
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-folder-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-board-a')), findsOneWidget);
  });

  testWidgets(
    'validates, duplicates, opens immediately, and retains library state',
    (tester) async {
      final store = _MemoryBoardLibraryStore(
        boards: [
          _board(
            id: 'source-board',
            name: 'Project Roadmap',
            modifiedAt: DateTime.utc(2026, 6, 1),
          ),
        ],
        favoriteBoardIds: {'source-board'},
      );
      final primingStates = <bool>[];
      await tester.pumpWidget(
        _testApp(store, onEditorOpened: primingStates.add),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-search-field')),
        'roadmap',
      );
      await tester.tap(find.text('Oldest first'));
      await tester.pump();

      await _chooseBoardAction(tester, 'source-board', 'duplicate');
      await tester.pumpAndSettle();
      expect(find.text('Duplicate board'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('board-name-field')))
            .controller!
            .text,
        'Copy of Project Roadmap',
      );
      await tester.enterText(
        find.byKey(const ValueKey('board-name-field')),
        '   ',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
      await tester.pump();
      expect(find.text('Enter a board name'), findsOneWidget);
      expect(store.duplicateCalls, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.duplicateCalls, isEmpty);

      await _chooseBoardAction(tester, 'source-board', 'duplicate');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-name-field')),
        ' Alternative Roadmap ',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
      await tester.pumpAndSettle();

      expect(find.text('Editing Alternative Roadmap'), findsOneWidget);
      expect(store.duplicateCalls, [('source-board', 'Alternative Roadmap')]);
      expect(primingStates.last, isFalse);
      await tester.tap(find.byKey(const ValueKey('test-return-button')));
      await tester.pumpAndSettle();
      expect(find.text('Oldest first'), findsOneWidget);
      _expectVerticalOrder(tester, ['Project Roadmap', 'Alternative Roadmap']);
      expect(
        find.byKey(const ValueKey('favorite-indicator-source-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'favorite-indicator-123e4567-e89b-42d3-b456-426614174019',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('disables conflicting library actions while duplicating', (
    tester,
  ) async {
    final duplicateGate = Completer<void>();
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'source-board', name: 'Source')],
      duplicateGate: duplicateGate,
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await _chooseBoardAction(tester, 'source-board', 'duplicate');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pump();

    expect(
      tester
          .widget<PopupMenuButton<dynamic>>(
            find.byKey(const ValueKey('board-actions-source-board')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('create-board-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('board-source-board')))
          .onTap,
      isNull,
    );

    duplicateGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Editing Copy of Source'), findsOneWidget);
  });

  testWidgets('shows an unavailable board without hiding a healthy board', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'healthy-board', name: 'Healthy')],
      unavailableIds: ['corrupt-board'],
      favoriteBoardIds: {'healthy-board', 'corrupt-board', 'missing-board'},
    );

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.text('Healthy'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('unavailable-board-corrupt-board')),
      findsOneWidget,
    );
    expect(find.textContaining('unavailable or invalid'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('board-actions-healthy-board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('board-actions-corrupt-board')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('favorite-indicator-healthy-board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('favorite-indicator-corrupt-board')),
      findsNothing,
    );
  });

  testWidgets('shows one labeled ordered board-actions menu with safe delete', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Planning Board')],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Board actions for Planning Board'), findsOneWidget);
    expect(find.byKey(ValueKey('rename-board-$boardId')), findsNothing);
    expect(find.byKey(ValueKey('duplicate-board-$boardId')), findsNothing);
    expect(find.byKey(ValueKey('export-board-$boardId')), findsNothing);
    expect(find.byKey(ValueKey('delete-board-$boardId')), findsNothing);

    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, [
      'Preview board',
      'Move to folder...',
      'Add to favorites',
      'Rename',
      'Duplicate',
      'Export',
      'Find in Explorer',
      'Delete',
    ]);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.preview_outlined), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsNWidgets(4));
    final deleteItem = tester.widget<PopupMenuItem<dynamic>>(
      find.byKey(ValueKey('board-action-delete-$boardId')),
    );
    final deleteTile = deleteItem.child! as ListTile;
    expect(
      deleteTile.textColor,
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.error,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Editing Planning Board'), findsNothing);
    expect(store.deleteCalls, isEmpty);

    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(12, 300));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Editing Planning Board'), findsNothing);
    expect(store.deleteCalls, isEmpty);
  });

  testWidgets('Find in Explorer opens the selected Board storage folder', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('vasmim-board-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File(
      '${directory.path}${Platform.pathSeparator}board.json',
    ).writeAsStringSync('{}');
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Planning Board')],
      storageDirectory: directory,
    );
    Directory? openedDirectory;
    await tester.pumpWidget(
      _testApp(
        store,
        explorerLauncher: (directory) async => openedDirectory = directory,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find in Explorer'));
    await tester.pumpAndSettle();

    expect(openedDirectory?.path, directory.path);
    expect(find.text('Editing Planning Board'), findsNothing);
  });

  testWidgets('supports keyboard navigation inside the board actions menu', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Keyboard Board')],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('board-preview-dialog')), findsOneWidget);
    expect(store.previewLoadCalls, [boardId]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board-preview-dialog')), findsNothing);
  });

  testWidgets('shows a whole-board thumbnail for each Library board', (
    tester,
  ) async {
    final board = _previewBoard(
      id: boardId,
      name: 'Spatial Plan',
    ).copyWith(paperTone: BoardPaperTone.blue);
    final store = _MemoryBoardLibraryStore(boards: [board]);
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    final thumbnailFinder = find.byKey(ValueKey('board-thumbnail-$boardId'));
    expect(thumbnailFinder, findsOneWidget);
    final painter =
        tester.widget<CustomPaint>(thumbnailFinder).painter!
            as CanvasOverviewPainter;
    expect(painter.objects, hasLength(3));
    expect(painter.links, hasLength(2));
    expect(painter.overviewSize, BoardLibraryThumbnail.thumbnailSize);
    expect(painter.showViewport, isFalse);
    expect(
      painter.backgroundColor,
      LayeredCanvasPaperPainter.paperColorFor(
        BoardPaperTone.blue,
        isDark: false,
      ),
    );
    expect(painter.objects.every((object) => !object.isSelected), isTrue);
  });

  testWidgets(
    'previews one requested board as a read-only spatial fingerprint',
    (tester) async {
      final board = _previewBoard(id: boardId, name: 'Spatial Plan');
      final store = _MemoryBoardLibraryStore(boards: [board]);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_testApp(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('board-action-preview-$boardId')));
      await tester.pumpAndSettle();

      expect(store.previewLoadCalls, [boardId]);
      expect(
        find.byKey(const ValueKey('board-preview-dialog')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('board-preview-dialog')),
          matching: find.text('Spatial Plan'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Board preview showing 3 objects and the saved viewport',
        ),
        findsOneWidget,
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('board-preview-paint')),
                  )
                  .painter!
              as CanvasOverviewPainter;
      expect(painter.objects, hasLength(3));
      expect(painter.links, hasLength(2));
      expect(painter.overviewSize, const Size(480, 360));
      expect(painter.objects.every((object) => !object.isSelected), isTrue);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('supports'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('close-board-preview-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vasmim Library'), findsOneWidget);
      expect(store.discoverCalls, 1);
      expect(store.favoriteCalls, isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets('preview opens the exact board and retains Library search', (
    tester,
  ) async {
    final target = _previewBoard(id: boardId, name: 'Preview Target');
    final store = _MemoryBoardLibraryStore(
      boards: [
        target,
        _board(id: 'other-board', name: 'Other Board'),
      ],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'target',
    );
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('board-action-preview-$boardId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-board-preview-button')));
    await tester.pumpAndSettle();

    expect(find.text('Editing Preview Target'), findsOneWidget);
    expect(store.previewLoadCalls, [boardId]);
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .controller!
          .text,
      'target',
    );
    expect(find.text('Preview Target'), findsOneWidget);
    expect(find.text('Other Board'), findsNothing);
  });

  testWidgets('preview failure is isolated and the dialog fits at 800 by 600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final healthy = _previewBoard(id: boardId, name: 'Healthy Preview');
    final store = _MemoryBoardLibraryStore(boards: [healthy]);
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('board-action-preview-$boardId')));
    await tester.pumpAndSettle();
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('board-preview-dialog')),
    );
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(800));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));
    await tester.tap(find.byKey(const ValueKey('close-board-preview-button')));
    await tester.pumpAndSettle();

    store.previewFailure = const FormatException('became unreadable');
    await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('board-action-preview-$boardId')));
    await tester.pumpAndSettle();
    expect(find.text('Could not preview the board'), findsOneWidget);
    expect(find.byKey(ValueKey('board-$boardId')), findsOneWidget);
  });

  testWidgets('favorites group first within both time-sort directions', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'favorite-old',
          name: 'Plan Favorite Old',
          modifiedAt: DateTime.utc(2026, 6, 1),
        ),
        _board(
          id: 'normal-old',
          name: 'Plan Normal Old',
          modifiedAt: DateTime.utc(2026, 6, 2),
        ),
        _board(
          id: 'normal-new',
          name: 'Plan Normal New',
          modifiedAt: DateTime.utc(2026, 6, 3),
        ),
        _board(
          id: 'favorite-new',
          name: 'Plan Favorite New',
          modifiedAt: DateTime.utc(2026, 6, 4),
        ),
      ],
      favoriteBoardIds: {'favorite-old', 'favorite-new'},
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, [
      'Plan Favorite New',
      'Plan Favorite Old',
      'Plan Normal New',
      'Plan Normal Old',
    ]);
    await tester.tap(find.text('Oldest first'));
    await tester.pump();
    _expectVerticalOrder(tester, [
      'Plan Favorite Old',
      'Plan Favorite New',
      'Plan Normal Old',
      'Plan Normal New',
    ]);
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'plan',
    );
    await tester.pump();
    _expectVerticalOrder(tester, [
      'Plan Favorite Old',
      'Plan Favorite New',
      'Plan Normal Old',
      'Plan Normal New',
    ]);
  });

  testWidgets('breaks modification ties by ID inside favorite groups', (
    tester,
  ) async {
    final modifiedAt = DateTime.utc(2026, 6, 1);
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: 'favorite-b', name: 'Favorite B', modifiedAt: modifiedAt),
        _board(id: 'normal-b', name: 'Normal B', modifiedAt: modifiedAt),
        _board(id: 'favorite-a', name: 'Favorite A', modifiedAt: modifiedAt),
        _board(id: 'normal-a', name: 'Normal A', modifiedAt: modifiedAt),
      ],
      favoriteBoardIds: {'favorite-a', 'favorite-b'},
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, [
      'Favorite A',
      'Favorite B',
      'Normal A',
      'Normal B',
    ]);
  });

  testWidgets('adds and removes a favorite through the targeted row menu', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'older-board',
          name: 'Older Board',
          modifiedAt: DateTime.utc(2026, 6, 1),
        ),
        _board(
          id: 'newer-board',
          name: 'Newer Board',
          modifiedAt: DateTime.utc(2026, 6, 2),
        ),
      ],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, ['Newer Board', 'Older Board']);
    await _chooseBoardAction(tester, 'older-board', 'favorite');
    _expectVerticalOrder(tester, ['Older Board', 'Newer Board']);
    expect(
      find.byKey(const ValueKey('favorite-indicator-older-board')),
      findsOneWidget,
    );
    expect(store.favoriteCalls, [('older-board', true)]);

    await tester.tap(find.byKey(const ValueKey('board-actions-older-board')));
    await tester.pumpAndSettle();
    expect(find.text('Remove from favorites'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('board-action-favorite-older-board')),
    );
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, ['Newer Board', 'Older Board']);
    expect(
      find.byKey(const ValueKey('favorite-indicator-older-board')),
      findsNothing,
    );
    expect(store.favoriteCalls, [
      ('older-board', true),
      ('older-board', false),
    ]);
  });

  testWidgets('failed favorite writes leave visible state unchanged', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Stable Board')],
      favoriteFailure: const FileSystemException('simulated failure'),
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await _chooseBoardAction(tester, boardId, 'favorite');

    expect(find.text('Could not update favorite'), findsOneWidget);
    expect(find.byKey(ValueKey('favorite-indicator-$boardId')), findsNothing);
    expect(store.favoriteCalls, [(boardId, true)]);
  });

  testWidgets('filtered favorite targeting retains search and time sort', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: 'other-board', name: 'Other Notes'),
        _board(id: boardId, name: 'Target Project'),
      ],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'target',
    );
    await tester.tap(find.text('Oldest first'));
    await tester.pump();

    await _chooseBoardAction(tester, boardId, 'favorite');

    expect(store.favoriteCalls, [(boardId, true)]);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .controller!
          .text,
      'target',
    );
    expect(find.text('Oldest first'), findsOneWidget);
    expect(find.text('Other Notes'), findsNothing);
  });

  testWidgets('keeps the board actions menu usable at 800 pixels wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryBoardLibraryStore(
      boards: List.generate(
        6,
        (index) => _board(id: 'board-$index', name: 'Board $index'),
      ),
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('board-actions-board-0')));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps eight boards usable in the library', (tester) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        for (var index = 1; index <= 8; index++)
          _board(id: 'board-$index', name: 'Board $index'),
      ],
    );

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.text('Board 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Board 8'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('board-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Board 8'), findsOneWidget);
  });

  testWidgets(
    'filters names case-insensitively in discovery order and clears locally',
    (tester) async {
      final store = _MemoryBoardLibraryStore(
        boards: [
          _board(id: 'project-archive', name: 'Project Archive'),
          _board(id: 'personal-atlas', name: 'Personal Atlas'),
          _board(id: 'project-atlas', name: 'Project Atlas'),
        ],
      );

      await tester.pumpWidget(_testApp(store));
      await tester.pumpAndSettle();
      expect(store.discoverCalls, 1);

      await tester.enterText(
        find.byKey(const ValueKey('board-search-field')),
        '  PROJECT  ',
      );
      await tester.pump();

      expect(find.text('Personal Atlas'), findsNothing);
      expect(find.text('Project Archive'), findsOneWidget);
      expect(find.text('Project Atlas'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Project Archive')).dy,
        lessThan(tester.getTopLeft(find.text('Project Atlas')).dy),
      );

      await tester.tap(find.byKey(const ValueKey('clear-board-search')));
      await tester.pump();

      expect(find.text('Personal Atlas'), findsOneWidget);
      expect(find.text('Project Archive'), findsOneWidget);
      expect(find.text('Project Atlas'), findsOneWidget);
      expect(store.discoverCalls, 1);
    },
  );

  testWidgets('shows no results while keeping create and import available', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'existing-board', name: 'Existing')],
    );

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'missing',
    );
    await tester.pump();

    expect(find.text('No boards match your search.'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-board-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-board-button')), findsOneWidget);
  });

  testWidgets('filters unavailable entries by displayed board ID', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'healthy-board', name: 'Healthy')],
      unavailableIds: ['CORRUPT-BOARD-42'],
    );

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      ' corrupt-board ',
    );
    await tester.pump();

    expect(find.text('Healthy'), findsNothing);
    expect(
      find.byKey(const ValueKey('unavailable-board-CORRUPT-BOARD-42')),
      findsOneWidget,
    );
    expect(find.textContaining('unavailable or invalid'), findsOneWidget);
  });

  testWidgets('retains the query across open and return', (tester) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: 'project-board', name: 'Project Atlas'),
        _board(id: 'personal-board', name: 'Personal Notes'),
      ],
    );

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'project',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-project-board')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .controller!
          .text,
      'project',
    );
    expect(find.text('Project Atlas'), findsOneWidget);
    expect(find.text('Personal Notes'), findsNothing);
  });

  testWidgets('re-evaluates an active query after rename', (tester) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Project Atlas')],
    );

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'project',
    );
    await _chooseBoardAction(tester, boardId, 'rename');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Personal Atlas',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();

    expect(find.text('No boards match your search.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-board-search')));
    await tester.pump();
    expect(find.text('Personal Atlas'), findsOneWidget);
  });

  testWidgets('re-evaluates an active query after rename in the editor', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: boardId, name: 'Project Atlas'),
        _board(id: 'personal-board', name: 'Personal Notes'),
      ],
    );
    await tester.pumpWidget(
      _testApp(
        store,
        editorBuilder: (board, _, initialTarget, onReturn) => CanvasExperiment(
          boardStore: _LibraryBackedBoardStore(store, board.id),
          imageAssetStore: _NoopImageAssetStore(),
          imagePicker: () async => null,
          initialTarget: initialTarget,
          onReturnToLibrary: onReturn,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'project',
    );
    await tester.tap(find.byKey(const ValueKey('board-$boardId')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rename-active-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Research Atlas',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('return-to-library-button')));
    await tester.pumpAndSettle();

    expect(find.text('No boards match your search.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-board-search')));
    await tester.pump();
    expect(find.text('Research Atlas'), findsOneWidget);
    expect(find.text('Project Atlas'), findsNothing);
  });

  testWidgets('finds notes across all healthy boards in active Library order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final timestamp = DateTime.utc(2026, 8, 26, 9);
    Note writtenNote(String id, String text) => Note(
      id: id,
      x: 320,
      y: 240,
      width: 260,
      height: 170,
      text: text,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'new-board',
          name: 'Same name',
          modifiedAt: DateTime.utc(2026, 8, 1),
          notes: [writtenNote('new-note', 'A SHARED PHRASE from August')],
        ),
        _board(
          id: 'old-board',
          name: 'Same name',
          modifiedAt: DateTime.utc(2026, 6, 1),
          notes: [writtenNote('old-note', 'A shared phrase from June')],
        ),
        _board(
          id: 'favorite-board',
          name: 'Favorite ideas',
          modifiedAt: DateTime.utc(2026, 7, 1),
          notes: [
            writtenNote('favorite-note', 'A shared phrase from a favorite'),
            writtenNote('empty-note', '   '),
          ],
        ),
        _board(id: 'blank-board', name: 'Blank board'),
      ],
      unavailableIds: ['unavailable-board'],
      favoriteBoardIds: {'favorite-board'},
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'Favorite ideas',
    );
    await tester.tap(find.text('Oldest first'));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Type words from a note or heading to search every healthy board.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      '  shared phrase  ',
    );
    await tester.pump();

    expect(find.text('3 results'), findsOneWidget);
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('library-note-search-dialog')),
    );
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(800));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));
    expect(find.bySemanticsLabel(RegExp('Words from a note')), findsOneWidget);
    final favoriteResult = find.byKey(
      const ValueKey('library-note-result-favorite-board-favorite-note'),
    );
    final oldResult = find.byKey(
      const ValueKey('library-note-result-old-board-old-note'),
    );
    final newResult = find.byKey(
      const ValueKey('library-note-result-new-board-new-note'),
    );
    expect(favoriteResult, findsOneWidget);
    expect(oldResult, findsOneWidget);
    expect(newResult, findsOneWidget);
    expect(
      tester.getTopLeft(favoriteResult).dy,
      lessThan(tester.getTopLeft(oldResult).dy),
    );
    expect(
      tester.getTopLeft(oldResult).dy,
      lessThan(tester.getTopLeft(newResult).dy),
    );
    expect(
      find.byKey(
        const ValueKey('library-note-result-blank-board-note-blank-board'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey(
          'library-note-result-unavailable-board-unavailable-note',
        ),
      ),
      findsNothing,
    );
    expect(find.textContaining('Board: Same name'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'absent phrase',
    );
    await tester.pump();
    expect(
      find.text('No notes or headings across boards match your search.'),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-note-search-dialog')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('discloses a hidden selection-set result before opening it', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 14, 12);
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'hidden-group-board',
          name: 'Hidden references',
          notes: [
            Note(
              id: 'hidden-note',
              x: 300,
              y: 240,
              width: 260,
              height: 170,
              text: 'Secret lighthouse route',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
            Note(
              id: 'hidden-partner',
              x: 650,
              y: 240,
              width: 260,
              height: 170,
              text: 'Second hidden member',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          groups: [
            BoardGroup(
              id: 'hidden-set',
              memberIds: const ['hidden-note', 'hidden-partner'],
              isVisible: false,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      ],
    );
    CanvasInitialTarget? openedTarget;
    await tester.pumpWidget(
      _testApp(
        store,
        editorBuilder: (board, _, initialTarget, onReturn) {
          openedTarget = initialTarget;
          return const Scaffold(body: Text('Hidden group board opened'));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'secret lighthouse',
    );
    await tester.pump();

    expect(
      find.textContaining('Hidden group · Show and select'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('library-note-result-hidden-group-board-hidden-note'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hidden group board opened'), findsOneWidget);
    expect(openedTarget!.type, CanvasInitialTargetType.note);
    expect(openedTarget!.objectId, 'hidden-note');
  });

  testWidgets('shows a no-written-notes state without opening a board', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: 'blank-board', name: 'Blank board')],
      unavailableIds: ['unavailable-board'],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This Library has no notes or headings to search.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Images'));
    await tester.pump();
    expect(find.text('This Library has no images to search.'), findsOneWidget);
    await tester.tap(find.text('Connections'));
    await tester.pump();
    expect(
      find.text('This Library has no labeled connections to search.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Scenes'));
    await tester.pump();
    expect(find.text('This Library has no Scenes to search.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('close-library-note-search-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vasmim Library'), findsOneWidget);
    expect(store.previewLoadCalls, isEmpty);
  });

  testWidgets('finds and routes one exact heading across boards', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 8, 12);
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'heading-board',
          name: 'Game outline',
          notes: const [],
          headings: [
            CanvasHeading(
              id: 'library-heading',
              x: 2200,
              y: 1500,
              text: 'Character arcs',
              size: CanvasHeadingSize.extraLarge,
              background: CanvasHeadingBackground.purple,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      ],
    );
    CanvasInitialTarget? openedTarget;
    await tester.pumpWidget(
      _testApp(
        store,
        editorBuilder: (board, _, initialTarget, onReturn) {
          openedTarget = initialTarget;
          return const Scaffold(body: Text('Heading board opened'));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'ARCS',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('library-heading-result-heading-board-library-heading'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heading board opened'), findsOneWidget);
    expect(openedTarget!.type, CanvasInitialTargetType.heading);
    expect(openedTarget!.objectId, 'library-heading');
  });

  testWidgets(
    'finds image filenames across all healthy boards and reuses the query',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final store = _MemoryBoardLibraryStore(
        boards: [
          _board(
            id: 'new-board',
            name: 'Same name',
            modifiedAt: DateTime.utc(2026, 8, 1),
            images: [_image('new-image', 'Shared Map August.PNG')],
          ),
          _board(
            id: 'old-board',
            name: 'Same name',
            modifiedAt: DateTime.utc(2026, 6, 1),
            images: [_image('old-image', 'shared map June.png')],
          ),
          _board(
            id: 'favorite-board',
            name: 'Favorite images',
            modifiedAt: DateTime.utc(2026, 7, 1),
            images: [
              _image('favorite-image', 'A SHARED MAP.PNG'),
              _image('other-image', 'Unrelated.png'),
            ],
          ),
          _board(id: 'blank-board', name: 'Blank board'),
        ],
        unavailableIds: ['unavailable-board'],
        favoriteBoardIds: {'favorite-board'},
      );
      await tester.pumpWidget(_testApp(store));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-search-field')),
        'Favorite images',
      );
      await tester.tap(find.text('Oldest first'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find across boards'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(RegExp('Words from a note')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        ' shared map ',
      );
      await tester.tap(find.text('Images'));
      await tester.pump();

      expect(find.text('3 results'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('Words from an image caption or filename'),
        ),
        findsOneWidget,
      );
      final favoriteResult = find.byKey(
        const ValueKey('library-image-result-favorite-board-favorite-image'),
      );
      final oldResult = find.byKey(
        const ValueKey('library-image-result-old-board-old-image'),
      );
      final newResult = find.byKey(
        const ValueKey('library-image-result-new-board-new-image'),
      );
      expect(favoriteResult, findsOneWidget);
      expect(oldResult, findsOneWidget);
      expect(newResult, findsOneWidget);
      expect(
        tester.getTopLeft(favoriteResult).dy,
        lessThan(tester.getTopLeft(oldResult).dy),
      );
      expect(
        tester.getTopLeft(oldResult).dy,
        lessThan(tester.getTopLeft(newResult).dy),
      );
      expect(find.text('A SHARED MAP.PNG'), findsOneWidget);
      expect(find.textContaining('Board: Same name'), findsNWidgets(2));
      final dialogRect = tester.getRect(
        find.byKey(const ValueKey('library-note-search-dialog')),
      );
      expect(dialogRect.left, greaterThanOrEqualTo(0));
      expect(dialogRect.top, greaterThanOrEqualTo(0));
      expect(dialogRect.right, lessThanOrEqualTo(800));
      expect(dialogRect.bottom, lessThanOrEqualTo(600));

      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'missing filename',
      );
      await tester.pump();
      expect(
        find.text(
          'No image captions or filenames across boards match your search.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'freshness-validates then opens and targets one exact image once',
    (tester) async {
      final targetBoard = _board(
        id: 'image-board',
        name: 'Image board',
        viewportX: 800,
        viewportY: 600,
        viewportZoom: 0.65,
        images: [
          _image('near-image', 'Nearby.png', x: 2700, y: 1900),
          _image('target-image', 'Distant Lighthouse.PNG', x: 3000, y: 2100),
        ],
      );
      final store = _MemoryBoardLibraryStore(
        boards: [
          targetBoard,
          _board(id: 'visible-board', name: 'Visible board'),
        ],
      );

      Widget editorBuilder(
        BoardDocument board,
        bool _,
        CanvasInitialTarget? initialTarget,
        VoidCallback onReturn,
      ) => CanvasExperiment(
        boardStore: _LibraryBackedBoardStore(store, board.id),
        imageAssetStore: _NoopImageAssetStore(),
        imagePicker: () async => null,
        initialTarget: initialTarget,
        onReturnToLibrary: onReturn,
      );

      await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-search-field')),
        'Visible board',
      );
      await tester.tap(find.text('Oldest first'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Images'));
      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'distant lighthouse',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('library-image-result-image-board-target-image'),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.previewLoadCalls, ['image-board']);
      expect(
        {
          for (final image in tester.widgetList<InteractiveBoardImage>(
            find.byType(InteractiveBoardImage),
          ))
            if (image.isSelected) image.image.id,
        },
        {'target-image'},
      );
      expect(
        find.byKey(const ValueKey('missing-image-target-image')),
        findsOneWidget,
      );
      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(0.65, 0.001));
      final canvasCenter = controller.toScene(
        tester.getSize(viewerFinder).center(Offset.zero),
      );
      expect(canvasCenter.dx, closeTo(3160, 0.001));
      expect(canvasCenter.dy, closeTo(2200, 0.001));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('image-drag-surface-near-image')),
      );
      await tester.pump();
      expect(
        {
          for (final image in tester.widgetList<InteractiveBoardImage>(
            find.byType(InteractiveBoardImage),
          ))
            if (image.isSelected) image.image.id,
        },
        {'near-image'},
      );
      await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
      await tester.pump();
      expect(
        {
          for (final image in tester.widgetList<InteractiveBoardImage>(
            find.byType(InteractiveBoardImage),
          ))
            if (image.isSelected) image.image.id,
        },
        {'near-image'},
      );

      await tester.tap(find.byKey(const ValueKey('return-to-library-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
            .controller!
            .text,
        'Visible board',
      );
      expect(find.text('Oldest first'), findsOneWidget);
    },
  );

  testWidgets('isolates a renamed image result before opening its board', (
    tester,
  ) async {
    final original = _board(
      id: 'changing-image-board',
      name: 'Changing image board',
      images: [_image('changing-image', 'Remember This Map.png')],
    );
    final store = _MemoryBoardLibraryStore(boards: [original]);
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Images'));
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'remember this',
    );
    await tester.pump();
    store.saveBoard(
      _withImages(original, [_image('changing-image', 'Renamed.png')]),
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-image-result-changing-image-board-changing-image',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vasmim Library'), findsOneWidget);
    expect(
      find.text('Could not open that search result. Try searching again.'),
      findsOneWidget,
    );
    expect(store.previewLoadCalls, ['changing-image-board']);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets(
    'finds labeled connections across ordered healthy boards and reuses query',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final store = _MemoryBoardLibraryStore(
        boards: [
          _connectionBoard(
            id: 'new-board',
            name: 'Same name',
            modifiedAt: DateTime.utc(2026, 8, 1),
            labels: const ['Shared dependency August'],
          ),
          _connectionBoard(
            id: 'old-board',
            name: 'Same name',
            modifiedAt: DateTime.utc(2026, 6, 1),
            labels: const ['shared dependency June'],
          ),
          _connectionBoard(
            id: 'favorite-board',
            name: 'Favorite relationships',
            modifiedAt: DateTime.utc(2026, 7, 1),
            labels: const ['A SHARED DEPENDENCY', null, 'Unrelated'],
          ),
        ],
        favoriteBoardIds: {'favorite-board'},
      );
      await tester.pumpWidget(_testApp(store));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-search-field')),
        'Favorite relationships',
      );
      await tester.tap(find.text('Oldest first'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        ' shared dependency ',
      );
      await tester.tap(find.text('Connections'));
      await tester.pump();

      expect(find.text('3 results'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Words from a connection label')),
        findsOneWidget,
      );
      final favoriteResult = find.byKey(
        const ValueKey(
          'library-connection-result-favorite-board-connector-0-favorite-board',
        ),
      );
      final oldResult = find.byKey(
        const ValueKey(
          'library-connection-result-old-board-connector-0-old-board',
        ),
      );
      final newResult = find.byKey(
        const ValueKey(
          'library-connection-result-new-board-connector-0-new-board',
        ),
      );
      expect(favoriteResult, findsOneWidget);
      expect(oldResult, findsOneWidget);
      expect(newResult, findsOneWidget);
      expect(
        tester.getTopLeft(favoriteResult).dy,
        lessThan(tester.getTopLeft(oldResult).dy),
      );
      expect(
        tester.getTopLeft(oldResult).dy,
        lessThan(tester.getTopLeft(newResult).dy),
      );
      expect(find.text('A SHARED DEPENDENCY'), findsOneWidget);
      expect(find.textContaining('Board: Same name'), findsNWidgets(2));

      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'missing relationship',
      );
      await tester.pump();
      expect(
        find.text('No connection labels across boards match your search.'),
        findsOneWidget,
      );
      final dialogRect = tester.getRect(
        find.byKey(const ValueKey('library-note-search-dialog')),
      );
      expect(dialogRect.left, greaterThanOrEqualTo(0));
      expect(dialogRect.top, greaterThanOrEqualTo(0));
      expect(dialogRect.right, lessThanOrEqualTo(800));
      expect(dialogRect.bottom, lessThanOrEqualTo(600));
      semantics.dispose();
    },
  );

  testWidgets(
    'freshness-validates and targets exact connection endpoints once',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 28, 12);
      final firstNote = Note(
        id: 'first-note',
        x: 2700,
        y: 1800,
        width: 260,
        height: 170,
        text: 'First endpoint',
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
      final otherNote = Note(
        id: 'other-note',
        x: 3000,
        y: 1900,
        width: 260,
        height: 170,
        text: 'Other note',
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
      final targetImage = _image(
        'target-image',
        'Missing endpoint.png',
        x: 3300,
        y: 2200,
      );
      final targetConnector = Connector(
        id: 'target-connector',
        objectAId: firstNote.id,
        objectBId: targetImage.id,
        label: 'Distant dependency',
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
      final targetBoard = _board(
        id: 'connection-board',
        name: 'Connection board',
        viewportZoom: 0.65,
        notes: [firstNote, otherNote],
        images: [targetImage],
        connectors: [targetConnector],
      );
      final store = _MemoryBoardLibraryStore(boards: [targetBoard]);

      Widget editorBuilder(
        BoardDocument board,
        bool _,
        CanvasInitialTarget? initialTarget,
        VoidCallback onReturn,
      ) => CanvasExperiment(
        boardStore: _LibraryBackedBoardStore(store, board.id),
        imageAssetStore: _NoopImageAssetStore(),
        imagePicker: () async => null,
        initialTarget: initialTarget,
        onReturnToLibrary: onReturn,
      );

      await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connections'));
      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'distant dependency',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'library-connection-result-connection-board-target-connector',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.previewLoadCalls, ['connection-board']);
      expect(
        {
          for (final note in tester.widgetList<EditableNote>(
            find.byType(EditableNote),
          ))
            if (note.isSelected) note.note.id,
        },
        {'first-note'},
      );
      expect(
        {
          for (final image in tester.widgetList<InteractiveBoardImage>(
            find.byType(InteractiveBoardImage),
          ))
            if (image.isSelected) image.image.id,
        },
        {'target-image'},
      );
      expect(
        find.byKey(const ValueKey('missing-image-target-image')),
        findsOneWidget,
      );
      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(0.65, 0.001));
      final expectedSegment = ConnectorGeometry.betweenRects(
        Rect.fromLTWH(
          firstNote.x,
          firstNote.y,
          firstNote.width,
          firstNote.height,
        ),
        Rect.fromLTWH(
          targetImage.x,
          targetImage.y,
          targetImage.width,
          targetImage.height,
        ),
      );
      final expectedCenter = Offset(
        (expectedSegment.start.dx + expectedSegment.end.dx) / 2,
        (expectedSegment.start.dy + expectedSegment.end.dy) / 2,
      );
      final canvasCenter = controller.toScene(
        tester.getSize(viewerFinder).center(Offset.zero),
      );
      expect(canvasCenter.dx, closeTo(expectedCenter.dx, 0.001));
      expect(canvasCenter.dy, closeTo(expectedCenter.dy, 0.001));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-other-note')),
      );
      await tester.pump();
      await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
      await tester.pump();
      expect(
        {
          for (final note in tester.widgetList<EditableNote>(
            find.byType(EditableNote),
          ))
            if (note.isSelected) note.note.id,
        },
        {'other-note'},
      );
    },
  );

  testWidgets('isolates a relabeled connection result before opening', (
    tester,
  ) async {
    final original = _connectionBoard(
      id: 'changing-connection-board',
      name: 'Changing connection board',
      labels: const ['Remember this relationship'],
    );
    final store = _MemoryBoardLibraryStore(boards: [original]);
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections'));
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'remember this',
    );
    await tester.pump();
    store.saveBoard(
      _withConnectors(original, [
        original.connectors.single.copyWith(label: 'Relabeled'),
      ]),
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-connection-result-changing-connection-board-connector-0-changing-connection-board',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vasmim Library'), findsOneWidget);
    expect(
      find.text('Could not open that search result. Try searching again.'),
      findsOneWidget,
    );
    expect(store.previewLoadCalls, ['changing-connection-board']);
  });

  testWidgets('finds Scenes across ordered healthy boards and reuses the query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryBoardLibraryStore(
      boards: [
        _sceneBoard(
          id: 'new-board',
          name: 'Same name',
          modifiedAt: DateTime.utc(2026, 8, 1),
          sceneNames: const ['Shared View August'],
        ),
        _sceneBoard(
          id: 'old-board',
          name: 'Same name',
          modifiedAt: DateTime.utc(2026, 6, 1),
          sceneNames: const ['shared view June'],
        ),
        _sceneBoard(
          id: 'favorite-board',
          name: 'Favorite views',
          modifiedAt: DateTime.utc(2026, 7, 1),
          sceneNames: const ['A SHARED VIEW', 'Unrelated'],
        ),
      ],
      favoriteBoardIds: {'favorite-board'},
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'Favorite views',
    );
    await tester.tap(find.text('Oldest first'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      ' shared view ',
    );
    await tester.tap(find.text('Scenes'));
    await tester.pump();

    expect(find.text('3 results'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Words from a Scene name')),
      findsOneWidget,
    );
    final favoriteResult = find.byKey(
      const ValueKey(
        'library-scene-result-favorite-board-123e4567-e89b-42d3-a456-000000000300',
      ),
    );
    final oldResult = find.byKey(
      const ValueKey(
        'library-scene-result-old-board-123e4567-e89b-42d3-a456-000000000200',
      ),
    );
    final newResult = find.byKey(
      const ValueKey(
        'library-scene-result-new-board-123e4567-e89b-42d3-a456-000000000100',
      ),
    );
    expect(favoriteResult, findsOneWidget);
    expect(oldResult, findsOneWidget);
    expect(newResult, findsOneWidget);
    expect(
      tester.getTopLeft(favoriteResult).dy,
      lessThan(tester.getTopLeft(oldResult).dy),
    );
    expect(
      tester.getTopLeft(oldResult).dy,
      lessThan(tester.getTopLeft(newResult).dy),
    );
    expect(find.text('A SHARED VIEW'), findsOneWidget);
    expect(find.textContaining('Board: Same name'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'missing scene',
    );
    await tester.pump();
    expect(
      find.text('No Scene names across boards match your search.'),
      findsOneWidget,
    );
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('library-note-search-dialog')),
    );
    expect(dialogRect.right, lessThanOrEqualTo(800));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('opens an exact Scene viewport and persists normal activation', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 28, 16);
    final targetScene = Scene(
      id: '123e4567-e89b-42d3-a456-426614174206',
      name: 'Distant planning view',
      x: 1480,
      y: 860,
      zoom: 0.55,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final targetBoard = _board(
      id: 'scene-board',
      name: 'Scene board',
      viewportX: 120,
      viewportY: 80,
      viewportZoom: 0.9,
      scenes: [targetScene],
    );
    final store = _MemoryBoardLibraryStore(boards: [targetBoard]);

    Widget editorBuilder(
      BoardDocument board,
      bool _,
      CanvasInitialTarget? initialTarget,
      VoidCallback onReturn,
    ) => CanvasExperiment(
      boardStore: _LibraryBackedBoardStore(store, board.id),
      imageAssetStore: _NoopImageAssetStore(),
      imagePicker: () async => null,
      initialTarget: initialTarget,
      onReturnToLibrary: onReturn,
    );

    await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('find-note-across-boards-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scenes'));
    await tester.enterText(
      find.byKey(const ValueKey('library-note-search-field')),
      'planning view',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-scene-result-scene-board-123e4567-e89b-42d3-a456-426614174206',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.previewLoadCalls, ['scene-board']);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final origin = controller.toScene(Offset.zero);
    expect(origin.dx, closeTo(targetScene.x, 0.001));
    expect(origin.dy, closeTo(targetScene.y, 0.001));
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(targetScene.zoom, 0.001),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .where((note) => note.isSelected),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      store.boardById('scene-board').viewportX,
      closeTo(targetScene.x, 0.001),
    );
    expect(
      store.boardById('scene-board').viewportY,
      closeTo(targetScene.y, 0.001),
    );
    expect(
      store.boardById('scene-board').viewportZoom,
      closeTo(targetScene.zoom, 0.001),
    );
    expect(
      store.boardById('scene-board').scenes.single.toJson(),
      targetScene.toJson(),
    );
  });

  testWidgets(
    'freshness-validates then opens and targets one exact note once',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 26, 10);
      final targetBoard = _board(
        id: 'target-board',
        name: 'Target board',
        modifiedAt: timestamp,
        viewportX: 800,
        viewportY: 600,
        viewportZoom: 0.65,
        notes: [
          Note(
            id: 'near-note',
            x: 2700,
            y: 1900,
            width: 260,
            height: 170,
            text: 'Unrelated nearby note',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'target-note',
            x: 3000,
            y: 2100,
            width: 260,
            height: 170,
            text: 'Remember the distant lighthouse',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      );
      final store = _MemoryBoardLibraryStore(
        boards: [
          targetBoard,
          _board(id: 'visible-board', name: 'Visible board'),
        ],
      );

      Widget editorBuilder(
        BoardDocument board,
        bool _,
        CanvasInitialTarget? initialTarget,
        VoidCallback onReturn,
      ) => CanvasExperiment(
        boardStore: _LibraryBackedBoardStore(store, board.id),
        imageAssetStore: _NoopImageAssetStore(),
        imagePicker: () async => null,
        initialTarget: initialTarget,
        onReturnToLibrary: onReturn,
      );

      await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-search-field')),
        'Visible board',
      );
      await tester.tap(find.text('Oldest first'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'distant lighthouse',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('library-note-result-target-board-target-note'),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.previewLoadCalls, ['target-board']);
      expect(
        {
          for (final note in tester.widgetList<EditableNote>(
            find.byType(EditableNote),
          ))
            if (note.isSelected) note.note.id,
        },
        {'target-note'},
      );
      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(0.65, 0.001));
      final canvasCenter = controller.toScene(
        tester.getSize(viewerFinder).center(Offset.zero),
      );
      expect(canvasCenter.dx, closeTo(3130, 0.001));
      expect(canvasCenter.dy, closeTo(2185, 0.001));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-near-note')),
      );
      await tester.pump();
      expect(
        {
          for (final note in tester.widgetList<EditableNote>(
            find.byType(EditableNote),
          ))
            if (note.isSelected) note.note.id,
        },
        {'near-note'},
      );
      await tester.pumpWidget(_testApp(store, editorBuilder: editorBuilder));
      await tester.pump();
      expect(
        {
          for (final note in tester.widgetList<EditableNote>(
            find.byType(EditableNote),
          ))
            if (note.isSelected) note.note.id,
        },
        {'near-note'},
      );

      await tester.tap(find.byKey(const ValueKey('return-to-library-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
            .controller!
            .text,
        'Visible board',
      );
      expect(find.text('Oldest first'), findsOneWidget);
    },
  );

  testWidgets(
    'isolates a stale cross-board result and restores Library focus',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 26, 11);
      final original = _board(
        id: 'changing-board',
        name: 'Changing board',
        notes: [
          Note(
            id: 'changing-note',
            x: 320,
            y: 240,
            width: 260,
            height: 170,
            text: 'Remember this phrase',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      );
      final store = _MemoryBoardLibraryStore(boards: [original]);
      await tester.pumpWidget(_testApp(store));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'remember this',
      );
      await tester.pump();
      store.saveBoard(
        _withNotes(original, [
          original.notes.single.copyWith(text: 'Changed after search'),
        ]),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('library-note-result-changing-board-changing-note'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vasmim Library'), findsOneWidget);
      expect(
        find.text('Could not open that search result. Try searching again.'),
        findsOneWidget,
      );
      expect(store.previewLoadCalls, ['changing-board']);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
            .focusNode!
            .hasFocus,
        isTrue,
      );

      store.saveBoard(original);
      store.previewFailure = const FormatException('became unreadable');
      await tester.tap(
        find.byKey(const ValueKey('find-note-across-boards-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('library-note-search-field')),
        'remember this',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('library-note-result-changing-board-changing-note'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vasmim Library'), findsOneWidget);
      expect(
        find.text('Could not open that search result. Try searching again.'),
        findsOneWidget,
      );
      expect(store.previewLoadCalls, ['changing-board', 'changing-board']);
    },
  );

  testWidgets('starts with an empty query on a new Library screen', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: 'project-board', name: 'Project Atlas'),
        _board(id: 'personal-board', name: 'Personal Notes'),
      ],
    );

    await tester.pumpWidget(
      KeyedSubtree(key: const ValueKey('first'), child: _testApp(store)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'project',
    );
    await tester.pump();
    expect(find.text('Personal Notes'), findsNothing);

    await tester.pumpWidget(
      KeyedSubtree(key: const ValueKey('second'), child: _testApp(store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Project Atlas'), findsOneWidget);
    expect(find.text('Personal Notes'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets(
    'sorts boards newest first by default and oldest first on demand',
    (tester) async {
      final tiedTime = DateTime.utc(2026, 7, 1);
      final store = _MemoryBoardLibraryStore(
        boards: [
          _board(id: 'middle-b', name: 'Middle B', modifiedAt: tiedTime),
          _board(
            id: 'newest-board',
            name: 'Newest',
            modifiedAt: DateTime.utc(2026, 8, 1),
          ),
          _board(
            id: 'oldest-board',
            name: 'Oldest',
            modifiedAt: DateTime.utc(2026, 6, 1),
          ),
          _board(id: 'middle-a', name: 'Middle A', modifiedAt: tiedTime),
        ],
        unavailableIds: ['corrupt-board'],
      );
      await tester.pumpWidget(_testApp(store));
      await tester.pumpAndSettle();

      _expectVerticalOrder(tester, [
        'Newest',
        'Middle A',
        'Middle B',
        'Oldest',
      ]);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('unavailable-board-corrupt-board')),
            )
            .dy,
        greaterThan(tester.getTopLeft(find.text('Oldest')).dy),
      );

      await tester.tap(find.text('Oldest first'));
      await tester.pump();

      _expectVerticalOrder(tester, [
        'Oldest',
        'Middle A',
        'Middle B',
        'Newest',
      ]);
      expect(store.discoverCalls, 1);
    },
  );

  testWidgets('applies time sorting within the active search', (tester) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'new-project',
          name: 'New Project',
          modifiedAt: DateTime.utc(2026, 8, 1),
        ),
        _board(
          id: 'personal-board',
          name: 'Personal Notes',
          modifiedAt: DateTime.utc(2026, 5, 1),
        ),
        _board(
          id: 'old-project',
          name: 'Old Project',
          modifiedAt: DateTime.utc(2026, 6, 1),
        ),
      ],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'project',
    );
    await tester.tap(find.text('Oldest first'));
    await tester.pump();

    expect(find.text('Personal Notes'), findsNothing);
    _expectVerticalOrder(tester, ['Old Project', 'New Project']);
  });

  testWidgets('retains time sorting across board open and return', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'new-board',
          name: 'New Board',
          modifiedAt: DateTime.utc(2026, 8, 1),
        ),
        _board(
          id: 'old-board',
          name: 'Old Board',
          modifiedAt: DateTime.utc(2026, 6, 1),
        ),
      ],
    );
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-old-board')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, ['Old Board', 'New Board']);
  });

  testWidgets('resets time sorting on a new Library screen', (tester) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(
          id: 'new-board',
          name: 'New Board',
          modifiedAt: DateTime.utc(2026, 8, 1),
        ),
        _board(
          id: 'old-board',
          name: 'Old Board',
          modifiedAt: DateTime.utc(2026, 6, 1),
        ),
      ],
    );
    await tester.pumpWidget(
      KeyedSubtree(key: const ValueKey('first'), child: _testApp(store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.pump();
    _expectVerticalOrder(tester, ['Old Board', 'New Board']);

    await tester.pumpWidget(
      KeyedSubtree(key: const ValueKey('second'), child: _testApp(store)),
    );
    await tester.pumpAndSettle();

    _expectVerticalOrder(tester, ['New Board', 'Old Board']);
  });

  testWidgets('exports a board with a safe suggested filename and feedback', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Plan: 2026')],
    );
    String? suggestedName;
    await tester.pumpWidget(
      _testApp(
        store,
        exportPicker: (suggested) async {
          suggestedName = suggested;
          return r'C:\Exports\plan.vasmim';
        },
      ),
    );
    await tester.pumpAndSettle();

    await _chooseBoardAction(tester, boardId, 'export');
    await tester.pumpAndSettle();

    expect(suggestedName, 'Plan_ 2026.vasmim');
    expect(store.exportCalls, [(boardId, r'C:\Exports\plan.vasmim')]);
    expect(find.text('Exported “Plan: 2026”'), findsOneWidget);
  });

  testWidgets('filtered export and delete keep targeting the matching board', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: 'other-board', name: 'Other Notes'),
        _board(id: boardId, name: 'Target Project'),
      ],
    );
    await tester.pumpWidget(
      _testApp(store, exportPicker: (_) async => 'target.vasmim'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'target',
    );
    await tester.pump();

    await _chooseBoardAction(tester, boardId, 'export');
    await tester.pumpAndSettle();
    expect(store.exportCalls, [(boardId, 'target.vasmim')]);

    await _chooseBoardAction(tester, boardId, 'delete');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-board-button')));
    await tester.pumpAndSettle();

    expect(find.text('No boards match your search.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-board-search')));
    await tester.pump();
    expect(find.text('Other Notes'), findsOneWidget);
    expect(find.text('Target Project'), findsNothing);
  });

  testWidgets('picker cancellation leaves the Library unchanged', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: boardId, name: 'Existing'),
        _board(id: 'older-board', name: 'Older'),
      ],
    );
    await tester.pumpWidget(_testApp(store, importPicker: () async => null));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-board-button')));
    await tester.pumpAndSettle();

    expect(store.importCalls, 0);
    expect(find.text('Existing'), findsOneWidget);
  });

  testWidgets('imports and immediately opens the portable board', (
    tester,
  ) async {
    final imported = _board(id: 'imported-board', name: 'Restored Project');
    final store = _MemoryBoardLibraryStore(importedBoard: imported);
    final primingStates = <bool>[];
    await tester.pumpWidget(
      _testApp(
        store,
        importPicker: () async => 'restored.vasmim',
        onEditorOpened: primingStates.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-board-button')));
    await tester.pumpAndSettle();

    expect(store.importCalls, 1);
    expect(find.text('Editing Restored Project'), findsOneWidget);
    expect(primingStates.single, isFalse);
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('favorite-indicator-imported-board')),
      findsNothing,
    );
  });

  testWidgets('disables actions while exporting and offers import conflicts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exportGate = Completer<void>();
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Existing')],
      exportGate: exportGate,
      importFailure: const BoardTransferException(
        BoardTransferFailureKind.duplicateBoard,
        'duplicate',
        null,
        BoardImportConflict(
          boardId: 'portable-board',
          boardName: 'Portable Project',
        ),
      ),
    );
    await tester.pumpWidget(
      _testApp(
        store,
        exportPicker: (_) async => 'existing.vasmim',
        importPicker: () async => 'duplicate.vasmim',
      ),
    );
    await tester.pumpAndSettle();

    await _chooseBoardAction(
      tester,
      boardId,
      'export',
      settleAfterSelection: false,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('create-board-button')),
          )
          .onPressed,
      isNull,
    );
    exportGate.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-board-button')));
    await tester.pumpAndSettle();

    expect(find.text('Existing'), findsOneWidget);
    expect(find.text('Board already exists'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-as-copy-button')), findsOneWidget);
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(800));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(store.importCopyCalls, isEmpty);
  });

  testWidgets('imports a validated conflict as a named non-favorite copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final copied = _board(
      id: '123e4567-e89b-42d3-a456-426614174036',
      name: 'placeholder',
    );
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Existing')],
      importedCopyBoard: copied,
      importFailure: const BoardTransferException(
        BoardTransferFailureKind.duplicateBoard,
        'duplicate',
        null,
        BoardImportConflict(
          boardId: 'portable-board',
          boardName: 'Portable Project',
        ),
      ),
    );
    await tester.pumpWidget(
      _testApp(store, importPicker: () async => 'duplicate.vasmim'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-board-button')));
    await tester.pumpAndSettle();
    expect(find.text('Board already exists'), findsOneWidget);
    expect(
      find.textContaining('existing board will not be changed'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('import-as-copy-button')));
    await tester.pumpAndSettle();

    expect(find.text('Import board as copy'), findsOneWidget);
    final nameDialogRect = tester.getRect(find.byType(AlertDialog));
    expect(nameDialogRect.right, lessThanOrEqualTo(800));
    expect(nameDialogRect.bottom, lessThanOrEqualTo(600));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-name-field')))
          .controller!
          .text,
      'Portable Project copy',
    );
    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pump();
    expect(find.text('Enter a board name'), findsOneWidget);
    expect(store.importCopyCalls, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('board-name-field')),
      'Recovered Project',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
    await tester.pumpAndSettle();

    expect(store.importCopyCalls, [('duplicate.vasmim', 'Recovered Project')]);
    expect(find.text('Editing Recovered Project'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('test-return-button')));
    await tester.pumpAndSettle();
    expect(find.text('Existing'), findsOneWidget);
    expect(find.text('Recovered Project'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'favorite-indicator-123e4567-e89b-42d3-a456-426614174036',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('invalid packages never offer import as copy', (tester) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Existing')],
      importFailure: const BoardTransferException(
        BoardTransferFailureKind.invalidArchive,
        'invalid',
      ),
    );
    await tester.pumpWidget(
      _testApp(store, importPicker: () async => 'invalid.vasmim'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-board-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('The selected file is not a valid portable board.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('import-as-copy-button')), findsNothing);
    expect(store.importCopyCalls, isEmpty);
  });

  testWidgets('export all is disabled for an empty Library', (tester) async {
    final store = _MemoryBoardLibraryStore();
    await tester.pumpWidget(
      _testApp(store, backupDirectoryPicker: () async => 'unused'),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('export-all-boards-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('unavailable boards block export all before the picker', (
    tester,
  ) async {
    var pickerCalls = 0;
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Healthy')],
      unavailableIds: const ['broken-board'],
    );
    await tester.pumpWidget(
      _testApp(
        store,
        backupDirectoryPicker: () async {
          pickerCalls += 1;
          return 'unused';
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('export-all-boards-button')));
    await tester.pumpAndSettle();

    expect(pickerCalls, 0);
    expect(store.backupCalls, isEmpty);
    expect(
      find.text('1 unavailable board prevents a complete export.'),
      findsOneWidget,
    );
  });

  testWidgets('exports the whole Library independent of presentation state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    final store = _MemoryBoardLibraryStore(
      boards: [
        _board(id: boardId, name: 'Visible Board'),
        _board(id: 'other-board', name: 'Hidden Board'),
      ],
      favoriteBoardIds: const {'other-board'},
      backupGate: gate,
      backupResult: const BoardLibraryBackupResult(
        directoryPath: r'C:\Backups\Vasmim Backup 2026-08-30 142530Z',
        folderName: 'Vasmim Backup 2026-08-30 142530Z',
        boardCount: 2,
      ),
    );
    await tester.pumpWidget(
      _testApp(store, backupDirectoryPicker: () async => r'C:\Backups'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('board-search-field')),
      'Visible',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('export-all-boards-button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('create-board-button')),
          )
          .onPressed,
      isNull,
    );
    expect(store.backupCalls, [r'C:\Backups']);
    gate.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Exported 2 boards to Vasmim Backup 2026-08-30 142530Z.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('board-search-field')))
          .controller!
          .text,
      'Visible',
    );
  });

  testWidgets('export-all picker cancellation is a no-op at 800 by 600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Existing')],
    );
    await tester.pumpWidget(
      _testApp(store, backupDirectoryPicker: () async => null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('export-all-boards-button')));
    await tester.pumpAndSettle();

    expect(store.backupCalls, isEmpty);
    expect(find.text('Existing'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('export-all write failure reports that no backup was created', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      boards: [_board(id: boardId, name: 'Existing')],
      backupFailure: const BoardLibraryBackupException(
        BoardLibraryBackupFailureKind.fileSystem,
        'Could not publish the backup folder.',
      ),
    );
    await tester.pumpWidget(
      _testApp(store, backupDirectoryPicker: () async => r'C:\Backups'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('export-all-boards-button')));
    await tester.pumpAndSettle();

    expect(store.backupCalls, [r'C:\Backups']);
    expect(
      find.text('The complete board export could not be written.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'verifies a selected backup folder without changing the Library',
    (tester) async {
      final store = _MemoryBoardLibraryStore(
        boards: [_board(id: boardId, name: 'Existing')],
        backupVerificationResult: const BoardLibraryBackupVerificationResult(
          boardCount: 2,
        ),
      );
      await tester.pumpWidget(
        _testApp(
          store,
          backupVerificationDirectoryPicker: () async => r'C:\Backups\Friday',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('verify-backup-folder-button')),
      );
      await tester.pumpAndSettle();

      expect(store.backupVerificationCalls, [r'C:\Backups\Friday']);
      expect(
        find.text('Verified 2 boards in the backup folder.'),
        findsOneWidget,
      );
      expect(store.backupCalls, isEmpty);
      expect(find.text('Existing'), findsOneWidget);
    },
  );

  testWidgets('cancelling backup verification does not call the store', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore();
    await tester.pumpWidget(
      _testApp(store, backupVerificationDirectoryPicker: () async => null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('verify-backup-folder-button')));
    await tester.pumpAndSettle();

    expect(store.backupVerificationCalls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('backup verification reports invalid packages clearly', (
    tester,
  ) async {
    final store = _MemoryBoardLibraryStore(
      backupVerificationFailure: const BoardLibraryBackupException(
        BoardLibraryBackupFailureKind.invalidPackage,
        'The package is corrupt.',
      ),
    );
    await tester.pumpWidget(
      _testApp(
        store,
        backupVerificationDirectoryPicker: () async => r'C:\Backups\Friday',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('verify-backup-folder-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('A backup package could not be verified.'),
      findsOneWidget,
    );
  });

  test('creates Windows-safe portable board filenames', () {
    expect(portableBoardSuggestedName('  CON.  '), '_CON.vasmim');
    expect(
      portableBoardSuggestedName(r'A<B>:C/D\\E|F?G*'),
      'A_B__C_D__E_F_G_.vasmim',
    );
    expect(portableBoardSuggestedName(' ... '), 'Board.vasmim');
  });
}

Future<void> _chooseBoardAction(
  WidgetTester tester,
  String boardId,
  String action, {
  bool settleAfterSelection = true,
}) async {
  await tester.tap(find.byKey(ValueKey('board-actions-$boardId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('board-action-$action-$boardId')));
  if (settleAfterSelection) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Widget _testApp(
  _MemoryBoardLibraryStore store, {
  Future<String?> Function()? importPicker,
  Future<String?> Function(String suggestedName)? exportPicker,
  Future<String?> Function()? backupDirectoryPicker,
  Future<String?> Function()? backupVerificationDirectoryPicker,
  Future<void> Function(Directory directory)? explorerLauncher,
  ValueChanged<bool>? onEditorOpened,
  Widget Function(BoardDocument, bool, CanvasInitialTarget?, VoidCallback)?
  editorBuilder,
  CrossBoardClipboard? crossBoardClipboard,
}) {
  return MaterialApp(
    home: BoardLibraryScreen(
      libraryStore: store,
      importPicker: importPicker,
      exportPicker: exportPicker,
      backupDirectoryPicker: backupDirectoryPicker,
      backupVerificationDirectoryPicker: backupVerificationDirectoryPicker,
      explorerLauncher: explorerLauncher,
      crossBoardClipboard: crossBoardClipboard,
      editorBuilder:
          editorBuilder ??
          (board, showBlankCanvasPriming, _, onReturn) {
            onEditorOpened?.call(showBlankCanvasPriming);
            return Scaffold(
              body: Center(child: Text('Editing ${board.name}')),
              floatingActionButton: FloatingActionButton(
                key: const ValueKey('test-return-button'),
                onPressed: onReturn,
                child: const Icon(Icons.arrow_back),
              ),
            );
          },
    ),
  );
}

class _MemoryBoardLibraryStore implements BoardLibraryStore {
  _MemoryBoardLibraryStore({
    List<BoardDocument> boards = const [],
    this.unavailableIds = const [],
    Set<String> favoriteBoardIds = const {},
    this.favoriteFailure,
    this.folderFailure,
    this.importedBoard,
    this.importedCopyBoard,
    this.importFailure,
    this.backupResult,
    this.backupFailure,
    this.backupGate,
    this.backupVerificationResult,
    this.backupVerificationFailure,
    this.exportGate,
    this.duplicateGate,
    this.storageDirectory,
  }) : _boards = [...boards],
       _favoriteBoardIds = {...favoriteBoardIds};

  final List<BoardDocument> _boards;
  final Directory? storageDirectory;
  BoardStarter? lastCreatedStarter;
  final List<String> unavailableIds;
  final Set<String> _favoriteBoardIds;
  final List<LibraryFolder> _folders = [];
  final Map<String, String> _boardFolderIds = {};
  final Object? favoriteFailure;
  final Object? folderFailure;
  final BoardDocument? importedBoard;
  final BoardDocument? importedCopyBoard;
  final Object? importFailure;
  final BoardLibraryBackupResult? backupResult;
  final Object? backupFailure;
  final Completer<void>? backupGate;
  final BoardLibraryBackupVerificationResult? backupVerificationResult;
  final Object? backupVerificationFailure;
  final Completer<void>? exportGate;
  final Completer<void>? duplicateGate;
  Object? previewFailure;
  Object? deleteFailure;
  final List<(String, String)> exportCalls = [];
  final List<(String, String)> duplicateCalls = [];
  final List<String> deleteCalls = [];
  final List<(String, bool)> favoriteCalls = [];
  final List<String> previewLoadCalls = [];
  int importCalls = 0;
  final List<(String, String)> importCopyCalls = [];
  final List<String> backupCalls = [];
  final List<String> backupVerificationCalls = [];
  int discoverCalls = 0;

  BoardDocument boardById(String boardId) {
    return _boards.singleWhere((board) => board.id == boardId);
  }

  void saveBoard(BoardDocument board) {
    final index = _boards.indexWhere((current) => current.id == board.id);
    _boards[index] = board;
  }

  @override
  Future<List<BoardLibraryEntry>> discover() async {
    discoverCalls += 1;
    return [
      for (final board in _boards) BoardLibraryEntry.available(board),
      for (final id in unavailableIds)
        BoardLibraryEntry.unavailable(
          boardId: id,
          error: 'Board data is unavailable or invalid.',
        ),
    ];
  }

  @override
  Future<BoardDocument> loadBoard(String boardId) async {
    previewLoadCalls.add(boardId);
    final failure = previewFailure;
    if (failure != null) {
      throw failure;
    }
    return boardById(boardId);
  }

  @override
  Future<Set<String>> favoriteBoardIds() async => {..._favoriteBoardIds};

  @override
  Future<void> setBoardFavorite(String boardId, bool isFavorite) async {
    favoriteCalls.add((boardId, isFavorite));
    final failure = favoriteFailure;
    if (failure != null) {
      throw failure;
    }
    if (isFavorite) {
      _favoriteBoardIds.add(boardId);
    } else {
      _favoriteBoardIds.remove(boardId);
    }
  }

  @override
  Future<LibraryFolderState> libraryFolderState() async {
    final failure = folderFailure;
    if (failure != null) {
      throw failure;
    }
    return LibraryFolderState(
      folders: _folders,
      boardFolderIds: _boardFolderIds,
    );
  }

  @override
  Future<LibraryFolder> createLibraryFolder(String name) async {
    final now = DateTime.utc(2026, 9, 17);
    final folder = LibraryFolder(
      id: '123e4567-e89b-42d3-a456-${(_folders.length + 1).toString().padLeft(12, '0')}',
      name: LibraryFolder.normalizeName(name),
      createdAt: now,
      modifiedAt: now,
    );
    _folders.add(folder);
    return folder;
  }

  @override
  Future<LibraryFolder> renameLibraryFolder(
    String folderId,
    String name,
  ) async {
    final index = _folders.indexWhere((folder) => folder.id == folderId);
    final renamed = _folders[index].copyWith(
      name: LibraryFolder.normalizeName(name),
    );
    _folders[index] = renamed;
    return renamed;
  }

  @override
  Future<void> deleteLibraryFolder(String folderId) async {
    if (_boardFolderIds.containsValue(folderId)) {
      throw StateError('Folder is not empty.');
    }
    _folders.removeWhere((folder) => folder.id == folderId);
  }

  @override
  Future<void> setBoardFolder(String boardId, String? folderId) async {
    folderId == null
        ? _boardFolderIds.remove(boardId)
        : _boardFolderIds[boardId] = folderId;
  }

  @override
  Future<BoardDocument> createBoard(
    String name, {
    BoardStarter starter = BoardStarter.blank,
  }) async {
    lastCreatedStarter = starter;
    final board = _board(
      id: '123e4567-e89b-42d3-a456-426614174000',
      name: name.trim(),
    );
    _boards.add(board);
    return board;
  }

  @override
  Future<BoardDocument> renameBoard(String boardId, String name) async {
    final index = _boards.indexWhere((board) => board.id == boardId);
    final renamed = _boards[index].copyWith(name: name.trim());
    _boards[index] = renamed;
    return renamed;
  }

  @override
  Future<BoardDocument> duplicateBoard(String boardId, String name) async {
    final source = boardById(boardId);
    duplicateCalls.add((boardId, name.trim()));
    await duplicateGate?.future;
    final now = DateTime.utc(2026, 8, 23);
    final duplicate = BoardDocument(
      id: '123e4567-e89b-42d3-b456-426614174019',
      name: name.trim(),
      createdAt: now,
      modifiedAt: now,
      viewportX: source.viewportX,
      viewportY: source.viewportY,
      viewportZoom: source.viewportZoom,
      notes: source.notes,
      connectors: source.connectors,
      images: source.images,
      scenes: source.scenes,
    );
    _boards.add(duplicate);
    return duplicate;
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    deleteCalls.add(boardId);
    if (deleteFailure != null) throw deleteFailure!;
    _boards.removeWhere((board) => board.id == boardId);
    _favoriteBoardIds.remove(boardId);
    _boardFolderIds.remove(boardId);
  }

  @override
  Future<void> exportBoard(String boardId, String destinationPath) async {
    exportCalls.add((boardId, destinationPath));
    await exportGate?.future;
  }

  @override
  Future<BoardDocument> importBoard(String sourcePath) async {
    importCalls += 1;
    final failure = importFailure;
    if (failure != null) {
      throw failure;
    }
    final board = importedBoard;
    if (board == null) {
      throw StateError('No portable board is configured for this test.');
    }
    _boards.add(board);
    return board;
  }

  @override
  Future<BoardDocument> importBoardAsCopy(
    String sourcePath,
    String name,
  ) async {
    importCopyCalls.add((sourcePath, name.trim()));
    final source = importedCopyBoard;
    if (source == null) {
      throw StateError('No copied portable board is configured for this test.');
    }
    final copied = source.copyWith(name: name.trim());
    _boards.add(copied);
    return copied;
  }

  @override
  Future<BoardLibraryBackupResult> exportAllBoards(
    String parentDirectoryPath,
  ) async {
    backupCalls.add(parentDirectoryPath);
    await backupGate?.future;
    final failure = backupFailure;
    if (failure != null) {
      throw failure;
    }
    final result = backupResult;
    if (result == null) {
      throw StateError('No Library backup result is configured for this test.');
    }
    return result;
  }

  @override
  Future<BoardLibraryBackupVerificationResult> verifyBackupFolder(
    String directoryPath,
  ) async {
    backupVerificationCalls.add(directoryPath);
    final failure = backupVerificationFailure;
    if (failure != null) {
      throw failure;
    }
    final result = backupVerificationResult;
    if (result == null) {
      throw StateError(
        'No backup verification result is configured for this test.',
      );
    }
    return result;
  }

  @override
  Future<Directory> boardDirectory(String boardId) async =>
      storageDirectory ??
      (throw UnimplementedError(
        'The injected editor does not use file storage.',
      ));
}

class _LibraryBackedBoardStore implements BoardStore {
  _LibraryBackedBoardStore(this.libraryStore, this.boardId);

  final _MemoryBoardLibraryStore libraryStore;
  final String boardId;

  @override
  Future<BoardDocument?> load() async => libraryStore.boardById(boardId);

  @override
  Future<void> save(BoardDocument board) async {
    libraryStore.saveBoard(board);
  }
}

class _NoopImageAssetStore implements ImageAssetStore {
  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) async => null;

  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) async => null;

  @override
  Future<File> resolve(String assetPath) {
    throw UnimplementedError('This test does not load managed images.');
  }
}

class _CrossBoardImageAssetStore implements ImageAssetStore {
  int importByteCalls = 0;
  Uint8List? receivedBytes;

  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) async {
    importByteCalls++;
    receivedBytes = bytes == null ? null : Uint8List.fromList(bytes);
    return const ManagedImageAsset(
      assetPath: 'assets/library-copy.png',
      originalFileName: 'Library source.png',
      pixelWidth: 1,
      pixelHeight: 1,
    );
  }

  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) async => null;

  @override
  Future<File> resolve(String assetPath) async => File(assetPath);
}

final _libraryOnePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

BoardDocument _board({
  required String id,
  required String name,
  DateTime? modifiedAt,
  double viewportX = 0,
  double viewportY = 0,
  double viewportZoom = 1,
  List<Note>? notes,
  List<BoardImage> images = const [],
  List<CanvasHeading> headings = const [],
  List<Connector> connectors = const [],
  List<Scene> scenes = const [],
  List<BoardGroup> groups = const [],
}) {
  final timestamp = DateTime.utc(2026, 8, 13);
  return BoardDocument(
    id: id,
    name: name,
    createdAt: timestamp,
    modifiedAt: modifiedAt ?? timestamp,
    viewportX: viewportX,
    viewportY: viewportY,
    viewportZoom: viewportZoom,
    notes:
        notes ??
        [
          Note(
            id: 'note-$id',
            x: 320,
            y: 240,
            width: 260,
            height: 170,
            text: '',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
    images: images,
    headings: headings,
    connectors: connectors,
    scenes: scenes,
    groups: groups,
  );
}

BoardDocument _sceneBoard({
  required String id,
  required String name,
  DateTime? modifiedAt,
  required List<String> sceneNames,
}) {
  final timestamp = DateTime.utc(2026, 8, 28, 15);
  final boardCode = switch (id) {
    'new-board' => 1,
    'old-board' => 2,
    'favorite-board' => 3,
    _ => 4,
  };
  return _board(
    id: id,
    name: name,
    modifiedAt: modifiedAt,
    scenes: [
      for (var index = 0; index < sceneNames.length; index++)
        Scene(
          id:
              '123e4567-e89b-42d3-a456-'
              '${(boardCode * 100 + index).toString().padLeft(12, '0')}',
          name: sceneNames[index],
          x: 300 + index * 500,
          y: 220 + index * 320,
          zoom: 0.8,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
    ],
  );
}

BoardDocument _connectionBoard({
  required String id,
  required String name,
  DateTime? modifiedAt,
  required List<String?> labels,
}) {
  final timestamp = DateTime.utc(2026, 8, 28, 12);
  final notes = [
    for (var index = 0; index <= labels.length; index++)
      Note(
        id: 'connection-note-$index-$id',
        x: 320 + index * 420,
        y: 240 + index * 220,
        width: 260,
        height: 170,
        text: 'Endpoint $index',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
  ];
  return _board(
    id: id,
    name: name,
    modifiedAt: modifiedAt,
    notes: notes,
    connectors: [
      for (var index = 0; index < labels.length; index++)
        Connector(
          id: 'connector-$index-$id',
          objectAId: notes[index].id,
          objectBId: notes[index + 1].id,
          label: labels[index],
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
    ],
  );
}

BoardImage _image(
  String id,
  String originalFileName, {
  double x = 320,
  double y = 240,
}) {
  final timestamp = DateTime.utc(2026, 8, 26, 12);
  return BoardImage(
    id: id,
    x: x,
    y: y,
    width: 320,
    height: 200,
    assetPath: 'assets/$id.png',
    originalFileName: originalFileName,
    pixelWidth: 800,
    pixelHeight: 500,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
}

BoardDocument _withImages(BoardDocument board, List<BoardImage> images) {
  return BoardDocument(
    id: board.id,
    name: board.name,
    createdAt: board.createdAt,
    modifiedAt: board.modifiedAt,
    viewportX: board.viewportX,
    viewportY: board.viewportY,
    viewportZoom: board.viewportZoom,
    notes: board.notes,
    connectors: board.connectors,
    images: images,
    scenes: board.scenes,
  );
}

BoardDocument _withNotes(BoardDocument board, List<Note> notes) {
  return BoardDocument(
    id: board.id,
    name: board.name,
    createdAt: board.createdAt,
    modifiedAt: board.modifiedAt,
    viewportX: board.viewportX,
    viewportY: board.viewportY,
    viewportZoom: board.viewportZoom,
    notes: notes,
    connectors: board.connectors,
    images: board.images,
    scenes: board.scenes,
  );
}

BoardDocument _withConnectors(BoardDocument board, List<Connector> connectors) {
  return BoardDocument(
    id: board.id,
    name: board.name,
    createdAt: board.createdAt,
    modifiedAt: board.modifiedAt,
    viewportX: board.viewportX,
    viewportY: board.viewportY,
    viewportZoom: board.viewportZoom,
    notes: board.notes,
    connectors: connectors,
    images: board.images,
    scenes: board.scenes,
  );
}

BoardDocument _previewBoard({required String id, required String name}) {
  final timestamp = DateTime.utc(2026, 8, 25, 18);
  return BoardDocument(
    id: id,
    name: name,
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 900,
    viewportY: 600,
    viewportZoom: 0.75,
    notes: [
      Note(
        id: 'note-a-$id',
        x: 300,
        y: 240,
        width: 260,
        height: 170,
        text: 'Alpha',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Note(
        id: 'note-b-$id',
        x: 1500,
        y: 900,
        width: 260,
        height: 170,
        text: 'Beta',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
    images: [
      BoardImage(
        id: 'image-$id',
        x: 2800,
        y: 1900,
        width: 320,
        height: 180,
        assetPath: 'assets/image.png',
        originalFileName: 'image.png',
        pixelWidth: 1600,
        pixelHeight: 900,
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
    connectors: [
      Connector(
        id: 'connector-a-b-$id',
        objectAId: 'note-a-$id',
        objectBId: 'note-b-$id',
        label: 'supports',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Connector(
        id: 'connector-b-image-$id',
        objectAId: 'note-b-$id',
        objectBId: 'image-$id',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
  );
}

void _expectVerticalOrder(WidgetTester tester, List<String> boardNames) {
  for (var index = 1; index < boardNames.length; index++) {
    expect(
      tester.getTopLeft(find.text(boardNames[index - 1])).dy,
      lessThan(tester.getTopLeft(find.text(boardNames[index])).dy),
    );
  }
}
