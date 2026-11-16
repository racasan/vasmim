import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/appearance/app_appearance_store.dart';
import 'package:vasmim/attachment/board_attachment.dart';
import 'package:vasmim/attachment/attachment_asset_store.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/board_paper_tone.dart';
import 'package:vasmim/board/board_store.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/connector/connector_geometry.dart';
import 'package:vasmim/connector/connector_painter.dart';
import 'package:vasmim/canvas/canvas_experiment.dart';
import 'package:vasmim/canvas/current_view_png_export.dart';
import 'package:vasmim/canvas/cross_board_clipboard.dart';
import 'package:vasmim/canvas/cross_board_foreground_snapshot.dart';
import 'package:vasmim/canvas/foreground_item_style.dart';
import 'package:vasmim/canvas/canvas_initial_target.dart';
import 'package:vasmim/canvas/canvas_overview_map.dart';
import 'package:vasmim/canvas/canvas_paper_painter.dart';
import 'package:vasmim/group/board_group.dart';
import 'package:vasmim/main.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/image/clipboard_image_reader.dart';
import 'package:vasmim/image/image_asset_store.dart';
import 'package:vasmim/image/interactive_board_image.dart';
import 'package:vasmim/image/managed_image_view.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/heading/canvas_heading_geometry.dart';
import 'package:vasmim/heading/interactive_canvas_heading.dart';
import 'package:vasmim/note/editable_note.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_text_link.dart';
import 'package:vasmim/scene/scene.dart';
import 'package:vasmim/thinking/fresh_pair_selector.dart';
import 'package:vasmim/youtube/interactive_youtube_embed.dart';
import 'package:vasmim/youtube/youtube_embed.dart';
import 'package:vasmim/youtube/youtube_thumbnail_fetcher.dart';

import '../image/animated_gif_fixture.dart';

Future<_MemoryBoardStore> _pumpTestApp(
  WidgetTester tester, {
  _MemoryBoardStore? store,
  Widget Function(BoardImage image)? imageViewBuilder,
  ImageAssetStore? imageAssetStore,
  AttachmentAssetStore? attachmentAssetStore,
  YouTubeThumbnailFetcher youTubeThumbnailFetcher =
      const _UnavailableYouTubeThumbnailFetcher(),
  CurrentViewPngPathPicker? currentViewPngPathPicker,
  CurrentViewPngPublisher? currentViewPngPublisher,
  CurrentViewPngCapturer? currentViewPngCapturer,
  CurrentViewPngClipboardWriter? currentViewPngClipboardWriter,
  CrossBoardClipboard? crossBoardClipboard,
  AppAppearanceStore? appearanceStore,
}) async {
  final testStore = store ?? _MemoryBoardStore();
  await tester.pumpWidget(
    MainApp(
      boardStore: testStore,
      imageViewBuilder: imageViewBuilder,
      imageAssetStore: imageAssetStore,
      attachmentAssetStore: attachmentAssetStore,
      youTubeThumbnailFetcher: youTubeThumbnailFetcher,
      currentViewPngPathPicker: currentViewPngPathPicker,
      currentViewPngPublisher: currentViewPngPublisher,
      currentViewPngCapturer: currentViewPngCapturer,
      currentViewPngClipboardWriter: currentViewPngClipboardWriter,
      crossBoardClipboard: crossBoardClipboard,
      appearanceStore: appearanceStore,
    ),
  );
  await tester.pumpAndSettle();
  return testStore;
}

Future<void> _controlTap(WidgetTester tester, Finder finder) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tap(finder);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _secondaryTap(WidgetTester tester, Finder finder) async {
  await tester.tap(
    finder,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

Future<void> _openImageSharingDialog(WidgetTester tester) async {
  await tester.tapAt(
    const Offset(40, 500),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('context-share-board-image-menu-item')),
  );
  await tester.pumpAndSettle();
}

void _expectSharedForegroundShadow(Decoration? decoration) {
  expect(decoration, isA<BoxDecoration>());
  expect((decoration! as BoxDecoration).boxShadow, ForegroundItemStyle.shadows);
}

Future<void> _mouseDragFrom(
  WidgetTester tester,
  Offset start,
  Offset delta, {
  required int buttons,
}) async {
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await gesture.moveBy(delta);
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _sendShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Set<String> _selectedNoteIds(WidgetTester tester) {
  return {
    for (final note in tester.widgetList<EditableNote>(
      find.byType(EditableNote),
    ))
      if (note.isSelected) note.note.id,
  };
}

Set<String> _selectedImageIds(WidgetTester tester) {
  return {
    for (final image in tester.widgetList<InteractiveBoardImage>(
      find.byType(InteractiveBoardImage),
    ))
      if (image.isSelected) image.image.id,
  };
}

Set<String> _selectedHeadingIds(WidgetTester tester) {
  return {
    for (final heading in tester.widgetList<InteractiveCanvasHeading>(
      find.byType(InteractiveCanvasHeading),
    ))
      if (heading.isSelected) heading.heading.id,
  };
}

Future<_MemoryBoardStore> _pumpFreshPairTestApp(
  WidgetTester tester, {
  required FreshPairSelector selector,
  int writtenNoteCount = 3,
  ThemeData? theme,
}) async {
  final store = _MemoryBoardStore(
    board: _freshPairBoard(writtenNoteCount: writtenNoteCount),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: CanvasExperiment(
        boardStore: store,
        imageAssetStore: _TestImageAssetStore(),
        imagePicker: () async => null,
        freshPairSelector: selector,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

BoardDocument _freshPairBoard({required int writtenNoteCount}) {
  final timestamp = DateTime.utc(2026, 8, 19, 12);
  const texts = ['Alpha thought', 'Beta question', 'Gamma possibility'];
  return BoardDocument(
    id: 'fresh-pair-board',
    name: 'Fresh Pair test',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: [
      for (var index = 0; index < writtenNoteCount; index++)
        Note(
          id: 'fresh-note-$index',
          x: 120.0 + (index * 340),
          y: 180.0 + (index * 80),
          width: 260,
          height: 170,
          text: texts[index],
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      Note(
        id: 'fresh-note-blank',
        x: 1200,
        y: 500,
        width: 260,
        height: 170,
        text: '   ',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
  );
}

BoardDocument _noteEditingComfortBoard(String text) {
  final timestamp = DateTime.utc(2026, 9, 4, 12);
  return BoardDocument(
    id: 'note-editing-comfort-board',
    name: 'Note editing comfort',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: [
      Note(
        id: 'comfort-note',
        x: 280,
        y: 180,
        width: 320,
        height: 210,
        text: text,
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
  );
}

Set<String> _selectedFreshPairNoteIds(WidgetTester tester) {
  return {
    for (final note in tester.widgetList<EditableNote>(
      find.byType(EditableNote),
    ))
      if (note.isSelected) note.note.id,
  };
}

void main() {
  testWidgets('Board Help presents guidance without saving the Board', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    final savesBefore = store.saveCalls;

    expect(find.byTooltip('Help and shortcuts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('board-help-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vasmim-help-dialog')), findsOneWidget);
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    expect(find.text('Edit text and Headings'), findsOneWidget);
    await tester.tap(find.text('Keys'));
    await tester.pumpAndSettle();
    expect(find.text('Common shortcuts'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vasmim-help-dialog')), findsNothing);
    expect(store.saveCalls, savesBefore);
  });

  testWidgets('dark mode follows app preference without changing the Board', (
    tester,
  ) async {
    final appearance = MemoryAppAppearanceStore(isDark: true);
    final store = await _pumpTestApp(tester, appearanceStore: appearance);
    final savesBefore = store.saveCalls;

    expect(
      Theme.of(tester.element(find.byType(CanvasExperiment))).brightness,
      Brightness.dark,
    );
    final paper = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('whole-board-export-surface')),
            matching: find.byType(CustomPaint),
          ),
        )
        .singleWhere((widget) => widget.painter is LayeredCanvasPaperPainter);
    expect((paper.painter! as LayeredCanvasPaperPainter).isDark, isTrue);
    await tester.tap(find.byKey(const ValueKey('board-appearance-toggle')));
    await tester.pumpAndSettle();
    expect(await appearance.readDarkMode(), isFalse);
    expect(
      Theme.of(tester.element(find.byType(CanvasExperiment))).brightness,
      Brightness.light,
    );
    expect(store.saveCalls, savesBefore);
  });

  testWidgets('organizes all accepted image actions behind one context entry', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    final savesBefore = store.saveCalls;

    await tester.tapAt(
      const Offset(40, 500),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('context-share-board-image-menu-item')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-export-current-view-menu-item')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('context-copy-current-view-menu-item')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('context-export-whole-board-menu-item')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('context-copy-whole-board-menu-item')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('context-share-board-image-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('image-sharing-dialog')), findsOneWidget);
    expect(find.text('Current view'), findsOneWidget);
    expect(find.text('Whole Board (6000 × 4500)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('share-current-view-save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-current-view-copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-whole-board-save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-whole-board-copy')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('share-image-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('image-sharing-dialog')), findsNothing);
    expect(store.saveCalls, savesBefore);
  });

  testWidgets(
    'sharing dialog is keyboard usable and dismissible at 800 by 600',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var pathPickerCalls = 0;
      await _pumpTestApp(
        tester,
        currentViewPngPathPicker: (_) async {
          pathPickerCalls += 1;
          return null;
        },
      );

      await _openImageSharingDialog(tester);
      final dialogRect = tester.getRect(
        find.byKey(const ValueKey('image-sharing-dialog')),
      );
      expect(dialogRect.left, greaterThanOrEqualTo(0));
      expect(dialogRect.top, greaterThanOrEqualTo(0));
      expect(dialogRect.right, lessThanOrEqualTo(800));
      expect(dialogRect.bottom, lessThanOrEqualTo(600));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(pathPickerCalls, 1);
      expect(find.byKey(const ValueKey('image-sharing-dialog')), findsNothing);

      await _openImageSharingDialog(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('image-sharing-dialog')), findsNothing);
      expect(pathPickerCalls, 1);

      await _openImageSharingDialog(tester);
      await tester.tap(
        find.byKey(const ValueKey('close-image-sharing-dialog')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('image-sharing-dialog')), findsNothing);
      expect(pathPickerCalls, 1);

      await _openImageSharingDialog(tester);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('image-sharing-dialog')), findsNothing);
      expect(pathPickerCalls, 1);
    },
  );

  testWidgets(
    'exports the current physical-pixel canvas view without editor chrome',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 19, 12);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'current-view-export-board',
          name: 'Act 1: Arrival?',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          lockedObjectIds: const {'export-note'},
          notes: [
            Note(
              id: 'export-note',
              x: 180,
              y: 140,
              width: 280,
              height: 190,
              text: 'Visible export content',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      String? suggestedName;
      Uint8List? publishedBytes;
      var cleanStateObserved = false;
      Size? capturedLogicalSize;
      double? capturedPixelRatio;
      final pickedPath = Completer<String?>();
      await _pumpTestApp(
        tester,
        store: store,
        currentViewPngPathPicker: (suggestion) {
          suggestedName = suggestion;
          return pickedPath.future;
        },
        currentViewPngPublisher: (path, bytes) async {
          expect(path, r'C:\exports\current-view.png');
          publishedBytes = Uint8List.fromList(bytes);
        },
        currentViewPngCapturer: (boundary, pixelRatio) async {
          final note = tester.widget<EditableNote>(find.byType(EditableNote));
          expect(note.isSelected, isFalse);
          expect(note.showInteractionChrome, isFalse);
          expect(
            find.byKey(const ValueKey('position-lock-indicator-export-note')),
            findsNothing,
          );
          cleanStateObserved = true;
          capturedLogicalSize = boundary.size;
          capturedPixelRatio = pixelRatio;
          return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-export-note')),
      );
      await tester.pumpAndSettle();
      expect(_selectedNoteIds(tester), {'export-note'});
      expect(
        find.byKey(const ValueKey('position-lock-indicator-export-note')),
        findsOneWidget,
      );
      final exportSurface = find.byKey(
        const ValueKey('current-view-export-surface'),
      );
      final logicalSize = tester.getSize(exportSurface);
      final pixelRatio = tester
          .widget<MediaQuery>(find.byType(MediaQuery).first)
          .data
          .devicePixelRatio;
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('find-board-button')),
          matching: exportSurface,
        ),
        findsNothing,
      );

      await _openImageSharingDialog(tester);
      await tester.tap(find.byKey(const ValueKey('share-current-view-save')));
      await tester.pumpAndSettle();
      expect(suggestedName, 'Act 1_ Arrival_ current view.png');
      pickedPath.complete(r'C:\exports\current-view.png');
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(cleanStateObserved, isTrue);
      expect(publishedBytes, isNotNull);
      expect(publishedBytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(capturedLogicalSize, logicalSize);
      expect(capturedPixelRatio, pixelRatio);
      expect(_selectedNoteIds(tester), {'export-note'});
      expect(
        find.byKey(const ValueKey('position-lock-indicator-export-note')),
        findsOneWidget,
      );
      expect(find.text('Current view exported'), findsOneWidget);
      expect(store.saveCalls, 0);
    },
  );

  testWidgets('cancelled current-view export is a no-op', (tester) async {
    var publishCalls = 0;
    await _pumpTestApp(
      tester,
      currentViewPngPathPicker: (_) async => null,
      currentViewPngPublisher: (_, _) async => publishCalls += 1,
    );

    await _openImageSharingDialog(tester);
    await tester.tap(find.byKey(const ValueKey('share-current-view-save')));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(publishCalls, 0);
    expect(find.text('Current view exported'), findsNothing);
    expect(find.text('Could not export current view'), findsNothing);
  });

  testWidgets('current-view export is unavailable during Note editing', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    await tester.tap(find.byKey(ValueKey('note-text-field-${note.note.id}')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
      isTrue,
    );

    await tester.tapAt(
      const Offset(40, 500),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('context-share-board-image-menu-item')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('image-sharing-dialog')), findsNothing);
  });

  testWidgets('failed current-view publication reports one clear error', (
    tester,
  ) async {
    final pickedPath = Completer<String?>();
    await _pumpTestApp(
      tester,
      currentViewPngPathPicker: (_) => pickedPath.future,
      currentViewPngPublisher: (_, _) async =>
          throw const FileSystemException('test publication failure'),
      currentViewPngCapturer: (_, _) async =>
          Uint8List.fromList([137, 80, 78, 71]),
    );

    await _openImageSharingDialog(tester);
    await tester.tap(find.byKey(const ValueKey('share-current-view-save')));
    await tester.pumpAndSettle();
    pickedPath.complete(r'C:\exports\current-view.png');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not export current view'), findsOneWidget);
    expect(find.text('Current view exported'), findsNothing);
  });

  testWidgets(
    'copies the clean physical-pixel current view without replacing objects',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 20, 10);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'current-view-copy-board',
          name: 'Clipboard sharing',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          lockedObjectIds: const {'copy-note'},
          notes: [
            Note(
              id: 'copy-note',
              x: 180,
              y: 140,
              width: 280,
              height: 190,
              text: 'Visible clipboard content',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      Uint8List? clipboardBytes;
      var cleanStateObserved = false;
      Size? capturedLogicalSize;
      double? capturedPixelRatio;
      await _pumpTestApp(
        tester,
        store: store,
        currentViewPngCapturer: (boundary, pixelRatio) async {
          final note = tester.widget<EditableNote>(find.byType(EditableNote));
          expect(note.isSelected, isFalse);
          expect(note.showInteractionChrome, isFalse);
          expect(
            find.byKey(const ValueKey('position-lock-indicator-copy-note')),
            findsNothing,
          );
          cleanStateObserved = true;
          capturedLogicalSize = boundary.size;
          capturedPixelRatio = pixelRatio;
          return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        },
        currentViewPngClipboardWriter: (bytes) async {
          clipboardBytes = Uint8List.fromList(bytes);
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-copy-note')),
      );
      await tester.pumpAndSettle();
      await _sendShortcut(tester, LogicalKeyboardKey.keyC);
      final exportSurface = find.byKey(
        const ValueKey('current-view-export-surface'),
      );
      final logicalSize = tester.getSize(exportSurface);
      final pixelRatio = tester
          .widget<MediaQuery>(find.byType(MediaQuery).first)
          .data
          .devicePixelRatio;

      await _openImageSharingDialog(tester);
      await tester.tap(find.byKey(const ValueKey('share-current-view-copy')));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(cleanStateObserved, isTrue);
      expect(clipboardBytes, isNotNull);
      expect(clipboardBytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(capturedLogicalSize, logicalSize);
      expect(capturedPixelRatio, pixelRatio);
      expect(_selectedNoteIds(tester), {'copy-note'});
      expect(
        find.byKey(const ValueKey('position-lock-indicator-copy-note')),
        findsOneWidget,
      );
      expect(find.text('Current view copied'), findsOneWidget);
      expect(store.saveCalls, 0);

      await _sendShortcut(tester, LogicalKeyboardKey.keyV);
      expect(find.byType(EditableNote), findsNWidgets(2));
    },
  );

  testWidgets('failed current-view clipboard write reports one clear error', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      currentViewPngCapturer: (_, _) async =>
          Uint8List.fromList([137, 80, 78, 71]),
      currentViewPngClipboardWriter: (_) async =>
          throw StateError('test clipboard failure'),
    );

    await _openImageSharingDialog(tester);
    await tester.tap(find.byKey(const ValueKey('share-current-view-copy')));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not copy current view'), findsOneWidget);
    expect(find.text('Current view copied'), findsNothing);
  });

  testWidgets(
    'exports one clean whole-Board PNG independent of the working viewport',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 20, 14);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'whole-board-export-board',
          name: 'Whole: Board?',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          lockedObjectIds: const {'near-note'},
          notes: [
            Note(
              id: 'near-note',
              x: 160,
              y: 140,
              width: 260,
              height: 170,
              text: 'Near content',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
            Note(
              id: 'far-note',
              x: 3520,
              y: 2620,
              width: 260,
              height: 170,
              text: 'Far content',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          connectors: [
            Connector(
              id: 'whole-board-connector',
              objectAId: 'near-note',
              objectBId: 'far-note',
              label: 'Across the whole Board',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      String? suggestedName;
      String? publishedPath;
      Uint8List? publishedBytes;
      var cleanStateObserved = false;
      Size? capturedSize;
      double? capturedPixelRatio;
      await _pumpTestApp(
        tester,
        store: store,
        currentViewPngPathPicker: (suggestion) async {
          suggestedName = suggestion;
          return r'C:\exports\whole-board.png';
        },
        currentViewPngPublisher: (path, bytes) async {
          publishedPath = path;
          publishedBytes = Uint8List.fromList(bytes);
        },
        currentViewPngCapturer: (boundary, pixelRatio) async {
          final nearNote = tester
              .widgetList<EditableNote>(find.byType(EditableNote))
              .singleWhere((widget) => widget.note.id == 'near-note');
          expect(nearNote.isSelected, isFalse);
          expect(nearNote.showInteractionChrome, isFalse);
          expect(
            find.byKey(const ValueKey('position-lock-indicator-near-note')),
            findsNothing,
          );
          final connectorPainter =
              tester
                      .widget<CustomPaint>(
                        find.byKey(const ValueKey('connector-layer')),
                      )
                      .painter
                  as ConnectorPainter;
          expect(connectorPainter.viewportScale, 1);
          cleanStateObserved = true;
          capturedSize = boundary.size;
          capturedPixelRatio = pixelRatio;
          return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-near-note')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.45, 0.45, 0.45)
        ..setTranslationRaw(-1180, -820, 0);
      await tester.pump();
      final workingTransform = Matrix4.copy(controller.value);

      await _openImageSharingDialog(tester);
      await tester.tap(find.byKey(const ValueKey('share-whole-board-save')));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(suggestedName, 'Whole_ Board_ whole Board.png');
      expect(publishedPath, r'C:\exports\whole-board.png');
      expect(publishedBytes, isNotNull);
      expect(publishedBytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(cleanStateObserved, isTrue);
      expect(capturedSize, const Size(6000, 4500));
      expect(capturedPixelRatio, 1);
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      expect(_selectedNoteIds(tester), {'near-note'});
      expect(
        find.byKey(const ValueKey('position-lock-indicator-near-note')),
        findsOneWidget,
      );
      expect(find.text('Whole Board exported'), findsOneWidget);
      expect(store.saveCalls, 0);
    },
  );

  testWidgets('cancelled whole-Board export is a complete no-op', (
    tester,
  ) async {
    var captureCalls = 0;
    var publishCalls = 0;
    await _pumpTestApp(
      tester,
      currentViewPngPathPicker: (_) async => null,
      currentViewPngCapturer: (_, _) async {
        captureCalls += 1;
        return Uint8List(0);
      },
      currentViewPngPublisher: (_, _) async => publishCalls += 1,
    );

    await _openImageSharingDialog(tester);
    await tester.tap(find.byKey(const ValueKey('share-whole-board-save')));
    await tester.pumpAndSettle();

    expect(captureCalls, 0);
    expect(publishCalls, 0);
    expect(find.text('Whole Board exported'), findsNothing);
    expect(find.text('Could not export whole Board'), findsNothing);
  });

  testWidgets('failed whole-Board publication reports one clear error', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      currentViewPngPathPicker: (_) async => r'C:\exports\whole-board.png',
      currentViewPngCapturer: (_, _) async =>
          Uint8List.fromList([137, 80, 78, 71]),
      currentViewPngPublisher: (_, _) async =>
          throw const FileSystemException('test whole-Board failure'),
    );

    await _openImageSharingDialog(tester);
    await tester.tap(find.byKey(const ValueKey('share-whole-board-save')));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not export whole Board'), findsOneWidget);
    expect(find.text('Whole Board exported'), findsNothing);
  });

  testWidgets(
    'copies one clean whole-Board image without replacing copied objects',
    (tester) async {
      final store = await _pumpTestApp(
        tester,
        currentViewPngCapturer: (boundary, pixelRatio) async {
          final note = tester.widget<EditableNote>(find.byType(EditableNote));
          expect(note.isSelected, isFalse);
          expect(note.showInteractionChrome, isFalse);
          expect(boundary.size, const Size(6000, 4500));
          expect(pixelRatio, 1);
          return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        },
        currentViewPngClipboardWriter: (bytes) async {
          expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        },
      );
      final original = tester.widget<EditableNote>(find.byType(EditableNote));
      await tester.tap(
        find.byKey(ValueKey('note-drag-handle-${original.note.id}')),
      );
      await tester.pumpAndSettle();
      await _sendShortcut(tester, LogicalKeyboardKey.keyC);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.5, 0.5, 0.5)
        ..setTranslationRaw(-900, -650, 0);
      await tester.pump();
      final workingTransform = Matrix4.copy(controller.value);
      final savesBeforeCopy = store.saveCalls;

      await _openImageSharingDialog(tester);
      await tester.tap(find.byKey(const ValueKey('share-whole-board-copy')));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Whole Board copied'), findsOneWidget);
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      expect(_selectedNoteIds(tester), {original.note.id});
      expect(store.saveCalls, savesBeforeCopy);

      await _sendShortcut(tester, LogicalKeyboardKey.keyV);
      expect(find.byType(EditableNote), findsNWidgets(2));
    },
  );

  testWidgets('failed whole-Board clipboard write reports one clear error', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      currentViewPngCapturer: (_, _) async =>
          Uint8List.fromList([137, 80, 78, 71]),
      currentViewPngClipboardWriter: (_) async =>
          throw StateError('test whole-Board clipboard failure'),
    );

    await _openImageSharingDialog(tester);
    await tester.tap(find.byKey(const ValueKey('share-whole-board-copy')));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not copy whole Board'), findsOneWidget);
    expect(find.text('Whole Board copied'), findsNothing);
  });

  testWidgets('uses one restrained shadow for every eligible foreground item', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 19);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'foreground-shadow-board',
        name: 'Foreground shadow board',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'shadow-note',
            x: 120,
            y: 120,
            width: 240,
            height: 160,
            text: 'Shadow note',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        images: [
          BoardImage(
            id: 'shadow-image',
            x: 120,
            y: 120,
            width: 240,
            height: 160,
            assetPath: 'assets/shadow-image.png',
            originalFileName: 'shadow-image.png',
            pixelWidth: 1200,
            pixelHeight: 800,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        headings: [
          CanvasHeading(
            id: 'shadow-coloured-heading',
            x: 120,
            y: 120,
            text: 'Coloured heading',
            size: CanvasHeadingSize.medium,
            background: CanvasHeadingBackground.white,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          CanvasHeading(
            id: 'shadow-transparent-heading',
            x: 120,
            y: 240,
            text: 'Transparent heading',
            size: CanvasHeadingSize.medium,
            background: CanvasHeadingBackground.transparent,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        attachments: [
          BoardAttachment(
            id: 'shadow-attachment',
            x: 120,
            y: 120,
            width: 300,
            height: 112,
            assetPath: 'assets/shadow.pdf',
            originalFileName: 'shadow.pdf',
            kind: AttachmentKind.pdf,
            byteSize: 100,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        youTubeEmbeds: [
          YouTubeEmbed(
            id: 'shadow-youtube',
            x: 120,
            y: 120,
            width: 300,
            height: 168,
            originalUrl: 'https://youtu.be/dQw4w9WgXcQ',
            videoId: 'dQw4w9WgXcQ',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(
      tester,
      store: store,
      imageViewBuilder: (image) =>
          SizedBox(width: image.width, height: image.height),
      imageAssetStore: _TestImageAssetStore(),
    );

    _expectSharedForegroundShadow(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('note-container-shadow-note')),
          )
          .decoration,
    );

    final imageSurface = find.byKey(
      const ValueKey('image-drag-surface-shadow-image'),
    );
    _expectSharedForegroundShadow(
      tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: imageSurface,
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration,
    );

    _expectSharedForegroundShadow(
      tester
          .widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(
                const ValueKey('heading-surface-shadow-coloured-heading'),
              ),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .decoration,
    );
    final transparentHeadingDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(
                      const ValueKey(
                        'heading-surface-shadow-transparent-heading',
                      ),
                    ),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(transparentHeadingDecoration.boxShadow, isNull);
    _expectSharedForegroundShadow(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('attachment-card-shadow-attachment')),
          )
          .decoration,
    );
    _expectSharedForegroundShadow(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('youtube-card-shadow-youtube')),
          )
          .decoration,
    );

    expect(tester.getSize(imageSurface), const Size(240, 160));
    expect(
      tester.getSize(
        find.byKey(const ValueKey('attachment-card-shadow-attachment')),
      ),
      const Size(300, 112),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('youtube-card-shadow-youtube'))),
      const Size(300, 168),
    );
  });

  testWidgets('locks a Note position without blocking selection and Undo', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 18);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'position-lock-widget-board',
        name: 'Position lock widget',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'lock-note',
            x: 320,
            y: 240,
            width: 280,
            height: 180,
            text: 'Editable while locked',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    final handle = find.byKey(const ValueKey('note-drag-handle-lock-note'));
    await _secondaryTap(tester, handle);
    await tester.tap(
      find.byKey(const ValueKey('context-position-lock-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('position-lock-indicator-lock-note')),
      findsOneWidget,
    );
    expect(_selectedNoteIds(tester), {'lock-note'});

    await tester.drag(handle, const Offset(120, 80));
    await tester.pumpAndSettle();
    var note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    expect(note.x, 320);
    expect(note.y, 240);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('position-lock-indicator-lock-note')),
      findsNothing,
    );

    await tester.drag(handle, const Offset(60, 40));
    await tester.pumpAndSettle();
    note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    expect(note.x, greaterThan(320));
    expect(note.y, greaterThan(240));
  });

  testWidgets('places layered canvas paper behind the interactive board', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    final paper = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is LayeredCanvasPaperPainter,
    );

    expect(paper, findsOneWidget);
    expect(
      find.descendant(of: find.byType(InteractiveViewer), matching: paper),
      findsOneWidget,
    );
  });

  testWidgets(
    'dispatches standard canvas shortcuts through existing commands',
    (tester) async {
      final store = await _pumpTestApp(tester);
      final source = tester
          .widget<EditableNote>(find.byType(EditableNote))
          .note;
      final sourceHandle = find.byKey(
        ValueKey('note-drag-handle-${source.id}'),
      );

      await tester.tap(sourceHandle);
      await _sendShortcut(tester, LogicalKeyboardKey.keyC);
      await _sendShortcut(tester, LogicalKeyboardKey.keyV);
      expect(find.byType(EditableNote), findsNWidgets(2));

      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(find.byType(EditableNote), findsOneWidget);
      await _sendShortcut(tester, LogicalKeyboardKey.keyY);
      expect(find.byType(EditableNote), findsNWidgets(2));
      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      await _sendShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(find.byType(EditableNote), findsNWidgets(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsOneWidget);
      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(find.byType(EditableNote), findsNWidgets(2));

      final savesBeforeShortcut = store.saveCalls;
      await _sendShortcut(tester, LogicalKeyboardKey.keyS);
      expect(store.saveCalls, savesBeforeShortcut + 1);
    },
  );

  testWidgets('unavailable canvas shortcuts are non-mutating no-ops', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 21, 14);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, includeConnector: false),
    );
    await _pumpTestApp(tester, store: store);
    final original = store.board!.toJson();
    final originalNotes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((note) => note.note.toJson())
        .toList();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    await _sendShortcut(tester, LogicalKeyboardKey.keyC);
    await _sendShortcut(tester, LogicalKeyboardKey.keyV);
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);

    expect(find.byType(EditableNote), findsNWidgets(2));
    expect(
      tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((note) => note.note.toJson()),
      originalNotes,
    );
    expect(store.board!.toJson(), original);
    expect(store.saveCalls, 0);
  });

  testWidgets('active note editing keeps text shortcuts and permits save', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    final textField = find.byKey(ValueKey('note-text-field-${note.note.id}'));

    await tester.tap(textField);
    await tester.enterText(textField, 'Alpha');
    await tester.pumpAndSettle();
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await _sendShortcut(tester, LogicalKeyboardKey.keyC);
    editable.controller.selection = const TextSelection.collapsed(offset: 5);
    await _sendShortcut(tester, LogicalKeyboardKey.keyV);
    expect(editable.controller.text, 'Alpha');
    expect(find.byType(EditableNote), findsOneWidget);

    editable.controller.selection = const TextSelection(
      baseOffset: 4,
      extentOffset: 5,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(editable.controller.text, 'Alph');
    expect(find.byType(EditableNote), findsOneWidget);

    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'Alpha');
    expect(editable.undoController!.value.canRedo, isTrue);
    expect(find.byType(EditableNote), findsOneWidget);

    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    expect(editable.controller.text, 'Alph');
    expect(find.byType(EditableNote), findsOneWidget);
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(editable.controller.text, 'Alpha');
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(editable.controller.text, 'Alph');
    expect(find.byType(EditableNote), findsOneWidget);
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
      isTrue,
    );

    final savesBeforeShortcut = store.saveCalls;
    await _sendShortcut(tester, LogicalKeyboardKey.keyS);
    expect(store.saveCalls, savesBeforeShortcut + 1);
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
      isTrue,
    );

    await tester.tap(find.byKey(ValueKey('note-drag-handle-${note.note.id}')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
      isFalse,
    );
    await _sendShortcut(tester, LogicalKeyboardKey.keyC);
    await _sendShortcut(tester, LogicalKeyboardKey.keyV);
    expect(find.byType(EditableNote), findsNWidgets(2));
  });

  testWidgets('dialogs and popup menus block background canvas shortcuts', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(find.byType(EditableNote), findsNWidgets(2));
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(find.byType(EditableNote), findsOneWidget);
    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    expect(find.byType(EditableNote), findsNWidgets(2));

    final selected = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .singleWhere((note) => note.isSelected);
    await tester.tap(find.byKey(const ValueKey('note-color-button')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _secondaryTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-${selected.note.id}')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(find.byType(EditableNote), findsOneWidget);
  });

  testWidgets('toolbar tooltips advertise implemented shortcuts', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    expect(find.byTooltip('Save board now (Ctrl+S)'), findsOneWidget);
    expect(find.byTooltip('Undo (Ctrl+Z)'), findsOneWidget);
    expect(find.byTooltip('Redo (Ctrl+Y or Ctrl+Shift+Z)'), findsOneWidget);
    expect(
      find.byTooltip('Copy or paste canvas objects (Ctrl+C / Ctrl+V)'),
      findsOneWidget,
    );
    expect(find.byTooltip('Delete selected notes (Delete)'), findsOneWidget);
  });

  testWidgets('keeps Fresh Pair unavailable until three notes are written', (
    tester,
  ) async {
    await _pumpFreshPairTestApp(
      tester,
      selector: FreshPairSelector(pickIndex: (_) => 0),
      writtenNoteCount: 2,
    );

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('fresh-pair-button')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.byTooltip('Add at least three written notes to use Fresh Pair'),
      findsOneWidget,
    );
  });

  testWidgets('Fresh Pair text stays readable on pale cards in Dark Mode', (
    tester,
  ) async {
    await _pumpFreshPairTestApp(
      tester,
      selector: FreshPairSelector(pickIndex: (_) => 0),
      theme: ThemeData.dark(),
    );
    await tester.tap(find.byKey(const ValueKey('fresh-pair-button')));
    await tester.pumpAndSettle();
    for (final id in ['fresh-note-0', 'fresh-note-1']) {
      final card = find.byKey(ValueKey('fresh-pair-note-$id'));
      final background = tester.widget<Card>(card).color!;
      for (final text in tester.widgetList<Text>(
        find.descendant(of: card, matching: find.byType(Text)),
      )) {
        final foreground = text.style!.color!;
        final contrast =
            (background.computeLuminance() + .05) /
            (foreground.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets(
    'YouTube thumbnail and context action open externally without changing the Board',
    (tester) async {
      final now = DateTime.utc(2026, 9, 28);
      final board = BoardDocument(
        id: 'youtube-links',
        name: 'Video links',
        createdAt: now,
        modifiedAt: now,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [],
        youTubeEmbeds: [
          for (var i = 0; i < 2; i++)
            YouTubeEmbed(
              id: 'video-$i',
              x: 100.0 + i * 340,
              y: 160,
              width: 300,
              height: 168,
              originalUrl: i == 0
                  ? 'https://youtu.be/dQw4w9WgXcQ?t=30'
                  : 'https://www.youtube.com/watch?v=abcdefghijk',
              videoId: i == 0 ? 'dQw4w9WgXcQ' : 'abcdefghijk',
              createdAt: now,
              modifiedAt: now,
            ),
        ],
      );
      final store = _MemoryBoardStore(board: board);
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CanvasExperiment(
            boardStore: store,
            imageAssetStore: _TestImageAssetStore(),
            imagePicker: () async => null,
            externalUrlLauncher: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('youtube-open-video-0')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(board.youTubeEmbeds.first.originalUrl)]);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Play'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Expand'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('youtube-card-video-0'))),
        const Size(300, 168),
      );

      await tester.tap(find.byKey(const ValueKey('youtube-select-video-1')));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(
        tester
            .widget<InteractiveYouTubeEmbed>(
              find.byKey(const ValueKey('video-1')),
            )
            .isSelected,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(const ValueKey('youtube-open-video-0')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(
        tester
            .widget<InteractiveYouTubeEmbed>(
              find.byKey(const ValueKey('video-0')),
            )
            .isSelected,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('youtube-open-video-1')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('youtube-open-menu-item')));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse(board.youTubeEmbeds.first.originalUrl),
        Uri.parse(board.youTubeEmbeds.last.originalUrl),
      ]);
      expect(store.saveCalls, 0);
      expect(store.board!.toJson(), board.toJson());

      await tester.drag(
        find.byKey(const ValueKey('youtube-select-video-1')),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();
      expect(opened, hasLength(2));
      expect(
        tester
            .widget<InteractiveYouTubeEmbed>(
              find.byKey(const ValueKey('video-1')),
            )
            .embed
            .x,
        greaterThan(440),
      );
    },
  );

  for (final throws in [false, true]) {
    testWidgets(
      'YouTube launch ${throws ? 'exception' : 'failure'} leaves the card usable',
      (tester) async {
        final now = DateTime.utc(2026, 9, 28);
        final store = _MemoryBoardStore(
          board: BoardDocument(
            id: 'failed-youtube-link',
            name: 'Video',
            createdAt: now,
            modifiedAt: now,
            viewportX: 0,
            viewportY: 0,
            viewportZoom: 1,
            notes: [],
            youTubeEmbeds: [
              YouTubeEmbed(
                id: 'failed-video',
                x: 100,
                y: 160,
                width: 300,
                height: 168,
                originalUrl: 'https://youtu.be/dQw4w9WgXcQ',
                videoId: 'dQw4w9WgXcQ',
                createdAt: now,
                modifiedAt: now,
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CanvasExperiment(
              boardStore: store,
              imageAssetStore: _TestImageAssetStore(),
              imagePicker: () async => null,
              externalUrlLauncher: (_) async {
                if (throws) throw StateError('Unavailable');
                return false;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('youtube-open-failed-video')),
        );
        await tester.pump();
        expect(find.text('Could not open YouTube'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('youtube-select-failed-video')),
        );
        await tester.pump();
        expect(
          tester
              .widget<InteractiveYouTubeEmbed>(
                find.byKey(const ValueKey('failed-video')),
              )
              .isSelected,
          isTrue,
        );
        expect(store.saveCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('closes Fresh Pair without changing selection or board state', (
    tester,
  ) async {
    final store = await _pumpFreshPairTestApp(
      tester,
      selector: FreshPairSelector(pickIndex: (_) => 0),
    );
    final originalBoard = store.board!.toJson();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final originalTransform = List<double>.of(
      viewer.transformationController!.value.storage,
    );
    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-fresh-note-0')),
    );
    await tester.pumpAndSettle();
    expect(_selectedFreshPairNoteIds(tester), {'fresh-note-0'});

    await tester.tap(find.byKey(const ValueKey('fresh-pair-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fresh-pair-dialog')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fresh-pair-excerpt-fresh-note-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fresh-pair-excerpt-fresh-note-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fresh-pair-note-fresh-note-blank')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('close-fresh-pair-button')));
    await tester.pumpAndSettle();

    expect(_selectedFreshPairNoteIds(tester), {'fresh-note-0'});
    expect(store.board!.toJson(), originalBoard);
    expect(store.saveCalls, 0);
    expect(
      viewer.transformationController!.value.storage,
      orderedEquals(originalTransform),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('rerolls and uses a Fresh Pair as transient selection only', (
    tester,
  ) async {
    final store = await _pumpFreshPairTestApp(
      tester,
      selector: FreshPairSelector(pickIndex: (_) => 0),
    );
    final originalBoard = store.board!.toJson();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final originalTransform = List<double>.of(
      viewer.transformationController!.value.storage,
    );

    await tester.tap(find.byKey(const ValueKey('fresh-pair-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fresh-pair-note-fresh-note-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fresh-pair-note-fresh-note-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('another-fresh-pair-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fresh-pair-note-fresh-note-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fresh-pair-note-fresh-note-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fresh-pair-note-fresh-note-2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('use-fresh-pair-button')));
    await tester.pumpAndSettle();

    expect(_selectedFreshPairNoteIds(tester), {'fresh-note-0', 'fresh-note-2'});
    expect(
      find.byKey(const ValueKey('connector-toggle-button')),
      findsOneWidget,
    );
    expect(store.board!.toJson(), originalBoard);
    expect(store.saveCalls, 0);
    expect(
      viewer.transformationController!.value.storage,
      orderedEquals(originalTransform),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('primes a newly created blank board and focuses its first note', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 19, 12);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'primed-board',
        name: 'New thought',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'initial-note',
            x: 320,
            y: 240,
            width: 260,
            height: 170,
            text: '',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(),
          imagePicker: () async => null,
          showBlankCanvasPriming: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('blank-canvas-priming-card')),
      findsOneWidget,
    );
    expect(find.text('What has your attention right now?'), findsOneWidget);
    expect(find.byType(EditableNote), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-writing-from-priming')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('blank-canvas-priming-card')),
      findsNothing,
    );
    expect(find.text('EDITING'), findsOneWidget);
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).note.text,
      '',
    );
    expect(store.saveCalls, 0);
  });

  testWidgets('dismisses blank-canvas priming without changing board data', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 19, 12);
    final board = BoardDocument(
      id: 'dismissed-priming-board',
      name: 'Blank board',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'initial-note',
          x: 320,
          y: 240,
          width: 260,
          height: 170,
          text: '',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );
    final store = _MemoryBoardStore(board: board);

    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(),
          imagePicker: () async => null,
          showBlankCanvasPriming: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('dismiss-blank-canvas-priming')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('blank-canvas-priming-card')),
      findsNothing,
    );
    expect(store.saveCalls, 0);
    expect(store.board!.toJson(), board.toJson());
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('does not prime an existing board', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 19, 12);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'existing-board',
        name: 'Existing board',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'existing-note',
            x: 320,
            y: 240,
            width: 260,
            height: 170,
            text: 'Already started',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(),
          imagePicker: () async => null,
          showBlankCanvasPriming: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('blank-canvas-priming-card')),
      findsNothing,
    );
  });

  testWidgets('shows a secondary-pannable zoomable canvas with one note', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    expect(find.text('Prototype Board'), findsOneWidget);
    expect(find.text('Vasmim'), findsNothing);
    expect(find.byType(EditableNote), findsOneWidget);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.panEnabled, isFalse);
    expect(viewer.scaleEnabled, isTrue);
    expect(viewer.minScale, 0.2);
    expect(viewer.maxScale, 4);
    expect(find.text('DRAG TO MOVE'), findsOneWidget);
  });

  testWidgets('shows the loaded board name in the editor title', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 23);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'named-board',
        name: 'Research Roadmap',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
      ),
    );

    await _pumpTestApp(tester, store: store);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('active-board-name'))).data,
      'Research Roadmap',
    );
    expect(find.text('Vasmim'), findsNothing);
  });

  testWidgets('double-clicking the Board title opens rename', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpTestApp(tester);
    final title = find.byKey(const ValueKey('active-board-name'));
    await tester.tap(title);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board-name-field')), findsOneWidget);
  });

  testWidgets(
    'validates editor rename and treats cancel or same name as no-op',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 23);
      final board = BoardDocument(
        id: 'rename-no-op-board',
        name: 'Named Board',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
      );
      final store = _MemoryBoardStore(board: board);
      await _pumpTestApp(tester, store: store);

      await tester.tap(
        find.byKey(const ValueKey('rename-active-board-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rename board'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('board-name-field')))
            .controller!
            .text,
        'Named Board',
      );
      await tester.enterText(
        find.byKey(const ValueKey('board-name-field')),
        '   ',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
      await tester.pump();
      expect(find.text('Enter a board name'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('rename-active-board-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('board-name-field')),
        '  Named Board  ',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Named Board'), findsOneWidget);
      expect(store.saveCalls, 0);
      expect(store.board!.modifiedAt, timestamp);
    },
  );

  testWidgets(
    'renames through autosave while preserving canvas state and undo target',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 23);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'rename-board',
          name: 'Working Name',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 140,
          viewportY: 90,
          viewportZoom: 0.8,
          notes: [
            Note(
              id: 'rename-note',
              x: 360,
              y: 260,
              width: 260,
              height: 170,
              text: 'Keep me selected',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-rename-note')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final transformBefore = Matrix4.copy(controller.value);

      await tester.tap(
        find.byKey(const ValueKey('rename-active-board-button')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(find.byType(EditableNote), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('active-board-name')))
            .data,
        'Working Name',
      );

      await tester.enterText(
        find.byKey(const ValueKey('board-name-field')),
        '  Research Roadmap 2027  ',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-board-name-button')));
      await tester.pumpAndSettle();

      expect(find.text('Research Roadmap 2027'), findsOneWidget);
      expect(_selectedNoteIds(tester), {'rename-note'});
      expect(controller.value.storage, orderedEquals(transformBefore.storage));
      expect(find.byType(EditableNote), findsNWidgets(2));

      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(find.byType(EditableNote), findsOneWidget);
      expect(find.text('Research Roadmap 2027'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.board!.name, 'Research Roadmap 2027');
      expect(store.board!.modifiedAt.isAfter(timestamp), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTestApp(tester, store: store);
      expect(find.text('Research Roadmap 2027'), findsOneWidget);
    },
  );

  testWidgets('keeps the canvas point under the mouse fixed while zooming', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    final viewerFinder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    const localPointer = Offset(400, 340);
    final globalPointer = tester.getTopLeft(viewerFinder) + localPointer;
    final scenePointBefore = controller.toScene(localPointer);
    final scaleBefore = controller.value.getMaxScaleOnAxis();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: globalPointer,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pumpAndSettle();

    final scenePointAfter = controller.toScene(localPointer);
    final scaleAfter = controller.value.getMaxScaleOnAxis();
    expect(scaleAfter, greaterThan(scaleBefore));
    expect(scenePointAfter.dx, closeTo(scenePointBefore.dx, 0.001));
    expect(scenePointAfter.dy, closeTo(scenePointBefore.dy, 0.001));

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: globalPointer,
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pumpAndSettle();

    final scenePointAfterZoomOut = controller.toScene(localPointer);
    expect(controller.value.getMaxScaleOnAxis(), lessThan(scaleAfter));
    expect(scenePointAfterZoomOut.dx, closeTo(scenePointBefore.dx, 0.001));
    expect(scenePointAfterZoomOut.dy, closeTo(scenePointBefore.dy, 0.001));
  });

  testWidgets(
    'allows ordinary wheel zoom to reach 20 percent on a wide viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpTestApp(tester);

      final viewerFinder = find.byType(InteractiveViewer);
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      final controller = viewer.transformationController!;
      final globalPointer = tester.getCenter(viewerFinder);

      for (var index = 0; index < 24; index++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: globalPointer,
            scrollDelta: const Offset(0, 100),
          ),
        );
      }
      await tester.pumpAndSettle();

      expect(controller.value.getMaxScaleOnAxis(), closeTo(0.2, 0.001));
      expect(find.text('20%'), findsOneWidget);
    },
  );

  testWidgets('enters text editing mode and accepts note text', (tester) async {
    await _pumpTestApp(tester);

    final editableNote = tester.widget<EditableNote>(find.byType(EditableNote));
    final textField = find.byKey(
      ValueKey('note-text-field-${editableNote.note.id}'),
    );
    expect(find.text('DRAG TO MOVE'), findsOneWidget);

    await tester.tap(textField);
    await tester.pumpAndSettle();
    expect(find.text('EDITING'), findsOneWidget);

    await tester.enterText(textField, 'First editable note');
    await tester.pump();
    expect(find.text('First editable note'), findsOneWidget);
  });

  testWidgets('pasting Markdown gives a Note editable formatting', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    final original = tester.widget<EditableNote>(find.byType(EditableNote));
    final field = find.byKey(ValueKey('note-text-field-${original.note.id}'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '# Title\n- **Bold** and *italic*');
    await tester.pump();

    final note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    expect(note.text, 'Title\n• Bold and italic');
    expect(
      note.emphasis,
      contains(const NoteEmphasisRange(start: 0, end: 5, bold: true)),
    );
    expect(
      note.emphasis,
      contains(const NoteEmphasisRange(start: 8, end: 12, bold: true)),
    );
    expect(
      note.emphasis,
      contains(const NoteEmphasisRange(start: 17, end: 23, italic: true)),
    );
  });

  testWidgets('clipboard Markdown paste permits editing another Note', (
    tester,
  ) async {
    const markdown =
        '# Title\r\n- **Bold** and *italic*\r\n[Site](https://example.com)';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': markdown};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pumpMixedBoard(tester, timestamp: DateTime.utc(2026, 9, 28));
    final originalField = find.byKey(
      const ValueKey('note-text-field-mixed-note'),
    );
    await tester.tap(originalField);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final pasted = tester
        .widget<EditableNote>(find.byKey(const ValueKey('mixed-note')))
        .note;
    expect(pasted.text, 'Title\n• Bold and italic\nSite');
    expect(NoteEmphasis.invalidReason(pasted.text, pasted.emphasis), isNull);
    expect(pasted.links.single.destination, 'https://example.com');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('mixed-note')))
          .note
          .text,
      'Mixed note',
    );
    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    final restored = tester
        .widget<EditableNote>(find.byKey(const ValueKey('mixed-note')))
        .note;
    expect(restored.text, pasted.text);
    expect(restored.emphasis, pasted.emphasis);
    expect(restored.links, pasted.links);

    // Create another Note through the same Board clipboard path the owner uses.
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-mixed-note')));
    await tester.pumpAndSettle();
    final viewport = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    viewport.value = Matrix4.diagonal3Values(0.75, 0.75, 0.75)
      ..setTranslationRaw(-120, -90, 0);
    await tester.pump();
    final surface = tester.getRect(
      find.byKey(const ValueKey('canvas-interaction-surface')),
    );
    await tester.tapAt(
      surface.topLeft + const Offset(610, 420),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('context-paste-text-menu-item')),
    );
    await tester.pumpAndSettle();
    final created = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .singleWhere((widget) => widget.note.id != 'mixed-note');
    expect(created.note.text, pasted.text);
    expect(created.note.emphasis, pasted.emphasis);
    expect(created.note.links, pasted.links);
    viewport.value = Matrix4.identity();
    await tester.pump();
    await tester.tap(originalField);
    await tester.pumpAndSettle();
    await tester.enterText(originalField, 'Still editable');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('mixed-note')))
          .note
          .text,
      'Still editable',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enter inserts and persists a blank Note line without losing ranges',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 5, 12);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'paragraph-break-board',
          name: 'Paragraph breaks',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'paragraph-break-note',
              x: 300,
              y: 200,
              width: 300,
              height: 200,
              text: 'Alpha beta',
              emphasis: const [NoteEmphasisRange(start: 0, end: 5, bold: true)],
              links: const [
                NoteTextLinkRange(
                  start: 6,
                  end: 10,
                  destination: 'https://example.com/beta',
                ),
              ],
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      await _pumpTestApp(tester, store: store);
      final field = find.byKey(
        const ValueKey('note-text-field-paragraph-break-note'),
      );

      await tester.tapAt(tester.getTopLeft(field) + const Offset(12, 12));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableNote>(
              find.byKey(const ValueKey('paragraph-break-note')),
            )
            .isEditing,
        isTrue,
      );
      final textField = tester.widget<TextField>(field);
      expect(textField.keyboardType, TextInputType.multiline);
      expect(textField.textInputAction, TextInputAction.newline);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump(const Duration(milliseconds: 600));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        tester
            .widget<EditableNote>(
              find.byKey(const ValueKey('paragraph-break-note')),
            )
            .isEditing,
        isTrue,
      );
      expect(editable.focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 600));

      var note = tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('paragraph-break-note')),
          )
          .note;
      expect(note.text, 'Alpha\n\n beta');
      expect(note.emphasis, [
        const NoteEmphasisRange(start: 0, end: 5, bold: true),
      ]);
      expect(note.links, [
        const NoteTextLinkRange(
          start: 8,
          end: 12,
          destination: 'https://example.com/beta',
        ),
      ]);
      expect(find.text('EDITING'), findsOneWidget);

      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(
        tester
            .widget<EditableNote>(
              find.byKey(const ValueKey('paragraph-break-note')),
            )
            .note
            .text,
        'Alpha beta',
      );
      await _sendShortcut(tester, LogicalKeyboardKey.keyY);
      expect(
        tester
            .widget<EditableNote>(
              find.byKey(const ValueKey('paragraph-break-note')),
            )
            .note
            .text,
        'Alpha\n\n beta',
      );

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTestApp(tester, store: store);

      note = tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('paragraph-break-note')),
          )
          .note;
      expect(note.text, 'Alpha\n\n beta');
      expect(note.emphasis, [
        const NoteEmphasisRange(start: 0, end: 5, bold: true),
      ]);
      expect(note.links, [
        const NoteTextLinkRange(
          start: 8,
          end: 12,
          destination: 'https://example.com/beta',
        ),
      ]);
    },
  );

  testWidgets(
    'toggles selected Note emphasis with keyboard and editor history',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 4, 16);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'emphasis-keyboard-board',
          name: 'Emphasis keyboard',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'emphasis-note',
              x: 300,
              y: 200,
              width: 300,
              height: 200,
              text: 'Alpha beta gamma',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      await _pumpTestApp(tester, store: store);
      final field = find.byKey(const ValueKey('note-text-field-emphasis-note'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      var editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );

      await _sendShortcut(tester, LogicalKeyboardKey.keyB);
      var note = tester
          .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
          .note;
      expect(note.emphasis, [
        const NoteEmphasisRange(start: 0, end: 5, bold: true),
      ]);
      editable = tester.widget<EditableText>(find.byType(EditableText));
      final styledText = editable.controller.buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        style: editable.style,
        withComposing: false,
      );
      expect(
        (styledText.children!.first as TextSpan).style!.fontWeight,
        FontWeight.bold,
      );
      expect(editable.controller.selection.start, 0);
      expect(editable.controller.selection.end, 5);

      editable.controller.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 10,
      );
      await _sendShortcut(tester, LogicalKeyboardKey.keyU);
      note = tester
          .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
          .note;
      expect(note.emphasis, [
        const NoteEmphasisRange(start: 0, end: 3, bold: true),
        const NoteEmphasisRange(start: 3, end: 5, bold: true, underline: true),
        const NoteEmphasisRange(start: 5, end: 10, underline: true),
      ]);

      editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 10,
      );
      await _sendShortcut(tester, LogicalKeyboardKey.keyI);
      note = tester
          .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
          .note;
      expect(note.emphasis, [
        const NoteEmphasisRange(start: 0, end: 3, bold: true),
        const NoteEmphasisRange(start: 3, end: 5, bold: true, underline: true),
        const NoteEmphasisRange(
          start: 5,
          end: 10,
          underline: true,
          italic: true,
        ),
      ]);
      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      note = tester
          .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
          .note;
      expect(note.emphasis, [
        const NoteEmphasisRange(start: 0, end: 3, bold: true),
        const NoteEmphasisRange(start: 3, end: 5, bold: true, underline: true),
        const NoteEmphasisRange(start: 5, end: 10, underline: true),
      ]);
      await _sendShortcut(tester, LogicalKeyboardKey.keyY);
      expect(
        tester
            .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
            .note
            .emphasis,
        hasLength(3),
      );

      editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection.collapsed(offset: 5);
      final beforeCollapsedCommand = tester
          .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
          .note
          .emphasis;
      await _sendShortcut(tester, LogicalKeyboardKey.keyB);
      expect(
        tester
            .widget<EditableNote>(find.byKey(const ValueKey('emphasis-note')))
            .note
            .emphasis,
        beforeCollapsedCommand,
      );
    },
  );

  testWidgets(
    'selection menu emphasis participates in Board history and save',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 4, 17);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'emphasis-menu-board',
          name: 'Emphasis menu',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'menu-note',
              x: 300,
              y: 200,
              width: 300,
              height: 200,
              text: 'Format this text',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      await _pumpTestApp(tester, store: store);
      final field = find.byKey(const ValueKey('note-text-field-menu-note'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.tapAt(
        tester.getTopLeft(field) + const Offset(24, 18),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(find.text('Bold'), findsOneWidget);
      expect(find.text('Underline'), findsOneWidget);
      expect(find.text('Italic'), findsOneWidget);
      await tester.tap(find.text('Bold'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableNote>(find.byKey(const ValueKey('menu-note')))
            .note
            .emphasis,
        [const NoteEmphasisRange(start: 0, end: 6, bold: true)],
      );

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-menu-note')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableNote>(find.byKey(const ValueKey('menu-note')))
            .note
            .emphasis,
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableNote>(find.byKey(const ValueKey('menu-note')))
            .note
            .emphasis,
        hasLength(1),
      );

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTestApp(tester, store: store);
      expect(
        tester
            .widget<EditableNote>(find.byKey(const ValueKey('menu-note')))
            .note
            .emphasis,
        [const NoteEmphasisRange(start: 0, end: 6, bold: true)],
      );
    },
  );

  testWidgets(
    'selection menu lists preserve ranges through text and Board history',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 22, 9);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'manual-list-board',
          name: 'Manual lists',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'manual-list-note',
              x: 300,
              y: 200,
              width: 320,
              height: 220,
              text: 'Alpha\n\nBeta',
              emphasis: const [NoteEmphasisRange(start: 0, end: 5, bold: true)],
              links: const [
                NoteTextLinkRange(
                  start: 7,
                  end: 11,
                  destination: 'https://example.com/beta',
                ),
              ],
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      );
      await _pumpTestApp(tester, store: store);
      final field = find.byKey(
        const ValueKey('note-text-field-manual-list-note'),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      var editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 9,
      );
      await tester.tapAt(
        tester.getTopLeft(field) + const Offset(24, 18),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      if (find.text('Bulleted list').evaluate().isEmpty) {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
      }
      expect(find.text('Bulleted list'), findsOneWidget);
      expect(find.text('Numbered list'), findsOneWidget);
      await tester.tap(find.text('Numbered list'));
      await tester.pumpAndSettle();

      Note currentNote() => tester
          .widget<EditableNote>(find.byKey(const ValueKey('manual-list-note')))
          .note;

      expect(currentNote().text, '1. Alpha\n\n2. Beta');
      expect(currentNote().emphasis, const [
        NoteEmphasisRange(start: 3, end: 8, bold: true),
      ]);
      expect(currentNote().links, const [
        NoteTextLinkRange(
          start: 13,
          end: 17,
          destination: 'https://example.com/beta',
        ),
      ]);
      editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(
        editable.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 17),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(currentNote().text, 'Alpha\n\nBeta');
      expect(currentNote().emphasis.single.start, 0);
      expect(currentNote().links.single.start, 7);
      await _sendShortcut(tester, LogicalKeyboardKey.keyY);
      expect(currentNote().text, '1. Alpha\n\n2. Beta');
      expect(currentNote().emphasis.single.start, 3);
      expect(currentNote().links.single.start, 13);

      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-manual-list-note')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(currentNote().text, 'Alpha\n\nBeta');
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(currentNote().text, '1. Alpha\n\n2. Beta');

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTestApp(tester, store: store);
      expect(currentNote().text, '1. Alpha\n\n2. Beta');
      expect(currentNote().emphasis.single.start, 3);
      expect(currentNote().links.single.start, 13);
    },
  );

  testWidgets('remaps Note emphasis as selected body text is edited', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 4, 18);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'emphasis-edit-board',
        name: 'Emphasis edits',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'edit-emphasis-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'abcdefgh',
            emphasis: const [NoteEmphasisRange(start: 2, end: 6, bold: true)],
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    final field = find.byKey(
      const ValueKey('note-text-field-edit-emphasis-note'),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abcdXefgh',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    var note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-emphasis-note')))
        .note;
    expect(note.text, 'abcdXefgh');
    expect(note.emphasis, [
      const NoteEmphasisRange(start: 2, end: 7, bold: true),
    ]);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abYgh',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-emphasis-note')))
        .note;
    expect(note.text, 'abYgh');
    expect(note.emphasis, [
      const NoteEmphasisRange(start: 2, end: 3, bold: true),
    ]);

    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-emphasis-note')))
        .note;
    expect(note.text, 'abcdXefgh');
    expect(note.emphasis, [
      const NoteEmphasisRange(start: 2, end: 7, bold: true),
    ]);
    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-emphasis-note')))
        .note;
    expect(note.text, 'abYgh');
    expect(note.emphasis, [
      const NoteEmphasisRange(start: 2, end: 3, bold: true),
    ]);
  });

  testWidgets('adds edits opens and removes a selected Note text link', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 4, 19);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'selected-link-board',
        name: 'Selected links',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'selected-link-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'Alpha beta gamma',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    final launched = <Uri>[];
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        externalUrlLauncher: (url) async {
          launched.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey('note-text-field-selected-link-note'),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );

    await tester.tapAt(
      tester.getTopLeft(field) + const Offset(24, 18),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    if (find.text('Add link...').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }
    expect(find.text('Add link...'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _sendShortcut(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.text('Add link'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('note-text-link-destination-field')),
      'https://example.com/source',
    );
    await tester.tap(find.byKey(const ValueKey('note-text-link-save')));
    await tester.pumpAndSettle();

    var note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('selected-link-note')))
        .note;
    expect(note.links, const [
      NoteTextLinkRange(
        start: 0,
        end: 5,
        destination: 'https://example.com/source',
      ),
    ]);
    editable = tester.widget<EditableText>(find.byType(EditableText));
    final styledText = editable.controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: editable.style,
      withComposing: false,
    );
    expect(
      (styledText.children!.first as TextSpan).style!.decoration,
      TextDecoration.underline,
    );

    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await _sendShortcut(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.text('Edit link'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('note-text-link-destination-field')),
          )
          .initialValue,
      'https://example.com/source',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-text-link-destination-field')),
      'mailto:test@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('note-text-link-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a complete http or https website address.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('selected-link-note')),
          )
          .note
          .links
          .single
          .destination,
      'https://example.com/source',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-text-link-destination-field')),
      'https://example.com/edited',
    );
    await tester.tap(find.byKey(const ValueKey('note-text-link-save')));
    await tester.pumpAndSettle();

    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('selected-link-note')),
          )
          .isEditing,
      isTrue,
    );
    expect(editable.controller.selection.start, 0);
    expect(editable.controller.selection.end, 5);
    await tester.tapAt(
      tester.getTopLeft(field) + const Offset(24, 18),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    if (find.text('Open link').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }
    expect(find.text('Open link'), findsOneWidget);
    await tester.tap(find.text('Open link'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://example.com/edited')]);

    editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await tester.tapAt(
      tester.getTopLeft(field) + const Offset(24, 18),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final editWasVisible = find.text('Edit link...').evaluate().isNotEmpty;
    if (find.text('Remove link').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }
    expect(
      editWasVisible || find.text('Edit link...').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('Remove link'), findsOneWidget);
    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('selected-link-note')))
        .note;
    expect(note.links, isEmpty);
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('selected-link-note')),
          )
          .note
          .links,
      hasLength(1),
    );
    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-selected-link-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('selected-link-note')),
          )
          .note
          .links,
      isEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('selected-link-note')),
          )
          .note
          .links,
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('selected-link-note')),
          )
          .note
          .links
          .single
          .destination,
      'https://example.com/edited',
    );
  });

  testWidgets('edits or removes the one link touched by a text selection', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 5, 14);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'touched-link-board',
        name: 'Touched link',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'touched-link-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'Alpha beta',
            links: const [
              NoteTextLinkRange(
                start: 0,
                end: 5,
                destination: 'https://example.com/touched',
              ),
            ],
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    final field = find.byKey(
      const ValueKey('note-text-field-touched-link-note'),
    );
    await tester.tapAt(tester.getTopLeft(field) + const Offset(150, 18));
    await tester.pumpAndSettle();
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );

    await tester.tapAt(
      tester.getTopLeft(field) + const Offset(24, 18),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit link...'), findsOneWidget);
    expect(find.text('Remove link'), findsOneWidget);
    await tester.tap(find.text('Edit link...'));
    await tester.pumpAndSettle();
    expect(find.text('Edit link'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.tapAt(
      tester.getTopLeft(field) + const Offset(24, 18),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove link'), findsOneWidget);
    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('touched-link-note')))
          .note
          .links,
      isEmpty,
    );
  });

  testWidgets('remaps selected text links through native text history', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 4, 20);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'link-edit-board',
        name: 'Link edits',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'edit-link-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'abcdefgh',
            links: const [
              NoteTextLinkRange(
                start: 2,
                end: 6,
                destination: 'https://example.com',
              ),
            ],
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    final field = find.byKey(const ValueKey('note-text-field-edit-link-note'));
    await tester.tap(field);
    await tester.pumpAndSettle();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abcdXefgh',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    var note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-link-note')))
        .note;
    expect(note.links, const [
      NoteTextLinkRange(start: 2, end: 7, destination: 'https://example.com'),
    ]);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abYgh',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-link-note')))
        .note;
    expect(note.links.single.start, 2);
    expect(note.links.single.end, 3);

    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-link-note')))
        .note;
    expect(note.text, 'abcdXefgh');
    expect(note.links.single.end, 7);
    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    note = tester
        .widget<EditableNote>(find.byKey(const ValueKey('edit-link-note')))
        .note;
    expect(note.text, 'abYgh');
    expect(note.links.single.end, 3);
  });

  testWidgets('control-click opens linked text without changing selection', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 4, 21);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'link-control-click-board',
        name: 'Link control click',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'control-click-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'Alpha beta',
            links: const [
              NoteTextLinkRange(
                start: 0,
                end: 5,
                destination: 'https://example.com/control',
              ),
            ],
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    final launched = <Uri>[];
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        externalUrlLauncher: (url) async {
          launched.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey('note-text-field-control-click-note'),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 6,
      extentOffset: 10,
    );
    final before = store.board!.toJson();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tapAt(tester.getTopLeft(field) + const Offset(24, 18));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(launched, [Uri.parse('https://example.com/control')]);
    expect(editable.controller.selection.start, 6);
    expect(editable.controller.selection.end, 10);
    expect(store.board!.toJson(), before);
    expect(
      tester
          .widget<EditableNote>(
            find.byKey(const ValueKey('control-click-note')),
          )
          .isEditing,
      isTrue,
    );
  });

  testWidgets('single click opens linked text only outside Note editing', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 5, 13);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'link-single-click-board',
        name: 'Link single click',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'single-click-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'Alpha beta',
            links: const [
              NoteTextLinkRange(
                start: 0,
                end: 5,
                destination: 'https://example.com/single',
              ),
            ],
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    final launched = <Uri>[];
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        externalUrlLauncher: (url) async {
          launched.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey('note-text-field-single-click-note'),
    );
    final before = store.board!.toJson();

    await tester.tapAt(tester.getTopLeft(field) + const Offset(24, 18));
    await tester.pumpAndSettle();

    expect(launched, [Uri.parse('https://example.com/single')]);
    expect(store.board!.toJson(), before);
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('single-click-note')))
          .isEditing,
      isFalse,
    );

    await tester.tapAt(tester.getTopLeft(field) + const Offset(150, 18));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('single-click-note')))
          .isEditing,
      isTrue,
    );
    await tester.tapAt(tester.getTopLeft(field) + const Offset(24, 18));
    await tester.pumpAndSettle();
    expect(launched, hasLength(1));
  });

  testWidgets('linked text shows a hand cursor and destination tooltip', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 5, 12);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'link-hover-board',
        name: 'Link hover',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'hover-link-note',
            x: 300,
            y: 200,
            width: 300,
            height: 200,
            text: 'Alpha beta',
            links: const [
              NoteTextLinkRange(
                start: 0,
                end: 5,
                destination: 'https://example.com/reference',
              ),
            ],
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    final field = find.byKey(const ValueKey('note-text-field-hover-link-note'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getTopLeft(field) + const Offset(24, 18));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<TextField>(field).mouseCursor,
      SystemMouseCursors.click,
    );
    expect(find.text('example.com\nClick to open'), findsOneWidget);

    await mouse.moveTo(tester.getTopLeft(field) + const Offset(150, 18));
    await tester.pump();
    expect(
      tester.widget<TextField>(field).mouseCursor,
      SystemMouseCursors.text,
    );
    expect(find.text('example.com\nClick to open'), findsNothing);
    await mouse.removePointer();

    await tester.tapAt(tester.getTopLeft(field) + const Offset(150, 18));
    await tester.pumpAndSettle();
    final editingMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await editingMouse.addPointer(location: Offset.zero);
    await tester.pump();
    await editingMouse.moveTo(tester.getTopLeft(field) + const Offset(24, 18));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('example.com\nCtrl+click to open'), findsOneWidget);
    await editingMouse.removePointer();
  });

  testWidgets('keeps one wider scrollbar fixed beside a reserved text gutter', (
    tester,
  ) async {
    final store = _MemoryBoardStore(
      board: _noteEditingComfortBoard(
        List.generate(24, (index) => 'Reference line ${index + 1}').join('\n'),
      ),
    );
    await _pumpTestApp(tester, store: store);

    final scrollbarTheme = tester.widget<ScrollbarTheme>(
      find.byKey(const ValueKey('note-text-scrollbar-theme-comfort-note')),
    );
    expect(scrollbarTheme.data.thickness!.resolve({}), 9);
    expect(scrollbarTheme.data.thickness!.resolve({WidgetState.hovered}), 12);
    final scrollbar = find.byKey(
      const ValueKey('note-text-scrollbar-comfort-note'),
    );
    final field = find.byKey(const ValueKey('note-text-field-comfort-note'));
    final resizeRail = find.byKey(
      const ValueKey('note-resize-rail-comfort-note'),
    );
    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('note-text-content-padding-comfort-note')),
    );
    expect((padding.padding as EdgeInsets).right, 18);
    final scrollbarRectBefore = tester.getRect(scrollbar);
    final fieldRectBefore = tester.getRect(field);
    final resizeRailRectBefore = tester.getRect(resizeRail);
    expect(fieldRectBefore.bottom, lessThanOrEqualTo(resizeRailRectBefore.top));
    expect(
      scrollbarRectBefore.bottom,
      lessThanOrEqualTo(resizeRailRectBefore.top),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-comfort-note')),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(scrollbar), scrollbarRectBefore);
    expect(tester.getRect(field), fieldRectBefore);
    expect(tester.getRect(resizeRail), resizeRailRectBefore);

    await tester.tapAt(fieldRectBefore.topLeft + const Offset(80, 18));
    await tester.pumpAndSettle();

    expect(tester.getRect(scrollbar), scrollbarRectBefore);
    expect(tester.getRect(field), fieldRectBefore);
    expect(tester.getRect(resizeRail), resizeRailRectBefore);
  });

  testWidgets('note body owns wheel scrolling without zoom fallthrough', (
    tester,
  ) async {
    final store = _MemoryBoardStore(
      board: _noteEditingComfortBoard(
        List.generate(30, (index) => 'Reference line ${index + 1}').join('\n'),
      ),
    );
    await _pumpTestApp(tester, store: store);

    const fieldKey = ValueKey('note-text-field-comfort-note');
    final field = find.byKey(fieldKey);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final viewportController = viewer.transformationController!;
    final textScrollable = find.descendant(
      of: field,
      matching: find.byType(Scrollable),
    );
    final textPosition = tester.state<ScrollableState>(textScrollable).position;
    final pointer = tester.getCenter(field);
    final zoomBefore = viewportController.value.getMaxScaleOnAxis();

    await tester.sendEventToBinding(
      PointerHoverEvent(position: pointer, kind: PointerDeviceKind.mouse),
    );
    await tester.pump();
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .scaleEnabled,
      isFalse,
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(position: pointer, scrollDelta: const Offset(0, 120)),
    );
    await tester.pumpAndSettle();

    expect(textPosition.pixels, greaterThan(0));
    expect(viewportController.value.getMaxScaleOnAxis(), zoomBefore);

    textPosition.jumpTo(textPosition.maxScrollExtent);
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(position: pointer, scrollDelta: const Offset(0, 120)),
    );
    await tester.pumpAndSettle();

    expect(textPosition.pixels, textPosition.maxScrollExtent);
    expect(viewportController.value.getMaxScaleOnAxis(), zoomBefore);

    final viewerFinder = find.byType(InteractiveViewer);
    final blankPointer = tester.getTopLeft(viewerFinder) + const Offset(60, 80);
    await tester.sendEventToBinding(
      PointerHoverEvent(position: blankPointer, kind: PointerDeviceKind.mouse),
    );
    await tester.pump();
    expect(tester.widget<InteractiveViewer>(viewerFinder).scaleEnabled, isTrue);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: blankPointer,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      viewportController.value.getMaxScaleOnAxis(),
      greaterThan(zoomBefore),
    );
  });

  testWidgets('short note body owns wheel input without scrolling or zooming', (
    tester,
  ) async {
    final store = _MemoryBoardStore(
      board: _noteEditingComfortBoard('A short thought'),
    );
    await _pumpTestApp(tester, store: store);

    const fieldKey = ValueKey('note-text-field-comfort-note');
    final field = find.byKey(fieldKey);
    final viewerFinder = find.byType(InteractiveViewer);
    final viewportController = tester
        .widget<InteractiveViewer>(viewerFinder)
        .transformationController!;
    final pointer = tester.getCenter(field);
    final zoomBefore = viewportController.value.getMaxScaleOnAxis();

    await tester.sendEventToBinding(
      PointerHoverEvent(position: pointer, kind: PointerDeviceKind.mouse),
    );
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(position: pointer, scrollDelta: const Offset(0, 120)),
    );
    await tester.pumpAndSettle();

    expect(viewportController.value.getMaxScaleOnAxis(), zoomBefore);
  });

  testWidgets('first note-body click edits at the pointed text position', (
    tester,
  ) async {
    const text = 'alpha beta gamma delta';
    final store = _MemoryBoardStore(board: _noteEditingComfortBoard(text));
    await _pumpTestApp(tester, store: store);

    const fieldKey = ValueKey('note-text-field-comfort-note');
    final field = find.byKey(fieldKey);
    final fieldTopLeft = tester.getTopLeft(field);
    await tester.tapAt(fieldTopLeft + const Offset(92, 18));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
      isTrue,
    );
    final controller = tester
        .widget<EditableText>(find.byType(EditableText))
        .controller;
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.extentOffset, greaterThan(0));
    expect(controller.selection.extentOffset, lessThan(text.length));
  });

  testWidgets('selects and moves the note by its header', (tester) async {
    await _pumpTestApp(tester);

    final noteFinder = find.byType(EditableNote);
    final editableNote = tester.widget<EditableNote>(noteFinder);
    final dragHandle = find.byKey(
      ValueKey('note-drag-handle-${editableNote.note.id}'),
    );
    final initialPosition = tester.getTopLeft(noteFinder);

    await tester.tap(dragHandle);
    await tester.pumpAndSettle();
    expect(find.text('SELECTED'), findsOneWidget);

    await tester.drag(dragHandle, const Offset(60, 40));
    await tester.pumpAndSettle();

    final movedPosition = tester.getTopLeft(noteFinder);
    expect(movedPosition.dx, closeTo(initialPosition.dx + 60, 1));
    expect(movedPosition.dy, closeTo(initialPosition.dy + 40, 1));
    expect(find.text('SELECTED'), findsOneWidget);
  });

  testWidgets('keeps a note dragged past the top edge inside the board', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    final initialNote = tester.widget<EditableNote>(find.byType(EditableNote));
    final dragHandle = find.byKey(
      ValueKey('note-drag-handle-${initialNote.note.id}'),
    );

    final gesture = await tester.startGesture(tester.getCenter(dragHandle));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -200));
    await gesture.up();
    await tester.pumpAndSettle();

    final movedNote = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(movedNote.note.x, initialNote.note.x);
    expect(movedNote.note.y, 0);
    expect(find.byKey(const ValueKey('recover-notes-button')), findsNothing);
  });

  testWidgets('resizes a note as one undoable and redoable action', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    final dragHandle = find.byKey(ValueKey('note-drag-handle-${note.note.id}'));
    await tester.tap(dragHandle);
    await tester.pumpAndSettle();

    final resizeHandle = find.byKey(
      ValueKey('note-resize-handle-${note.note.id}'),
    );
    await tester.drag(resizeHandle, const Offset(80, 50));
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.note.width, closeTo(340, 1));
    expect(note.note.height, closeTo(220, 1));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.note.width, 260);
    expect(note.note.height, 170);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.note.width, closeTo(340, 1));
    expect(note.note.height, closeTo(220, 1));
  });

  testWidgets('directly resizes an unselected Note from its persistent rail', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    final noteId = note.note.id;
    expect(note.isSelected, isFalse);
    final resizeRail = find.byKey(ValueKey('note-resize-rail-$noteId'));
    expect(resizeRail, findsOneWidget);

    await tester.drag(resizeRail, const Offset(70, 40));
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.isSelected, isTrue);
    expect(note.note.width, closeTo(330, 1));
    expect(note.note.height, closeTo(210, 1));
  });

  testWidgets('resize rail click selects without changing the Board', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    final original = note.note;
    final resizeRail = find.byKey(ValueKey('note-resize-rail-${original.id}'));
    final saveCallsBefore = store.saveCalls;

    await tester.tap(resizeRail);
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.isSelected, isTrue);
    expect(note.note.width, original.width);
    expect(note.note.height, original.height);
    expect(note.note.modifiedAt, original.modifiedAt);
    expect(store.saveCalls, saveCallsBefore);
  });

  testWidgets('resize rail secondary click opens Note actions without resize', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    final original = tester
        .widget<EditableNote>(find.byType(EditableNote))
        .note;
    final saveCallsBefore = store.saveCalls;

    await _secondaryTap(
      tester,
      find.byKey(ValueKey('note-resize-rail-${original.id}')),
    );

    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.isSelected, isTrue);
    expect(note.note.width, original.width);
    expect(note.note.height, original.height);
    expect(note.note.modifiedAt, original.modifiedAt);
    expect(
      find.byKey(const ValueKey('context-copy-menu-item')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-delete-menu-item')),
      findsOneWidget,
    );
    expect(store.saveCalls, saveCallsBefore);
  });

  testWidgets('resize rail advertises its pointer target and tooltip', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    final region = find.byKey(
      ValueKey('note-resize-rail-region-${note.note.id}'),
    );
    expect(
      tester.widget<MouseRegion>(region).cursor,
      SystemMouseCursors.resizeUpLeftDownRight,
    );

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 71,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(region));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Resize note'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('resize rail ends Note editing and starts resize directly', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    final noteId = note.note.id;
    final field = find.byKey(ValueKey('note-text-field-$noteId'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
      isTrue,
    );

    await tester.drag(
      find.byKey(ValueKey('note-resize-rail-$noteId')),
      const Offset(50, 30),
    );
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.isEditing, isFalse);
    expect(note.isSelected, isTrue);
    expect(note.note.width, closeTo(310, 1));
    expect(note.note.height, closeTo(200, 1));
  });

  testWidgets('enforces minimum dimensions while resizing', (tester) async {
    await _pumpTestApp(tester);

    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    await tester.tap(find.byKey(ValueKey('note-drag-handle-${note.note.id}')));
    await tester.pumpAndSettle();
    final resizeHandle = find.byKey(
      ValueKey('note-resize-handle-${note.note.id}'),
    );
    final gesture = await tester.startGesture(tester.getCenter(resizeHandle));
    await gesture.moveBy(const Offset(-40, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(-40, -20));
    await gesture.up();
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.note.width, 180);
    expect(note.note.height, 120);
  });

  testWidgets('keeps a resized note inside the board', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 9, 12);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'resize-boundary-board',
        name: 'Resize boundary test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 5500,
        viewportY: 4000,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'edge-note',
            x: 5700,
            y: 4200,
            width: 260,
            height: 170,
            text: 'Stay inside',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    await tester.tap(find.byKey(ValueKey('note-drag-handle-${note.note.id}')));
    await tester.pumpAndSettle();
    final resizeHandle = find.byKey(
      ValueKey('note-resize-handle-${note.note.id}'),
    );
    final gesture = await tester.startGesture(tester.getCenter(resizeHandle));
    await gesture.moveBy(const Offset(20, 50));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 50));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await gesture.up();
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote));
    expect(note.note.x + note.note.width, 6000);
    expect(note.note.y + note.note.height, 4500);
    expect(find.byKey(const ValueKey('recover-notes-button')), findsNothing);
  });

  testWidgets('saves and reopens resized note dimensions', (tester) async {
    final store = await _pumpTestApp(tester);

    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    final noteId = note.note.id;
    await tester.tap(find.byKey(ValueKey('note-drag-handle-$noteId')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(ValueKey('note-resize-handle-$noteId')),
      const Offset(70, 40),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    expect(store.board!.notes.single.width, closeTo(330, 1));
    expect(store.board!.notes.single.height, closeTo(210, 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);

    note = tester.widget<EditableNote>(find.byKey(ValueKey(noteId)));
    expect(note.note.width, closeTo(330, 1));
    expect(note.note.height, closeTo(210, 1));
  });

  testWidgets('changes, undoes, redoes, and reopens a note colour', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);

    var note = tester.widget<EditableNote>(find.byType(EditableNote));
    final noteId = note.note.id;
    await tester.tap(find.byKey(ValueKey('note-drag-handle-$noteId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-color-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-color-blue')));
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byKey(ValueKey(noteId)));
    expect(note.note.color, NoteColor.blue);
    final decoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(ValueKey('note-container-$noteId')),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, const Color(0xFFCFE8FF));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    note = tester.widget<EditableNote>(find.byKey(ValueKey(noteId)));
    expect(note.note.color, NoteColor.yellow);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    note = tester.widget<EditableNote>(find.byKey(ValueKey(noteId)));
    expect(note.note.color, NoteColor.blue);

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);

    note = tester.widget<EditableNote>(find.byKey(ValueKey(noteId)));
    expect(note.note.color, NoteColor.blue);
  });

  testWidgets(
    'sticky Note colour drives both creation paths across Undo and Paste',
    (tester) async {
      await _pumpTestApp(tester);
      final original = tester.widget<EditableNote>(find.byType(EditableNote));
      await tester.tap(
        find.byKey(ValueKey('note-drag-handle-${original.note.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-blue')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableNote>(find.byKey(ValueKey(original.note.id)))
            .note
            .color,
        NoteColor.yellow,
      );

      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
      await tester.pumpAndSettle();
      final afterPaste = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      expect(afterPaste, hasLength(2));
      expect(afterPaste.last.color, NoteColor.yellow);

      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      await tester.tapAt(
        surfaceRect.topLeft + const Offset(40, 80),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-add-note-menu-item')),
      );
      await tester.pumpAndSettle();
      var notes = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      final contextualNote = notes.last;
      expect(contextualNote.color, NoteColor.blue);

      await tester.tap(
        find.byKey(ValueKey('note-drag-handle-${contextualNote.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      notes = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      expect(notes.last.color, NoteColor.blue);
    },
  );

  testWidgets(
    'same-colour choice sticks without history and resets on reopen',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 2, 12);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'sticky-colour-board',
          name: 'Sticky colour board',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'blue-note',
              x: 300,
              y: 200,
              width: 260,
              height: 170,
              text: 'Blue thought',
              createdAt: timestamp,
              modifiedAt: timestamp,
              color: NoteColor.blue,
            ),
          ],
        ),
      );
      await _pumpTestApp(tester, store: store);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-blue-note')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-blue')));
      await tester.pumpAndSettle();

      expect(store.saveCalls, 0);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      var notes = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      expect(notes.last.color, NoteColor.blue);

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      notes = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      expect(notes.last.color, NoteColor.yellow);
    },
  );

  testWidgets('copies and pastes a note with new identity and properties', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 9, 13);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'copy-paste-board',
        name: 'Copy and paste test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'source-note',
            x: 300,
            y: 200,
            width: 310,
            height: 220,
            text: 'Preserve these properties',
            title: 'Source title',
            emphasis: const [NoteEmphasisRange(start: 0, end: 8, bold: true)],
            links: const [
              NoteTextLinkRange(
                start: 9,
                end: 14,
                destination: 'https://example.com/source',
              ),
            ],
            createdAt: timestamp,
            modifiedAt: timestamp,
            color: NoteColor.green,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-source-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    var notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    expect(notes, hasLength(2));
    final source = notes.firstWhere((note) => note.id == 'source-note');
    final pasted = notes.firstWhere((note) => note.id != 'source-note');
    expect(pasted.id, isNot(source.id));
    expect(pasted.text, source.text);
    expect(pasted.title, source.title);
    expect(pasted.emphasis, source.emphasis);
    expect(pasted.links, source.links);
    expect(pasted.width, source.width);
    expect(pasted.height, source.height);
    expect(pasted.color, source.color);
    expect(pasted.x, source.x + 32);
    expect(pasted.y, source.y + 32);
    expect(pasted.createdAt, isNot(source.createdAt));
    expect(find.text('SELECTED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    expect(notes, hasLength(2));
    expect(notes.any((note) => note.id == pasted.id), isTrue);

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);

    notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    expect(notes, hasLength(2));
    expect(notes.any((note) => note.id == pasted.id), isTrue);
  });

  testWidgets(
    'right-clicking an unselected note targets only it and opens actions',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 19, 21);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          includeConnector: false,
          includeThirdNote: true,
        ),
      );
      await _pumpTestApp(tester, store: store);

      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});

      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-c')),
      );

      expect(_selectedNoteIds(tester), {'note-c'});
      expect(_selectedImageIds(tester), isEmpty);
      expect(
        find.byKey(const ValueKey('context-copy-menu-item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('context-paste-menu-item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('context-delete-menu-item')),
        findsOneWidget,
      );
      expect(find.text('Copy selected object'), findsOneWidget);
      expect(find.text('Copy selected objects'), findsNothing);
      expect(store.saveCalls, 0);
    },
  );

  testWidgets('adds edits removes and restores an exact Note title', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 4, 14);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, includeConnector: false),
    );
    await _pumpTestApp(tester, store: store);
    const noteId = 'note-a';
    final handle = find.byKey(const ValueKey('note-drag-handle-note-a'));

    await _secondaryTap(tester, handle);
    expect(find.text('Add title...'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('context-note-title-menu-item')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      '  FretFlip release  ',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-note-title-button')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey(noteId)))
          .note
          .title,
      'FretFlip release',
    );
    expect(find.byKey(const ValueKey('note-title-note-a')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey(noteId)))
          .note
          .title,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey(noteId)))
          .note
          .title,
      'FretFlip release',
    );

    await _secondaryTap(tester, handle);
    expect(find.text('Edit title...'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('context-note-title-menu-item')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note-title-field')))
          .controller!
          .text,
      'FretFlip release',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-note-title-button')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey(noteId)))
          .note
          .title,
      isNull,
    );
    expect(find.text('DRAG TO MOVE'), findsWidgets);
  });

  testWidgets('double-clicking a Note header edits that exact title', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _selectionSetBoard(grouped: true));
    await _pumpTestApp(tester, store: store);
    final handle = find.byKey(const ValueKey('note-drag-handle-group-a'));

    await tester.tap(handle);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(handle);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-title-field')), findsOneWidget);
    expect(_selectedNoteIds(tester), {'group-a', 'group-b'});
    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      'Parser plan',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-note-title-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    final notesById = {for (final note in store.board!.notes) note.id: note};
    expect(notesById['group-a']!.title, 'Parser plan');
    expect(notesById['group-b']!.title, isNull);
    expect(store.board!.groups.single.memberIds, ['group-a', 'group-b']);
  });

  testWidgets(
    'Open link targets the exact clicked Note without mutating the board',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 2, 8);
      final board = _connectedBoard(
        timestamp: timestamp,
        includeConnector: false,
        includeThirdNote: true,
        noteAText: 'Provider https://example.com/catalogue.',
        noteBText: 'Other https://provider.test/path',
      );
      final store = _MemoryBoardStore(board: board);
      final launchedUrls = <Uri>[];
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          websiteIconBuilder: (url) =>
              Text(url.host, key: const ValueKey('injected-website-icon')),
          externalUrlLauncher: (url) async {
            launchedUrls.add(url);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      final before = store.board!.toJson();
      final noteA = find.byKey(const ValueKey('note-drag-handle-note-a'));
      final noteB = find.byKey(const ValueKey('note-drag-handle-note-b'));

      expect(
        find.byKey(const ValueKey('note-website-marker-note-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-website-body-note-a')),
        findsOneWidget,
      );
      expect(find.text('WEBSITE · example.com'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('note-website-marker-note-c')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-website-body-note-c')),
        findsNothing,
      );

      await tester.tap(noteA);
      await _controlTap(tester, noteB);
      await _secondaryTap(tester, noteA);

      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      final paste = find.byKey(const ValueKey('context-paste-menu-item'));
      final openLink = find.byKey(
        const ValueKey('context-open-link-menu-item'),
      );
      final colour = find.byKey(const ValueKey('context-note-color-menu-item'));
      expect(openLink, findsOneWidget);
      expect(
        tester.getTopLeft(paste).dy,
        lessThan(tester.getTopLeft(openLink).dy),
      );
      expect(
        tester.getTopLeft(openLink).dy,
        lessThan(tester.getTopLeft(colour).dy),
      );

      await tester.tap(openLink);
      await tester.pumpAndSettle();

      expect(launchedUrls, [Uri.parse('https://example.com/catalogue')]);
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      expect(store.board!.toJson(), before);
      expect(store.saveCalls, 0);
    },
  );

  testWidgets('Open link is omitted for an ambiguous Note URL', (tester) async {
    final timestamp = DateTime.utc(2026, 9, 2, 8, 5);
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: timestamp,
        includeConnector: false,
        noteAText: 'https://one.test https://two.test',
      ),
    );
    var launchCalls = 0;
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        websiteIconBuilder: (url) => const Icon(Icons.public),
        externalUrlLauncher: (url) async {
          launchCalls += 1;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-website-marker-note-a')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-website-body-note-a')),
      findsNothing,
    );

    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-a')),
    );

    expect(
      find.byKey(const ValueKey('context-open-link-menu-item')),
      findsNothing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(launchCalls, 0);
    expect(store.saveCalls, 0);
  });

  testWidgets('Open link reports launcher failure without board mutation', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 2, 8, 10);
    final board = _connectedBoard(
      timestamp: timestamp,
      includeConnector: false,
      noteAText: 'https://example.com',
    );
    final store = _MemoryBoardStore(board: board);
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        websiteIconBuilder: (url) => const Icon(Icons.public),
        externalUrlLauncher: (url) async => false,
      ),
    );
    await tester.pumpAndSettle();
    final before = store.board!.toJson();

    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-a')),
    );
    await tester.tap(find.byKey(const ValueKey('context-open-link-menu-item')));
    await tester.pumpAndSettle();

    expect(find.text('Could not open link'), findsOneWidget);
    expect(store.board!.toJson(), before);
    expect(store.saveCalls, 0);
  });

  testWidgets('Open link eligibility follows edited Note text after reopen', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 2, 8, 15);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, includeConnector: false),
    );
    final launchedUrls = <Uri>[];
    Future<bool> launcher(Uri url) async {
      launchedUrls.add(url);
      return true;
    }

    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        websiteIconBuilder: (url) => const Icon(Icons.public),
        externalUrlLauncher: launcher,
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('note-text-field-note-a'));
    await tester.tap(field);
    await tester.enterText(field, 'Source https://example.com/reopened');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('note-website-body-note-a')),
      findsOneWidget,
    );
    expect(find.text('WEBSITE · example.com'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    expect(store.board!.notes.first.text, contains('https://example.com'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        websiteIconBuilder: (url) => const Icon(Icons.public),
        externalUrlLauncher: launcher,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-website-body-note-a')),
      findsOneWidget,
    );

    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-a')),
    );
    await tester.tap(find.byKey(const ValueKey('context-open-link-menu-item')));
    await tester.pumpAndSettle();

    expect(launchedUrls, [Uri.parse('https://example.com/reopened')]);
  });

  testWidgets('multiple Note links open an ordered exact-target chooser', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 3, 9);
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: timestamp,
        includeConnector: false,
        noteAText:
            'First https://first.example/path then https://second.example/info',
      ),
    );
    final launchedUrls = <Uri>[];
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        externalUrlLauncher: (url) async {
          launchedUrls.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-a')),
    );
    expect(
      find.byKey(const ValueKey('context-open-links-menu-item')),
      findsOneWidget,
    );
    expect(find.text('Open link'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('context-open-links-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open a link'), findsOneWidget);
    expect(find.text('first.example'), findsOneWidget);
    expect(find.text('https://first.example/path'), findsOneWidget);
    expect(find.text('second.example'), findsOneWidget);
    expect(find.text('https://second.example/info'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-link-choice-1')));
    await tester.pumpAndSettle();

    expect(launchedUrls, [Uri.parse('https://second.example/info')]);
    expect(_selectedNoteIds(tester), {'note-a'});
    expect(store.saveCalls, 0);
  });

  testWidgets('multi-link Note treatment follows live distinct URL count', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 3, 11);
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: timestamp,
        includeConnector: false,
        noteAText: 'https://first.example/a https://second.example/b',
      ),
    );
    await _pumpTestApp(tester, store: store);

    expect(
      find.byKey(const ValueKey('note-multi-website-marker-note-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-multi-website-body-note-a')),
      findsOneWidget,
    );
    expect(find.text('WEBSITES · 2 LINKS'), findsOneWidget);

    final field = find.byKey(const ValueKey('note-text-field-note-a'));
    await tester.tap(field);
    await tester.enterText(field, 'https://only.example/a');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('note-multi-website-body-note-a')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-website-body-note-a')),
      findsOneWidget,
    );

    await tester.enterText(field, 'No website now');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('note-website-body-note-a')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-multi-website-body-note-a')),
      findsNothing,
    );
  });

  testWidgets('multiple-link chooser deduplicates cancels and reports failure', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 3, 9, 5);
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: timestamp,
        includeConnector: false,
        noteAText:
            'https://same.example/a https://same.example/a https://other.example/b',
      ),
    );
    var launchCalls = 0;
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        externalUrlLauncher: (url) async {
          launchCalls++;
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();
    final note = find.byKey(const ValueKey('note-drag-handle-note-a'));

    await _secondaryTap(tester, note);
    await tester.tap(
      find.byKey(const ValueKey('context-open-links-menu-item')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-link-choice-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-link-choice-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-link-choice-2')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(launchCalls, 0);

    await _secondaryTap(tester, note);
    await tester.tap(
      find.byKey(const ValueKey('context-open-links-menu-item')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-link-choice-0')));
    await tester.pumpAndSettle();
    expect(launchCalls, 1);
    expect(find.text('Could not open link'), findsOneWidget);
    expect(store.saveCalls, 0);
  });

  testWidgets(
    'right-clicking a selected image preserves a mixed selection and copies it',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 19, 21, 5);
      final store = await _pumpMixedBoard(tester, timestamp: timestamp);
      final noteHandle = find.byKey(
        const ValueKey('note-drag-handle-mixed-note'),
      );
      final imageSurface = find.byKey(
        const ValueKey('image-drag-surface-board-image'),
      );

      await tester.tap(noteHandle);
      await _controlTap(tester, imageSurface);
      await _secondaryTap(tester, imageSurface);

      expect(_selectedNoteIds(tester), {'mixed-note'});
      expect(_selectedImageIds(tester), {'board-image'});
      expect(find.text('Copy selected objects'), findsOneWidget);
      expect(find.text('Copy selected object'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('context-copy-menu-item')));
      await tester.pumpAndSettle();

      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_selectedNoteIds(tester), {'mixed-note'});
      expect(_selectedImageIds(tester), {'board-image'});
      await tester.tap(find.byKey(const ValueKey('context-paste-menu-item')));
      await tester.pumpAndSettle();

      expect(find.byType(EditableNote), findsNWidgets(2));
      expect(find.byType(InteractiveBoardImage), findsNWidgets(2));
      expect(_selectedNoteIds(tester), hasLength(1));
      expect(_selectedImageIds(tester), hasLength(1));
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsOneWidget);
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
      expect(store.board!.notes, hasLength(1));
      expect(store.board!.images, hasLength(1));
    },
  );

  testWidgets(
    'group command creates a persistent selection set from the current selection',
    (tester) async {
      final store = _MemoryBoardStore(board: _selectionSetBoard());
      await _pumpTestApp(tester, store: store);
      final noteA = find.byKey(const ValueKey('note-drag-handle-group-a'));
      final noteB = find.byKey(const ValueKey('note-drag-handle-group-b'));

      await tester.tap(noteA);
      await _controlTap(tester, noteB);
      await _secondaryTap(tester, noteB);
      expect(
        find.byKey(const ValueKey('context-group-menu-item')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('context-group-menu-item')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('groups-side-panel')), findsOneWidget);
      expect(find.text('Group 1'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('selected-group-outline')),
        findsOneWidget,
      );
      expect(store.board!.groups, hasLength(1));
      expect(store.board!.groups.single.memberIds.toSet(), {
        'group-a',
        'group-b',
      });
    },
  );

  testWidgets(
    'group visibility, reselection, and ungroup preserve every member',
    (tester) async {
      final store = _MemoryBoardStore(board: _selectionSetBoard(grouped: true));
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('groups-panel-button')));
      await tester.pumpAndSettle();

      final groupId = store.board!.groups.single.id;
      await tester.tap(find.byKey(ValueKey('group-visibility-$groupId')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsOneWidget);
      expect(store.board!.groups.single.isVisible, isFalse);

      await tester.tap(find.byKey(ValueKey('group-visibility-$groupId')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(3));
      expect(_selectedNoteIds(tester), {'group-a', 'group-b'});

      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-group-a')),
      );
      await tester.tap(find.byKey(const ValueKey('context-ungroup-menu-item')));
      await tester.pumpAndSettle();
      expect(store.board!.groups, isEmpty);
      expect(find.byType(EditableNote), findsNWidgets(3));
      expect(_selectedNoteIds(tester), {'group-a', 'group-b'});
    },
  );

  testWidgets('adds selected loose items to one group and removes one member', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _selectionSetBoard(grouped: true));
    await _pumpTestApp(tester, store: store);
    final member = find.byKey(const ValueKey('note-drag-handle-group-a'));
    final outside = find.byKey(
      const ValueKey('note-drag-handle-outside-group'),
    );

    await tester.tap(member);
    await _controlTap(tester, outside);
    await _secondaryTap(tester, outside);
    expect(
      find.byKey(const ValueKey('context-add-to-group-menu-item')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('context-add-to-group-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(store.board!.groups.single.memberIds, [
      'group-a',
      'group-b',
      'outside-group',
    ]);
    expect(_selectedNoteIds(tester), {'group-a', 'group-b', 'outside-group'});

    await _secondaryTap(tester, member);
    await tester.tap(
      find.byKey(const ValueKey('context-remove-from-group-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(store.board!.groups.single.memberIds, ['group-b', 'outside-group']);
    expect(_selectedNoteIds(tester), {'group-a'});
    expect(store.board!.notes, hasLength(3));
  });

  testWidgets('removing from a two-item group dissolves it safely', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _selectionSetBoard(grouped: true));
    await _pumpTestApp(tester, store: store);
    final member = find.byKey(const ValueKey('note-drag-handle-group-a'));

    await _secondaryTap(tester, member);
    await tester.tap(
      find.byKey(const ValueKey('context-remove-from-group-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(store.board!.groups, isEmpty);
    expect(store.board!.notes, hasLength(3));
    expect(_selectedNoteIds(tester), {'group-a'});
  });

  testWidgets('renames a group and restores its automatic label', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _selectionSetBoard(grouped: true));
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('groups-panel-button')));
    await tester.pumpAndSettle();
    final groupId = store.board!.groups.single.id;
    final row = find.byKey(ValueKey('group-row-$groupId'));

    await tester.tap(
      find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('group-name-field')),
      '  Quest outline  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Quest outline'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(store.board!.groups.single.name, 'Quest outline');

    await tester.tap(
      find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('group-use-automatic-name-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Group 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(store.board!.groups.single.name, isNull);
  });

  testWidgets(
    'copying one selected group member pastes a fresh complete group',
    (tester) async {
      final store = _MemoryBoardStore(board: _selectionSetBoard(grouped: true));
      await _pumpTestApp(tester, store: store);

      await tester.tap(find.byKey(const ValueKey('note-drag-handle-group-a')));
      await tester.pumpAndSettle();
      expect(_selectedNoteIds(tester), {'group-a', 'group-b'});
      await _sendShortcut(tester, LogicalKeyboardKey.keyC);
      await _sendShortcut(tester, LogicalKeyboardKey.keyV);

      expect(find.byType(EditableNote), findsNWidgets(5));
      expect(store.board!.groups, hasLength(2));
      final original = store.board!.groups.first;
      final pasted = store.board!.groups.last;
      expect(pasted.id, isNot(original.id));
      expect(pasted.memberIds, hasLength(2));
      expect(
        pasted.memberIds.toSet().intersection(original.memberIds.toSet()),
        isEmpty,
      );
      expect(_selectedNoteIds(tester), pasted.memberIds.toSet());
    },
  );

  testWidgets('dragging a persistent group member moves only that member', (
    tester,
  ) async {
    final original = _selectionSetBoard(grouped: true);
    final store = _MemoryBoardStore(board: original);
    await _pumpTestApp(tester, store: store);

    final groupMember = find.byKey(const ValueKey('note-drag-handle-group-a'));
    final independent = find.byKey(
      const ValueKey('note-drag-handle-outside-group'),
    );
    await tester.tap(groupMember);
    await tester.pumpAndSettle();
    await _controlTap(tester, independent);
    expect(_selectedNoteIds(tester), {'group-a', 'group-b', 'outside-group'});

    final gesture = await tester.startGesture(tester.getCenter(groupMember));
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 10));
    await gesture.up();
    await tester.pumpAndSettle();

    final afterById = {
      for (final widget in tester.widgetList<EditableNote>(
        find.byType(EditableNote),
      ))
        widget.note.id: widget.note,
    };
    final beforeById = {for (final note in original.notes) note.id: note};
    expect(
      afterById['group-a']!.x - beforeById['group-a']!.x,
      closeTo(80, 0.01),
    );
    expect(
      afterById['group-a']!.y - beforeById['group-a']!.y,
      closeTo(40, 0.01),
    );
    for (final id in ['group-b', 'outside-group']) {
      expect(
        (afterById[id]!.x, afterById[id]!.y),
        (beforeById[id]!.x, beforeById[id]!.y),
      );
    }
    expect(_selectedNoteIds(tester), {'group-a', 'group-b', 'outside-group'});
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      store.board!.notes.map((note) => (note.x, note.y)),
      original.notes.map((note) => (note.x, note.y)),
    );
  });

  testWidgets('selected group move handle moves the complete group', (
    tester,
  ) async {
    final original = _selectionSetBoard(grouped: true);
    final store = _MemoryBoardStore(board: original);
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-group-a')));
    await tester.pumpAndSettle();
    final handle = find.byKey(const ValueKey('selected-group-move-handle'));
    expect(handle, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-marquee')), findsNothing);
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 10));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    final moved = store.board!.notes.where(
      (note) => {'group-a', 'group-b'}.contains(note.id),
    );
    for (final after in moved) {
      final before = original.notes.singleWhere((note) => note.id == after.id);
      expect(after.x - before.x, closeTo(80, 0.01));
      expect(after.y - before.y, closeTo(40, 0.01));
    }
    final outsideBefore = original.notes.singleWhere(
      (note) => note.id == 'outside-group',
    );
    final outsideAfter = store.board!.notes.singleWhere(
      (note) => note.id == 'outside-group',
    );
    expect(
      (outsideAfter.x, outsideAfter.y),
      (outsideBefore.x, outsideBefore.y),
    );

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      store.board!.notes.map((note) => (note.x, note.y)),
      original.notes.map((note) => (note.x, note.y)),
    );
  });

  testWidgets(
    'a disclosed Library target shows and selects its hidden complete group',
    (tester) async {
      final board = _selectionSetBoard(grouped: true);
      final hiddenBoard = BoardDocument(
        id: board.id,
        name: board.name,
        createdAt: board.createdAt,
        modifiedAt: board.modifiedAt,
        viewportX: board.viewportX,
        viewportY: board.viewportY,
        viewportZoom: board.viewportZoom,
        notes: board.notes,
        groups: [
          board.groups.single.copyWith(
            isVisible: false,
            modifiedAt: board.modifiedAt,
          ),
        ],
      );
      final store = _MemoryBoardStore(board: hiddenBoard);
      await tester.pumpWidget(
        MaterialApp(
          home: CanvasExperiment(
            boardStore: store,
            imageAssetStore: _TestImageAssetStore(resolveError: true),
            imagePicker: () async => null,
            initialTarget: const CanvasInitialTarget.note('group-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditableNote), findsNWidgets(3));
      expect(_selectedNoteIds(tester), {'group-a', 'group-b'});
      expect(store.board!.groups.single.isVisible, isTrue);
    },
  );

  testWidgets(
    'context menu exposes selection-aware colour and relationship commands',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 21, 10);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          includeConnector: false,
          includeThirdNote: true,
        ),
      );
      await _pumpTestApp(tester, store: store);
      final noteA = find.byKey(const ValueKey('note-drag-handle-note-a'));
      final noteB = find.byKey(const ValueKey('note-drag-handle-note-b'));
      final noteC = find.byKey(const ValueKey('note-drag-handle-note-c'));

      await _secondaryTap(tester, noteA);
      expect(
        find.byKey(const ValueKey('context-note-color-menu-item')),
        findsOneWidget,
      );
      expect(find.text('Change note colour'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('context-connection-menu-item')),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _controlTap(tester, noteB);
      await _secondaryTap(tester, noteB);
      expect(find.text("Change selected notes' colour"), findsOneWidget);
      expect(
        find.byKey(const ValueKey('context-connection-menu-item')),
        findsOneWidget,
      );
      expect(find.text('Connect selected objects'), findsNWidgets(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _controlTap(tester, noteC);
      await _secondaryTap(tester, noteC);
      expect(find.text("Change selected notes' colour"), findsOneWidget);
      expect(
        find.byKey(const ValueKey('context-connection-menu-item')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'context command selects a complete mixed connected component without mutation',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 2, 14);
      final store = _MemoryBoardStore(board: _connectedClusterBoard(timestamp));
      await _pumpTestApp(
        tester,
        store: store,
        imageViewBuilder: (image) => SizedBox(
          key: ValueKey('test-image-${image.id}'),
          width: image.width,
          height: image.height,
        ),
      );

      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-cluster-b')),
      );
      expect(
        find.byKey(const ValueKey('context-select-connected-menu-item')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('context-select-connected-menu-item')),
      );
      await tester.pumpAndSettle();

      expect(_selectedNoteIds(tester), {'cluster-a', 'cluster-b', 'cluster-c'});
      expect(_selectedImageIds(tester), {'cluster-image'});
      expect(store.saveCalls, 0);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'connected selection uses the exact context seed and omits disconnected objects',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 2, 14, 5);
      final store = _MemoryBoardStore(board: _connectedClusterBoard(timestamp));
      await _pumpTestApp(
        tester,
        store: store,
        imageViewBuilder: (image) => SizedBox(
          key: ValueKey('test-image-${image.id}'),
          width: image.width,
          height: image.height,
        ),
      );
      final connected = find.byKey(
        const ValueKey('note-drag-handle-cluster-b'),
      );
      final disconnected = find.byKey(
        const ValueKey('note-drag-handle-cluster-d'),
      );

      await tester.tap(disconnected);
      await _controlTap(tester, connected);
      expect(_selectedNoteIds(tester), {'cluster-b', 'cluster-d'});
      await _secondaryTap(tester, connected);
      await tester.tap(
        find.byKey(const ValueKey('context-select-connected-menu-item')),
      );
      await tester.pumpAndSettle();

      expect(_selectedNoteIds(tester), {'cluster-a', 'cluster-b', 'cluster-c'});
      expect(_selectedImageIds(tester), {'cluster-image'});

      await _secondaryTap(tester, disconnected);
      expect(
        find.byKey(const ValueKey('context-select-connected-menu-item')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'contextual colour changes only selected notes through undo redo and reopen',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 21, 10, 5);
      final store = await _pumpMixedBoard(tester, timestamp: timestamp);
      final noteHandle = find.byKey(
        const ValueKey('note-drag-handle-mixed-note'),
      );
      final imageSurface = find.byKey(
        const ValueKey('image-drag-surface-board-image'),
      );

      await tester.tap(noteHandle);
      await _controlTap(tester, imageSurface);
      await _secondaryTap(tester, imageSurface);
      expect(find.text("Change selected note's colour"), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('context-note-color-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('context-note-color-blue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('context-copy-menu-item')),
        findsNothing,
        reason: 'The object menu must close before the colour chooser opens.',
      );
      await tester.tap(find.byKey(const ValueKey('context-note-color-blue')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableNote>(find.byType(EditableNote)).note.color,
        NoteColor.blue,
      );
      expect(_selectedImageIds(tester), {'board-image'});
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableNote>(find.byType(EditableNote)).note.color,
        NoteColor.yellow,
      );
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableNote>(find.byType(EditableNote)).note.color,
        NoteColor.blue,
      );

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(resolveError: true),
          imagePicker: () async => null,
          imageViewBuilder: (current) => SizedBox(
            key: ValueKey('test-image-${current.id}'),
            width: current.width,
            height: current.height,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.board!.notes.single.color, NoteColor.blue);
      expect(store.board!.images.single.id, 'board-image');
    },
  );

  testWidgets('image-only context menu omits note colour', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 21, 10, 10);
    await _pumpImageBoard(tester, image: _testBoardImage(timestamp: timestamp));

    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );

    expect(
      find.byKey(const ValueKey('context-note-color-menu-item')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('context-connection-menu-item')),
      findsNothing,
    );
  });

  testWidgets('adds, removes, undoes, and reopens an exact Image caption', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 6, 10);
    final store = await _pumpImageBoard(
      tester,
      image: _testBoardImage(timestamp: timestamp),
    );
    final surface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );

    await _secondaryTap(tester, surface);
    expect(find.text('Add caption...'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('context-image-caption-menu-item')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('image-caption-field')),
      '  Enemy silhouette reference  ',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-image-caption-button')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .image
          .caption,
      'Enemy silhouette reference',
    );
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .image
          .caption,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        imageAssetStore: _TestImageAssetStore(resolveError: true),
        imagePicker: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    expect(store.board!.images.single.caption, 'Enemy silhouette reference');
    expect(
      find.byKey(const ValueKey('image-caption-band-board-image')),
      findsOneWidget,
    );
    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    expect(find.text('Edit caption...'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('context-remove-image-caption-menu-item')),
    );
    await tester.pumpAndSettle();
    expect(store.board!.images.single.caption, isNull);
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(store.board!.images.single.caption, 'Enemy silhouette reference');
  });

  testWidgets(
    'contextual relationship connects and removes a note pair through history',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 21, 10, 15);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp, includeConnector: false),
      );
      await _pumpTestApp(tester, store: store);
      final noteA = find.byKey(const ValueKey('note-drag-handle-note-a'));
      final noteB = find.byKey(const ValueKey('note-drag-handle-note-b'));

      await tester.tap(noteA);
      await _controlTap(tester, noteB);
      await _secondaryTap(tester, noteB);
      await tester.tap(
        find.byKey(const ValueKey('context-connection-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTestApp(tester, store: store);
      expect(store.board!.connectors, hasLength(1));

      await tester.tap(noteA);
      await _controlTap(tester, noteB);

      await _secondaryTap(tester, noteB);
      expect(find.text('Remove connection'), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('context-connection-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsNothing);
    },
  );

  testWidgets(
    'contextual relationship supports note-image and image-image pairs',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 21, 10, 20);
      await _pumpMixedBoard(tester, timestamp: timestamp);
      final noteHandle = find.byKey(
        const ValueKey('note-drag-handle-mixed-note'),
      );
      final mixedImage = find.byKey(
        const ValueKey('image-drag-surface-board-image'),
      );

      await tester.tap(noteHandle);
      await _controlTap(tester, mixedImage);
      await _secondaryTap(tester, mixedImage);
      await tester.tap(
        find.byKey(const ValueKey('context-connection-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
      await _secondaryTap(tester, mixedImage);
      expect(find.text('Remove connection'), findsNWidgets(2));

      BoardImage image(String id, double x) => BoardImage(
        id: id,
        x: x,
        y: 300,
        width: 320,
        height: 180,
        assetPath: 'assets/$id.png',
        originalFileName: '$id.png',
        pixelWidth: 1600,
        pixelHeight: 900,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final imageStore = _MemoryBoardStore(
        board: BoardDocument(
          id: 'context-image-pair-board',
          name: 'Context image pair',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 0.75,
          notes: const [],
          images: [
            image('context-image-a', 300),
            image('context-image-b', 900),
          ],
        ),
      );
      await tester.pumpWidget(
        MainApp(
          boardStore: imageStore,
          imageAssetStore: _TestImageAssetStore(resolveError: true),
          imagePicker: () async => null,
          imageViewBuilder: (current) =>
              SizedBox(width: current.width, height: current.height),
        ),
      );
      await tester.pumpAndSettle();
      final imageA = find.byKey(
        const ValueKey('image-drag-surface-context-image-a'),
      );
      final imageB = find.byKey(
        const ValueKey('image-drag-surface-context-image-b'),
      );

      await tester.tap(imageA);
      await _controlTap(tester, imageB);
      await _secondaryTap(tester, imageB);
      expect(
        find.byKey(const ValueKey('context-note-color-menu-item')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('context-connection-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
      await _secondaryTap(tester, imageB);
      expect(find.text('Remove connection'), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('context-connection-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsNothing);
    },
  );

  testWidgets(
    'right-clicking an unselected image targets and deletes it with its connector',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 19, 21, 7);
      final image = _testBoardImage(timestamp: timestamp, x: 700, y: 400);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          images: [image],
          connectorObjectBId: image.id,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(resolveError: true),
          imagePicker: () async => null,
          imageViewBuilder: (current) => SizedBox(
            key: ValueKey('test-image-${current.id}'),
            width: current.width,
            height: current.height,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-b')));

      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('image-drag-surface-board-image')),
      );
      expect(_selectedNoteIds(tester), isEmpty);
      expect(_selectedImageIds(tester), {'board-image'});
      await tester.tap(find.byKey(const ValueKey('context-delete-menu-item')));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveBoardImage), findsNothing);
      expect(find.byKey(const ValueKey('connector-layer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveBoardImage), findsNothing);
    },
  );

  testWidgets('right-clicking a non-editing note body opens object actions', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    final textField = find.byKey(ValueKey('note-text-field-${note.note.id}'));

    await _secondaryTap(tester, textField);

    expect(_selectedNoteIds(tester), {note.note.id});
    expect(
      find.byKey(const ValueKey('context-copy-menu-item')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-delete-menu-item')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-paste-menu-item')),
      findsOneWidget,
      reason: 'The object menu must not be covered by a second canvas menu.',
    );
  });

  testWidgets('competing object and canvas callbacks open only one menu', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    final notePosition = tester.getCenter(
      find.byKey(ValueKey('note-text-field-${note.note.id}')),
    );

    note.onSecondaryTapDown(
      TapDownDetails(
        globalPosition: notePosition,
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pumpAndSettle();
    final canvasSurface = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('canvas-interaction-surface')),
    );
    canvasSurface.onSecondaryTapUp!(
      TapUpDetails(globalPosition: notePosition, kind: PointerDeviceKind.mouse),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('context-paste-menu-item')),
      findsOneWidget,
      reason: 'One secondary press must never stack object and canvas menus.',
    );
    expect(
      find.byKey(const ValueKey('context-delete-menu-item')),
      findsOneWidget,
    );
  });

  testWidgets('empty-canvas menu disables Paste before anything is copied', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    await tester.tapAt(
      const Offset(40, 500),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    final pasteItem = tester.widget<PopupMenuItem<dynamic>>(
      find.byKey(const ValueKey('context-paste-menu-item')),
    );
    final addNoteItem = tester.widget<PopupMenuItem<dynamic>>(
      find.byKey(const ValueKey('context-add-note-menu-item')),
    );
    expect(addNoteItem.enabled, isTrue);
    expect(pasteItem.enabled, isFalse);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('context-add-note-menu-item')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('context-paste-menu-item')))
            .dy,
      ),
    );
    expect(find.byKey(const ValueKey('context-copy-menu-item')), findsNothing);
    expect(
      find.byKey(const ValueKey('context-delete-menu-item')),
      findsNothing,
    );
  });

  testWidgets(
    'creates, edits, styles, saves, and undoes a free-floating heading',
    (tester) async {
      final store = await _pumpTestApp(tester);

      await tester.tapAt(
        const Offset(300, 300),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-add-heading-menu-item')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('heading-text-field')),
        'Act One',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-heading-text-button')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));

      var headingWidget = tester.widget<InteractiveCanvasHeading>(
        find.byType(InteractiveCanvasHeading),
      );
      expect(headingWidget.heading.text, 'Act One');
      expect(headingWidget.heading.size, CanvasHeadingSize.large);
      expect(
        headingWidget.heading.background,
        CanvasHeadingBackground.transparent,
      );
      expect(_selectedHeadingIds(tester), {headingWidget.heading.id});
      expect(store.board!.headings.single.text, 'Act One');

      headingWidget.onSecondaryTapDown(
        TapDownDetails(
          globalPosition: Offset(300, 300),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-heading-size-menu-item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-heading-size-extraLarge')),
      );
      await tester.pumpAndSettle();

      headingWidget = tester.widget<InteractiveCanvasHeading>(
        find.byType(InteractiveCanvasHeading),
      );
      expect(headingWidget.heading.size, CanvasHeadingSize.extraLarge);

      headingWidget.onSecondaryTapDown(
        TapDownDetails(
          globalPosition: Offset(300, 300),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-heading-background-menu-item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-heading-background-blue')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));

      headingWidget = tester.widget<InteractiveCanvasHeading>(
        find.byType(InteractiveCanvasHeading),
      );
      expect(headingWidget.heading.background, CanvasHeadingBackground.blue);
      expect(
        store.board!.headings.single.background,
        CanvasHeadingBackground.blue,
      );

      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      headingWidget = tester.widget<InteractiveCanvasHeading>(
        find.byType(InteractiveCanvasHeading),
      );
      expect(
        headingWidget.heading.background,
        CanvasHeadingBackground.transparent,
      );
    },
  );

  testWidgets('double-click edits heading appearance in one history action', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 23);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'heading-appearance-board',
        name: 'Heading appearance',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        headings: [
          CanvasHeading(
            id: 'heading-appearance',
            x: 200,
            y: 150,
            text: 'Original',
            size: CanvasHeadingSize.large,
            background: CanvasHeadingBackground.transparent,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(
      find.byKey(const ValueKey('heading-surface-heading-appearance')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const ValueKey('heading-surface-heading-appearance')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('heading-appearance-dialog')),
      findsOneWidget,
    );
    expect(find.text('Original'), findsWidgets);
    expect(
      tester
          .widget<DropdownButtonFormField<CanvasHeadingSize>>(
            find.byKey(const ValueKey('heading-appearance-size')),
          )
          .initialValue,
      CanvasHeadingSize.large,
    );
    await tester.enterText(
      find.byKey(const ValueKey('heading-appearance-text-field')),
      'Revised',
    );
    await tester.tap(find.byKey(const ValueKey('heading-appearance-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra large · 56').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('heading-appearance-background')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-heading-appearance-button')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.headings.single.text, 'Revised');
    expect(store.board!.headings.single.size, CanvasHeadingSize.extraLarge);
    expect(
      store.board!.headings.single.background,
      CanvasHeadingBackground.blue,
    );
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.headings.single.text, 'Original');
    expect(store.board!.headings.single.size, CanvasHeadingSize.large);
    expect(
      store.board!.headings.single.background,
      CanvasHeadingBackground.transparent,
    );
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.headings.single.text, 'Revised');
    expect(store.board!.headings.single.size, CanvasHeadingSize.extraLarge);
    expect(
      store.board!.headings.single.background,
      CanvasHeadingBackground.blue,
    );
  });

  testWidgets('locked heading keeps its size in the appearance editor', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 23);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'locked-heading-appearance-board',
        name: 'Locked heading appearance',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        headings: [
          CanvasHeading(
            id: 'locked-heading-appearance',
            x: 200,
            y: 150,
            text: 'Locked',
            size: CanvasHeadingSize.large,
            background: CanvasHeadingBackground.transparent,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        lockedObjectIds: const {'locked-heading-appearance'},
      ),
    );
    await _pumpTestApp(tester, store: store);
    tester
        .widget<InteractiveCanvasHeading>(find.byType(InteractiveCanvasHeading))
        .onEdit();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<CanvasHeadingSize>>(
            find.byKey(const ValueKey('heading-appearance-size')),
          )
          .onChanged,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('heading-appearance-background')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-heading-appearance-button')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.headings.single.size, CanvasHeadingSize.large);
    expect(
      store.board!.headings.single.background,
      CanvasHeadingBackground.green,
    );
    expect(store.board!.lockedObjectIds, {'locked-heading-appearance'});
    tester
        .widget<InteractiveCanvasHeading>(find.byType(InteractiveCanvasHeading))
        .onSecondaryTapDown(
          TapDownDetails(
            globalPosition: const Offset(300, 300),
            kind: PointerDeviceKind.mouse,
          ),
        );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<dynamic>>(
            find.byKey(const ValueKey('context-heading-size-menu-item')),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('marquee selects a heading on inclusive edge contact', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 8, 9);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'heading-marquee-board',
        name: 'Heading marquee',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        headings: [
          CanvasHeading(
            id: 'heading-marquee',
            x: 200,
            y: 150,
            text: 'Characters',
            size: CanvasHeadingSize.large,
            background: CanvasHeadingBackground.transparent,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    final headingRect = tester.getRect(find.byType(InteractiveCanvasHeading));
    final gesture = await tester.startGesture(
      headingRect.topLeft - const Offset(12, 12),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(Offset(headingRect.left, headingRect.center.dy));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_selectedHeadingIds(tester), {'heading-marquee'});
    expect(store.saveCalls, 0);
  });

  testWidgets('moves and copies a heading with a mixed selection', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 8, 10);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'heading-mixed-board',
        name: 'Heading mixed selection',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'heading-note',
            x: 420,
            y: 180,
            width: 260,
            height: 170,
            text: 'Opening beat',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        headings: [
          CanvasHeading(
            id: 'heading-mixed',
            x: 180,
            y: 180,
            text: 'Act One',
            size: CanvasHeadingSize.large,
            background: CanvasHeadingBackground.green,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    tester.widget<EditableNote>(find.byType(EditableNote)).onSelect();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(HardwareKeyboard.instance.isControlPressed, isTrue);
    tester
        .widget<InteractiveCanvasHeading>(find.byType(InteractiveCanvasHeading))
        .onSelect();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_selectedHeadingIds(tester), {'heading-mixed'});
    expect(_selectedNoteIds(tester), {'heading-note'});

    final headingWidget = tester.widget<InteractiveCanvasHeading>(
      find.byType(InteractiveCanvasHeading),
    );
    headingWidget.onBeginMoving(const Offset(300, 300));
    headingWidget.onMove(const Offset(350, 330));
    headingWidget.onEndMoving();
    await tester.pumpAndSettle();

    final movedHeading = tester
        .widget<InteractiveCanvasHeading>(find.byType(InteractiveCanvasHeading))
        .heading;
    final movedNote = tester
        .widget<EditableNote>(find.byType(EditableNote))
        .note;
    expect(movedHeading.x, 230);
    expect(movedHeading.y, 210);
    expect(movedNote.x, 470);
    expect(movedNote.y, 210);

    await _sendShortcut(tester, LogicalKeyboardKey.keyC);
    await _sendShortcut(tester, LogicalKeyboardKey.keyV);
    expect(find.byType(InteractiveCanvasHeading), findsNWidgets(2));
    expect(find.byType(EditableNote), findsNWidgets(2));
    expect(_selectedHeadingIds(tester), hasLength(1));
    expect(_selectedNoteIds(tester), hasLength(1));
    expect(
      tester
          .widgetList<InteractiveCanvasHeading>(
            find.byType(InteractiveCanvasHeading),
          )
          .map((widget) => widget.heading.id)
          .toSet(),
      hasLength(2),
    );
  });

  testWidgets('find selects and recenters an exact heading without history', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 8, 11);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'heading-find-board',
        name: 'Heading find',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.75,
        notes: const [],
        headings: [
          CanvasHeading(
            id: 'heading-find',
            x: 2400,
            y: 1600,
            text: 'Character arcs',
            size: CanvasHeadingSize.extraLarge,
            background: CanvasHeadingBackground.purple,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final saveCallsBefore = store.saveCalls;

    await tester.tap(find.byKey(const ValueKey('find-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'ARCS',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('find-heading-result-heading-find')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('find-heading-result-heading-find')),
    );
    await tester.pumpAndSettle();

    expect(_selectedHeadingIds(tester), {'heading-find'});
    expect(controller.value.getMaxScaleOnAxis(), closeTo(0.75, 0.0001));
    expect(store.saveCalls, saveCallsBefore);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Paste text here creates one positioned edit-ready note and keeps object paste',
    (tester) async {
      const clipboardText = '  First line\n\n  Second line  ';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final timestamp = DateTime.utc(2026, 9, 3, 21);
      await _pumpMixedBoard(tester, timestamp: timestamp);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-mixed-note')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-blue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.75, 0.75, 0.75)
        ..setTranslationRaw(-120, -90, 0);
      await tester.pump();
      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      const requestLocal = Offset(610, 420);
      final expectedCanvasCenter = controller.toScene(requestLocal);

      await tester.tapAt(
        surfaceRect.topLeft + requestLocal,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      final textItem = find.byKey(
        const ValueKey('context-paste-text-menu-item'),
      );
      expect(textItem, findsOneWidget);
      expect(find.text('Paste text here'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuItem<dynamic>>(
              find.byKey(const ValueKey('context-paste-menu-item')),
            )
            .enabled,
        isTrue,
      );
      expect(
        tester.getTopLeft(textItem).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('context-add-note-menu-item')),
              )
              .dy,
        ),
      );
      expect(
        tester.getTopLeft(textItem).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('context-paste-menu-item')))
              .dy,
        ),
      );

      await tester.tap(textItem);
      await tester.pumpAndSettle();

      final created = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .singleWhere((note) => note.text.startsWith('First line'));
      expect(created.text, 'First line\n\n  Second line');
      expect(created.color, NoteColor.blue);
      expect(
        created.x + created.width / 2,
        closeTo(expectedCanvasCenter.dx, 1),
      );
      expect(
        created.y + created.height / 2,
        closeTo(expectedCanvasCenter.dy, 1),
      );
      expect(
        tester.widget<EditableNote>(find.byKey(ValueKey(created.id))).isEditing,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(ValueKey('note-text-field-${created.id}')),
            )
            .controller!
            .selection,
        TextSelection.collapsed(offset: created.text.length),
      );
      expect(find.byType(EditableNote), findsNWidgets(2));
    },
  );

  testWidgets(
    'Paste image here creates one managed image at the request point',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 5, 15);
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'clipboard-image-board',
          name: 'Clipboard image',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
        ),
      );
      final clipboard = _TestClipboardImageReader(
        payload: ClipboardImagePayload(
          pngBytes: Uint8List.fromList([1, 2, 3]),
          suggestedFileName: 'Browser reference.png',
        ),
      );
      final imageStore = _TestImageAssetStore(
        importedAsset: const ManagedImageAsset(
          assetPath: 'assets/clipboard.png',
          originalFileName: 'Browser reference.png',
          pixelWidth: 800,
          pixelHeight: 400,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          clipboardImageReader: clipboard,
          imageAssetStore: imageStore,
          imageViewBuilder: (image) => SizedBox(
            key: ValueKey('clipboard-image-${image.id}'),
            width: image.width,
            height: image.height,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      const requestLocal = Offset(610, 420);
      final expectedCenter = controller.toScene(requestLocal);

      await tester.tapAt(
        surfaceRect.topLeft + requestLocal,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final imageItem = find.byKey(
        const ValueKey('context-paste-image-menu-item'),
      );
      expect(imageItem, findsOneWidget);
      expect(find.text('Paste image here'), findsOneWidget);
      await tester.tap(imageItem);
      await tester.pumpAndSettle();

      expect(clipboard.hasImageCalls, 1);
      expect(clipboard.readCalls, 1);
      expect(imageStore.importByteCalls, 1);
      expect(imageStore.receivedBytes, [1, 2, 3]);
      expect(imageStore.receivedOriginalFileName, 'Browser reference.png');
      final image = tester.widget<InteractiveBoardImage>(
        find.byType(InteractiveBoardImage),
      );
      expect(image.isSelected, isTrue);
      expect(image.image.width, 480);
      expect(image.image.height, 240);
      expect(
        image.image.x + image.image.width / 2,
        closeTo(expectedCenter.dx, 1),
      );
      expect(
        image.image.y + image.image.height / 2,
        closeTo(expectedCenter.dy, 1),
      );
    },
  );

  testWidgets('clipboard image change is a non-mutating failure', (
    tester,
  ) async {
    final clipboard = _TestClipboardImageReader(
      payload: ClipboardImagePayload(
        pngBytes: Uint8List.fromList([1, 2, 3]),
        suggestedFileName: 'Clipboard image.png',
      ),
    );
    final imageStore = _TestImageAssetStore();
    await tester.pumpWidget(
      MainApp(
        boardStore: _MemoryBoardStore(),
        clipboardImageReader: clipboard,
        imageAssetStore: imageStore,
      ),
    );
    await tester.pumpAndSettle();
    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('canvas-interaction-surface')),
    );
    await tester.tapAt(
      surfaceRect.topLeft + const Offset(610, 420),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    clipboard.payload = ClipboardImagePayload(
      pngBytes: Uint8List.fromList([4, 5, 6]),
      suggestedFileName: 'Replacement image.png',
    );
    await tester.tap(
      find.byKey(const ValueKey('context-paste-image-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clipboard image changed'), findsOneWidget);
    expect(imageStore.importByteCalls, 0);
    expect(find.byType(InteractiveBoardImage), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'text paste yields to website commands and rejects changed content',
    (tester) async {
      String? clipboardText = 'Ordinary copied text';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pumpTestApp(tester);

      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final textItem = find.byKey(
        const ValueKey('context-paste-text-menu-item'),
      );
      expect(textItem, findsOneWidget);
      clipboardText = 'Changed copied text';
      await tester.tap(textItem);
      await tester.pumpAndSettle();
      expect(find.text('Clipboard text changed'), findsOneWidget);
      expect(find.byType(EditableNote), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      clipboardText = 'https://one.example/path';
      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('context-paste-website-menu-item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('context-paste-text-menu-item')),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      clipboardText = 'https://one.example\nhttps://two.example';
      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('context-paste-website-list-menu-item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('context-paste-text-menu-item')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Paste website list here creates one ordered edit-ready multi-link note',
    (tester) async {
      const firstUrl = 'https://first.example/a';
      const secondUrl = 'https://second.example/b';
      String? clipboardText = '  $firstUrl  \n\n$secondUrl\n$firstUrl';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final timestamp = DateTime.utc(2026, 9, 3, 20);
      await _pumpMixedBoard(tester, timestamp: timestamp);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-mixed-note')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-blue')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.75, 0.75, 0.75)
        ..setTranslationRaw(-120, -90, 0);
      await tester.pump();
      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      const requestLocal = Offset(610, 420);
      final expectedCanvasCenter = controller.toScene(requestLocal);

      await tester.tapAt(
        surfaceRect.topLeft + requestLocal,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      final websiteListItem = find.byKey(
        const ValueKey('context-paste-website-list-menu-item'),
      );
      expect(websiteListItem, findsOneWidget);
      expect(find.text('Paste 2 websites here'), findsOneWidget);
      expect(
        tester.getTopLeft(websiteListItem).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('context-add-note-menu-item')),
              )
              .dy,
        ),
      );
      expect(
        tester.getTopLeft(websiteListItem).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('context-paste-menu-item')))
              .dy,
        ),
      );

      await tester.tap(websiteListItem);
      await tester.pumpAndSettle();

      final created = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .singleWhere((note) => note.text.contains(firstUrl));
      expect(created.text, '$firstUrl\n$secondUrl');
      expect(created.color, NoteColor.blue);
      expect(
        created.x + created.width / 2,
        closeTo(expectedCanvasCenter.dx, 1),
      );
      expect(
        created.y + created.height / 2,
        closeTo(expectedCanvasCenter.dy, 1),
      );
      expect(
        tester.widget<EditableNote>(find.byKey(ValueKey(created.id))).isEditing,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(ValueKey('note-text-field-${created.id}')),
            )
            .controller!
            .selection,
        TextSelection.collapsed(offset: created.text.length),
      );
      expect(find.byType(EditableNote), findsNWidgets(2));
    },
  );

  testWidgets(
    'website list paste refuses a changed distinct count without mutation',
    (tester) async {
      String? clipboardText =
          'https://one.example\nhttps://two.example\nhttps://three.example';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pumpTestApp(tester);

      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final websiteListItem = find.byKey(
        const ValueKey('context-paste-website-list-menu-item'),
      );
      expect(find.text('Paste 3 websites here'), findsOneWidget);

      clipboardText = 'https://one.example\nhttps://two.example';
      await tester.tap(websiteListItem);
      await tester.pumpAndSettle();

      expect(find.text('Website list changed'), findsOneWidget);
      expect(find.byType(EditableNote), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'Paste website here creates an edit-ready URL note at the request point',
    (tester) async {
      const clipboardUrl = 'https://example.com/provider';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': '  $clipboardUrl  '};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final timestamp = DateTime.utc(2026, 9, 3, 18);
      await _pumpMixedBoard(tester, timestamp: timestamp);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.75, 0.75, 0.75)
        ..setTranslationRaw(-120, -90, 0);
      await tester.pump();
      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      const requestLocal = Offset(610, 420);
      final expectedCanvasCenter = controller.toScene(requestLocal);

      await tester.tapAt(
        surfaceRect.topLeft + requestLocal,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      final websiteItem = find.byKey(
        const ValueKey('context-paste-website-menu-item'),
      );
      expect(websiteItem, findsOneWidget);
      expect(
        tester.getTopLeft(websiteItem).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('context-add-note-menu-item')),
              )
              .dy,
        ),
      );
      expect(
        tester.getTopLeft(websiteItem).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('context-paste-menu-item')))
              .dy,
        ),
      );

      await tester.tap(websiteItem);
      await tester.pumpAndSettle();

      final created = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .singleWhere((note) => note.id != 'mixed-note');
      expect(created.text, clipboardUrl);
      expect(
        created.x + created.width / 2,
        closeTo(expectedCanvasCenter.dx, 1),
      );
      expect(
        created.y + created.height / 2,
        closeTo(expectedCanvasCenter.dy, 1),
      );
      expect(created.color, NoteColor.yellow);
      expect(_selectedNoteIds(tester), {created.id});
      expect(
        tester.widget<EditableNote>(find.byKey(ValueKey(created.id))).isEditing,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(ValueKey('note-text-field-${created.id}')),
            )
            .controller!
            .selection,
        const TextSelection.collapsed(offset: clipboardUrl.length),
      );

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(created.id)), findsNothing);
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(created.id)), findsOneWidget);
    },
  );

  testWidgets(
    'YouTube clipboard URL offers both embed and website-note actions',
    (tester) async {
      const clipboardUrl = 'https://youtu.be/dQw4w9WgXcQ';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardUrl};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final imageStore = _TestImageAssetStore(
        importedAsset: const ManagedImageAsset(
          assetPath: 'assets/youtube-preview.jpg',
          originalFileName: 'youtube-dQw4w9WgXcQ.jpg',
          pixelWidth: 480,
          pixelHeight: 360,
        ),
      );
      final store = await _pumpTestApp(
        tester,
        imageAssetStore: imageStore,
        youTubeThumbnailFetcher: _TestYouTubeThumbnailFetcher(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
        ),
      );

      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      final embedItem = find.byKey(
        const ValueKey('context-embed-youtube-menu-item'),
      );
      expect(embedItem, findsOneWidget);
      expect(find.text('Embed YouTube here'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('context-paste-website-menu-item')),
        findsOneWidget,
      );

      await tester.tap(embedItem);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveYouTubeEmbed), findsOneWidget);
      expect(
        find.byKey(
          ValueKey('youtube-thumbnail-${store.board!.youTubeEmbeds.single.id}'),
        ),
        findsOneWidget,
      );
      expect(imageStore.receivedOriginalFileName, 'youtube-dQw4w9WgXcQ.jpg');
      expect(
        store.board!.youTubeEmbeds.single.thumbnailAssetPath,
        'assets/youtube-preview.jpg',
      );
    },
  );

  testWidgets(
    'website paste rejects ineligible or changed clipboard text without mutation',
    (tester) async {
      String? clipboardText = 'ordinary copied prose';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pumpTestApp(tester);

      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('context-paste-website-menu-item')),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      clipboardText = 'https://example.com/current';
      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final websiteItem = find.byKey(
        const ValueKey('context-paste-website-menu-item'),
      );
      expect(websiteItem, findsOneWidget);
      clipboardText = 'changed after the menu opened';
      await tester.tap(websiteItem);
      await tester.pumpAndSettle();

      expect(find.text('No website address to paste'), findsOneWidget);
      expect(find.byType(EditableNote), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'website paste keeps system and object clipboards distinct and uses sticky colour',
    (tester) async {
      const clipboardUrl = 'https://example.com/reference';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardUrl};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pumpTestApp(tester);
      final original = tester.widget<EditableNote>(find.byType(EditableNote));
      await tester.tap(
        find.byKey(ValueKey('note-drag-handle-${original.note.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-color-blue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
      await tester.pumpAndSettle();

      await tester.tapAt(
        const Offset(40, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('context-paste-website-menu-item')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PopupMenuItem<dynamic>>(
              find.byKey(const ValueKey('context-paste-menu-item')),
            )
            .enabled,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('context-paste-website-menu-item')),
      );
      await tester.pumpAndSettle();

      final websiteNote = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .singleWhere((note) => note.text == clipboardUrl);
      expect(websiteNote.color, NoteColor.blue);
      expect(find.byType(EditableNote), findsNWidgets(2));
    },
  );

  testWidgets(
    'Add note here creates one edit-ready note at transformed request point',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 2, 8);
      final store = await _pumpMixedBoard(tester, timestamp: timestamp);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.75, 0.75, 0.75)
        ..setTranslationRaw(-120, -90, 0);
      await tester.pump();
      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      const requestLocal = Offset(610, 420);
      final requestGlobal = surfaceRect.topLeft + requestLocal;
      final expectedCanvasCenter = controller.toScene(requestLocal);

      await tester.tapAt(
        requestGlobal,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('context-add-note-menu-item')),
      );
      await tester.pumpAndSettle();

      final created = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .singleWhere((note) => note.id != 'mixed-note');
      expect(
        created.x + created.width / 2,
        closeTo(expectedCanvasCenter.dx, 1),
      );
      expect(
        created.y + created.height / 2,
        closeTo(expectedCanvasCenter.dy, 1),
      );
      expect(created.color, NoteColor.yellow);
      expect(_selectedNoteIds(tester), {created.id});
      expect(_selectedImageIds(tester), isEmpty);
      expect(
        tester.widget<EditableNote>(find.byKey(ValueKey(created.id))).isEditing,
        isTrue,
      );
      expect(store.board!.notes, hasLength(2));

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(created.id)), findsNothing);

      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(created.id)), findsOneWidget);
    },
  );

  testWidgets('Add note here clamps the complete note at the board edge', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 2, 8, 5);
    await _pumpMixedBoard(tester, timestamp: timestamp);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    controller.value = Matrix4.diagonal3Values(0.1, 0.1, 0.1)
      ..setTranslationRaw(-550, -362, 0);
    await tester.pump();
    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('canvas-interaction-surface')),
    );
    const requestLocal = Offset(40, 80);

    await tester.tapAt(
      surfaceRect.topLeft + requestLocal,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('context-add-note-menu-item')));
    await tester.pumpAndSettle();

    final created = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .singleWhere((note) => note.id != 'mixed-note');
    expect(created.x, 6000 - created.width);
    expect(created.y, 4500 - created.height);
  });

  testWidgets('dismissing the blank-canvas creation menu is a complete no-op', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 2, 8, 10);
    final store = await _pumpMixedBoard(tester, timestamp: timestamp);
    final originalBoard = store.board!.toJson();
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final originalTransform = List<double>.of(controller.value.storage);

    await tester.tapAt(
      const Offset(40, 500),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('context-add-note-menu-item')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(store.board!.toJson(), originalBoard);
    expect(store.saveCalls, 0);
    expect(controller.value.storage, orderedEquals(originalTransform));
    expect(_selectedNoteIds(tester), isEmpty);
    expect(_selectedImageIds(tester), isEmpty);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('keeps an empty-canvas menu inside the window near an edge', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    final note = tester.widget<EditableNote>(find.byType(EditableNote));
    await _secondaryTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-${note.note.id}')),
    );
    await tester.tap(find.byKey(const ValueKey('context-copy-menu-item')));
    await tester.pumpAndSettle();
    final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;

    await tester.tapAt(
      Offset(viewSize.width - 2, viewSize.height - 2),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    final itemRect = tester.getRect(
      find.byKey(const ValueKey('context-paste-menu-item')),
    );
    expect(itemRect.left, greaterThanOrEqualTo(0));
    expect(itemRect.top, greaterThanOrEqualTo(0));
    expect(itemRect.right, lessThanOrEqualTo(viewSize.width));
    expect(itemRect.bottom, lessThanOrEqualTo(viewSize.height));
  });

  testWidgets('dismissing a context menu does not mutate or enter history', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 19, 21, 10);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, includeConnector: false),
    );
    final original = store.board!.toJson();
    await _pumpTestApp(tester, store: store);

    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-a')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('context-copy-menu-item')), findsNothing);
    expect(_selectedNoteIds(tester), {'note-a'});
    expect(store.board!.toJson(), original);
    expect(store.saveCalls, 0);
    final undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('undo-button')),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets(
    'repeated right-clicks while editing never open canvas object actions',
    (tester) async {
      await _pumpTestApp(tester);
      final note = tester.widget<EditableNote>(find.byType(EditableNote));
      final textField = find.byKey(ValueKey('note-text-field-${note.note.id}'));

      await tester.tap(textField);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
        isTrue,
      );
      await _secondaryTap(tester, textField);

      expect(
        find.byKey(const ValueKey('context-copy-menu-item')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('context-delete-menu-item')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('context-paste-menu-item')),
        findsNothing,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableNote>(find.byType(EditableNote)).isEditing,
        isTrue,
      );

      final canvasSurface = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      canvasSurface.onSecondaryTapUp!(
        TapUpDetails(
          globalPosition: tester.getCenter(textField),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('context-paste-menu-item')),
        findsNothing,
      );

      await _secondaryTap(tester, textField);

      expect(
        find.byKey(const ValueKey('context-copy-menu-item')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('context-delete-menu-item')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('context-paste-menu-item')),
        findsNothing,
      );
    },
  );

  testWidgets('offsets pasted notes visibly while keeping them on board', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 9, 14);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'copy-paste-edge-board',
        name: 'Copy and paste edge test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 5400,
        viewportY: 3900,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'bottom-right-note',
            x: 5740,
            y: 4330,
            width: 260,
            height: 170,
            text: 'At the edge',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(
      find.byKey(const ValueKey('note-drag-handle-bottom-right-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    final pasted = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .firstWhere((note) => note.id != 'bottom-right-note');
    expect(Offset(pasted.x, pasted.y), isNot(const Offset(5740, 4330)));
    expect(pasted.x, greaterThanOrEqualTo(0));
    expect(pasted.y, greaterThanOrEqualTo(0));
    expect(pasted.x + pasted.width, lessThanOrEqualTo(6000));
    expect(pasted.y + pasted.height, lessThanOrEqualTo(4500));
  });

  testWidgets('control-click adds and removes notes from selection', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();

    final createdNote = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .last;
    await tester.drag(
      find.byKey(ValueKey('note-drag-handle-${createdNote.note.id}')),
      const Offset(180, 100),
    );
    await tester.pumpAndSettle();

    final notes = tester.widgetList<EditableNote>(find.byType(EditableNote));
    final firstId = notes.first.note.id;
    final secondId = notes.last.note.id;
    await tester.tap(find.byKey(ValueKey('note-drag-handle-$firstId')));
    await tester.pumpAndSettle();
    await _controlTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-$secondId')),
    );

    expect(find.text('SELECTED'), findsNWidgets(2));
    expect(find.byKey(ValueKey('note-resize-handle-$firstId')), findsOneWidget);
    expect(
      find.byKey(ValueKey('note-resize-handle-$secondId')),
      findsOneWidget,
    );

    await _controlTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-$secondId')),
    );
    expect(find.text('SELECTED'), findsOneWidget);
    expect(find.byKey(ValueKey('note-resize-handle-$firstId')), findsOneWidget);
    expect(
      find.byKey(ValueKey('note-resize-handle-$secondId')),
      findsOneWidget,
    );
  });

  testWidgets('resize rail targets one Note from a multi-selection', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 5, 14);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'resize-rail-multi-board',
        name: 'Resize rail multi-selection',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'resize-rail-first',
            x: 100,
            y: 100,
            width: 220,
            height: 150,
            text: 'First',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'resize-rail-second',
            x: 450,
            y: 100,
            width: 220,
            height: 150,
            text: 'Second',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    var notes = tester.widgetList<EditableNote>(find.byType(EditableNote));
    final first = notes.first.note;
    final second = notes.last.note;
    await tester.tap(find.byKey(ValueKey('note-drag-handle-${first.id}')));
    await _controlTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-${second.id}')),
    );
    expect(_selectedNoteIds(tester), {first.id, second.id});

    await tester.drag(
      find.byKey(ValueKey('note-resize-rail-${first.id}')),
      const Offset(80, 50),
    );
    await tester.pumpAndSettle();

    notes = tester.widgetList<EditableNote>(find.byType(EditableNote));
    final resizedFirst = notes.firstWhere(
      (widget) => widget.note.id == first.id,
    );
    final unchangedSecond = notes.firstWhere(
      (widget) => widget.note.id == second.id,
    );
    expect(_selectedNoteIds(tester), {first.id});
    expect(resizedFirst.note.width, closeTo(first.width + 80, 1));
    expect(resizedFirst.note.height, closeTo(first.height + 50, 1));
    expect(unchangedSecond.note.width, second.width);
    expect(unchangedSecond.note.height, second.height);
  });

  testWidgets('moves a selected group together within board bounds', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 9, 15);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'group-move-board',
        name: 'Group move test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.2,
        notes: [
          Note(
            id: 'group-left',
            x: 100,
            y: 200,
            width: 260,
            height: 170,
            text: 'Left',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'group-right',
            x: 3600,
            y: 1000,
            width: 260,
            height: 170,
            text: 'Right',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-group-left')));
    await tester.pumpAndSettle();
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-group-right')),
    );
    expect(find.text('SELECTED'), findsNWidgets(2));
    final groupDragHandle = find.byKey(
      const ValueKey('note-drag-handle-group-left'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(groupDragHandle),
    );
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 5));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 5));
    await gesture.up();
    await tester.pumpAndSettle();

    var notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    var left = notes.firstWhere((note) => note.id == 'group-left');
    var right = notes.firstWhere((note) => note.id == 'group-right');
    expect(left.x, 400);
    expect(left.y, 300);
    expect(right.x, 3900);
    expect(right.y, 1100);
    expect(right.x + right.width, lessThanOrEqualTo(6000));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    left = notes.firstWhere((note) => note.id == 'group-left');
    right = notes.firstWhere((note) => note.id == 'group-right');
    expect(left.x, 100);
    expect(left.y, 200);
    expect(right.x, 3600);
    expect(right.y, 1000);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    expect(notes.firstWhere((note) => note.id == 'group-left').x, 400);
    expect(notes.firstWhere((note) => note.id == 'group-right').x, 3900);
  });

  testWidgets('applies colour and deletion to a selected group', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    final createdNote = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .last;
    await tester.drag(
      find.byKey(ValueKey('note-drag-handle-${createdNote.note.id}')),
      const Offset(180, 100),
    );
    await tester.pumpAndSettle();
    final notes = tester.widgetList<EditableNote>(find.byType(EditableNote));
    final firstId = notes.first.note.id;
    final secondId = notes.last.note.id;
    await tester.tap(find.byKey(ValueKey('note-drag-handle-$firstId')));
    await tester.pumpAndSettle();
    await _controlTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-$secondId')),
    );

    await tester.tap(find.byKey(const ValueKey('note-color-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-color-purple')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .every((widget) => widget.note.color == NoteColor.purple),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('delete-note-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNothing);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));
    expect(find.text('SELECTED'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .every((widget) => widget.note.color == NoteColor.yellow),
      isTrue,
    );
  });

  testWidgets('copies and pastes a selected group as one action', (
    tester,
  ) async {
    await _pumpTestApp(tester);
    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    final createdNote = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .last;
    await tester.drag(
      find.byKey(ValueKey('note-drag-handle-${createdNote.note.id}')),
      const Offset(180, 100),
    );
    await tester.pumpAndSettle();
    final originalNotes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    await tester.tap(
      find.byKey(ValueKey('note-drag-handle-${originalNotes.first.id}')),
    );
    await tester.pumpAndSettle();
    await _controlTap(
      tester,
      find.byKey(ValueKey('note-drag-handle-${originalNotes.last.id}')),
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    final allNotes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .toList();
    final originalIds = originalNotes.map((note) => note.id).toSet();
    final pastedNotes = allNotes
        .where((note) => !originalIds.contains(note.id))
        .toList();
    expect(allNotes, hasLength(4));
    expect(pastedNotes, hasLength(2));
    expect(find.text('SELECTED'), findsNWidgets(2));
    expect(
      pastedNotes[1].x - pastedNotes[0].x,
      originalNotes[1].x - originalNotes[0].x,
    );
    expect(
      pastedNotes[1].y - pastedNotes[0].y,
      originalNotes[1].y - originalNotes[0].y,
    );

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(4));
    expect(find.text('SELECTED'), findsNWidgets(2));
  });

  testWidgets('copies only internal connectors and remaps pasted endpoints', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 20);
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: timestamp,
        includeThirdNote: true,
        includeExternalConnector: true,
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    var pastedNotes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .where((note) => !{'note-a', 'note-b', 'note-c'}.contains(note.id))
        .toList();
    expect(pastedNotes, hasLength(2));
    expect(find.text('SELECTED'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors, hasLength(3));
    final originalConnectorIds = {'connector-a-b', 'connector-a-c'};
    final pastedConnector = store.board!.connectors.singleWhere(
      (connector) => !originalConnectorIds.contains(connector.id),
    );
    final pastedNoteIds = pastedNotes.map((note) => note.id).toSet();
    expect(pastedNoteIds, contains(pastedConnector.objectAId));
    expect(pastedNoteIds, contains(pastedConnector.objectBId));
    expect(pastedConnector.objectAId, isNot(anyOf('note-a', 'note-b')));
    expect(pastedConnector.objectBId, isNot(anyOf('note-a', 'note-b')));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(5));
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors, hasLength(3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);
    pastedNotes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .map((widget) => widget.note)
        .where((note) => !{'note-a', 'note-b', 'note-c'}.contains(note.id))
        .toList();
    expect(pastedNotes, hasLength(2));
    expect(store.board!.connectors, hasLength(3));
  });

  testWidgets('creates a selected editable note with a unique identifier', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();

    final noteWidgets = tester.widgetList<EditableNote>(
      find.byType(EditableNote),
    );
    final identifiers = noteWidgets.map((widget) => widget.note.id).toSet();
    expect(noteWidgets, hasLength(2));
    expect(identifiers, hasLength(2));
    expect(find.text('EDITING'), findsOneWidget);

    final createdNote = noteWidgets.last;
    final textField = find.byKey(
      ValueKey('note-text-field-${createdNote.note.id}'),
    );
    await tester.enterText(textField, 'New note text');
    await tester.pump();
    expect(find.text('New note text'), findsOneWidget);
  });

  testWidgets('autosaves board changes', (tester) async {
    final store = await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();

    expect(store.board, isNotNull);
    expect(store.board!.notes, hasLength(2));
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('deletes the selected note and restores it with undo', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('delete-note-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));
    expect(find.text('SELECTED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsOneWidget);
  });

  testWidgets('undoes note creation', (tester) async {
    await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(find.byType(EditableNote), findsNWidgets(2));
  });

  testWidgets('undoes note movement', (tester) async {
    await _pumpTestApp(tester);

    final noteFinder = find.byType(EditableNote);
    final editableNote = tester.widget<EditableNote>(noteFinder);
    final dragHandle = find.byKey(
      ValueKey('note-drag-handle-${editableNote.note.id}'),
    );
    final initialPosition = tester.getTopLeft(noteFinder);

    await tester.drag(dragHandle, const Offset(60, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();

    final restoredPosition = tester.getTopLeft(noteFinder);
    expect(restoredPosition.dx, closeTo(initialPosition.dx, 1));
    expect(restoredPosition.dy, closeTo(initialPosition.dy, 1));

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    final redonePosition = tester.getTopLeft(noteFinder);
    expect(redonePosition.dx, closeTo(initialPosition.dx + 60, 1));
    expect(redonePosition.dy, closeTo(initialPosition.dy + 40, 1));
  });

  testWidgets('undoes a note text editing session', (tester) async {
    await _pumpTestApp(tester);

    final editableNote = tester.widget<EditableNote>(find.byType(EditableNote));
    final textField = find.byKey(
      ValueKey('note-text-field-${editableNote.note.id}'),
    );
    await tester.tap(textField);
    await tester.pumpAndSettle();
    await tester.enterText(textField, 'Undo this text');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.text('Undo this text'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(find.text('Undo this text'), findsOneWidget);
  });

  testWidgets('clears redo history after a new board action', (tester) async {
    await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();

    var redoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('redo-button')),
    );
    expect(redoButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();

    redoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('redo-button')),
    );
    expect(redoButton.onPressed, isNull);
  });

  testWidgets('zooms to fit notes created across distant canvas regions', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    viewer.transformationController!.value = Matrix4.identity()
      ..setTranslationRaw(-2000, -1400, 0);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(InteractiveViewer)) + const Offset(10, 10),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('zoom-to-fit-button')))
          .tooltip,
      'Zoom to fit all notes',
    );
    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(find.byType(InteractiveViewer));
    final noteFinders = find.byType(EditableNote);
    expect(noteFinders, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      final noteRect = tester.getRect(noteFinders.at(index));
      expect(noteRect.left, greaterThanOrEqualTo(viewportRect.left + 47));
      expect(noteRect.top, greaterThanOrEqualTo(viewportRect.top + 47));
      expect(noteRect.right, lessThanOrEqualTo(viewportRect.right - 47));
      expect(noteRect.bottom, lessThanOrEqualTo(viewportRect.bottom - 47));
    }

    final scale = viewer.transformationController!.value.getMaxScaleOnAxis();
    expect(scale, inInclusiveRange(0.1, 1.0));
  });

  testWidgets('centres one selected note then frames all notes', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 19, 18);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'single-selection-fit-board',
        name: 'Single selection fit test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.2,
        notes: [
          Note(
            id: 'fit-single',
            x: 400,
            y: 400,
            width: 260,
            height: 170,
            text: 'Centre me',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'leave-distant-single',
            x: 3400,
            y: 2500,
            width: 260,
            height: 170,
            text: 'Leave me distant',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-fit-single')));
    await tester.pumpAndSettle();

    var fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit selected note');
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('fit-single')))
          .isSelected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(find.byType(InteractiveViewer));
    final selectedRect = tester.getRect(
      find.byKey(const ValueKey('fit-single')),
    );
    expect(selectedRect.center.dx, closeTo(viewportRect.center.dx, 1));
    expect(selectedRect.center.dy, closeTo(viewportRect.center.dy, 1));
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1.0);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('leave-distant-single')))
          .overlaps(viewportRect),
      isFalse,
    );
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('fit-single')))
          .isSelected,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('redo-button')))
          .onPressed,
      isNull,
    );
    fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit all notes');

    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    final allObjectsViewport = tester.getRect(find.byType(InteractiveViewer));
    for (final noteId in ['fit-single', 'leave-distant-single']) {
      final noteRect = tester.getRect(find.byKey(ValueKey(noteId)));
      expect(noteRect.left, greaterThanOrEqualTo(allObjectsViewport.left + 47));
      expect(noteRect.top, greaterThanOrEqualTo(allObjectsViewport.top + 47));
      expect(noteRect.right, lessThanOrEqualTo(allObjectsViewport.right - 47));
      expect(
        noteRect.bottom,
        lessThanOrEqualTo(allObjectsViewport.bottom - 47),
      );
    }
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      lessThan(1.0),
    );
  });

  testWidgets('zooms to fit the selected set when several notes are selected', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 9, 16);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'selection-fit-board',
        name: 'Selection fit test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.2,
        notes: [
          Note(
            id: 'fit-first',
            x: 400,
            y: 400,
            width: 260,
            height: 170,
            text: 'Fit me',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'fit-second',
            x: 1000,
            y: 800,
            width: 260,
            height: 170,
            text: 'Fit me too',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'leave-distant',
            x: 3400,
            y: 2500,
            width: 260,
            height: 170,
            text: 'Do not fit me',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-fit-first')));
    await tester.pumpAndSettle();
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-fit-second')),
    );
    final fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit selected notes');

    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(find.byType(InteractiveViewer));
    for (final noteId in ['fit-first', 'fit-second']) {
      final noteRect = tester.getRect(find.byKey(ValueKey(noteId)));
      expect(noteRect.left, greaterThanOrEqualTo(viewportRect.left + 47));
      expect(noteRect.top, greaterThanOrEqualTo(viewportRect.top + 47));
      expect(noteRect.right, lessThanOrEqualTo(viewportRect.right - 47));
      expect(noteRect.bottom, lessThanOrEqualTo(viewportRect.bottom - 47));
    }
    final distantRect = tester.getRect(
      find.byKey(const ValueKey('leave-distant')),
    );
    expect(distantRect.overlaps(viewportRect), isFalse);
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('fit-first')))
          .isSelected,
      isFalse,
    );
    expect(
      tester
          .widget<EditableNote>(find.byKey(const ValueKey('fit-second')))
          .isSelected,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('zoom-to-fit-button')))
          .tooltip,
      'Zoom to fit all notes',
    );
  });

  testWidgets('keeps new notes inside the board at an off-board viewport', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    viewer.transformationController!.value = Matrix4.identity()
      ..setTranslationRaw(-6000, -5000, 0);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();

    final createdNote = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .last
        .note;
    expect(createdNote.x, inInclusiveRange(0, 5740));
    expect(createdNote.y, inInclusiveRange(0, 4330));
    expect(find.byKey(const ValueKey('recover-notes-button')), findsNothing);
  });

  testWidgets('recovers an existing off-board note and can undo recovery', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 6, 12);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'board-with-off-board-note',
        name: 'Recovery test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'off-board-note',
            x: -120,
            y: -100,
            width: 260,
            height: 170,
            text: 'Bring me back',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    expect(find.byKey(const ValueKey('recover-notes-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recover-notes-button')));
    await tester.pumpAndSettle();

    var note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    expect(note.x, 0);
    expect(note.y, 0);
    expect(find.byKey(const ValueKey('recover-notes-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    expect(note.x, -120);
    expect(note.y, -100);
    expect(find.byKey(const ValueKey('recover-notes-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();

    note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    expect(note.x, 0);
    expect(note.y, 0);
    expect(find.byKey(const ValueKey('recover-notes-button')), findsNothing);
  });

  testWidgets('saves and reopens notes and viewport state', (tester) async {
    final store = await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('create-note-button')));
    await tester.pumpAndSettle();
    final createdNote = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .last;
    final textField = find.byKey(
      ValueKey('note-text-field-${createdNote.note.id}'),
    );
    await tester.enterText(textField, 'Remember this board');
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    await _mouseDragFrom(
      tester,
      const Offset(760, 540),
      const Offset(-300, -200),
      buttons: kSecondaryMouseButton,
    );
    await _mouseDragFrom(
      tester,
      const Offset(760, 540),
      const Offset(-300, -200),
      buttons: kSecondaryMouseButton,
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(InteractiveViewer)),
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pumpAndSettle();
    final savedZoom = viewer.transformationController!.value
        .getMaxScaleOnAxis();
    final savedOrigin = viewer.transformationController!.toScene(Offset.zero);
    expect(savedZoom, isNot(1.0));
    expect(savedOrigin.dx, greaterThan(0));
    expect(savedOrigin.dy, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(store.board!.viewportZoom, closeTo(savedZoom, 0.001));
    expect(store.board!.viewportX, closeTo(savedOrigin.dx, 0.001));
    expect(store.board!.viewportY, closeTo(savedOrigin.dy, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(store.board!.viewportZoom, closeTo(savedZoom, 0.001));
    expect(store.board!.viewportX, closeTo(savedOrigin.dx, 0.001));
    expect(store.board!.viewportY, closeTo(savedOrigin.dy, 0.001));
    await _pumpTestApp(tester, store: store);
    await tester.pump();

    expect(find.byType(EditableNote), findsNWidgets(2));
    expect(find.text('Remember this board'), findsOneWidget);
    final restoredViewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(
      restoredViewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(savedZoom, 0.001),
    );
    final restoredOrigin = restoredViewer.transformationController!.toScene(
      Offset.zero,
    );
    expect(restoredOrigin.dx, closeTo(savedOrigin.dx, 0.001));
    expect(restoredOrigin.dy, closeTo(savedOrigin.dy, 0.001));
  });

  testWidgets('renders and preserves a saved connector behind its notes', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 15);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp),
    );

    await _pumpTestApp(tester, store: store);

    final layerFinder = find.byKey(const ValueKey('connector-layer'));
    expect(layerFinder, findsOneWidget);
    final ignorePointerAncestors = tester.widgetList<IgnorePointer>(
      find.ancestor(of: layerFinder, matching: find.byType(IgnorePointer)),
    );
    expect(ignorePointerAncestors.any((widget) => widget.ignoring), isTrue);
    final painter = tester.widget<CustomPaint>(layerFinder).painter!;
    expect(painter, isA<ConnectorPainter>());
    final segment = (painter as ConnectorPainter).segments.single;
    expect(segment.start, const Offset(560, 285));
    expect(segment.end, const Offset(800, 285));

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors.single.id, 'connector-a-b');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);

    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
  });

  testWidgets('updates connector anchors as a note moves and resizes', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 16);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _connectedBoard(timestamp: timestamp)),
    );

    ConnectorSegmentSnapshot segment() {
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('connector-layer')),
                  )
                  .painter!
              as ConnectorPainter;
      final value = painter.segments.single;
      return (start: value.start, end: value.end);
    }

    final before = segment();
    await tester.drag(
      find.byKey(const ValueKey('note-drag-handle-note-a')),
      const Offset(80, 40),
    );
    await tester.pump();
    final after = segment();

    expect(after.start, isNot(before.start));
    expect(after.end, isNot(before.end));

    await tester.drag(
      find.byKey(const ValueKey('note-resize-handle-note-a')),
      const Offset(60, 40),
    );
    await tester.pump();
    final afterResize = segment();

    expect(afterResize.start, isNot(after.start));
    expect(afterResize.end, isNot(after.end));
  });

  testWidgets('keeps a connector attached through selected group movement', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 21);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _connectedBoard(timestamp: timestamp)),
    );

    ConnectorSegmentSnapshot segment() {
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('connector-layer')),
                  )
                  .painter!
              as ConnectorPainter;
      final value = painter.segments.single;
      return (start: value.start, end: value.end);
    }

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    final before = segment();

    await tester.drag(
      find.byKey(const ValueKey('note-drag-handle-note-a')),
      const Offset(60, 30),
    );
    await tester.pump();
    final after = segment();
    final startDelta = after.start - before.start;
    final endDelta = after.end - before.end;

    expect(startDelta.dx, closeTo(endDelta.dx, 0.001));
    expect(startDelta.dy, closeTo(endDelta.dy, 0.001));
    expect(startDelta.distance, greaterThan(0));
  });

  testWidgets('deletes attached connectors and restores them with undo', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 17);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          connectorLabel: 'supports',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-note-button')));
    await tester.pumpAndSettle();

    expect(find.byType(EditableNote), findsOneWidget);
    expect(find.byKey(const ValueKey('connector-layer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();

    expect(find.byType(EditableNote), findsNWidgets(2));
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
    expect(find.text('supports'), findsOneWidget);
  });

  testWidgets('preserves connector identity through off-board recovery', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 22);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'connected-recovery-board',
        name: 'Connected recovery test',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'off-board-connected-note',
            x: -120,
            y: -100,
            width: 260,
            height: 170,
            text: 'Recover with relationship',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          Note(
            id: 'on-board-connected-note',
            x: 500,
            y: 300,
            width: 260,
            height: 170,
            text: 'Stay here',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        connectors: [
          Connector(
            id: 'recovery-connector',
            objectAId: 'off-board-connected-note',
            objectBId: 'on-board-connected-note',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('recover-notes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    expect(store.board!.connectors.single.id, 'recovery-connector');
    expect(
      store.board!.connectors.single.objectAId,
      'off-board-connected-note',
    );
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    final recoveredNote = tester.widget<EditableNote>(
      find.byKey(const ValueKey('off-board-connected-note')),
    );
    expect(recoveredNote.note.x, -120);
    expect(recoveredNote.note.y, -100);
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
  });

  testWidgets('shows the connector command only for exactly two objects', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 18);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          includeConnector: false,
          includeThirdNote: true,
        ),
      ),
    );

    const commandKey = ValueKey('connector-toggle-button');
    expect(find.byKey(commandKey), findsNothing);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(commandKey), findsNothing);

    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    expect(find.byKey(commandKey), findsOneWidget);
    expect(find.text('Connect selected objects'), findsOneWidget);

    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-c')),
    );
    expect(find.byKey(commandKey), findsNothing);
  });

  testWidgets('connects and removes a selected pair with undo and redo', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 19);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, includeConnector: false),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    await tester.tap(find.byKey(const ValueKey('connector-toggle-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
    expect(find.text('Remove connection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connector-layer')), findsNothing);
    expect(find.text('Connect selected objects'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
    expect(find.text('Remove connection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('connector-toggle-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connector-layer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors, hasLength(1));
    expect(
      store.board!.connectors.single.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpTestApp(tester, store: store);
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
  });

  testWidgets('autosaves a newly created connector', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 12, 23);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, includeConnector: false),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    await tester.tap(find.byKey(const ValueKey('connector-toggle-button')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(store.board!.connectors, hasLength(1));
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets(
    'adds edits removes and restores a connection label without changing selection',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final timestamp = DateTime.utc(2026, 8, 25, 15);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp),
      );
      await _pumpTestApp(tester, store: store);

      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      expect(find.text('Add connection label...'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('connector-label-button')));
      await tester.pumpAndSettle();
      expect(find.text('Add connection label'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('connection-label-field')),
        'supports',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-connection-label-button')),
      );
      await tester.pumpAndSettle();

      const labelKey = ValueKey('connector-label-connector-a-b');
      expect(find.byKey(labelKey), findsOneWidget);
      expect(find.text('supports'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Connection label: supports'),
        findsOneWidget,
      );
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      final pointerBlockers = tester.widgetList<IgnorePointer>(
        find.ancestor(
          of: find.byKey(labelKey),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(pointerBlockers.every((widget) => !widget.ignoring), isTrue);

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(labelKey), findsNothing);
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});

      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.text('supports'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('connector-label-button')));
      await tester.pumpAndSettle();
      expect(find.text('Edit connection label'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('connection-label-field')),
      );
      expect(field.controller!.text, 'supports');
      await tester.enterText(
        find.byKey(const ValueKey('connection-label-field')),
        '   ',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-connection-label-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(labelKey), findsNothing);
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.connectors.single.label, isNull);
      semantics.dispose();
    },
  );

  testWidgets('context menu edits the exact selected connection label', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 25, 15, 5);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, connectorLabel: 'supports'),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );

    expect(
      find.byKey(const ValueKey('context-connection-label-menu-item')),
      findsOneWidget,
    );
    expect(find.text('Edit connection label...'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const ValueKey('context-connection-label-menu-item')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-copy-menu-item')), findsNothing);
    expect(find.text('Edit connection label'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('connection-label-field')),
      List.filled(81, 'a').join(),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-connection-label-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    expect(store.board!.connectors.single.label!.runes.length, 80);
    expect(store.board!.connectors.single.objectAId, 'note-a');
    expect(store.board!.connectors.single.objectBId, 'note-b');
  });

  testWidgets('copy and paste preserves an internal connection label', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 25, 15, 10);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, connectorLabel: 'supports'),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    expect(find.text('supports'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors, hasLength(2));
    expect(
      store.board!.connectors.map((connector) => connector.label),
      everyElement('supports'),
    );
    expect(
      store.board!.connectors.map((connector) => connector.id).toSet(),
      hasLength(2),
    );
  });

  testWidgets('connection label follows its connector as an endpoint moves', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 25, 15, 15);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          connectorLabel: 'supports',
        ),
      ),
    );
    const labelKey = ValueKey('connector-label-connector-a-b');
    final before = tester.getCenter(find.byKey(labelKey));

    await tester.drag(
      find.byKey(const ValueKey('note-drag-handle-note-a')),
      const Offset(80, 40),
    );
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.byKey(labelKey)), isNot(before));
  });

  testWidgets('clicking a connection label edits its exact connector', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 25, 15, 16);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, connectorLabel: 'supports'),
    );
    await _pumpTestApp(tester, store: store);
    expect(_selectedNoteIds(tester), isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('connector-label-connector-a-b')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit connection label'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('connection-label-field')),
    );
    expect(field.controller!.text, 'supports');
    await tester.enterText(
      find.byKey(const ValueKey('connection-label-field')),
      'depends on',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-connection-label-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('depends on'), findsOneWidget);
    expect(_selectedNoteIds(tester), isEmpty);
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.connectors.single.label, 'depends on');
  });

  testWidgets(
    'clicking an unlabeled connection line adds its label with normal history',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final timestamp = DateTime.utc(2026, 8, 29, 10);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp),
      );
      await _pumpTestApp(tester, store: store);
      const targetKey = ValueKey('connection-line-label-target-connector-a-b');

      expect(_selectedNoteIds(tester), isEmpty);
      expect(
        find.bySemanticsLabel('Unlabeled connection. Add connection label'),
        findsOneWidget,
      );
      final targetRect = tester.getRect(find.byKey(targetKey));
      await tester.tapAt(
        Offset(targetRect.left + targetRect.width * 0.25, targetRect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add connection label'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('connection-label-field')),
        'supports',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-connection-label-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('supports'), findsOneWidget);
      expect(_selectedNoteIds(tester), isEmpty);
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.text('supports'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.text('supports'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'clicking a labeled connection line edits it and cancel is a no-op',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 29, 10, 5);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          connectorLabel: 'supports',
        ),
      );
      await _pumpTestApp(tester, store: store);
      const targetKey = ValueKey('connection-line-label-target-connector-a-b');

      final targetRect = tester.getRect(find.byKey(targetKey));
      await tester.tapAt(
        Offset(targetRect.left + targetRect.width * 0.25, targetRect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit connection label'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('connection-label-field')),
      );
      expect(field.controller!.text, 'supports');
      await tester.enterText(
        find.byKey(const ValueKey('connection-label-field')),
        'changed but cancelled',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.board!.connectors.single.label, 'supports');
      expect(_selectedNoteIds(tester), isEmpty);
      final undoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('undo-button')),
      );
      expect(undoButton.onPressed, isNull);
    },
  );

  testWidgets('connection line hit target remains constant in screen space', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 29, 10, 10);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _connectedBoard(timestamp: timestamp)),
    );
    const targetKey = ValueKey('connection-line-label-target-connector-a-b');
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    final initialHeight = tester.getSize(find.byKey(targetKey)).height;
    expect(initialHeight * 0.75, closeTo(18, 0.001));

    controller.value = Matrix4.diagonal3Values(0.5, 0.5, 0.5);
    await tester.pump();
    final distantHeight = tester.getSize(find.byKey(targetKey)).height;

    expect(distantHeight * 0.5, closeTo(18, 0.001));
    expect(distantHeight, greaterThan(initialHeight));
  });

  testWidgets(
    'hovering a connection line highlights only it without mutation',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 29, 11);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp),
      );
      await _pumpTestApp(tester, store: store);
      const targetKey = ValueKey('connection-line-label-target-connector-a-b');
      ConnectorPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('connector-layer')),
                  )
                  .painter!
              as ConnectorPainter;
      final savesBefore = store.saveCalls;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await tester.pump();

      expect(painter().hoveredConnectorId, isNull);
      final targetRect = tester.getRect(find.byKey(targetKey));
      final targetPoint = Offset(
        targetRect.left + targetRect.width * 0.25,
        targetRect.center.dy,
      );
      await mouse.moveTo(targetPoint);
      await tester.pump();

      expect(painter().hoveredConnectorId, 'connector-a-b');
      expect(_selectedNoteIds(tester), isEmpty);
      expect(store.saveCalls, savesBefore);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await mouse.down(targetPoint);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('Add connection label'), findsOneWidget);
      expect(painter().hoveredConnectorId, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await mouse.moveTo(const Offset(10, 10));
      await tester.pump();
      expect(painter().hoveredConnectorId, isNull);
      await mouse.removePointer();
    },
  );

  testWidgets('label and distant marker hover highlight their exact line', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 29, 11, 5);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          connectorLabel: 'supports',
        ),
      ),
    );
    ConnectorPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connector-layer')),
                )
                .painter!
            as ConnectorPainter;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    final lineRect = tester.getRect(
      find.byKey(const ValueKey('connection-line-label-target-connector-a-b')),
    );
    await mouse.moveTo(
      Offset(lineRect.left + lineRect.width * 0.25, lineRect.center.dy),
    );
    await tester.pump();
    expect(painter().hoveredConnectorId, 'connector-a-b');
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('connector-label-connector-a-b')),
      ),
    );
    await tester.pump();

    expect(painter().hoveredConnectorId, 'connector-a-b');

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    controller.value = Matrix4.diagonal3Values(0.3, 0.3, 0.3);
    await tester.pump();
    await mouse.moveTo(const Offset(10, 10));
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('connector-label-marker-connector-a-b')),
      ),
    );
    await tester.pump();

    expect(painter().hoveredConnectorId, 'connector-a-b');
    final hoveredStroke = painter().strokes.single;
    expect(
      hoveredStroke.strokeWidth * 0.3,
      closeTo(ConnectorPainter.hoveredScreenStrokeWidth, 0.001),
    );
    await mouse.removePointer();
  });

  testWidgets('crossing line hover follows stable connector order', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 29, 11, 10);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _crossingConnectorBoard(timestamp)),
    );
    final layerFinder = find.byKey(const ValueKey('connector-layer'));
    final layer = tester.renderObject<RenderBox>(layerFinder);
    final painter =
        tester.widget<CustomPaint>(layerFinder).painter! as ConnectorPainter;
    final segments = painter.segments;
    final crossingPoint = Offset(
      (segments.first.start.dx + segments.first.end.dx) / 2,
      (segments.first.start.dy + segments.first.end.dy) / 2,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(layer.localToGlobal(crossingPoint));
    await tester.pump();

    final hoveredPainter =
        tester.widget<CustomPaint>(layerFinder).painter! as ConnectorPainter;
    expect(hoveredPainter.hoveredConnectorId, 'connector-c-d');
    expect(_selectedNoteIds(tester), isEmpty);
    await mouse.removePointer();
  });

  testWidgets(
    'connection line context menu is exact and dismissal is non-mutating',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 30, 9);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp),
      );
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      final savesBefore = store.saveCalls;
      const targetKey = ValueKey('connection-line-label-target-connector-a-b');
      final targetRect = tester.getRect(find.byKey(targetKey));

      await tester.tapAt(
        Offset(targetRect.left + targetRect.width * 0.25, targetRect.center.dy),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('connection-context-label-menu-item')),
        findsOneWidget,
      );
      expect(find.text('Add connection label...'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connection-context-remove-menu-item')),
        findsOneWidget,
      );
      expect(find.text('Remove connection'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('context-paste-menu-item')),
        findsNothing,
        reason: 'The ancestor canvas menu must not stack over this menu.',
      );
      expect(_selectedNoteIds(tester), {'note-a'});

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_selectedNoteIds(tester), {'note-a'});
      expect(store.saveCalls, savesBefore);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
      expect(store.board!.connectors, hasLength(1));
    },
  );

  testWidgets(
    'connection label and marker context menus edit the exact label',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 30, 9, 5);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          connectorLabel: 'supports',
        ),
      );
      await _pumpTestApp(tester, store: store);

      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('connector-label-control-connector-a-b')),
      );
      expect(find.text('Edit connection label...'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('connection-context-label-menu-item')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit connection label'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('connection-label-field')),
            )
            .controller!
            .text,
        'supports',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.3, 0.3, 0.3);
      await tester.pump();
      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('connector-label-marker-connector-a-b')),
      );

      expect(find.text('Edit connection label...'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connection-context-remove-menu-item')),
        findsOneWidget,
      );
      expect(_selectedNoteIds(tester), isEmpty);
    },
  );

  testWidgets(
    'connection context removal is exact undoable and persists on reopen',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 30, 9, 10);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          includeThirdNote: true,
          includeExternalConnector: true,
        ),
      );
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-c')));

      await _secondaryTap(
        tester,
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-b'),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('connection-context-remove-menu-item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-b'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-c'),
        ),
        findsOneWidget,
      );
      expect(_selectedNoteIds(tester), {'note-c'});

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-b'),
        ),
        findsOneWidget,
      );
      expect(_selectedNoteIds(tester), {'note-c'});

      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.connectors.map((connector) => connector.id), [
        'connector-a-c',
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpTestApp(tester, store: store);
      expect(
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-b'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-c'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('crossing line context menu follows stable connector order', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 30, 9, 15);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _crossingConnectorBoard(timestamp)),
    );
    final layerFinder = find.byKey(const ValueKey('connector-layer'));
    final layer = tester.renderObject<RenderBox>(layerFinder);
    final painter =
        tester.widget<CustomPaint>(layerFinder).painter! as ConnectorPainter;
    final crossingPoint = Offset(
      (painter.segments.first.start.dx + painter.segments.first.end.dx) / 2,
      (painter.segments.first.start.dy + painter.segments.first.end.dy) / 2,
    );

    await tester.tapAt(
      layer.localToGlobal(crossingPoint),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('connection-context-remove-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-line-label-target-connector-a-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('connection-line-label-target-connector-c-d')),
      findsNothing,
    );
  });

  testWidgets(
    'connect with label overlay keeps cancel blank and instant connect bounded',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 30, 12);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp, includeConnector: false),
      );
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      final savesBefore = store.saveCalls;

      expect(
        find.byKey(const ValueKey('connector-with-label-button')),
        findsOneWidget,
      );
      expect(find.text('Connect with label...'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connector-toggle-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('connector-with-label-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add connection label'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('connection-line-label-target-connector-a-b'),
        ),
        findsNothing,
      );
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      expect(store.saveCalls, savesBefore);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('connector-with-label-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('connection-label-field')),
        '   ',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-connection-label-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('connector-layer')), findsNothing);
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      expect(store.saveCalls, savesBefore);

      await tester.tap(find.byKey(const ValueKey('connector-toggle-button')));
      await tester.pumpAndSettle();

      expect(find.text('Add connection label'), findsNothing);
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connector-with-label-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'context connect with label is one persistent identity-preserving action',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 30, 12, 5);
      final store = _MemoryBoardStore(
        board: _connectedBoard(timestamp: timestamp, includeConnector: false),
      );
      await _pumpTestApp(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );

      expect(
        find.byKey(const ValueKey('context-connect-with-label-menu-item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('context-connection-menu-item')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('context-connect-with-label-menu-item')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('connection-label-field')),
        'supports',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-connection-label-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('supports'), findsOneWidget);
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      final connectorId = store.board!.connectors.single.id;
      expect(store.board!.connectors.single.label, 'supports');

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.text('supports'), findsNothing);
      expect(_selectedNoteIds(tester), {'note-a', 'note-b'});
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.connectors.single.id, connectorId);
      expect(store.board!.connectors.single.label, 'supports');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpTestApp(tester, store: store);
      expect(find.text('supports'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      expect(
        find.byKey(const ValueKey('context-connect-with-label-menu-item')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('context-connection-label-menu-item')),
        findsOneWidget,
      );
    },
  );

  testWidgets('connect with label is eligible for mixed and image pairs', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 30, 12, 10);
    final mixedStore = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: timestamp,
        includeConnector: false,
        images: [_testBoardImage(timestamp: timestamp, x: 650, y: 500)],
      ),
    );
    await _pumpTestApp(
      tester,
      store: mixedStore,
      imageViewBuilder: (image) => SizedBox(
        key: ValueKey('connect-label-mixed-image-${image.id}'),
        width: image.width,
        height: image.height,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    expect(
      find.byKey(const ValueKey('connector-with-label-button')),
      findsOneWidget,
    );
    await _secondaryTap(
      tester,
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    expect(
      find.byKey(const ValueKey('context-connect-with-label-menu-item')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    BoardImage image(String id, double x) => BoardImage(
      id: id,
      x: x,
      y: 300,
      width: 320,
      height: 180,
      assetPath: 'assets/$id.png',
      originalFileName: '$id.png',
      pixelWidth: 1600,
      pixelHeight: 900,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final imageStore = _MemoryBoardStore(
      board: BoardDocument(
        id: 'connect-with-label-images',
        name: 'Connect with label images',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.75,
        notes: const [],
        images: [image('image-a', 100), image('image-b', 650)],
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MainApp(
        boardStore: imageStore,
        imageAssetStore: _TestImageAssetStore(resolveError: true),
        imagePicker: () async => null,
        imageViewBuilder: (image) => SizedBox(
          key: ValueKey('connect-label-image-${image.id}'),
          width: image.width,
          height: image.height,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('image-drag-surface-image-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('image-drag-surface-image-b')),
    );

    expect(
      find.byKey(const ValueKey('connector-with-label-button')),
      findsOneWidget,
    );
    expect(_selectedImageIds(tester), {'image-a', 'image-b'});
  });

  testWidgets('shows the live canvas zoom as a percentage', (tester) async {
    final semantics = tester.ensureSemantics();
    final timestamp = DateTime.utc(2026, 8, 25, 15, 17);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _connectedBoard(timestamp: timestamp)),
    );

    expect(find.byKey(const ValueKey('zoom-indicator')), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    controller.value = Matrix4.diagonal3Values(0.5, 0.5, 0.5);
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);
    expect(find.bySemanticsLabel('Canvas zoom: 50 percent'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('find defaults to unchanged note results and cancel is a no-op', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _noteSearchBoard());
    await _pumpTestApp(
      tester,
      store: store,
      imageViewBuilder: _searchImageView,
    );
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-search-a')));
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final transformBefore = List<double>.of(controller.value.storage);
    final savesBefore = store.saveCalls;

    expect(find.text('Find on board'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('find-board-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('find-mode-notes')), findsOneWidget);
    expect(find.byKey(const ValueKey('find-mode-images')), findsOneWidget);
    expect(find.byKey(const ValueKey('find-mode-connections')), findsOneWidget);
    final modeControl = tester.widget<SegmentedButton<String>>(
      find.byKey(const ValueKey('find-mode-control')),
    );
    expect(modeControl.selected, {'notes'});
    expect(
      find.text('Type words from a note or heading to search this board.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'missing words',
    );
    await tester.pump();
    expect(
      find.text('No notes or headings match your search.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'fretflip',
    );
    await tester.pump();
    final titleResult = find.byKey(const ValueKey('find-note-result-search-a'));
    expect(titleResult, findsOneWidget);
    expect(
      find.descendant(of: titleResult, matching: find.text('FretFlip release')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      '  SHARED phrase ',
    );
    await tester.pump();
    expect(find.text('2 results'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('find-note-result-search-b')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('find-note-result-search-d')))
            .dy,
      ),
    );
    expect(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('find-board-results')),
              matching: find.byType(Text),
            ),
          )
          .every((text) => !(text.data ?? '').contains('\n')),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('find-note-result-search-empty')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('close-find-board-button')));
    await tester.pumpAndSettle();
    expect(_selectedNoteIds(tester), {'search-a'});
    expect(controller.value.storage, transformBefore);
    expect(store.saveCalls, savesBefore);

    await _sendShortcut(tester, LogicalKeyboardKey.keyF);
    expect(find.byKey(const ValueKey('find-board-dialog')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('find-board-dialog')), findsNothing);
  });

  testWidgets('find reports empty modes with an accessible mode control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final timestamp = DateTime.utc(2026, 8, 26, 12, 30);
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'empty-search-board',
        name: 'Empty search board',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.75,
        notes: [
          Note(
            id: 'blank-note',
            x: 200,
            y: 200,
            width: 260,
            height: 170,
            text: '   ',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('find-board-button')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        'Choose whether to search notes, images, or connections',
      ),
      findsOneWidget,
    );
    expect(
      find.text('This board has no notes or headings to search.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('find-mode-images')));
    await tester.pump();
    expect(find.text('This board has no images to search.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('find-mode-connections')));
    await tester.pump();
    expect(
      find.text('This board has no labeled connections to search.'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'find result selects and recenters at current zoom without history',
    (tester) async {
      final store = _MemoryBoardStore(board: _noteSearchBoard());
      await _pumpTestApp(
        tester,
        store: store,
        imageViewBuilder: _searchImageView,
      );
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(7));
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-search-a')));
      await tester.pumpAndSettle();
      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      final zoomBefore = controller.value.getMaxScaleOnAxis();

      await tester.tap(find.byKey(const ValueKey('find-board-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'distant lighthouse',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-note-result-search-target')),
      );
      await tester.pumpAndSettle();

      expect(_selectedNoteIds(tester), {'search-target'});
      expect(_selectedImageIds(tester), isEmpty);
      expect(controller.value.getMaxScaleOnAxis(), closeTo(zoomBefore, 0.001));
      final canvasCenter = controller.toScene(
        tester.getSize(viewerFinder).center(Offset.zero),
      );
      expect(canvasCenter.dx, closeTo(3130, 0.001));
      expect(canvasCenter.dy, closeTo(2085, 0.001));
      final overviewPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-overview-paint')),
                  )
                  .painter!
              as CanvasOverviewPainter;
      expect(
        overviewPainter.objects
            .singleWhere((object) => object.id == 'search-target')
            .isSelected,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(6));
    },
  );

  testWidgets(
    'image mode reuses query and selects exact image at current zoom without history',
    (tester) async {
      final store = _MemoryBoardStore(board: _noteSearchBoard());
      await _pumpTestApp(
        tester,
        store: store,
        imageViewBuilder: _searchImageView,
      );
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(7));
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-search-a')));
      await tester.pumpAndSettle();
      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      final zoomBefore = controller.value.getMaxScaleOnAxis();

      await tester.tap(find.byKey(const ValueKey('find-board-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'shared reference',
      );
      await tester.pump();
      expect(
        find.text('No notes or headings match your search.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('find-mode-images')));
      await tester.pump();
      expect(find.text('2 results'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('find-image-result-image-a')))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('find-image-result-image-b')),
              )
              .dy,
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'absent filename',
      );
      await tester.pump();
      expect(
        find.text('No image captions or filenames match your search.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'unavailable diagram',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('find-image-result-image-missing')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'distant lighthouse',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-image-result-image-target')),
      );
      await tester.pumpAndSettle();

      expect(_selectedNoteIds(tester), isEmpty);
      expect(_selectedImageIds(tester), {'image-target'});
      expect(controller.value.getMaxScaleOnAxis(), closeTo(zoomBefore, 0.001));
      final canvasCenter = controller.toScene(
        tester.getSize(viewerFinder).center(Offset.zero),
      );
      expect(canvasCenter.dx, closeTo(3360, 0.001));
      expect(canvasCenter.dy, closeTo(2390, 0.001));
      final overviewPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-overview-paint')),
                  )
                  .painter!
              as CanvasOverviewPainter;
      expect(
        overviewPainter.objects
            .singleWhere((object) => object.id == 'image-target')
            .isSelected,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(6));
    },
  );

  testWidgets(
    'connections mode finds labels and navigates exact endpoints without history',
    (tester) async {
      final store = _MemoryBoardStore(board: _noteSearchBoard());
      await _pumpTestApp(
        tester,
        store: store,
        imageViewBuilder: _searchImageView,
      );
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(7));
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-search-a')));
      await tester.pumpAndSettle();
      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      final zoomBefore = controller.value.getMaxScaleOnAxis();

      await tester.tap(find.byKey(const ValueKey('find-board-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'shared link',
      );
      await tester.pump();
      expect(
        find.text('No notes or headings match your search.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('find-mode-connections')));
      await tester.pump();
      expect(find.text('2 results'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('find-connection-result-connection-a')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('find-connection-result-connection-b'),
                ),
              )
              .dy,
        ),
      );
      expect(
        find.byKey(
          const ValueKey('find-connection-result-connection-unlabeled'),
        ),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'absent relationship',
      );
      await tester.pump();
      expect(
        find.text('No connection labels match your search.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'unavailable endpoint',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-connection-result-connection-missing')),
      );
      await tester.pumpAndSettle();
      expect(_selectedNoteIds(tester), {'search-other'});
      expect(_selectedImageIds(tester), {'image-missing'});

      await tester.tap(find.byKey(const ValueKey('find-board-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('find-mode-connections')));
      await tester.enterText(
        find.byKey(const ValueKey('find-board-field')),
        'distant relationship',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('find-connection-result-connection-target')),
      );
      await tester.pumpAndSettle();

      expect(_selectedNoteIds(tester), {'search-target'});
      expect(_selectedImageIds(tester), {'image-target'});
      expect(controller.value.getMaxScaleOnAxis(), closeTo(zoomBefore, 0.001));
      final segment = ConnectorGeometry.betweenRects(
        const Rect.fromLTWH(3000, 2000, 260, 170),
        const Rect.fromLTWH(3200, 2300, 320, 180),
      );
      final expectedMidpoint = Offset(
        (segment.start.dx + segment.end.dx) / 2,
        (segment.start.dy + segment.end.dy) / 2,
      );
      final canvasCenter = controller.toScene(
        tester.getSize(viewerFinder).center(Offset.zero),
      );
      expect(canvasCenter.dx, closeTo(expectedMidpoint.dx, 0.001));
      expect(canvasCenter.dy, closeTo(expectedMidpoint.dy, 0.001));
      final overviewPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-overview-paint')),
                  )
                  .painter!
              as CanvasOverviewPainter;
      expect(
        overviewPainter.objects
            .where(
              (object) => {'search-target', 'image-target'}.contains(object.id),
            )
            .every((object) => object.isSelected),
        isTrue,
      );
      expect(find.text('Remove connection'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connector-label-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('connector-label-control-connection-target')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit connection label'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(6));
    },
  );

  testWidgets('find shortcut respects note editing and another modal route', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _noteSearchBoard()),
      imageViewBuilder: _searchImageView,
    );
    final field = find.byKey(const ValueKey('note-text-field-search-a'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('EDITING'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('find-board-button')))
          .onPressed,
      isNull,
    );
    await _sendShortcut(tester, LogicalKeyboardKey.keyF);
    expect(find.byKey(const ValueKey('find-board-dialog')), findsNothing);
    expect(find.text('EDITING'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-search-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rename-active-board-button')));
    await tester.pumpAndSettle();
    await _sendShortcut(tester, LogicalKeyboardKey.keyF);
    expect(find.byKey(const ValueKey('board-name-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('find-board-dialog')), findsNothing);
  });

  testWidgets('find dialog modes remain usable at 800 by 600', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _noteSearchBoard()),
      imageViewBuilder: _searchImageView,
    );

    expect(find.text('Find on board'), findsOneWidget);
    final actionRect = tester.getRect(
      find.byKey(const ValueKey('find-board-button')),
    );
    expect(actionRect.left, greaterThanOrEqualTo(0));
    expect(actionRect.top, greaterThanOrEqualTo(0));
    expect(actionRect.right, lessThanOrEqualTo(800));
    expect(actionRect.bottom, lessThanOrEqualTo(600));
    await tester.tap(find.byKey(const ValueKey('find-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'shared phrase',
    );
    await tester.pump();
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('find-board-dialog')),
    );
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(800));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));
    expect(find.byKey(const ValueKey('find-board-results')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('find-mode-images')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'shared reference',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('find-board-results')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('find-mode-connections')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'shared link',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('find-board-results')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('close-find-board-button')),
      findsOneWidget,
    );
  });

  testWidgets('overview shows current objects links and viewport', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final timestamp = DateTime.utc(2026, 8, 25, 16, 30);
    await tester.pumpWidget(
      MainApp(
        boardStore: _MemoryBoardStore(
          board: _connectedBoard(
            timestamp: timestamp,
            images: [_testBoardImage(timestamp: timestamp, x: 1400, y: 900)],
          ),
        ),
        imageAssetStore: _TestImageAssetStore(resolveError: true),
        imagePicker: () async => null,
        imageViewBuilder: (current) =>
            SizedBox(width: current.width, height: current.height),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CanvasOverviewMap), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Canvas overview showing 3 objects and the current viewport',
      ),
      findsOneWidget,
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('canvas-overview-paint')),
                )
                .painter!
            as CanvasOverviewPainter;
    expect(painter.objects, hasLength(3));
    expect(painter.links, hasLength(1));
    expect(
      painter.objects,
      everyElement(
        predicate<CanvasOverviewObject>((object) => !object.isSelected),
      ),
    );
    expect(painter.viewportRect.width, greaterThan(0));
    expect(painter.viewportRect.height, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await tester.pump();
    final selectedPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('canvas-overview-paint')),
                )
                .painter!
            as CanvasOverviewPainter;
    expect(
      selectedPainter.objects
          .singleWhere((object) => object.id == 'note-a')
          .isSelected,
      isTrue,
    );
    expect(
      selectedPainter.objects
          .where((object) => object.id != 'note-a')
          .every((object) => !object.isSelected),
      isTrue,
    );
    expect(
      CanvasOverviewPainter.selectedObjectOutlineWidth,
      greaterThan(CanvasOverviewPainter.normalObjectOutlineWidth),
    );
    semantics.dispose();
  });

  testWidgets('overview viewport outline follows zoom', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 25, 16, 31);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(board: _connectedBoard(timestamp: timestamp)),
    );
    CanvasOverviewPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('canvas-overview-paint')),
                )
                .painter!
            as CanvasOverviewPainter;
    final initialViewport = painter().viewportRect;
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    controller.value = Matrix4.diagonal3Values(1, 1, 1);
    await tester.pump();

    expect(painter().viewportRect.width, lessThan(initialViewport.width));
    expect(painter().viewportRect.height, lessThan(initialViewport.height));
  });

  testWidgets(
    'overview click recenters without changing selection or history',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 25, 16, 32);
      await _pumpTestApp(
        tester,
        store: _MemoryBoardStore(board: _connectedBoard(timestamp: timestamp)),
      );
      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pumpAndSettle();
      final createdNote = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .last;
      expect(_selectedNoteIds(tester), {createdNote.note.id});
      expect(
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('canvas-overview-paint')),
                    )
                    .painter!
                as CanvasOverviewPainter)
            .objects,
        hasLength(3),
      );

      final viewerFinder = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!;
      final zoomBefore = controller.value.getMaxScaleOnAxis();
      final overviewFinder = find.byKey(const ValueKey('canvas-overview-map'));
      await tester.tapAt(
        tester.getTopLeft(overviewFinder) + const Offset(150, 100),
      );
      await tester.pump();

      final viewportCenter = tester.getSize(viewerFinder).center(Offset.zero);
      final canvasCenter = controller.toScene(viewportCenter);
      expect(controller.value.getMaxScaleOnAxis(), closeTo(zoomBefore, 0.001));
      expect(canvasCenter.dx, closeTo(6000 * 150 / 180, 0.001));
      expect(canvasCenter.dy, closeTo(4500 * 100 / 135, 0.001));
      expect(_selectedNoteIds(tester), {createdNote.note.id});

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableNote), findsNWidgets(2));
      expect(
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('canvas-overview-paint')),
                    )
                    .painter!
                as CanvasOverviewPainter)
            .objects,
        hasLength(2),
      );
    },
  );

  testWidgets(
    'overview coexists with recovery and relationship controls at 800 pixels',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final timestamp = DateTime.utc(2026, 8, 25, 16, 33);
      final base = _connectedBoard(timestamp: timestamp);
      final board = BoardDocument(
        id: base.id,
        name: base.name,
        createdAt: base.createdAt,
        modifiedAt: base.modifiedAt,
        viewportX: base.viewportX,
        viewportY: base.viewportY,
        viewportZoom: base.viewportZoom,
        notes: [
          base.notes.first,
          base.notes.last.copyWith(x: 500),
          Note(
            id: 'off-board-overview-note',
            x: -120,
            y: -100,
            width: 260,
            height: 170,
            text: 'Recover me',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        connectors: base.connectors,
      );
      await _pumpTestApp(tester, store: _MemoryBoardStore(board: board));
      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );

      final overviewRect = tester.getRect(
        find.byKey(const ValueKey('canvas-overview-map')),
      );
      final recoveryRect = tester.getRect(
        find.byKey(const ValueKey('recover-notes-button')),
      );
      final relationshipRect = tester.getRect(
        find.byKey(const ValueKey('connector-toggle-button')),
      );
      expect(overviewRect.top, greaterThan(recoveryRect.bottom));
      expect(overviewRect.overlaps(relationshipRect), isFalse);
      expect(overviewRect.left, greaterThanOrEqualTo(0));
      expect(overviewRect.right, lessThanOrEqualTo(800));
      expect(overviewRect.bottom, lessThanOrEqualTo(600));
    },
  );

  testWidgets('connection labels shrink then collapse to an outlined marker', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final timestamp = DateTime.utc(2026, 8, 25, 15, 18);
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          connectorLabel: 'supports',
        ),
      ),
    );
    const labelKey = ValueKey('connector-label-connector-a-b');
    final initialRect = tester.getRect(find.byKey(labelKey));

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    controller.value = Matrix4.diagonal3Values(0.5, 0.5, 0.5);
    await tester.pump();
    final smallerRect = tester.getRect(find.byKey(labelKey));

    expect(smallerRect.width, lessThan(initialRect.width));
    expect(find.text('supports'), findsOneWidget);

    controller.value = Matrix4.diagonal3Values(0.3, 0.3, 0.3);
    await tester.pump();

    expect(find.text('supports'), findsNothing);
    expect(
      find.byKey(const ValueKey('connector-label-marker-connector-a-b')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Connection label: supports'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('connector-label-marker-connector-a-b')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit connection label'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('label dialog cancel and unchanged submit are history no-ops', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 25, 15, 20);
    final store = _MemoryBoardStore(
      board: _connectedBoard(timestamp: timestamp, connectorLabel: 'supports'),
    );
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('note-drag-handle-note-b')),
    );

    await tester.tap(find.byKey(const ValueKey('connector-label-button')));
    await tester.pumpAndSettle();
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(find.text('Edit connection label'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('connector-label-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-connection-label-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('supports'), findsOneWidget);
    expect(store.saveCalls, 0);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('renders labels for every supported endpoint pair type', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 25, 15, 25);
    BoardImage image(String id, double x) => BoardImage(
      id: id,
      x: x,
      y: 500,
      width: 240,
      height: 180,
      assetPath: 'assets/$id.png',
      originalFileName: '$id.png',
      pixelWidth: 800,
      pixelHeight: 600,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    Connector connector(String id, String a, String b, String label) =>
        Connector(
          id: id,
          objectAId: a,
          objectBId: b,
          label: label,
          createdAt: timestamp,
          modifiedAt: timestamp,
        );
    final board = _connectedBoard(
      timestamp: timestamp,
      images: [image('image-a', 500), image('image-b', 900)],
    );
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: board.id,
        name: board.name,
        createdAt: board.createdAt,
        modifiedAt: board.modifiedAt,
        viewportX: board.viewportX,
        viewportY: board.viewportY,
        viewportZoom: board.viewportZoom,
        notes: board.notes,
        images: board.images,
        connectors: [
          connector('note-note', 'note-a', 'note-b', 'supports'),
          connector('note-image', 'note-b', 'image-a', 'illustrates'),
          connector('image-image', 'image-a', 'image-b', 'compare'),
        ],
      ),
    );

    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        imageAssetStore: _TestImageAssetStore(resolveError: true),
        imagePicker: () async => null,
        imageViewBuilder: (image) => SizedBox(
          key: ValueKey('test-image-${image.id}'),
          width: image.width,
          height: image.height,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final id in ['note-note', 'note-image', 'image-image']) {
      expect(find.byKey(ValueKey('connector-label-$id')), findsOneWidget);
    }
  });

  testWidgets('failed loading cannot edit or save a replacement Board', (
    tester,
  ) async {
    final store = _FailingBoardStore();
    await tester.pumpWidget(MainApp(boardStore: store));
    await tester.pumpAndSettle();

    expect(find.byType(EditableNote), findsNothing);
    expect(find.text('Could not open saved board'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Retry opening'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(store.saveCalls, 0);
  });

  testWidgets(
    'normal exit waits for the latest revision during an active save',
    (tester) async {
      final store = _DelayedBoardStore();
      await tester.pumpWidget(MainApp(boardStore: store));
      await tester.pumpAndSettle();
      // The new-board save starts, but remains pending until the disk responds.
      await tester.pump(const Duration(milliseconds: 700));
      expect(store.saveCalls, 1);
      await tester.tap(find.byType(EditableNote).first);
      await tester.enterText(find.byType(TextField).last, 'Latest knowledge');
      await tester.pump();
      final exit = tester.binding.handleRequestAppExit();
      await tester.pump();
      expect(find.text('Saving your changes before closing…'), findsOneWidget);
      store.release.complete();
      await tester.pumpAndSettle();
      expect(await exit, AppExitResponse.exit);
      expect(store.board!.notes.single.text, 'Latest knowledge');
      expect(store.saveCalls, 2);
    },
  );

  testWidgets('save failure cancels exit and keeps unsaved work available', (
    tester,
  ) async {
    final store = _SaveFailingBoardStore();
    await tester.pumpWidget(MainApp(boardStore: store));
    await tester.pumpAndSettle();
    final exit = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    expect(
      find.text('Your latest changes have not been saved'),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep open'));
    await tester.pumpAndSettle();
    expect(await exit, AppExitResponse.cancel);
    expect(find.byType(EditableNote), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);
    store.fail = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('cancelled image import leaves board and history unchanged', (
    tester,
  ) async {
    final boardStore = _MemoryBoardStore();
    final imageStore = _TestImageAssetStore();
    await tester.pumpWidget(
      MainApp(
        boardStore: boardStore,
        imageAssetStore: imageStore,
        imagePicker: () async => null,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-image-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(imageStore.importCalls, 0);
    expect(find.byType(ManagedImageView), findsNothing);
    final undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('undo-button')),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('imports, renders, saves, undoes, and redoes an image', (
    tester,
  ) async {
    final boardStore = _MemoryBoardStore();
    final imageStore = _TestImageAssetStore(
      importedAsset: const ManagedImageAsset(
        assetPath: 'assets/imported.png',
        originalFileName: 'reference.png',
        pixelWidth: 1,
        pixelHeight: 1,
      ),
    );
    await tester.pumpWidget(
      MainApp(
        boardStore: boardStore,
        imageAssetStore: imageStore,
        imagePicker: () async => 'C:\\reference.png',
        imageViewBuilder: (image) => SizedBox(
          key: ValueKey('test-image-${image.id}'),
          width: image.width,
          height: image.height,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-image-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(imageStore.importCalls, 1);
    final testImageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('test-image-'),
    );
    expect(testImageFinder, findsOneWidget);
    final renderedImage = tester.widget<SizedBox>(testImageFinder);
    expect(renderedImage.width, 360);
    expect(renderedImage.height, 360);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
    expect(boardStore.board!.images, hasLength(1));
    final savedImageId = boardStore.board!.images.single.id;

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    expect(find.byKey(ValueKey('test-image-$savedImageId')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump();
    expect(find.byKey(ValueKey('test-image-$savedImageId')), findsOneWidget);
  });

  testWidgets('shows a stable placeholder for a missing managed image', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final missingImage = BoardImage(
      id: 'missing-image',
      x: 400,
      y: 300,
      width: 320,
      height: 180,
      assetPath: 'assets/missing.png',
      originalFileName: 'lost-reference.png',
      pixelWidth: 1600,
      pixelHeight: 900,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final board = _connectedBoard(
      timestamp: timestamp,
      images: [missingImage],
      connectorObjectBId: missingImage.id,
    );
    final imageStore = _TestImageAssetStore(resolveError: true);
    await tester.pumpWidget(
      MainApp(
        boardStore: _MemoryBoardStore(board: board),
        imageAssetStore: imageStore,
        imagePicker: () async => null,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('missing-image-missing-image')),
      findsOneWidget,
    );
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(find.text('lost-reference.png'), findsOneWidget);
    expect(tester.getSize(find.byType(ManagedImageView)), const Size(320, 180));
    expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connector-layer')),
                )
                .painter!
            as ConnectorPainter;
    expect(painter.segments, hasLength(1));
  });

  group('GIF playback on a Board', () {
    late Directory gifDirectory;
    late FileImageAssetStore gifAssets;
    late BoardDocument gifBoard;

    setUp(() async {
      gifDirectory = await Directory.systemTemp.createTemp('vasmim_gif_board_');
      gifAssets = FileImageAssetStore.scoped(
        boardDirectoryProvider: () async => gifDirectory,
        idGenerator: () => 'animation',
      );
      final asset = (await gifAssets.importBytes(
        twoFrameGif,
        originalFileName: 'animation.gif',
      ))!;
      final now = DateTime.utc(2026, 9, 24);
      gifBoard = BoardDocument(
        id: 'gif-board',
        name: 'GIF Board',
        createdAt: now,
        modifiedAt: now,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.75,
        notes: const [],
        images: [
          BoardImage(
            id: 'gif-image',
            x: 400,
            y: 300,
            width: 320,
            height: 200,
            assetPath: asset.assetPath,
            originalFileName: asset.originalFileName,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            createdAt: now,
            modifiedAt: now,
          ),
        ],
      );
    });

    tearDown(() async => gifDirectory.delete(recursive: true));

    testWidgets('shows labeled controls on the Board and in the Image menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        MainApp(
          boardStore: _MemoryBoardStore(board: gifBoard),
          imageAssetStore: gifAssets,
          imagePicker: () async => null,
        ),
      );
      for (var attempt = 0; attempt < 10; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        if (find.byType(RawImage).evaluate().isNotEmpty) break;
      }

      expect(find.text('Play GIF'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gif-playback-gif-image')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('gif-playback-gif-image')));
      await tester.pump();
      expect(
        tester
            .widget<ManagedImageView>(find.byType(ManagedImageView))
            .isPlaying,
        isTrue,
      );
      expect(find.text('Pause GIF'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('gif-playback-gif-image')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ManagedImageView>(find.byType(ManagedImageView))
            .isPlaying,
        isFalse,
      );

      await _secondaryTap(
        tester,
        find.byKey(const ValueKey('image-drag-surface-gif-image')),
      );
      expect(
        find.byKey(const ValueKey('context-gif-playback-menu-item')),
        findsOneWidget,
      );
      expect(find.text('Play GIF'), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('context-gif-playback-menu-item')),
      );
      await tester.pump();
      expect(
        tester
            .widget<ManagedImageView>(find.byType(ManagedImageView))
            .isPlaying,
        isTrue,
      );
    });
  });

  testWidgets('selects an image without enabling note-only commands', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final image = _testBoardImage(timestamp: timestamp);
    await _pumpImageBoard(tester, image: image);

    await tester.tap(
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    await tester.pump();

    final interactiveImage = tester.widget<InteractiveBoardImage>(
      find.byType(InteractiveBoardImage),
    );
    expect(interactiveImage.isSelected, isTrue);
    expect(
      find.byKey(const ValueKey('image-resize-handle-board-image')),
      findsOneWidget,
    );
    final colorButton = tester.widget<PopupMenuButton<NoteColor>>(
      find.byKey(const ValueKey('note-color-button')),
    );
    expect(colorButton.enabled, isFalse);
    final clipboardButton = tester.widget<PopupMenuButton<dynamic>>(
      find.byKey(const ValueKey('clipboard-menu-button')),
    );
    expect(clipboardButton.enabled, isTrue);
    expect(find.byKey(const ValueKey('connector-toggle-button')), findsNothing);
    final deleteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('delete-note-button')),
    );
    expect(deleteButton.onPressed, isNotNull);
  });

  testWidgets('moves an image as one board-clamped undoable action', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final image = _testBoardImage(timestamp: timestamp);
    await _pumpImageBoard(tester, image: image);
    final surface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );

    await tester.drag(surface, const Offset(75, 45));
    await tester.pump();

    var moved = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(moved.x, closeTo(500, 1));
    expect(moved.y, closeTo(360, 1));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    moved = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(moved.x, 400);
    expect(moved.y, 300);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump();
    moved = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(moved.x, closeTo(500, 1));
    expect(moved.y, closeTo(360, 1));
  });

  testWidgets('keeps a moved image fully inside the board', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final image = _testBoardImage(timestamp: timestamp);
    await _pumpImageBoard(tester, image: image);
    final surface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );

    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-150, 0));
    await gesture.up();
    await tester.pump();

    final moved = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(moved.x, 0);
    expect(moved.y, 300);
  });

  testWidgets('resizes an image proportionally and reopens its geometry', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final image = _testBoardImage(timestamp: timestamp);
    final store = await _pumpImageBoard(tester, image: image);
    final surface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );
    await tester.tap(surface);
    await tester.pump();

    final resizeHandle = find.byKey(
      const ValueKey('image-resize-handle-board-image'),
    );
    await tester.drag(resizeHandle, const Offset(75, 0));
    await tester.pump();

    var resized = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(resized.width, closeTo(420, 1));
    expect(resized.width / resized.height, closeTo(16 / 9, 0.001));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    resized = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(resized.width, 320);
    expect(resized.height, 180);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
    final saved = store.board!.images.single;
    expect(saved.width, closeTo(420, 1));
    expect(saved.width / saved.height, closeTo(16 / 9, 0.001));

    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        imageAssetStore: _TestImageAssetStore(resolveError: true),
        imagePicker: () async => null,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final reopened = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(reopened.width, closeTo(420, 1));
    expect(reopened.height, closeTo(saved.height, 0.001));
  });

  testWidgets('deletes and restores an image without changing its asset', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final image = _testBoardImage(timestamp: timestamp);
    await _pumpImageBoard(tester, image: image);
    await tester.tap(
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('delete-note-button')));
    await tester.pump();
    expect(find.byType(InteractiveBoardImage), findsNothing);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    final restored = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(restored.id, image.id);
    expect(restored.assetPath, image.assetPath);
    expect(restored.width, image.width);
    expect(restored.height, image.height);
  });

  testWidgets('enforces practical minimum and board edge while resizing', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    await _pumpImageBoard(tester, image: _testBoardImage(timestamp: timestamp));
    await tester.tap(
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    await tester.pump();
    var resizeHandle = find.byKey(
      const ValueKey('image-resize-handle-board-image'),
    );

    await tester.drag(resizeHandle, const Offset(-240, 0));
    await tester.pump();
    var resized = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(resized.width, closeTo(80 * 16 / 9, 0.01));
    expect(resized.height, closeTo(80, 0.01));

    await _pumpImageBoard(
      tester,
      image: _testBoardImage(timestamp: timestamp, x: 5650),
      viewportX: 5200,
    );
    await tester.tap(
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    await tester.pump();
    resizeHandle = find.byKey(
      const ValueKey('image-resize-handle-board-image'),
    );
    await tester.drag(resizeHandle, const Offset(75, 0));
    await tester.pump();
    resized = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(resized.width, 350);
    expect(resized.height, closeTo(196.875, 0.001));
    expect(resized.x + resized.width, 6000);
  });

  testWidgets('control-click creates a mixed selection with safe commands', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    await _pumpMixedBoard(tester, timestamp: timestamp);
    final note = tester.widget<EditableNote>(find.byType(EditableNote).first);
    final noteHandle = find.byKey(ValueKey('note-drag-handle-${note.note.id}'));
    final imageSurface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );

    await tester.tap(noteHandle);
    await _controlTap(tester, imageSurface);

    expect(
      tester
          .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .isSelected,
      isTrue,
    );
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote).first).isSelected,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('image-resize-handle-board-image')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('connector-toggle-button')),
      findsOneWidget,
    );
    expect(find.text('Connect selected objects'), findsOneWidget);
    final clipboardButton = tester.widget<PopupMenuButton<dynamic>>(
      find.byKey(const ValueKey('clipboard-menu-button')),
    );
    expect(clipboardButton.enabled, isTrue);

    await _controlTap(tester, imageSurface);
    expect(
      tester
          .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .isSelected,
      isFalse,
    );
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote).first).isSelected,
      isTrue,
    );
  });

  testWidgets('marquee selects touched notes and images in transformed view', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 1, 12);
    final store = await _pumpMixedBoard(tester, timestamp: timestamp);
    final noteRect = tester.getRect(find.byType(EditableNote));
    final imageRect = tester.getRect(find.byType(InteractiveBoardImage));
    final enclosedBounds = noteRect.expandToInclude(imageRect);
    final start = enclosedBounds.topLeft - const Offset(12, 12);
    final end = enclosedBounds.bottomRight + const Offset(12, 12);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(end);
    await tester.pump();

    expect(find.byKey(const ValueKey('selection-marquee')), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_selectedNoteIds(tester), {'mixed-note'});
    expect(_selectedImageIds(tester), {'board-image'});
    expect(store.saveCalls, 0);

    final partialGesture = await tester.startGesture(
      noteRect.topLeft - const Offset(12, 12),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await partialGesture.moveTo(noteRect.center);
    await partialGesture.up();
    await tester.pumpAndSettle();

    expect(_selectedNoteIds(tester), {'mixed-note'});
    expect(_selectedImageIds(tester), isEmpty);
    expect(store.saveCalls, 0);

    final edgeTouchGesture = await tester.startGesture(
      noteRect.topLeft - const Offset(12, 12),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await edgeTouchGesture.moveTo(Offset(noteRect.left, noteRect.center.dy));
    await edgeTouchGesture.up();
    await tester.pumpAndSettle();

    expect(_selectedNoteIds(tester), {'mixed-note'});
    expect(_selectedImageIds(tester), isEmpty);
    expect(store.saveCalls, 0);
  });

  testWidgets('Escape cancels a marquee and preserves prior selection', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 1, 12, 5);
    final store = await _pumpMixedBoard(tester, timestamp: timestamp);
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-mixed-note')));
    await tester.pumpAndSettle();
    expect(_selectedNoteIds(tester), {'mixed-note'});

    final imageRect = tester.getRect(find.byType(InteractiveBoardImage));
    final gesture = await tester.startGesture(
      imageRect.topLeft - const Offset(12, 12),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(imageRect.bottomRight + const Offset(12, 12));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-marquee')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(const ValueKey('selection-marquee')), findsNothing);
    expect(_selectedNoteIds(tester), {'mixed-note'});
    expect(_selectedImageIds(tester), isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_selectedNoteIds(tester), {'mixed-note'});
    expect(_selectedImageIds(tester), isEmpty);
    expect(store.saveCalls, 0);
  });

  testWidgets('secondary blank drag pans while a secondary click opens Paste', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 1, 12, 10);
    await _pumpMixedBoard(tester, timestamp: timestamp);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final original = Matrix4.copy(controller.value);
    final surface = tester.getRect(
      find.byKey(const ValueKey('canvas-interaction-surface')),
    );
    final start = surface.topLeft + const Offset(40, 80);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.moveBy(const Offset(90, 55));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.value.storage[12], closeTo(original.storage[12] + 90, 1));
    expect(controller.value.storage[13], closeTo(original.storage[13] + 55, 1));
    expect(find.byKey(const ValueKey('context-paste-menu-item')), findsNothing);

    await tester.tapAt(
      surface.topLeft + const Offset(40, 80),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('context-paste-menu-item')),
      findsOneWidget,
    );
  });

  testWidgets(
    'connects a note to an image through movement deletion undo and reopen',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 19, 20);
      final store = await _pumpMixedBoard(tester, timestamp: timestamp);
      final noteHandle = find.byKey(
        const ValueKey('note-drag-handle-mixed-note'),
      );
      final imageSurface = find.byKey(
        const ValueKey('image-drag-surface-board-image'),
      );

      await tester.tap(noteHandle);
      await _controlTap(tester, imageSurface);
      expect(find.text('Connect selected objects'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('connector-toggle-button')));
      await tester.pumpAndSettle();

      ConnectorSegmentSnapshot segment() {
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('connector-layer')),
                    )
                    .painter!
                as ConnectorPainter;
        final value = painter.segments.single;
        return (start: value.start, end: value.end);
      }

      final beforeMove = segment();
      await tester.tap(imageSurface);
      await tester.drag(imageSurface, const Offset(-80, -40));
      await tester.pump();
      final afterMove = segment();
      expect(afterMove.start, isNot(beforeMove.start));
      expect(afterMove.end, isNot(beforeMove.end));

      await tester.drag(
        find.byKey(const ValueKey('image-resize-handle-board-image')),
        const Offset(60, 0),
      );
      await tester.pump();
      final afterResize = segment();
      expect(afterResize.start, isNot(afterMove.start));
      expect(afterResize.end, isNot(afterMove.end));

      await tester.tap(find.byKey(const ValueKey('delete-note-button')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveBoardImage), findsNothing);
      expect(find.byKey(const ValueKey('connector-layer')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.connectors.single.objectAId, 'board-image');
      expect(store.board!.connectors.single.objectBId, 'mixed-note');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(resolveError: true),
          imagePicker: () async => null,
          imageViewBuilder: (image) => SizedBox(
            key: ValueKey('reopened-${image.id}'),
            width: image.width,
            height: image.height,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connector-layer')), findsOneWidget);
    },
  );

  testWidgets('connects and copies an image pair with remapped endpoints', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 19, 21);
    BoardImage image(String id, double x) => BoardImage(
      id: id,
      x: x,
      y: 300,
      width: 320,
      height: 180,
      assetPath: 'assets/$id.png',
      originalFileName: '$id.png',
      pixelWidth: 1600,
      pixelHeight: 900,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'image-pair-board',
        name: 'Image pair',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 0.75,
        notes: const [],
        images: [image('image-a', 300), image('image-b', 900)],
      ),
    );
    await tester.pumpWidget(
      MainApp(
        boardStore: store,
        imageAssetStore: _TestImageAssetStore(resolveError: true),
        imagePicker: () async => null,
        imageViewBuilder: (image) => SizedBox(
          key: ValueKey('test-${image.id}'),
          width: image.width,
          height: image.height,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('image-drag-surface-image-a')));
    await _controlTap(
      tester,
      find.byKey(const ValueKey('image-drag-surface-image-b')),
    );
    await tester.tap(find.byKey(const ValueKey('connector-toggle-button')));
    await tester.pumpAndSettle();
    expect(find.text('Remove connection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveBoardImage), findsNWidgets(4));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connector-layer')),
                )
                .painter!
            as ConnectorPainter;
    expect(painter.segments, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    final pastedImageIds = store.board!.images
        .map((image) => image.id)
        .where((id) => id != 'image-a' && id != 'image-b')
        .toSet();
    final pastedConnector = store.board!.connectors.singleWhere(
      (connector) => connector.id != store.board!.connectors.first.id,
    );
    expect(pastedImageIds, contains(pastedConnector.objectAId));
    expect(pastedImageIds, contains(pastedConnector.objectBId));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    expect(find.byType(InteractiveBoardImage), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump();
    expect(find.byType(InteractiveBoardImage), findsNWidgets(4));
  });

  testWidgets('moves a mixed selection with one shared undoable delta', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    await _pumpMixedBoard(tester, timestamp: timestamp);
    final originalNote = tester.widget<EditableNote>(find.byType(EditableNote));
    final noteHandle = find.byKey(
      ValueKey('note-drag-handle-${originalNote.note.id}'),
    );
    final imageSurface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );
    final originalImage = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;

    await tester.tap(noteHandle);
    await _controlTap(tester, imageSurface);
    await tester.drag(imageSurface, const Offset(75, 45));
    await tester.pump();

    var note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    var image = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(note.x - originalNote.note.x, closeTo(100, 1));
    expect(note.y - originalNote.note.y, closeTo(60, 1));
    expect(image.x - originalImage.x, closeTo(100, 1));
    expect(image.y - originalImage.y, closeTo(60, 1));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    image = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(note.x, originalNote.note.x);
    expect(note.y, originalNote.note.y);
    expect(image.x, originalImage.x);
    expect(image.y, originalImage.y);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump();
    note = tester.widget<EditableNote>(find.byType(EditableNote)).note;
    image = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(note.x - originalNote.note.x, closeTo(100, 1));
    expect(image.x - originalImage.x, closeTo(100, 1));
  });

  testWidgets('zooms to fit a mixed selection instead of distant objects', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    await _pumpMixedBoard(
      tester,
      timestamp: timestamp,
      includeDistantNote: true,
    );
    final notes = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .toList();
    final nearNoteHandle = find.byKey(
      ValueKey('note-drag-handle-${notes.first.note.id}'),
    );
    final imageSurface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );

    await tester.tap(nearNoteHandle);
    await _controlTap(tester, imageSurface);
    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(0.3),
    );
    final fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit all objects');
    expect(
      tester.widget<EditableNote>(find.byType(EditableNote).first).isSelected,
      isFalse,
    );
    expect(
      tester
          .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .isSelected,
      isFalse,
    );
  });

  testWidgets('centres one selected image then frames all objects', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 19, 18, 30);
    await _pumpMixedBoard(
      tester,
      timestamp: timestamp,
      includeDistantNote: true,
    );
    final imageSurface = find.byKey(
      const ValueKey('image-drag-surface-board-image'),
    );

    var fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit all objects');

    await tester.tap(imageSurface);
    await tester.pumpAndSettle();
    fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit selected image');

    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(find.byType(InteractiveViewer));
    final imageRect = tester.getRect(find.byKey(const ValueKey('board-image')));
    expect(imageRect.center.dx, closeTo(viewportRect.center.dx, 1));
    expect(imageRect.center.dy, closeTo(viewportRect.center.dy, 1));
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1.0);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('distant-note')))
          .overlaps(viewportRect),
      isFalse,
    );
    expect(
      tester
          .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .isSelected,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('redo-button')))
          .onPressed,
      isNull,
    );
    fitButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('zoom-to-fit-button')),
    );
    expect(fitButton.tooltip, 'Zoom to fit all objects');

    await tester.tap(find.byKey(const ValueKey('zoom-to-fit-button')));
    await tester.pumpAndSettle();

    final allObjectsViewport = tester.getRect(find.byType(InteractiveViewer));
    final distantRect = tester.getRect(
      find.byKey(const ValueKey('distant-note')),
    );
    expect(
      distantRect.left,
      greaterThanOrEqualTo(allObjectsViewport.left + 47),
    );
    expect(distantRect.top, greaterThanOrEqualTo(allObjectsViewport.top + 47));
    expect(distantRect.right, lessThanOrEqualTo(allObjectsViewport.right - 47));
    expect(
      distantRect.bottom,
      lessThanOrEqualTo(allObjectsViewport.bottom - 47),
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      lessThan(1.0),
    );
  });

  testWidgets('recovers an off-board image and preserves it through undo', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final image = _testBoardImage(timestamp: timestamp, x: 5900, y: 4450);
    await _pumpImageBoard(tester, image: image, viewportX: 5300);

    expect(find.byKey(const ValueKey('recover-notes-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recover-notes-button')));
    await tester.pumpAndSettle();

    var recovered = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(recovered.x, 5680);
    expect(recovered.y, 4320);
    expect(recovered.id, image.id);
    expect(recovered.assetPath, image.assetPath);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    recovered = tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .image;
    expect(recovered.x, 5900);
    expect(recovered.y, 4450);
    expect(recovered.width / recovered.height, closeTo(16 / 9, 0.001));
  });

  testWidgets('copies an image with fresh identity and shared managed asset', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12, 21);
    final source = _testBoardImage(timestamp: timestamp, x: 5680, y: 4320);
    await _pumpImageBoard(
      tester,
      image: source,
      viewportX: 5300,
      viewportY: 3900,
    );

    await tester.tap(
      find.byKey(const ValueKey('image-drag-surface-board-image')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();

    var images = tester
        .widgetList<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .map((widget) => widget.image)
        .toList();
    expect(images, hasLength(2));
    final pasted = images.singleWhere((image) => image.id != source.id);
    expect(pasted.id, isNot(source.id));
    expect(pasted.assetPath, source.assetPath);
    expect(pasted.originalFileName, source.originalFileName);
    expect(pasted.pixelWidth, source.pixelWidth);
    expect(pasted.pixelHeight, source.pixelHeight);
    expect(pasted.width, source.width);
    expect(pasted.height, source.height);
    expect(pasted.x, 5648);
    expect(pasted.y, 4288);
    expect(pasted.createdAt, isNot(source.createdAt));

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump();
    expect(find.byType(InteractiveBoardImage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump();
    images = tester
        .widgetList<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .map((widget) => widget.image)
        .toList();
    expect(images.any((image) => image.id == pasted.id), isTrue);
  });

  testWidgets(
    'copies a mixed connected selection as one persistent history action',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 12, 22);
      final sourceImage = _testBoardImage(timestamp: timestamp, x: 650, y: 500);
      final store = _MemoryBoardStore(
        board: _connectedBoard(
          timestamp: timestamp,
          images: [sourceImage],
          connectorObjectBId: sourceImage.id,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(resolveError: true),
          imagePicker: () async => null,
          imageViewBuilder: (image) => SizedBox(
            key: ValueKey('test-image-${image.id}'),
            width: image.width,
            height: image.height,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
      await _controlTap(
        tester,
        find.byKey(const ValueKey('note-drag-handle-note-b')),
      );
      await _controlTap(
        tester,
        find.byKey(const ValueKey('image-drag-surface-board-image')),
      );
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
      await tester.pumpAndSettle();

      var notes = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      var images = tester
          .widgetList<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .map((widget) => widget.image)
          .toList();
      expect(notes, hasLength(4));
      expect(images, hasLength(2));
      final pastedNotes = notes
          .where((note) => !{'note-a', 'note-b'}.contains(note.id))
          .toList();
      final pastedImage = images.singleWhere(
        (image) => image.id != sourceImage.id,
      );
      expect(pastedNotes.map((note) => note.id).toSet(), hasLength(2));
      expect(pastedImage.assetPath, sourceImage.assetPath);
      expect(pastedImage.id, isNot(sourceImage.id));
      expect(pastedImage.x, sourceImage.x + 32);
      expect(pastedImage.y, sourceImage.y + 32);
      expect(pastedNotes.singleWhere((note) => note.text == 'A').x, 332);
      expect(
        tester
            .widgetList<EditableNote>(find.byType(EditableNote))
            .where((widget) => widget.isSelected),
        hasLength(2),
      );
      expect(
        tester
            .widgetList<InteractiveBoardImage>(
              find.byType(InteractiveBoardImage),
            )
            .where((widget) => widget.isSelected),
        hasLength(1),
      );

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pump();
      expect(find.byType(EditableNote), findsNWidgets(2));
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pump();
      expect(find.byType(EditableNote), findsNWidgets(4));
      expect(find.byType(InteractiveBoardImage), findsNWidgets(2));

      await tester.pump(const Duration(milliseconds: 700));
      expect(store.board!.notes, hasLength(4));
      expect(store.board!.images, hasLength(2));
      expect(store.board!.connectors, hasLength(2));
      final sourceConnectorIds = {'connector-a-b'};
      final pastedConnector = store.board!.connectors.singleWhere(
        (connector) => !sourceConnectorIds.contains(connector.id),
      );
      final pastedObjectIds = {
        ...pastedNotes.map((note) => note.id),
        pastedImage.id,
      };
      expect(pastedObjectIds, contains(pastedConnector.objectAId));
      expect(pastedObjectIds, contains(pastedConnector.objectBId));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MainApp(
          boardStore: store,
          imageAssetStore: _TestImageAssetStore(resolveError: true),
          imagePicker: () async => null,
          imageViewBuilder: (image) =>
              SizedBox(key: ValueKey('reopened-image-${image.id}')),
        ),
      );
      await tester.pumpAndSettle();
      notes = tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .map((widget) => widget.note)
          .toList();
      images = tester
          .widgetList<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
          .map((widget) => widget.image)
          .toList();
      expect(notes, hasLength(4));
      expect(images, hasLength(2));
      expect(images.any((image) => image.id == pastedImage.id), isTrue);
      expect(store.board!.connectors, hasLength(2));
    },
  );
  testWidgets('activates a saved scene without changing selection or content', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 13);
    final scene = Scene(
      id: '123e4567-e89b-42d3-a456-426614174000',
      name: 'References',
      x: 640,
      y: 480,
      zoom: 0.75,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'scene-navigation-board',
        name: 'Scene navigation',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          Note(
            id: 'scene-note',
            x: 300,
            y: 200,
            width: 260,
            height: 170,
            text: 'Scene content',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        scenes: [scene],
      ),
    );
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-scene-note')));
    await tester.pumpAndSettle();
    expect(find.text('SELECTED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Scenes save a canvas location and zoom, not canvas objects.'),
      findsOneWidget,
    );
    expect(find.textContaining('x 640'), findsNothing);
    expect(find.textContaining('y 480'), findsNothing);
    expect(find.textContaining('75%'), findsNothing);
    await tester.tap(find.byKey(ValueKey('scene-${scene.id}')));
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final controller = viewer.transformationController!;
    expect(controller.toScene(Offset.zero).dx, closeTo(scene.x, 0.001));
    expect(controller.toScene(Offset.zero).dy, closeTo(scene.y, 0.001));
    expect(controller.value.getMaxScaleOnAxis(), closeTo(scene.zoom, 0.001));
    expect(find.text('SELECTED'), findsOneWidget);
    expect(find.text('Scene content'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.scenes.single.toJson(), scene.toJson());
    expect(store.board!.viewportX, closeTo(scene.x, 0.001));
    expect(store.board!.viewportY, closeTo(scene.y, 0.001));
    expect(store.board!.viewportZoom, closeTo(scene.zoom, 0.001));
  });

  testWidgets('animates Scene activation to its exact endpoint', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final startOrigin = controller.toScene(Offset.zero);
    final evidence = store.board!.scenes[1];

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scene-${evidence.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));

    final movingOrigin = controller.toScene(Offset.zero);
    expect(movingOrigin.dx, isNot(closeTo(startOrigin.dx, 0.001)));
    expect(movingOrigin.dx, isNot(closeTo(evidence.x, 0.001)));
    expect(
      controller.value.getMaxScaleOnAxis(),
      isNot(closeTo(evidence.zoom, 0.001)),
    );

    await tester.pumpAndSettle();
    _expectViewportAtScene(tester, evidence);
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.saveCalls, 1);
  });

  testWidgets('reduced motion activates a Scene immediately', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    final evidence = store.board!.scenes[1];

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scene-${evidence.id}')));
    await tester.pump();

    _expectViewportAtScene(tester, evidence);
  });

  testWidgets('creates, renames, deletes, undoes, and redoes scenes', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    expect(find.text('No saved scenes yet'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('save-current-view-scene-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scene-name-field')),
      '  Brainstorm  ',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-scene-name-button')));
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsNothing);
    expect(find.byKey(const ValueKey('scenes-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    expect(find.text('Brainstorm'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    expect(store.board!.scenes, hasLength(1));
    final sceneId = store.board!.scenes.single.id;
    expect(
      sceneId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('reorder-scene-$sceneId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('rename-scene-$sceneId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scene-name-field')),
      'Plan',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-scene-name-button')));
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.scenes.single.name, 'Brainstorm');
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.scenes.single.name, 'Plan');

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('reorder-scene-$sceneId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('delete-scene-$sceneId')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Canvas objects will not be changed.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-delete-scene-button')));
    await tester.pumpAndSettle();
    expect(find.text('No saved scenes yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.scenes.single.name, 'Plan');
  });

  testWidgets('autosaves and reopens a newly created scene', (tester) async {
    final store = await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('save-current-view-scene-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scene-name-field')),
      'Brainstorm',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-scene-name-button')));
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));

    expect(store.board!.scenes.single.name, 'Brainstorm');
    final savedScene = store.board!.scenes.single;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(MainApp(boardStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();

    expect(find.text('Brainstorm'), findsOneWidget);
    expect(store.board!.scenes.single.toJson(), savedScene.toJson());
  });

  testWidgets(
    'Enter completes scene capture and restores board shortcut focus',
    (tester) async {
      await _pumpTestApp(tester);

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('save-current-view-scene-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('scene-name-field')),
        'Keyboard scene',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Scenes'), findsNothing);
      expect(find.byKey(const ValueKey('scenes-button')), findsOneWidget);

      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      expect(find.text('No saved scenes yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      await _sendShortcut(tester, LogicalKeyboardKey.keyY);
      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard scene'), findsOneWidget);
    },
  );

  testWidgets('invalid or cancelled scene capture keeps the manager open', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('save-current-view-scene-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-scene-name-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a scene name'), findsOneWidget);
    expect(find.text('Scenes'), findsOneWidget);
    expect(find.byKey(const ValueKey('scene-name-field')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scene-name-field')), findsNothing);
    expect(find.text('Scenes'), findsOneWidget);
    expect(find.text('No saved scenes yet'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('keeps eight scenes usable in stable order', (tester) async {
    final timestamp = DateTime.utc(2026, 8, 13);
    final scenes = [
      for (var index = 1; index <= 8; index++)
        Scene(
          id: '123e4567-e89b-42d3-a456-${index.toString().padLeft(12, '0')}',
          name: 'Scene $index',
          x: index * 100,
          y: index * 80,
          zoom: 1,
          createdAt: timestamp.add(Duration(minutes: index)),
          modifiedAt: timestamp.add(Duration(minutes: index)),
        ),
    ];
    final store = _MemoryBoardStore(
      board: BoardDocument(
        id: 'eight-scene-board',
        name: 'Eight scenes',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        scenes: scenes,
      ),
    );
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();

    expect(find.text('Scene 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Scene 8'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('scene-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Scene 8'), findsOneWidget);
    expect(store.board!.scenes.map((scene) => scene.name), [
      'Scene 1',
      'Scene 2',
      'Scene 3',
      'Scene 4',
      'Scene 5',
      'Scene 6',
      'Scene 7',
      'Scene 8',
    ]);
  });

  testWidgets('unifies all existing Scene commands in one ordered menu', (
    tester,
  ) async {
    final originalBoard = _walkthroughBoard();
    final store = _MemoryBoardStore(board: originalBoard);
    await _pumpTestApp(tester, store: store);
    final evidence = originalBoard.scenes[1];

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('scene-${evidence.id}'));
    expect(
      find.descendant(of: row, matching: find.byType(IconButton)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
    await tester.pumpAndSettle();
    final rename = find.byKey(ValueKey('rename-scene-${evidence.id}'));
    final delete = find.byKey(ValueKey('delete-scene-${evidence.id}'));
    expect(tester.widget<PopupMenuItem<Object?>>(rename).enabled, isTrue);
    expect(tester.widget<PopupMenuItem<Object?>>(delete).enabled, isTrue);
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    expect(
      [
        'Update to current view',
        'Start walkthrough here',
        'Move earlier',
        'Move later',
        'Rename',
        'Delete',
      ].map((label) => tester.getTopLeft(find.text(label)).dy),
      orderedEquals(
        [
            'Update to current view',
            'Start walkthrough here',
            'Move earlier',
            'Move later',
            'Rename',
            'Delete',
          ].map((label) => tester.getTopLeft(find.text(label)).dy).toList()
          ..sort(),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(store.board!.toJson(), originalBoard.toJson());
  });

  testWidgets('derives Current view indicators from matching Scene viewports', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _walkthroughBoard(sceneCount: 4));
    await _pumpTestApp(tester, store: store);
    final evidence = store.board!.scenes[1];
    final duplicateView = store.board!.scenes[3];

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scene-${evidence.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('current-view-scene-${evidence.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('current-view-scene-${duplicateView.id}')),
      findsOneWidget,
    );
    expect(find.text('Current view'), findsNWidgets(2));
    for (final scene in store.board!.scenes.where(
      (scene) => scene != evidence && scene != duplicateView,
    )) {
      expect(
        find.byKey(ValueKey('current-view-scene-${scene.id}')),
        findsNothing,
      );
    }
  });

  testWidgets('Scene reorder endpoints and dismissal are history no-ops', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();

    final firstScene = store.board!.scenes.first;
    await tester.tap(find.byKey(ValueKey('reorder-scene-${firstScene.id}')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<Object?>>(
            find.byKey(ValueKey('move-scene-earlier-${firstScene.id}')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<PopupMenuItem<Object?>>(
            find.byKey(ValueKey('move-scene-later-${firstScene.id}')),
          )
          .enabled,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final lastScene = store.board!.scenes.last;
    await tester.tap(find.byKey(ValueKey('reorder-scene-${lastScene.id}')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<Object?>>(
            find.byKey(ValueKey('move-scene-earlier-${lastScene.id}')),
          )
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<PopupMenuItem<Object?>>(
            find.byKey(ValueKey('move-scene-later-${lastScene.id}')),
          )
          .enabled,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    expect(store.saveCalls, 0);
    expect(store.board!.scenes.map((scene) => scene.name), [
      'Question',
      'Evidence',
      'Plan',
    ]);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'reorders Scenes with history persistence and Walkthrough agreement',
    (tester) async {
      final originalBoard = _walkthroughBoard();
      final originalScenesById = {
        for (final scene in originalBoard.scenes) scene.id: scene.toJson(),
      };
      final store = _MemoryBoardStore(board: originalBoard);
      await _pumpTestApp(tester, store: store);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-walkthrough-note')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final workingTransform = Matrix4.copy(controller.value);
      final plan = originalBoard.scenes.last;

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      for (var move = 0; move < 2; move++) {
        await tester.tap(find.byKey(ValueKey('reorder-scene-${plan.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('move-scene-earlier-${plan.id}')));
        await tester.pumpAndSettle();
      }
      expect(
        tester.getTopLeft(find.text('Plan')).dy,
        lessThan(tester.getTopLeft(find.text('Question')).dy),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.text('SELECTED'), findsOneWidget);
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.scenes.map((scene) => scene.name), [
        'Plan',
        'Question',
        'Evidence',
      ]);
      for (final scene in store.board!.scenes) {
        expect(scene.toJson(), originalScenesById[scene.id]);
      }

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.scenes.map((scene) => scene.name), [
        'Question',
        'Plan',
        'Evidence',
      ]);

      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.scenes.map((scene) => scene.name), [
        'Plan',
        'Question',
        'Evidence',
      ]);

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('start-scene-walkthrough-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      _expectViewportAtScene(tester, plan);
      await tester.tap(find.byKey(const ValueKey('scene-walkthrough-exit')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(MainApp(boardStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Plan')).dy,
        lessThan(tester.getTopLeft(find.text('Question')).dy),
      );
      expect(store.board!.scenes.map((scene) => scene.name), [
        'Plan',
        'Question',
        'Evidence',
      ]);
    },
  );

  testWidgets('Scene reorder menu remains keyboard usable at 800 by 600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(800));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));

    final plan = store.board!.scenes.last;
    await tester.tap(find.byKey(ValueKey('reorder-scene-${plan.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Plan')).dy,
      lessThan(tester.getTopLeft(find.text('Evidence')).dy),
    );

    await tester.tap(find.byKey(ValueKey('reorder-scene-${plan.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.scenes.map((scene) => scene.name), [
      'Question',
      'Plan',
      'Evidence',
    ]);
  });

  testWidgets(
    'Update Scene View disables matches and cancellation is a no-op',
    (tester) async {
      final originalBoard = _walkthroughBoard();
      final store = _MemoryBoardStore(board: originalBoard);
      await _pumpTestApp(tester, store: store);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-walkthrough-note')),
      );
      await tester.pumpAndSettle();
      final evidence = originalBoard.scenes[1];

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('scene-${evidence.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<Object?>>(
              find.byKey(ValueKey('update-scene-view-${evidence.id}')),
            )
            .enabled,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(1.1, 1.1, 1.1)
        ..setTranslationRaw(-330, -440, 0);
      final workingTransform = Matrix4.copy(controller.value);
      final originalScenes = [
        for (final scene in originalBoard.scenes) scene.toJson(),
      ];

      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byKey(const ValueKey('scenes-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('update-scene-view-${evidence.id}')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Update saved scene?'), findsOneWidget);
        expect(
          find.textContaining('Canvas objects will not be changed.'),
          findsOneWidget,
        );
        if (attempt == 0) {
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await tester.pumpAndSettle();
        expect(find.text('Scenes'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await tester.pumpAndSettle();
      }

      expect([
        for (final scene in store.board!.scenes) scene.toJson(),
      ], originalScenes);
      expect(find.text('SELECTED'), findsOneWidget);
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'updates one Scene view through history Walkthrough and persistence',
    (tester) async {
      final originalBoard = _walkthroughBoard();
      final store = _MemoryBoardStore(board: originalBoard);
      await _pumpTestApp(tester, store: store);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-walkthrough-note')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(1.1, 1.1, 1.1)
        ..setTranslationRaw(-330, -440, 0);
      final workingTransform = Matrix4.copy(controller.value);
      final evidence = originalBoard.scenes[1];

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('update-scene-view-${evidence.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-update-scene-view-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Scenes'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<Object?>>(
              find.byKey(ValueKey('update-scene-view-${evidence.id}')),
            )
            .enabled,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.text('SELECTED'), findsOneWidget);
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.scenes.map((scene) => scene.name), [
        'Question',
        'Evidence',
        'Plan',
      ]);
      final updated = store.board!.scenes[1];
      expect(updated.id, evidence.id);
      expect(updated.name, evidence.name);
      expect(updated.createdAt, evidence.createdAt);
      expect(updated.modifiedAt.isAfter(evidence.modifiedAt), isTrue);
      expect(updated.x, closeTo(300, 0.001));
      expect(updated.y, closeTo(400, 0.001));
      expect(updated.zoom, closeTo(1.1, 0.001));
      expect(
        store.board!.scenes.first.toJson(),
        originalBoard.scenes.first.toJson(),
      );
      expect(
        store.board!.scenes.last.toJson(),
        originalBoard.scenes.last.toJson(),
      );

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.scenes[1].toJson(), evidence.toJson());

      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(store.board!.scenes[1].toJson(), updated.toJson());

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('start-scene-walkthrough-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scene-walkthrough-next')));
      await tester.pump();
      expect(find.text('Evidence'), findsOneWidget);
      await tester.pumpAndSettle();
      _expectViewportAtScene(tester, updated);
      await tester.tap(find.byKey(const ValueKey('scene-walkthrough-exit')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(MainApp(boardStore: store));
      await tester.pumpAndSettle();
      expect(store.board!.scenes[1].toJson(), updated.toJson());
    },
  );

  testWidgets('Update Scene View remains keyboard usable at 800 by 600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    controller.value = Matrix4.diagonal3Values(1.1, 1.1, 1.1)
      ..setTranslationRaw(-330, -440, 0);
    final evidence = store.board!.scenes[1];

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final confirmationRect = tester.getRect(
      find.widgetWithText(AlertDialog, 'Update saved scene?'),
    );
    expect(confirmationRect.left, greaterThanOrEqualTo(0));
    expect(confirmationRect.top, greaterThanOrEqualTo(0));
    expect(confirmationRect.right, lessThanOrEqualTo(800));
    expect(confirmationRect.bottom, lessThanOrEqualTo(600));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(store.board!.scenes[1].x, closeTo(300, 0.001));
    expect(store.board!.scenes[1].y, closeTo(400, 0.001));
    expect(store.board!.scenes[1].zoom, closeTo(1.1, 0.001));
  });

  testWidgets('enables Scene Walkthrough only with at least two scenes', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _walkthroughBoard(sceneCount: 1));
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('start-scene-walkthrough-button')),
          )
          .onPressed,
      isNull,
    );

    final scene = store.board!.scenes.single;
    await tester.tap(find.byKey(ValueKey('reorder-scene-${scene.id}')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<Object?>>(
            find.byKey(ValueKey('start-walkthrough-here-${scene.id}')),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('walks saved Scenes in order with buttons and arrow keys', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('start-scene-walkthrough-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scene-walkthrough')), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('scene-walkthrough-previous')),
          )
          .onPressed,
      isNull,
    );
    _expectViewportAtScene(tester, store.board!.scenes[0]);

    await tester.tap(find.byKey(const ValueKey('scene-walkthrough-next')));
    await tester.pump();
    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.pumpAndSettle();
    _expectViewportAtScene(tester, store.board!.scenes[1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('scene-walkthrough-next')),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpAndSettle();
    _expectViewportAtScene(tester, store.board!.scenes[2]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('latest Walkthrough request wins and Exit cancels motion', (
    tester,
  ) async {
    final originalBoard = _walkthroughBoard();
    final store = _MemoryBoardStore(board: originalBoard);
    await _pumpTestApp(tester, store: store);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final workingTransform = Matrix4.copy(controller.value);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('start-scene-walkthrough-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scene-walkthrough-next')));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
      controller.toScene(Offset.zero).dx,
      isNot(closeTo(originalBoard.scenes.last.x, 0.001)),
    );

    await tester.pumpAndSettle();
    _expectViewportAtScene(tester, originalBoard.scenes.last);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scene-walkthrough')), findsNothing);
    expect(controller.value.storage, orderedEquals(workingTransform.storage));
    expect(store.saveCalls, 0);
    expect(store.board!.toJson(), originalBoard.toJson());
  });

  testWidgets(
    'starts Walkthrough at an exact Scene and restores unchanged working state',
    (tester) async {
      final originalBoard = _walkthroughBoard();
      final store = _MemoryBoardStore(board: originalBoard);
      await _pumpTestApp(tester, store: store);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-walkthrough-note')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(0.9, 0.9, 0.9)
        ..setTranslationRaw(-180, -260, 0);
      final workingTransform = Matrix4.copy(controller.value);
      final boardJson = originalBoard.toJson();
      final evidence = originalBoard.scenes[1];

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('reorder-scene-${evidence.id}')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('start-walkthrough-here-${evidence.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scene-walkthrough')), findsOneWidget);
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      _expectViewportAtScene(tester, evidence);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('scene-walkthrough-previous')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('scene-walkthrough-next')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('Question'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('scene-walkthrough-previous')),
            )
            .onPressed,
        isNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('scene-walkthrough-next')),
            )
            .onPressed,
        isNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      expect(find.text('SELECTED'), findsOneWidget);
      expect(store.board!.toJson(), boardJson);
      expect(store.saveCalls, 0);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('Start Walkthrough Here is keyboard usable at 800 by 600', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    controller.value = Matrix4.diagonal3Values(0.9, 0.9, 0.9)
      ..setTranslationRaw(-180, -260, 0);
    final workingTransform = Matrix4.copy(controller.value);
    final plan = store.board!.scenes.last;

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('reorder-scene-${plan.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Scenes'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('reorder-scene-${plan.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    _expectViewportAtScene(tester, plan);
    final controlsRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('scene-walkthrough')),
        matching: find.byType(Card),
      ),
    );
    expect(controlsRect.left, greaterThanOrEqualTo(0));
    expect(controlsRect.top, greaterThanOrEqualTo(0));
    expect(controlsRect.right, lessThanOrEqualTo(800));
    expect(controlsRect.bottom, lessThanOrEqualTo(600));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.value.storage, orderedEquals(workingTransform.storage));
  });

  testWidgets(
    'walkthrough blocks canvas commands and restores working state on Escape',
    (tester) async {
      final originalBoard = _walkthroughBoard();
      final store = _MemoryBoardStore(board: originalBoard);
      await _pumpTestApp(tester, store: store);
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-walkthrough-note')),
      );
      await tester.pumpAndSettle();
      expect(find.text('SELECTED'), findsOneWidget);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      final workingTransform = Matrix4.copy(controller.value);
      final boardJson = originalBoard.toJson();

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('start-scene-walkthrough-button')),
      );
      await tester.pumpAndSettle();
      _expectViewportAtScene(tester, originalBoard.scenes.first);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
      await _sendShortcut(tester, LogicalKeyboardKey.keyS);
      final sceneTransform = Matrix4.copy(controller.value);
      await tester.dragFrom(const Offset(400, 300), const Offset(120, 80));
      await tester.pump();

      expect(controller.value.storage, orderedEquals(sceneTransform.storage));
      expect(find.text('Walkthrough note'), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);
      expect(store.saveCalls, 0);
      expect(store.board!.toJson(), boardJson);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scene-walkthrough')), findsNothing);
      expect(controller.value.storage, orderedEquals(workingTransform.storage));
      expect(find.text('SELECTED'), findsOneWidget);
      expect(store.saveCalls, 0);
      expect(store.board!.toJson(), boardJson);
    },
  );

  testWidgets('visible walkthrough Exit restores the working viewport', (
    tester,
  ) async {
    final store = _MemoryBoardStore(board: _walkthroughBoard());
    await _pumpTestApp(tester, store: store);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final workingTransform = Matrix4.copy(controller.value);

    await tester.tap(find.byKey(const ValueKey('scenes-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('start-scene-walkthrough-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene-walkthrough-exit')));
    await tester.pumpAndSettle();

    expect(controller.value.storage, orderedEquals(workingTransform.storage));
  });

  testWidgets(
    'pending autosave uses the working viewport and walkthrough adds no history',
    (tester) async {
      final store = _MemoryBoardStore(board: _walkthroughBoard());
      await _pumpTestApp(tester, store: store);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;

      await tester.tap(find.byKey(const ValueKey('create-note-button')));
      await tester.pump();
      expect(find.byType(EditableNote), findsNWidgets(2));
      final workingOrigin = controller.toScene(Offset.zero);
      final workingZoom = controller.value.getMaxScaleOnAxis();

      await tester.tap(find.byKey(const ValueKey('scenes-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('start-scene-walkthrough-button')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.saveCalls, 1);
      expect(store.board!.viewportX, closeTo(workingOrigin.dx, 0.001));
      expect(store.board!.viewportY, closeTo(workingOrigin.dy, 0.001));
      expect(store.board!.viewportZoom, closeTo(workingZoom, 0.001));
      expect(store.board!.notes, hasLength(2));

      await tester.tap(find.byKey(const ValueKey('scene-walkthrough-exit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();

      expect(find.byType(EditableNote), findsOneWidget);
    },
  );

  testWidgets('new Boards persist the toolbar Snap toggle without history', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    IconButton toggle() => tester.widget<IconButton>(
      find.byKey(const ValueKey('snapping-toggle-button')),
    );

    expect(toggle().isSelected, isTrue);
    await tester.tap(find.byKey(const ValueKey('snapping-toggle-button')));
    await tester.pumpAndSettle();

    expect(toggle().isSelected, isFalse);
    expect(store.board!.isSnappingEnabled, isFalse);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpTestApp(tester, store: store);
    expect(toggle().isSelected, isFalse);
  });

  testWidgets('paper tone saves per Board without adding history', (
    tester,
  ) async {
    final store = await _pumpTestApp(tester);
    await tester.tap(find.byKey(const ValueKey('paper-tone-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paper-tone-warm')));
    await tester.pumpAndSettle();

    expect(store.board!.paperTone, BoardPaperTone.warm);
    expect(
      (tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-overview-paint')),
                  )
                  .painter!
              as CanvasOverviewPainter)
          .backgroundColor,
      LayeredCanvasPaperPainter.paperColorFor(
        BoardPaperTone.warm,
        isDark: false,
      ),
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('current-view-export-surface')),
          )
          .color,
      LayeredCanvasPaperPainter.paperColorFor(
        BoardPaperTone.warm,
        isDark: false,
      ),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('paper-tone-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckedPopupMenuItem<BoardPaperTone>>(
            find.byKey(const ValueKey('paper-tone-warm')),
          )
          .checked,
      isTrue,
    );
  });

  testWidgets('Snap aligns a foreground drag and keeps one undo step', (
    tester,
  ) async {
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: DateTime.utc(2026, 9, 16),
      ).copyWith(isSnappingEnabled: true),
    );
    await _pumpTestApp(tester, store: store);
    final handle = find.byKey(const ValueKey('note-drag-handle-note-a'));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    await tester.timedDrag(
      handle,
      const Offset(177.75, 10),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    final moving = tester
        .widgetList<EditableNote>(find.byType(EditableNote))
        .firstWhere((widget) => widget.note.id == 'note-a');
    expect(moving.note.x, 540);
    expect(find.byKey(const ValueKey('canvas-snap-guides')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .firstWhere((widget) => widget.note.id == 'note-a')
          .note
          .x,
      300,
    );
  });

  testWidgets('disabled Snap preserves exact free movement', (tester) async {
    final store = _MemoryBoardStore(
      board: _connectedBoard(
        timestamp: DateTime.utc(2026, 9, 16),
      ).copyWith(isSnappingEnabled: false),
    );
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-note-a')));
    await tester.pumpAndSettle();

    await tester.timedDrag(
      find.byKey(const ValueKey('note-drag-handle-note-a')),
      const Offset(177.75, 10),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<EditableNote>(find.byType(EditableNote))
          .firstWhere((widget) => widget.note.id == 'note-a')
          .note
          .x,
      537,
    );
    expect(find.byKey(const ValueKey('canvas-snap-guides')), findsNothing);
  });

  testWidgets('Snap uses group bounds without changing member spacing', (
    tester,
  ) async {
    final store = _MemoryBoardStore(
      board: _selectionSetBoard(
        grouped: true,
      ).copyWith(isSnappingEnabled: true),
    );
    await _pumpTestApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('note-drag-handle-group-a')));
    await tester.pumpAndSettle();

    final handle = find.byKey(const ValueKey('selected-group-move-handle'));
    await tester.timedDrag(
      handle,
      const Offset(57.75, 10),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    final notes = {
      for (final widget in tester.widgetList<EditableNote>(
        find.byType(EditableNote),
      ))
        widget.note.id: widget.note,
    };
    expect(notes['group-a']!.x, 340);
    expect(notes['group-b']!.x, 640);
    expect(notes['group-b']!.x - notes['group-a']!.x, 300);
    expect(find.byKey(const ValueKey('canvas-snap-guides')), findsNothing);
  });

  testWidgets(
    'carries eligible grouped text objects between Boards with one history action',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 21, 20);
      final clipboard = CrossBoardClipboard();
      final sourceStore = _MemoryBoardStore(
        board: BoardDocument(
          id: 'source-board',
          name: 'Source',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [
            Note(
              id: 'source-note-a',
              x: 100,
              y: 140,
              width: 280,
              height: 190,
              text: 'Linked source text',
              title: 'Source title',
              emphasis: const [NoteEmphasisRange(start: 0, end: 6, bold: true)],
              links: const [
                NoteTextLinkRange(
                  start: 7,
                  end: 13,
                  destination: 'https://example.com/source',
                ),
              ],
              createdAt: timestamp,
              modifiedAt: timestamp,
              color: NoteColor.green,
            ),
            Note(
              id: 'source-note-b',
              x: 520,
              y: 220,
              width: 240,
              height: 160,
              text: 'Connected thought',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          connectors: [
            Connector(
              id: 'source-connector',
              objectAId: 'source-note-a',
              objectBId: 'source-note-b',
              label: 'supports',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          headings: [
            CanvasHeading(
              id: 'source-heading',
              x: 280,
              y: 60,
              text: 'Source cluster',
              size: CanvasHeadingSize.large,
              background: CanvasHeadingBackground.purple,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          groups: [
            BoardGroup(
              id: 'source-group',
              memberIds: const [
                'source-note-a',
                'source-note-b',
                'source-heading',
              ],
              isVisible: true,
              name: 'Reusable cluster',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          lockedObjectIds: const {'source-note-b'},
        ),
      );
      await _pumpTestApp(
        tester,
        store: sourceStore,
        crossBoardClipboard: clipboard,
      );
      await tester.tap(
        find.byKey(const ValueKey('note-drag-handle-source-note-a')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
      await tester.pumpAndSettle();
      expect(clipboard.hasPayload, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final destinationStore = _MemoryBoardStore(
        board: BoardDocument(
          id: 'destination-board',
          name: 'Destination',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 600,
          viewportY: 400,
          viewportZoom: 1,
          notes: const [],
        ),
      );
      await _pumpTestApp(
        tester,
        store: destinationStore,
        crossBoardClipboard: clipboard,
      );
      final viewportSize = tester.getSize(find.byType(InteractiveViewer));
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();

      var pasted = destinationStore.board!;
      expect(pasted.notes, hasLength(2));
      expect(pasted.headings, hasLength(1));
      expect(pasted.connectors, hasLength(1));
      expect(pasted.groups, hasLength(1));
      expect(pasted.groups.single.name, 'Reusable cluster');
      final pastedIds = {
        ...pasted.notes.map((note) => note.id),
        pasted.headings.single.id,
      };
      expect(
        pastedIds.intersection({
          'source-note-a',
          'source-note-b',
          'source-heading',
        }),
        isEmpty,
      );
      expect(pasted.groups.single.memberIds.toSet(), pastedIds);
      expect(pasted.lockedObjectIds, hasLength(1));
      expect(pastedIds, containsAll(pasted.lockedObjectIds));
      expect(
        pastedIds,
        containsAll([
          pasted.connectors.single.objectAId,
          pasted.connectors.single.objectBId,
        ]),
      );
      final richNote = pasted.notes.singleWhere(
        (note) => note.title == 'Source title',
      );
      expect(richNote.text, 'Linked source text');
      expect(richNote.color, NoteColor.green);
      expect(richNote.emphasis, hasLength(1));
      expect(richNote.links.single.destination, 'https://example.com/source');
      expect(pasted.headings.single.text, 'Source cluster');
      expect(pasted.headings.single.size, CanvasHeadingSize.large);
      expect(pasted.headings.single.background, CanvasHeadingBackground.purple);
      var pastedBounds = <Rect>[
        for (final note in pasted.notes)
          Rect.fromLTWH(note.x, note.y, note.width, note.height),
        CanvasHeadingGeometry.boundsFor(pasted.headings.single),
      ].reduce((value, element) => value.expandToInclude(element));
      expect(
        pastedBounds.center.dx,
        closeTo(600 + viewportSize.width / 2, 0.01),
      );
      expect(
        pastedBounds.center.dy,
        closeTo(400 + viewportSize.height / 2, 0.01),
      );

      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      pasted = destinationStore.board!;
      expect(pasted.notes, hasLength(4));
      expect(pasted.headings, hasLength(2));
      expect(pasted.connectors, hasLength(2));
      expect(pasted.groups, hasLength(2));

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(destinationStore.board!.notes, hasLength(2));
      expect(destinationStore.board!.groups, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      expect(destinationStore.board!.notes, hasLength(4));
      expect(destinationStore.board!.groups, hasLength(2));
    },
  );

  testWidgets('captures one eligible Image for the cross-Board clipboard', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 22, 11);
    final sourceImage = BoardImage(
      id: 'eligible-source-image',
      x: 180,
      y: 140,
      width: 320,
      height: 180,
      assetPath: 'assets/source.png',
      originalFileName: 'Source reference.png',
      pixelWidth: 1,
      pixelHeight: 1,
      caption: 'Independent reference',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final clipboard = CrossBoardClipboard();
    var captureCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: _MemoryBoardStore(
            board: BoardDocument(
              id: 'eligible-image-source-board',
              name: 'Eligible Image source',
              createdAt: timestamp,
              modifiedAt: timestamp,
              viewportX: 0,
              viewportY: 0,
              viewportZoom: 1,
              notes: const [],
              images: [sourceImage],
              lockedObjectIds: const {'eligible-source-image'},
            ),
          ),
          imageAssetStore: _TestImageAssetStore(),
          imagePicker: () async => null,
          imageViewBuilder: (_) => const SizedBox(),
          crossBoardClipboard: clipboard,
          crossBoardImageSnapshotCapturer:
              ({required image, required sourceFile}) async {
                captureCalls++;
                expect(image, sourceImage);
                return CrossBoardImageSnapshot.fromValidatedBytes(
                  image: image,
                  bytes: _onePixelPng,
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .onSelect();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();

    expect(captureCalls, 1);
    expect(clipboard.payload!.image!.bytes, orderedEquals(_onePixelPng));
    expect(clipboard.payload!.lockedObjectIds, {'eligible-source-image'});
    expect(
      find.text('Copied 1 Image for this and other Boards.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'pastes one independent managed Image across Boards with history',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 22, 12);
      final sourceImage = BoardImage(
        id: 'cross-board-source-image',
        x: 180,
        y: 140,
        width: 320,
        height: 180,
        assetPath: 'assets/source.png',
        originalFileName: 'Source reference.png',
        pixelWidth: 1,
        pixelHeight: 1,
        caption: 'Independent reference',
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
      final clipboard = CrossBoardClipboard()
        ..publish(
          CrossBoardClipboardPayload(
            sourceBoardId: 'image-source-board',
            notes: const [],
            connectors: const [],
            headings: const [],
            groups: const [],
            lockedObjectIds: const {'cross-board-source-image'},
            image: CrossBoardImageSnapshot.fromValidatedBytes(
              image: sourceImage,
              bytes: _onePixelPng,
            ),
          ),
        );

      final destinationStore = _MemoryBoardStore(
        board: BoardDocument(
          id: 'image-destination-board',
          name: 'Image destination',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 600,
          viewportY: 400,
          viewportZoom: 1,
          notes: const [],
        ),
      );
      final destinationAssets = _TestImageAssetStore(
        importedAsset: const ManagedImageAsset(
          assetPath: 'assets/destination.png',
          originalFileName: 'Source reference.png',
          pixelWidth: 1,
          pixelHeight: 1,
        ),
      );
      await _pumpTestApp(
        tester,
        store: destinationStore,
        crossBoardClipboard: clipboard,
        imageAssetStore: destinationAssets,
        imageViewBuilder: (_) => const SizedBox(),
      );
      await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
      await tester.pumpAndSettle();

      expect(destinationAssets.importByteCalls, 1);
      expect(destinationAssets.receivedBytes, orderedEquals(_onePixelPng));
      expect(
        destinationAssets.receivedOriginalFileName,
        'Source reference.png',
      );
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      var pasted = destinationStore.board!.images.single;
      expect(pasted.id, isNot('cross-board-source-image'));
      expect(pasted.assetPath, 'assets/destination.png');
      expect(pasted.caption, 'Independent reference');
      expect(destinationStore.board!.lockedObjectIds, {pasted.id});

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveBoardImage), findsNothing);
      await tester.tap(find.byKey(const ValueKey('redo-button')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-board-button')));
      await tester.pumpAndSettle();
      pasted = destinationStore.board!.images.single;
      expect(pasted.assetPath, 'assets/destination.png');
    },
  );

  testWidgets(
    'failed cross-Board Image publication is non-mutating and retryable',
    (tester) async {
      final timestamp = DateTime.utc(2026, 9, 22, 13);
      final sourceImage = BoardImage(
        id: 'retry-source-image',
        x: 100,
        y: 100,
        width: 200,
        height: 120,
        assetPath: 'assets/retry.png',
        originalFileName: 'Retry.png',
        pixelWidth: 1,
        pixelHeight: 1,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
      final clipboard = CrossBoardClipboard()
        ..publish(
          CrossBoardClipboardPayload(
            sourceBoardId: 'retry-source-board',
            notes: const [],
            connectors: const [],
            headings: const [],
            groups: const [],
            lockedObjectIds: const {},
            image: CrossBoardImageSnapshot.fromValidatedBytes(
              image: sourceImage,
              bytes: _onePixelPng,
            ),
          ),
        );
      final store = _MemoryBoardStore(
        board: BoardDocument(
          id: 'retry-destination-board',
          name: 'Retry destination',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
        ),
      );
      final assets = _TestImageAssetStore();
      await _pumpTestApp(
        tester,
        store: store,
        crossBoardClipboard: clipboard,
        imageAssetStore: assets,
        imageViewBuilder: (_) => const SizedBox(),
      );

      Future<void> paste() async {
        await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
        await tester.pumpAndSettle();
      }

      await paste();
      expect(assets.importByteCalls, 1);
      expect(find.byType(InteractiveBoardImage), findsNothing);
      expect(store.saveCalls, 0);
      expect(clipboard.hasPayload, isTrue);
      expect(
        find.text(
          'Could not publish the copied Image on this Board. Nothing was pasted; try again.',
        ),
        findsOneWidget,
      );

      assets.importedAsset = const ManagedImageAsset(
        assetPath: 'assets/retry-destination.png',
        originalFileName: 'Retry.png',
        pixelWidth: 1,
        pixelHeight: 1,
      );
      await paste();
      expect(assets.importByteCalls, 2);
      expect(find.byType(InteractiveBoardImage), findsOneWidget);
    },
  );

  testWidgets('failed Image capture clears stale cross-Board content', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 22, 14);
    final clipboard = CrossBoardClipboard()
      ..publish(
        CrossBoardClipboardPayload(
          sourceBoardId: 'stale-board',
          notes: [
            Note(
              id: 'stale-note',
              x: 0,
              y: 0,
              width: 200,
              height: 120,
              text: 'Stale',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          connectors: const [],
          headings: const [],
          groups: const [],
          lockedObjectIds: const {},
        ),
      );
    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: BoardDocument(
          id: 'missing-image-board',
          name: 'Missing Image',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
          images: [
            BoardImage(
              id: 'missing-source-image',
              x: 100,
              y: 100,
              width: 200,
              height: 120,
              assetPath: 'assets/missing.png',
              originalFileName: 'Missing.png',
              pixelWidth: 1,
              pixelHeight: 1,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
        ),
      ),
      crossBoardClipboard: clipboard,
      imageAssetStore: _TestImageAssetStore(resolveError: true),
      imageViewBuilder: (_) => const SizedBox(),
    );
    tester
        .widget<InteractiveBoardImage>(find.byType(InteractiveBoardImage))
        .onSelect();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.pumpAndSettle();

    expect(clipboard.hasPayload, isFalse);
    expect(
      find.text(
        'Could not copy this Image to other Boards. It remains available for Paste on this Board.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveBoardImage), findsNWidgets(2));
  });

  testWidgets('pastes a mixed foreground snapshot with independent assets', (
    tester,
  ) async {
    final setup = await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('vasmim-mixed-test-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final sourceDir = await Directory('${root.path}/source').create();
      final sourceFiles = <String, File>{};
      for (final name in ['one.png', 'two.png', 'preview.png', 'thumb.png']) {
        sourceFiles['assets/$name'] = await File(
          '${sourceDir.path}/$name',
        ).writeAsBytes(_onePixelPng);
      }
      sourceFiles['assets/reference.pdf'] = await File(
        '${sourceDir.path}/reference.pdf',
      ).writeAsBytes('%PDF-1.4 example'.codeUnits);
      final now = DateTime.utc(2026, 9, 23, 12);
      final sourceNote = Note(
        id: 'source-note',
        x: 100,
        y: 100,
        width: 260,
        height: 170,
        text: 'Mixed Board idea',
        createdAt: now,
        modifiedAt: now,
      );
      final sourceImages = [
        for (final name in ['one', 'two'])
          BoardImage(
            id: 'source-$name',
            x: name == 'one' ? 400 : 650,
            y: 100,
            width: 200,
            height: 120,
            assetPath: 'assets/$name.png',
            originalFileName: '$name.png',
            pixelWidth: 1,
            pixelHeight: 1,
            createdAt: now,
            modifiedAt: now,
          ),
      ];
      final sourceAttachment = BoardAttachment(
        id: 'source-attachment',
        x: 100,
        y: 350,
        width: 300,
        height: 112,
        assetPath: 'assets/reference.pdf',
        originalFileName: 'reference.pdf',
        kind: AttachmentKind.pdf,
        byteSize: 16,
        previewAssetPath: 'assets/preview.png',
        createdAt: now,
        modifiedAt: now,
      );
      final sourceYouTube = YouTubeEmbed(
        id: 'source-youtube',
        x: 500,
        y: 350,
        width: 300,
        height: 168,
        originalUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
        videoId: 'abcdefghijk',
        thumbnailAssetPath: 'assets/thumb.png',
        createdAt: now,
        modifiedAt: now,
      );
      final sourceHeading = CanvasHeading(
        id: 'source-heading',
        x: 850,
        y: 100,
        text: 'References',
        size: CanvasHeadingSize.medium,
        background: CanvasHeadingBackground.blue,
        createdAt: now,
        modifiedAt: now,
      );
      final snapshot = await CrossBoardForegroundSnapshot.capture(
        notes: [sourceNote],
        connectors: [
          Connector(
            id: 'source-connector',
            objectAId: sourceNote.id,
            objectBId: sourceImages.first.id,
            label: 'reference',
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        images: sourceImages,
        headings: [sourceHeading],
        attachments: [sourceAttachment],
        youTubeEmbeds: [sourceYouTube],
        groups: [
          BoardGroup(
            id: 'source-group',
            memberIds: [
              sourceNote.id,
              ...sourceImages.map((image) => image.id),
              sourceAttachment.id,
              sourceYouTube.id,
              sourceHeading.id,
            ],
            name: 'Reference cluster',
            isVisible: true,
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        lockedObjectIds: const {'source-one'},
        resolveImage: (path) async => sourceFiles[path]!,
        resolveAttachment: (path) async => sourceFiles[path]!,
      );
      final clipboard = CrossBoardClipboard()
        ..publish(
          CrossBoardClipboardPayload(
            sourceBoardId: 'source-board',
            notes: const [],
            connectors: const [],
            headings: const [],
            groups: const [],
            lockedObjectIds: const {},
            foreground: snapshot,
          ),
        );
      await sourceDir.delete(recursive: true);
      return (clipboard: clipboard, now: now);
    });
    final clipboard = setup!.clipboard;
    final now = setup.now;
    final destinationImages = _TransferImageAssetStore();
    final destinationAttachments = _TransferAttachmentAssetStore();
    final destinationStore = _MemoryBoardStore(
      board: BoardDocument(
        id: 'destination-board',
        name: 'Destination',
        createdAt: now,
        modifiedAt: now,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
      ),
    );
    await _pumpTestApp(
      tester,
      store: destinationStore,
      crossBoardClipboard: clipboard,
      imageAssetStore: destinationImages,
      attachmentAssetStore: destinationAttachments,
      imageViewBuilder: (_) => const SizedBox(),
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();

    final pasted = destinationStore.board!;
    expect(pasted.notes, hasLength(1));
    expect(pasted.images, hasLength(2));
    expect(pasted.headings, hasLength(1));
    expect(pasted.attachments, hasLength(1));
    expect(pasted.youTubeEmbeds, hasLength(1));
    expect(pasted.groups, hasLength(1));
    expect(pasted.groups.single.memberIds, hasLength(6));
    expect(pasted.groups.single.name, 'Reference cluster');
    expect(pasted.connectors, hasLength(1));
    expect(pasted.connectors.single.objectAId, pasted.notes.single.id);
    expect(pasted.connectors.single.objectBId, pasted.images.first.id);
    expect(pasted.lockedObjectIds, {pasted.images.first.id});
    final assetPaths = [
      ...pasted.images.map((image) => image.assetPath),
      pasted.attachments.single.assetPath,
      pasted.attachments.single.previewAssetPath!,
      pasted.youTubeEmbeds.single.thumbnailAssetPath!,
    ];
    expect(assetPaths.toSet(), hasLength(5));
    expect(destinationImages.importCount, 4);
    expect(destinationAttachments.importCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final retryStore = _MemoryBoardStore(
      board: BoardDocument(
        id: 'retry-board',
        name: 'Retry',
        createdAt: now,
        modifiedAt: now,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
      ),
    );
    final retryImages = _TransferImageAssetStore(failAt: 2);
    await _pumpTestApp(
      tester,
      store: retryStore,
      crossBoardClipboard: clipboard,
      imageAssetStore: retryImages,
      attachmentAssetStore: _TransferAttachmentAssetStore(),
      imageViewBuilder: (_) => const SizedBox(),
    );
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();
    expect(retryStore.board!.notes, isEmpty);
    expect(retryStore.board!.images, isEmpty);
    retryImages.failAt = null;
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-board-button')));
    await tester.pumpAndSettle();
    expect(retryStore.board!.images, hasLength(2));
    clipboard.clear();
  });

  testWidgets('failed multi-Image Copy clears only the cross-Board payload', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 21, 21);
    final clipboard = CrossBoardClipboard()
      ..publish(
        CrossBoardClipboardPayload(
          sourceBoardId: 'earlier-board',
          notes: [
            Note(
              id: 'earlier-note',
              x: 0,
              y: 0,
              width: 260,
              height: 170,
              text: 'Earlier',
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ],
          connectors: const [],
          headings: const [],
          groups: const [],
          lockedObjectIds: const {},
        ),
      );
    final imageStore = _MemoryBoardStore(
      board: BoardDocument(
        id: 'image-board',
        name: 'Image source',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        images: [
          BoardImage(
            id: 'source-image',
            x: 200,
            y: 160,
            width: 320,
            height: 180,
            assetPath: 'assets/source.png',
            originalFileName: 'source.png',
            pixelWidth: 640,
            pixelHeight: 360,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
          BoardImage(
            id: 'source-image-2',
            x: 600,
            y: 200,
            width: 240,
            height: 160,
            assetPath: 'assets/source-2.png',
            originalFileName: 'source-2.png',
            pixelWidth: 480,
            pixelHeight: 320,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      ),
    );
    await _pumpTestApp(
      tester,
      store: imageStore,
      crossBoardClipboard: clipboard,
      imageViewBuilder: (_) => const SizedBox(),
    );
    tester
        .widget<InteractiveBoardImage>(
          find.byKey(const ValueKey('source-image')),
        )
        .onSelect();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester
        .widget<InteractiveBoardImage>(
          find.byKey(const ValueKey('source-image-2')),
        )
        .onSelect();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-note-menu-item')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(clipboard.hasPayload, isFalse);
    await tester.tap(find.byKey(const ValueKey('clipboard-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-note-menu-item')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveBoardImage), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pumpTestApp(
      tester,
      store: _MemoryBoardStore(
        board: BoardDocument(
          id: 'other-board',
          name: 'Other',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: const [],
        ),
      ),
      crossBoardClipboard: clipboard,
    );
    expect(
      tester
          .widget<PopupMenuButton>(
            find.byKey(const ValueKey('clipboard-menu-button')),
          )
          .enabled,
      isFalse,
    );
  });
}

BoardDocument _selectionSetBoard({bool grouped = false}) {
  final timestamp = DateTime.utc(2026, 9, 14, 10);
  Note note(String id, double x, String text) => Note(
    id: id,
    x: x,
    y: 260,
    width: 220,
    height: 150,
    text: text,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
  return BoardDocument(
    id: 'selection-set-board',
    name: 'Selection set board',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 0.75,
    notes: [
      note('group-a', 260, 'First group member'),
      note('group-b', 560, 'Second group member'),
      note('outside-group', 860, 'Outside group'),
    ],
    groups: grouped
        ? [
            BoardGroup(
              id: 'selection-set-1',
              memberIds: const ['group-a', 'group-b'],
              isVisible: true,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
          ]
        : const [],
  );
}

BoardDocument _walkthroughBoard({int sceneCount = 3}) {
  final timestamp = DateTime.utc(2026, 8, 23);
  final scenes = [
    Scene(
      id: '123e4567-e89b-42d3-a456-426614174101',
      name: 'Question',
      x: 420,
      y: 320,
      zoom: 0.8,
      createdAt: timestamp,
      modifiedAt: timestamp,
    ),
    Scene(
      id: '123e4567-e89b-42d3-a456-426614174102',
      name: 'Evidence',
      x: 1480,
      y: 860,
      zoom: 0.65,
      createdAt: timestamp.add(const Duration(minutes: 1)),
      modifiedAt: timestamp.add(const Duration(minutes: 1)),
    ),
    Scene(
      id: '123e4567-e89b-42d3-a456-426614174103',
      name: 'Plan',
      x: 2520,
      y: 1720,
      zoom: 0.5,
      createdAt: timestamp.add(const Duration(minutes: 2)),
      modifiedAt: timestamp.add(const Duration(minutes: 2)),
    ),
    Scene(
      id: '123e4567-e89b-42d3-a456-426614174104',
      name: 'Evidence duplicate',
      x: 1480,
      y: 860,
      zoom: 0.65,
      createdAt: timestamp.add(const Duration(minutes: 3)),
      modifiedAt: timestamp.add(const Duration(minutes: 3)),
    ),
  ];
  return BoardDocument(
    id: 'scene-walkthrough-board',
    name: 'Scene walkthrough',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 160,
    viewportY: 120,
    viewportZoom: 0.9,
    notes: [
      Note(
        id: 'walkthrough-note',
        x: 300,
        y: 200,
        width: 260,
        height: 170,
        text: 'Walkthrough note',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
    scenes: scenes.take(sceneCount).toList(growable: false),
  );
}

void _expectViewportAtScene(WidgetTester tester, Scene scene) {
  final controller = tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!;
  final origin = controller.toScene(Offset.zero);
  expect(origin.dx, closeTo(scene.x, 0.001));
  expect(origin.dy, closeTo(scene.y, 0.001));
  expect(controller.value.getMaxScaleOnAxis(), closeTo(scene.zoom, 0.001));
}

typedef ConnectorSegmentSnapshot = ({Offset start, Offset end});

Future<_MemoryBoardStore> _pumpImageBoard(
  WidgetTester tester, {
  required BoardImage image,
  double viewportX = 0,
  double viewportY = 0,
}) async {
  final store = _MemoryBoardStore(
    board: BoardDocument(
      id: 'image-board',
      name: 'Image board',
      createdAt: image.createdAt,
      modifiedAt: image.modifiedAt,
      viewportX: viewportX,
      viewportY: viewportY,
      viewportZoom: 0.75,
      notes: const [],
      connectors: const [],
      images: [image],
    ),
  );
  await tester.pumpWidget(
    MainApp(
      key: ValueKey('image-board-${image.x}-$viewportX-$viewportY'),
      boardStore: store,
      imageAssetStore: _TestImageAssetStore(resolveError: true),
      imagePicker: () async => null,
      imageViewBuilder: (current) => SizedBox(
        key: ValueKey('test-image-${current.id}'),
        width: current.width,
        height: current.height,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<_MemoryBoardStore> _pumpMixedBoard(
  WidgetTester tester, {
  required DateTime timestamp,
  bool includeDistantNote = false,
}) async {
  final image = _testBoardImage(timestamp: timestamp, x: 700, y: 400);
  final store = _MemoryBoardStore(
    board: BoardDocument(
      id: 'mixed-board',
      name: 'Mixed board',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 0.75,
      notes: [
        Note(
          id: 'mixed-note',
          x: 300,
          y: 200,
          width: 260,
          height: 170,
          text: 'Mixed note',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
        if (includeDistantNote)
          Note(
            id: 'distant-note',
            x: 3400,
            y: 2500,
            width: 260,
            height: 170,
            text: 'Distant',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
      ],
      connectors: const [],
      images: [image],
    ),
  );
  await tester.pumpWidget(
    MainApp(
      key: ValueKey('mixed-board-$includeDistantNote'),
      boardStore: store,
      imageAssetStore: _TestImageAssetStore(resolveError: true),
      imagePicker: () async => null,
      imageViewBuilder: (current) => SizedBox(
        key: ValueKey('test-image-${current.id}'),
        width: current.width,
        height: current.height,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

BoardImage _testBoardImage({
  required DateTime timestamp,
  double x = 400,
  double y = 300,
}) {
  return BoardImage(
    id: 'board-image',
    x: x,
    y: y,
    width: 320,
    height: 180,
    assetPath: 'assets/board-image.png',
    originalFileName: 'planning-reference.png',
    pixelWidth: 1600,
    pixelHeight: 900,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
}

BoardDocument _noteSearchBoard() {
  final timestamp = DateTime.utc(2026, 8, 25, 19, 30);
  Note note(String id, double x, double y, String text, {String? title}) =>
      Note(
        id: id,
        x: x,
        y: y,
        width: 260,
        height: 170,
        text: text,
        title: title,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
  BoardImage image(String id, double x, double y, String originalFileName) =>
      BoardImage(
        id: id,
        x: x,
        y: y,
        width: 320,
        height: 180,
        assetPath: 'assets/$id.png',
        originalFileName: originalFileName,
        pixelWidth: 1600,
        pixelHeight: 900,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
  return BoardDocument(
    id: 'note-search-board',
    name: 'Note search board',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 0.5,
    notes: [
      note('search-a', 200, 200, 'Starting thought', title: 'FretFlip release'),
      note('search-b', 700, 300, 'First SHARED phrase example'),
      note('search-empty', 1100, 500, '   '),
      note(
        'search-d',
        1700,
        900,
        'Second multiline\nshared phrase with more context',
      ),
      note('search-other', 2300, 1400, 'Completely unrelated note'),
      note(
        'search-target',
        3000,
        2000,
        'The distant lighthouse marks this result',
      ),
    ],
    images: [
      image('image-a', 500, 1700, 'Shared Reference.PNG'),
      image('image-b', 1100, 1900, 'shared reference detail.jpg'),
      image('image-missing', 2200, 500, 'Unavailable Diagram.png'),
      image('image-target', 3200, 2300, 'Distant Lighthouse.JPG'),
    ],
    connectors: [
      Connector(
        id: 'connection-a',
        objectAId: 'search-a',
        objectBId: 'search-b',
        label: 'Shared Link',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Connector(
        id: 'connection-b',
        objectAId: 'search-d',
        objectBId: 'image-a',
        label: 'shared link follow-up',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Connector(
        id: 'connection-missing',
        objectAId: 'search-other',
        objectBId: 'image-missing',
        label: 'Unavailable endpoint',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Connector(
        id: 'connection-target',
        objectAId: 'search-target',
        objectBId: 'image-target',
        label: 'Distant relationship',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Connector(
        id: 'connection-unlabeled',
        objectAId: 'image-b',
        objectBId: 'image-missing',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
  );
}

Widget _searchImageView(BoardImage image) => SizedBox(
  key: ValueKey('search-image-${image.id}'),
  width: image.width,
  height: image.height,
);

BoardDocument _connectedBoard({
  required DateTime timestamp,
  bool includeConnector = true,
  bool includeThirdNote = false,
  bool includeExternalConnector = false,
  List<BoardImage> images = const [],
  String connectorObjectAId = 'note-a',
  String connectorObjectBId = 'note-b',
  double viewportX = 0,
  String? connectorLabel,
  String noteAText = 'A',
  String noteBText = 'B',
  String noteCText = 'C',
}) {
  return BoardDocument(
    id: 'connected-board',
    name: 'Connected board',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: viewportX,
    viewportY: 0,
    viewportZoom: 0.75,
    notes: [
      Note(
        id: 'note-a',
        x: 300,
        y: 200,
        width: 260,
        height: 170,
        text: noteAText,
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Note(
        id: 'note-b',
        x: 800,
        y: 200,
        width: 260,
        height: 170,
        text: noteBText,
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      if (includeThirdNote)
        Note(
          id: 'note-c',
          x: 600,
          y: 450,
          width: 260,
          height: 170,
          text: noteCText,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
    ],
    connectors: includeConnector
        ? [
            Connector(
              id: 'connector-a-b',
              objectAId: connectorObjectAId,
              objectBId: connectorObjectBId,
              label: connectorLabel,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
            if (includeExternalConnector)
              Connector(
                id: 'connector-a-c',
                objectAId: 'note-a',
                objectBId: 'note-c',
                createdAt: timestamp,
                modifiedAt: timestamp,
              ),
          ]
        : const [],
    images: images,
  );
}

BoardDocument _connectedClusterBoard(DateTime timestamp) {
  Note note(String id, double x, double y) => Note(
    id: id,
    x: x,
    y: y,
    width: 210,
    height: 130,
    text: id,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
  Connector connector(String id, String objectAId, String objectBId) =>
      Connector(
        id: id,
        objectAId: objectAId,
        objectBId: objectBId,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
  return BoardDocument(
    id: 'connected-cluster-board',
    name: 'Connected cluster board',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 0.75,
    notes: [
      note('cluster-a', 100, 100),
      note('cluster-b', 440, 100),
      note('cluster-c', 440, 390),
      note('cluster-d', 100, 390),
    ],
    images: [
      BoardImage(
        id: 'cluster-image',
        x: 800,
        y: 300,
        width: 220,
        height: 140,
        assetPath: 'assets/cluster-image.png',
        originalFileName: 'cluster-image.png',
        pixelWidth: 1100,
        pixelHeight: 700,
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
    connectors: [
      connector('cluster-a-b', 'cluster-a', 'cluster-b'),
      connector('cluster-b-c', 'cluster-b', 'cluster-c'),
      connector('cluster-c-image', 'cluster-c', 'cluster-image'),
      connector('cluster-image-a', 'cluster-image', 'cluster-a'),
    ],
  );
}

BoardDocument _crossingConnectorBoard(DateTime timestamp) {
  Note note(String id, double x, double y) => Note(
    id: id,
    x: x,
    y: y,
    width: 260,
    height: 170,
    text: id,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
  Connector connector(String id, String objectAId, String objectBId) =>
      Connector(
        id: id,
        objectAId: objectAId,
        objectBId: objectBId,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
  return BoardDocument(
    id: 'crossing-connector-board',
    name: 'Crossing connector board',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 0.75,
    notes: [
      note('note-a', 100, 100),
      note('note-b', 900, 600),
      note('note-c', 100, 600),
      note('note-d', 900, 100),
    ],
    connectors: [
      connector('connector-a-b', 'note-a', 'note-b'),
      connector('connector-c-d', 'note-c', 'note-d'),
    ],
  );
}

class _MemoryBoardStore implements BoardStore {
  _MemoryBoardStore({this.board});

  BoardDocument? board;
  int saveCalls = 0;

  @override
  Future<BoardDocument?> load() async => board;

  @override
  Future<void> save(BoardDocument board) async {
    saveCalls += 1;
    this.board = board;
  }
}

class _FailingBoardStore implements BoardStore {
  int saveCalls = 0;
  @override
  Future<BoardDocument?> load() async {
    throw const FormatException('Invalid test board');
  }

  @override
  Future<void> save(BoardDocument board) async {
    saveCalls++;
  }
}

class _DelayedBoardStore extends _MemoryBoardStore {
  final release = Completer<void>();
  @override
  Future<void> save(BoardDocument board) async {
    saveCalls++;
    await release.future;
    this.board = board;
  }
}

class _SaveFailingBoardStore extends _MemoryBoardStore {
  bool fail = true;
  @override
  Future<void> save(BoardDocument board) async {
    if (fail) throw const FileSystemException('Disk unavailable');
    await super.save(board);
  }
}

class _TransferImageAssetStore implements ImageAssetStore {
  _TransferImageAssetStore({this.failAt});

  int importCount = 0;
  int? failAt;

  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) async => null;

  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) async {
    if (bytes == null || bytes.isEmpty) return null;
    importCount++;
    if (importCount == failAt) return null;
    return ManagedImageAsset(
      assetPath: 'assets/copied-$importCount.png',
      originalFileName: originalFileName,
      pixelWidth: 1,
      pixelHeight: 1,
    );
  }

  @override
  Future<File> resolve(String assetPath) async => File(assetPath);
}

class _TransferAttachmentAssetStore implements AttachmentAssetStore {
  int importCount = 0;

  @override
  Future<AttachmentImportCandidate?> inspectPath(String? sourcePath) async =>
      null;

  @override
  Future<ManagedAttachmentAsset> importCandidate(
    AttachmentImportCandidate candidate,
  ) async {
    importCount++;
    return ManagedAttachmentAsset(
      assetPath: 'assets/copied-$importCount.pdf',
      originalFileName: candidate.originalFileName,
      kind: candidate.kind,
      byteSize: candidate.byteSize,
    );
  }

  @override
  Future<File> resolve(String assetPath) async => File(assetPath);
}

class _TestImageAssetStore implements ImageAssetStore {
  _TestImageAssetStore({this.importedAsset, this.resolveError = false});

  ManagedImageAsset? importedAsset;
  final bool resolveError;
  int importCalls = 0;
  int importByteCalls = 0;
  Uint8List? receivedBytes;
  String? receivedOriginalFileName;

  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) async {
    importCalls += 1;
    return importedAsset;
  }

  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) async {
    importByteCalls += 1;
    receivedBytes = bytes;
    receivedOriginalFileName = originalFileName;
    return importedAsset;
  }

  @override
  Future<File> resolve(String assetPath) async {
    if (resolveError) {
      throw const FileSystemException('Missing test asset');
    }
    return File(assetPath);
  }
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _UnavailableYouTubeThumbnailFetcher implements YouTubeThumbnailFetcher {
  const _UnavailableYouTubeThumbnailFetcher();

  @override
  Future<Uint8List?> fetch(String videoId) async => null;
}

class _TestYouTubeThumbnailFetcher implements YouTubeThumbnailFetcher {
  _TestYouTubeThumbnailFetcher(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> fetch(String videoId) async => bytes;
}

class _TestClipboardImageReader implements ClipboardImageReader {
  _TestClipboardImageReader({this.payload});

  ClipboardImagePayload? payload;
  int hasImageCalls = 0;
  int readCalls = 0;
  Uint8List? _eligibleBytes;

  @override
  Future<bool> hasImage() async {
    hasImageCalls += 1;
    _eligibleBytes = payload == null
        ? null
        : Uint8List.fromList(payload!.pngBytes);
    return _eligibleBytes != null;
  }

  @override
  Future<ClipboardImagePayload?> readImage() async {
    readCalls += 1;
    final eligibleBytes = _eligibleBytes;
    _eligibleBytes = null;
    final current = payload;
    if (eligibleBytes == null ||
        current == null ||
        !listEquals(eligibleBytes, current.pngBytes)) {
      return null;
    }
    return current;
  }
}
