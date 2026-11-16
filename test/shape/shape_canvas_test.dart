import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/board_store.dart';
import 'package:vasmim/canvas/canvas_experiment.dart';
import 'package:vasmim/canvas/canvas_overview_map.dart';
import 'package:vasmim/group/board_group.dart';
import 'package:vasmim/image/image_asset_store.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/shape/board_shape.dart';
import 'package:vasmim/shape/shape_layer.dart';
import 'package:vasmim/shape/shape_layer_painter.dart';

Future<void> _tapShapeTool(WidgetTester tester, Finder tool) async {
  if (tool.evaluate().isEmpty) {
    final chooser = find.text('Choose a Shape');
    await tester.ensureVisible(chooser);
    await tester.tap(chooser);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(tool);
  await tester.pump();
  await tester.tap(tool);
  await tester.pump();
}

Future<void> _openShapeRollup(
  WidgetTester tester,
  String title,
  String key,
  Finder child,
) async {
  final panelScroll = find
      .descendant(
        of: find.byKey(const ValueKey('shape-side-panel')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    200,
    scrollable: panelScroll,
  );
  if (key == 'shape-order-rollup'
      ? child.evaluate().length <= 1
      : child.evaluate().isEmpty) {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }
}

Future<void> _openShapeLayers(WidgetTester tester) => _openShapeRollup(
  tester,
  'Layers',
  'shape-layers-rollup',
  find.byKey(const ValueKey('rename-shape-layer')),
);

Future<void> _openShapeOrder(WidgetTester tester) => _openShapeRollup(
  tester,
  'Shape order',
  'shape-order-rollup',
  find.descendant(
    of: find.byKey(const ValueKey('shape-order-rollup')),
    matching: find.byType(ListTile),
  ),
);

void main() {
  for (final hidden in [false, true]) {
    testWidgets(
      hidden
          ? 'hidden Shapes cannot activate Shapes mode'
          : 'foreground Notes keep priority over Shapes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final shape = _mixedGroupBoard().shapes.single;
        final store = _ShapeBoardStore(
          _emptyBoard(
            shapes: [shape],
            notes: hidden
                ? []
                : [
                    Note(
                      id: 'cover',
                      x: shape.x,
                      y: shape.y,
                      width: shape.width,
                      height: shape.height,
                      text: 'Cover',
                      createdAt: shape.createdAt,
                      modifiedAt: shape.modifiedAt,
                    ),
                  ],
            shapeLayers: [
              ShapeLayer(
                id: 'layer',
                name: 'Layer',
                shapeIds: [shape.id],
                isVisible: !hidden,
                createdAt: shape.createdAt,
                modifiedAt: shape.modifiedAt,
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CanvasExperiment(
              boardStore: store,
              imageAssetStore: _NoImageStore(),
              imagePicker: () async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final surface = tester.getTopLeft(
          find.byKey(const ValueKey('canvas-interaction-surface')),
        );
        await tester.tapAt(surface + Offset(shape.x + 30, shape.y + 70));
        await tester.pump();
        expect(find.byKey(const ValueKey('shape-side-panel')), findsNothing);
        expect(store.board!.shapes.single.x, shape.x);
      },
    );
  }

  testWidgets(
    'dragging an exposed Shape enters its visible layer and supports undo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final shape = _mixedGroupBoard().shapes.single;
      final time = shape.createdAt;
      final store = _ShapeBoardStore(
        _emptyBoard(
          shapes: [shape],
          shapeLayers: [
            ShapeLayer(
              id: 'target',
              name: 'Target',
              shapeIds: [shape.id],
              createdAt: time,
              modifiedAt: time,
            ),
            ShapeLayer(
              id: 'empty',
              name: 'Empty',
              shapeIds: const [],
              createdAt: time,
              modifiedAt: time,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CanvasExperiment(
            boardStore: store,
            imageAssetStore: _NoImageStore(),
            imagePicker: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.getTopLeft(
        find.byKey(const ValueKey('canvas-interaction-surface')),
      );
      final gesture = await tester.startGesture(
        surface + Offset(shape.x + 30, shape.y + 70),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveBy(const Offset(50, 30));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('shape-side-panel')), findsOneWidget);
      expect(store.board!.shapes.single.x, shape.x + 50);
      expect(store.board!.shapes.single.y, shape.y + 30);
      expect(store.board!.shapeLayers.first.shapeIds, [shape.id]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 700));
      expect(store.board!.shapes.single.x, shape.x);
      expect(store.board!.shapes.single.y, shape.y);
    },
  );

  testWidgets(
    'Shape headings follow theme changes without changing saved colours',
    (tester) async {
      final shape = _mixedGroupBoard().shapes.single.copyWith(
        heading: const ShapeHeading(text: 'Heading', colorValue: 0xFFFFFFFF),
      );
      final store = _ShapeBoardStore(_emptyBoard(shapes: [shape]));
      Future<void> show(Brightness brightness) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: CanvasExperiment(
              boardStore: store,
              imageAssetStore: _NoImageStore(),
              imagePicker: () async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      ShapeLayerPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('background-shape-layer')),
                  )
                  .painter!
              as ShapeLayerPainter;
      await show(Brightness.dark);
      expect(painter().headingColor(shape.heading!.colorValue), Colors.white);
      await show(Brightness.light);
      expect(painter().headingColor(shape.heading!.colorValue), Colors.black);
      expect(painter().headingColor(0xFF000000), Colors.black);
      expect(painter().headingColor(0xFF336699), const Color(0xFF336699));
      await show(Brightness.dark);
      expect(painter().headingColor(0xFF000000), Colors.white);
      expect(store.board!.shapes.single.heading!.colorValue, 0xFFFFFFFF);
    },
  );

  testWidgets('Circle tool creates a square-bounded ellipse', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-circle')),
    );
    final gesture = await tester.startGesture(
      const Offset(180, 180),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(430, 350));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    final shape = store.board!.shapes.single;
    expect(shape.type, BoardShapeType.ellipse);
    expect(shape.width, shape.height);
  });

  testWidgets('Shape drawing follows the visible Snap toggle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('snapping-toggle-button'));
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<IconButton>(toggle).isSelected, isTrue);
    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-rectangle')),
    );
    final surface = tester.getTopLeft(
      find.byKey(const ValueKey('canvas-interaction-surface')),
    );
    var gesture = await tester.startGesture(
      surface + const Offset(163, 163),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(surface + const Offset(317, 317));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));
    final snapped = store.board!.shapes.single;
    expect(snapped.x % 80, 0);
    expect(snapped.y % 80, 0);
    expect(snapped.width % 80, 0);
    expect(snapped.height % 80, 0);

    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<IconButton>(toggle).isSelected, isFalse);
    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-rectangle')),
    );
    gesture = await tester.startGesture(
      surface + const Offset(483, 163),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(surface + const Offset(637, 317));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));
    final free = store.board!.shapes.last;
    expect(free.x % 80, isNot(0));
    expect(free.y % 80, isNot(0));
  });

  testWidgets('draws one background shape and returns to selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shape-side-panel')), findsOneWidget);

    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-rectangle')),
    );
    final gesture = await tester.startGesture(
      const Offset(180, 180),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(520, 390));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapes, hasLength(1));
    expect(store.board!.shapes.single.type, BoardShapeType.rectangle);
    expect(find.byKey(const ValueKey('shape-editing-overlay')), findsOneWidget);
    await tester.tap(find.text('Choose a Shape'));
    await tester.pumpAndSettle();
    final selectButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('shape-tool-select')),
    );
    expect(selectButton.isSelected, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-shape-heading')),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('edit-shape-heading')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shape-heading-field')),
      'Planning area',
    );
    await tester.tap(find.byKey(const ValueKey('save-shape-heading')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapes.single.heading?.text, 'Planning area');

    await tester.tap(find.byKey(const ValueKey('close-shapes-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shape-editing-overlay')), findsNothing);
    expect(
      find.byKey(const ValueKey('background-shape-layer')),
      findsOneWidget,
    );
  });

  testWidgets('first fill colour activates at 100% then preserves reductions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-rectangle')),
    );
    final gesture = await tester.startGesture(
      const Offset(180, 180),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(520, 390));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapes.single.fillOpacity, 0);
    await tester.scrollUntilVisible(
      find.text('Fill colour'),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Fill colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use colour'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapes.single.fillOpacity, 1);
    expect(find.text('100%'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapes.single.fillOpacity, 0);

    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump(const Duration(milliseconds: 700));
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('shape-fill-opacity')),
    );
    slider.onChangeStart!(1);
    slider.onChanged!(0.4);
    slider.onChangeEnd!(0.4);
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapes.single.fillOpacity, 0.4);

    await tester.tap(find.text('Fill colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use colour'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapes.single.fillOpacity, 0.4);
  });

  testWidgets('shape list selects a covered shape without mixed selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final time = DateTime.utc(2026, 9, 9);
    final shape = BoardShape(
      id: 'covered-shape',
      type: BoardShapeType.ellipse,
      x: 100,
      y: 100,
      width: 600,
      height: 400,
      lineStartsAtTopLeft: true,
      lineReversed: false,
      fillColorValue: 0xFF90CAF9,
      fillOpacity: 0.2,
      outlineColorValue: 0xFF37474F,
      outlineWidth: 2,
      heading: const ShapeHeading(text: 'Covered region'),
      createdAt: time,
      modifiedAt: time,
    );
    final store = _ShapeBoardStore(_emptyBoard(shapes: [shape]));
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _openShapeOrder(tester);
    await tester.scrollUntilVisible(
      find.text('Covered region'),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Covered region'));
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-editing-overlay')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-shape-heading')),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('edit-shape-heading')), findsOneWidget);
  });

  testWidgets('draws an expanded shape from the basic-shapes catalogue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-hexagon')),
    );
    expect(find.text('Rectangles & basic shapes'), findsOneWidget);

    final gesture = await tester.startGesture(
      const Offset(240, 220),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(560, 220));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapes, hasLength(1));
    expect(store.board!.shapes.single.type, BoardShapeType.hexagon);
    expect(
      store.board!.shapes.single.height,
      greaterThanOrEqualTo(BoardShape.minimumClosedHeight),
    );
    await tester.tap(find.text('Choose a Shape'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('shape-tool-select')))
          .isSelected,
      isTrue,
    );
  });

  testWidgets('draws an elbow route and changes its first segment direction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _tapShapeTool(
      tester,
      find.byKey(const ValueKey('shape-tool-elbow-line')),
    );
    final gesture = await tester.startGesture(
      const Offset(220, 220),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(560, 420));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapes.single.type, BoardShapeType.elbowLine);
    expect(
      store.board!.shapes.single.routeAxis,
      OrthogonalRouteAxis.horizontalFirst,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('orthogonal-route-axis')),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Down first'));
    await tester.pump();
    await tester.tap(find.text('Down first'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      store.board!.shapes.single.routeAxis,
      OrthogonalRouteAxis.verticalFirst,
    );
  });

  testWidgets('draws both double-ended arrow tools from the Lines catalogue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    for (final entry in const [
      ('shape-tool-double-ended-arrow', Offset(220, 220), Offset(520, 320)),
      (
        'shape-tool-double-ended-elbow-arrow',
        Offset(260, 480),
        Offset(620, 650),
      ),
    ]) {
      await _tapShapeTool(tester, find.byKey(ValueKey(entry.$1)));
      final gesture = await tester.startGesture(
        entry.$2,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveTo(entry.$3);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 700));
    }

    expect(store.board!.shapes.map((shape) => shape.type), [
      BoardShapeType.doubleArrow,
      BoardShapeType.doubleElbowArrow,
    ]);
  });

  testWidgets('draws all four block-arrow catalogue tools', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    final cases = const [
      ('right-block-arrow', Offset(180, 180), Offset(420, 300)),
      ('left-block-arrow', Offset(180, 360), Offset(420, 480)),
      ('up-block-arrow', Offset(520, 200), Offset(660, 440)),
      ('down-block-arrow', Offset(740, 200), Offset(880, 440)),
    ];
    for (final entry in cases) {
      final tool = find.byKey(ValueKey('shape-tool-${entry.$1}'));
      await _tapShapeTool(tester, tool);
      final gesture = await tester.startGesture(
        entry.$2,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveTo(entry.$3);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 700));
    }

    expect(store.board!.shapes.map((shape) => shape.type), [
      BoardShapeType.blockArrowRight,
      BoardShapeType.blockArrowLeft,
      BoardShapeType.blockArrowUp,
      BoardShapeType.blockArrowDown,
    ]);
  });

  testWidgets('draws all four focused flowchart catalogue tools', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    final cases = const [
      ('terminator', Offset(180, 180), Offset(420, 300)),
      ('document', Offset(180, 360), Offset(420, 480)),
      ('database', Offset(520, 180), Offset(760, 320)),
      ('predefined-process', Offset(520, 400), Offset(800, 540)),
    ];
    for (final entry in cases) {
      final tool = find.byKey(ValueKey('shape-tool-${entry.$1}'));
      await _tapShapeTool(tester, tool);
      final gesture = await tester.startGesture(
        entry.$2,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveTo(entry.$3);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 700));
    }

    expect(store.board!.shapes.map((shape) => shape.type), [
      BoardShapeType.terminator,
      BoardShapeType.document,
      BoardShapeType.database,
      BoardShapeType.predefinedProcess,
    ]);
  });

  testWidgets('draws named symbols and new block arrows from the catalogue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();

    final cases = const [
      ('turn-block-arrow', Offset(180, 180), Offset(400, 310)),
      ('star', Offset(440, 180), Offset(640, 380)),
      ('callout', Offset(680, 180), Offset(910, 310)),
      ('curved-line', Offset(180, 430), Offset(420, 570)),
      ('multi-bend-line', Offset(500, 430), Offset(740, 570)),
    ];
    for (final entry in cases) {
      final tool = find.byKey(ValueKey('shape-tool-${entry.$1}'));
      await _tapShapeTool(tester, tool);
      final gesture = await tester.startGesture(
        entry.$2,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveTo(entry.$3);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(store.board!.shapes.map((shape) => shape.type), [
      BoardShapeType.turnBlockArrow,
      BoardShapeType.star,
      BoardShapeType.callout,
      BoardShapeType.curvedLine,
      BoardShapeType.multiBendLine,
    ]);
  });

  testWidgets('selected Shape controls return to the top after drawing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('shape-side-panel'));
    await tester.tap(find.text('Choose a Shape'));
    await tester.pumpAndSettle();
    final callout = find.byKey(const ValueKey('shape-tool-callout'));
    await tester.ensureVisible(callout);
    await tester.pump();
    await tester.tap(callout);
    final gesture = await tester.startGesture(
      const Offset(80, 180),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(280, 320));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapes.single.type, BoardShapeType.callout);
    final panelRect = tester.getRect(panel);
    for (final control in [
      find.text('Outline'),
      find.text('Fill colour'),
      find.byKey(const ValueKey('edit-shape-heading')),
    ]) {
      final rect = tester.getRect(control);
      expect(rect.top, greaterThanOrEqualTo(panelRect.top));
      expect(rect.bottom, lessThanOrEqualTo(panelRect.bottom));
    }
  });

  testWidgets('Layers and Shape order open as separate rollups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rename-shape-layer')), findsNothing);
    expect(find.text('No shapes yet. Choose a tool, then drag.'), findsNothing);
    await _openShapeLayers(tester);
    expect(find.byKey(const ValueKey('add-shape-layer')), findsOneWidget);
    expect(find.text('Shape layer 1'), findsOneWidget);
    await _openShapeOrder(tester);
    expect(
      find.text('No shapes yet. Choose a tool, then drag.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates renames and assigns shapes to active layers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_emptyBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _openShapeLayers(tester);
    expect(find.text('Shape layer 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-shape-layer')));
    await tester.pump();
    expect(find.text('Shape layer 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rename-shape-layer')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shape-layer-name-field')),
      'Directions',
    );
    await tester.tap(find.byKey(const ValueKey('save-shape-layer-name')));
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapeLayers.map((layer) => layer.name), [
      'Shape layer 1',
      'Directions',
    ]);
    final rectangleTool = find.byKey(const ValueKey('shape-tool-rectangle'));
    await _tapShapeTool(tester, rectangleTool);
    final gesture = await tester.startGesture(
      const Offset(220, 220),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(const Offset(520, 380));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    final directions = store.board!.shapeLayers.last;
    expect(directions.name, 'Directions');
    expect(directions.shapeIds, [store.board!.shapes.single.id]);
    expect(store.board!.shapeLayers.first.shapeIds, isEmpty);
  });

  testWidgets('isolates reorders moves and safely deletes shape layers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final time = DateTime.utc(2026, 9, 11);
    BoardShape shape(String id, String heading, double x) => BoardShape(
      id: id,
      type: BoardShapeType.rectangle,
      x: x,
      y: 180,
      width: 220,
      height: 140,
      lineStartsAtTopLeft: true,
      lineReversed: false,
      fillColorValue: 0xFF90CAF9,
      fillOpacity: 0.2,
      outlineColorValue: 0xFF37474F,
      outlineWidth: 2,
      heading: ShapeHeading(text: heading),
      createdAt: time,
      modifiedAt: time,
    );

    final shapes = [
      shape('back-shape', 'Back shape', 120),
      shape('front-shape', 'Front shape', 620),
    ];
    final layers = [
      ShapeLayer(
        id: 'back-layer',
        name: 'Back',
        shapeIds: const ['back-shape'],
        createdAt: time,
        modifiedAt: time,
      ),
      ShapeLayer(
        id: 'front-layer',
        name: 'Front',
        shapeIds: const ['front-shape'],
        createdAt: time,
        modifiedAt: time,
      ),
    ];
    final store = _ShapeBoardStore(
      _emptyBoard(shapes: shapes, shapeLayers: layers),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();

    await _openShapeLayers(tester);
    await tester.tap(find.byKey(const ValueKey('shape-layer-back-layer')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shape-layer-forward')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers.map((layer) => layer.name), [
      'Front',
      'Back',
    ]);

    await _openShapeOrder(tester);
    await tester.scrollUntilVisible(
      find.text('Back shape'),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Back shape'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('move-shape-to-layer')),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('move-shape-to-layer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front').last);
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapeLayers.first.shapeIds, [
      'front-shape',
      'back-shape',
    ]);
    expect(store.board!.shapeLayers.last.shapeIds, isEmpty);

    await _openShapeLayers(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shape-layer-back-layer')),
      -250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('shape-layer-back-layer')));
    await tester.pump();
    await _openShapeLayers(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('delete-shape-layer')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete-shape-layer')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers, hasLength(1));
    expect(store.board!.shapeLayers.single.name, 'Front');

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers, hasLength(2));
  });

  testWidgets(
    'hides active layer from canvas overview and editing with history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final time = DateTime.utc(2026, 9, 12);
      BoardShape shape(String id, double x) => BoardShape(
        id: id,
        type: BoardShapeType.rectangle,
        x: x,
        y: 180,
        width: 220,
        height: 140,
        lineStartsAtTopLeft: true,
        lineReversed: false,
        fillColorValue: 0xFF90CAF9,
        fillOpacity: 0.2,
        outlineColorValue: 0xFF37474F,
        outlineWidth: 2,
        createdAt: time,
        modifiedAt: time,
      );

      final store = _ShapeBoardStore(
        _emptyBoard(
          shapes: [shape('back-shape', 120), shape('front-shape', 620)],
          shapeLayers: [
            ShapeLayer(
              id: 'back-layer',
              name: 'Back',
              shapeIds: const ['back-shape'],
              createdAt: time,
              modifiedAt: time,
            ),
            ShapeLayer(
              id: 'front-layer',
              name: 'Front',
              shapeIds: const ['front-shape'],
              createdAt: time,
              modifiedAt: time,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CanvasExperiment(
            boardStore: store,
            imageAssetStore: _NoImageStore(),
            imagePicker: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
      await tester.pumpAndSettle();

      await _openShapeLayers(tester);
      await tester.tap(
        find.byKey(const ValueKey('shape-layer-visibility-front-layer')),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(store.board!.shapeLayers.last.isVisible, isFalse);
      final hiddenOpacity = tester.widget<PopupMenuButton<double>>(
        find.byKey(const ValueKey('shape-layer-opacity-control-front-layer')),
      );
      expect(hiddenOpacity.enabled, isFalse);
      expect(
        find.byKey(const ValueKey('show-active-shape-layer')),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose a Shape'));
      await tester.pumpAndSettle();
      final rectangleTool = tester.widget<IconButton>(
        find.byKey(const ValueKey('shape-tool-rectangle')),
      );
      expect(rectangleTool.onPressed, isNull);
      final shapePainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('background-shape-layer')),
                  )
                  .painter
              as ShapeLayerPainter;
      expect(shapePainter.shapes.map((shape) => shape.id), ['back-shape']);
      final overviewPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-overview-paint')),
                  )
                  .painter
              as CanvasOverviewPainter;
      expect(overviewPainter.objects.map((object) => object.id), [
        'back-shape',
      ]);

      await tester.ensureVisible(find.text('Choose a Shape'));
      await tester.tap(find.text('Choose a Shape'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-active-shape-layer')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(store.board!.shapeLayers.last.isVisible, isTrue);

      await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(store.board!.shapeLayers.last.isVisible, isFalse);
      await tester.tap(find.byTooltip('Redo (Ctrl+Y or Ctrl+Shift+Z)'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(store.board!.shapeLayers.last.isVisible, isTrue);
    },
  );

  testWidgets('changes layer opacity through history visibility and solo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final time = DateTime.utc(2026, 9, 13);
    BoardShape shape(String id, String heading, double x) => BoardShape(
      id: id,
      type: BoardShapeType.rectangle,
      x: x,
      y: 180,
      width: 220,
      height: 140,
      lineStartsAtTopLeft: true,
      lineReversed: false,
      fillColorValue: 0xFF90CAF9,
      fillOpacity: 0.2,
      outlineColorValue: 0xFF37474F,
      outlineWidth: 2,
      heading: ShapeHeading(text: heading),
      createdAt: time,
      modifiedAt: time,
    );
    final store = _ShapeBoardStore(
      _emptyBoard(
        shapes: [
          shape('back-shape', 'Back shape', 120),
          shape('front-shape', 'Front shape', 620),
        ],
        shapeLayers: [
          ShapeLayer(
            id: 'back-layer',
            name: 'Back',
            shapeIds: const ['back-shape'],
            createdAt: time,
            modifiedAt: time,
          ),
          ShapeLayer(
            id: 'front-layer',
            name: 'Front',
            shapeIds: const ['front-shape'],
            createdAt: time,
            modifiedAt: time,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();

    await _openShapeLayers(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shape-side-panel')),
        matching: find.text('100%'),
      ),
      findsNWidgets(2),
    );
    expect(find.byIcon(Icons.opacity_outlined), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('shape-layer-opacity-control-back-layer')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('shape-layer-opacity-option-back-layer-50')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers.first.opacity, 0.5);
    expect(store.board!.shapeLayers.last.opacity, 1);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('shape-layer-back-layer')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers.first.opacity, 1);
    await tester.tap(
      find.byKey(const ValueKey('shape-layer-opacity-control-front-layer')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('shape-layer-opacity-option-front-layer-25')),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.shapeLayers.last.opacity, 0.25);
    ShapeLayerPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('background-shape-layer')),
                )
                .painter
            as ShapeLayerPainter;
    expect(painter().opacityByShapeId, {'back-shape': 1, 'front-shape': 0.25});

    await tester.tap(find.byKey(const ValueKey('undo-button')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers.last.opacity, 1);
    await tester.tap(find.byKey(const ValueKey('redo-button')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers.last.opacity, 0.25);

    await tester.tap(
      find.byKey(const ValueKey('shape-layer-visibility-front-layer')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(painter().opacityByShapeId, {'back-shape': 1});
    await tester.tap(find.byKey(const ValueKey('show-active-shape-layer')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(store.board!.shapeLayers.last.opacity, 0.25);
    expect(painter().opacityByShapeId['front-shape'], 0.25);

    await tester.tap(
      find.byKey(const ValueKey('solo-shape-layer-front-layer')),
    );
    await tester.pump();
    expect(painter().shapes.map((shape) => shape.id), ['front-shape']);
    expect(painter().opacityByShapeId, {'front-shape': 0.25});

    await _openShapeOrder(tester);
    await tester.scrollUntilVisible(
      find.text('Front shape'),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shape-side-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Front shape'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front shape'));
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-editing-overlay')), findsOneWidget);
  });

  testWidgets(
    'solo filters visible shapes transiently and transfers between layers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final time = DateTime.utc(2026, 9, 13);
      BoardShape shape(String id, double x) => BoardShape(
        id: id,
        type: BoardShapeType.rectangle,
        x: x,
        y: 180,
        width: 220,
        height: 140,
        lineStartsAtTopLeft: true,
        lineReversed: false,
        fillColorValue: 0xFF90CAF9,
        fillOpacity: 0.2,
        outlineColorValue: 0xFF37474F,
        outlineWidth: 2,
        createdAt: time,
        modifiedAt: time,
      );
      final store = _ShapeBoardStore(
        _emptyBoard(
          shapes: [
            shape('back-shape', 120),
            shape('hidden-shape', 380),
            shape('front-shape', 640),
          ],
          shapeLayers: [
            ShapeLayer(
              id: 'back-layer',
              name: 'Back',
              shapeIds: const ['back-shape'],
              createdAt: time,
              modifiedAt: time,
            ),
            ShapeLayer(
              id: 'hidden-layer',
              name: 'Hidden references',
              shapeIds: const ['hidden-shape'],
              createdAt: time,
              modifiedAt: time,
              isVisible: false,
            ),
            ShapeLayer(
              id: 'front-layer',
              name: 'Front',
              shapeIds: const ['front-shape'],
              createdAt: time,
              modifiedAt: time,
            ),
          ],
        ),
      );
      final originalBoard = store.board!.toJson();
      await tester.pumpWidget(
        MaterialApp(
          home: CanvasExperiment(
            boardStore: store,
            imageAssetStore: _NoImageStore(),
            imagePicker: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
      await tester.pumpAndSettle();

      await _openShapeLayers(tester);
      await tester.tap(
        find.byKey(const ValueKey('solo-shape-layer-front-layer')),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Solo layer view'), findsOneWidget);
      final soloPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('background-shape-layer')),
                  )
                  .painter
              as ShapeLayerPainter;
      expect(soloPainter.shapes.map((shape) => shape.id), ['front-shape']);
      final overviewPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-overview-paint')),
                  )
                  .painter
              as CanvasOverviewPainter;
      expect(overviewPainter.objects.map((object) => object.id), [
        'front-shape',
      ]);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('shape-layer-visibility-front-layer')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('shape-layer-hidden-layer')),
            )
            .enabled,
        isFalse,
      );
      expect(store.board!.toJson(), originalBoard);
      expect(store.saveCount, 0);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('undo-button')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('shape-layer-backward')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Solo layer view'), findsOneWidget);
      await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
      await tester.pump(const Duration(milliseconds: 700));
      final afterUndoPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('background-shape-layer')),
                  )
                  .painter
              as ShapeLayerPainter;
      expect(afterUndoPainter.shapes.map((shape) => shape.id), ['front-shape']);

      await tester.tap(find.byKey(const ValueKey('shape-layer-back-layer')));
      await tester.pump();
      final transferredPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('background-shape-layer')),
                  )
                  .painter
              as ShapeLayerPainter;
      expect(transferredPainter.shapes.map((shape) => shape.id), [
        'back-shape',
      ]);

      await tester.tap(find.byKey(const ValueKey('exit-shape-layer-solo')));
      await tester.pump();
      final restoredPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('background-shape-layer')),
                  )
                  .painter
              as ShapeLayerPainter;
      expect(restoredPainter.shapes.map((shape) => shape.id), [
        'back-shape',
        'front-shape',
      ]);

      await tester.tap(
        find.byKey(const ValueKey('solo-shape-layer-back-layer')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('close-shapes-mode')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
      await tester.pump();
      expect(find.text('Solo layer view'), findsNothing);
    },
  );

  testWidgets('Find exits solo before navigating to another visible layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final time = DateTime.utc(2026, 9, 13);
    BoardShape shape(String id, String heading, double x) => BoardShape(
      id: id,
      type: BoardShapeType.rectangle,
      x: x,
      y: 180,
      width: 220,
      height: 140,
      lineStartsAtTopLeft: true,
      lineReversed: false,
      fillColorValue: 0xFF90CAF9,
      fillOpacity: 0.2,
      outlineColorValue: 0xFF37474F,
      outlineWidth: 2,
      heading: ShapeHeading(text: heading),
      createdAt: time,
      modifiedAt: time,
    );
    final store = _ShapeBoardStore(
      _emptyBoard(
        shapes: [
          shape('back-shape', 'Back landmark', 120),
          shape('front-shape', 'Front landmark', 640),
        ],
        shapeLayers: [
          ShapeLayer(
            id: 'back-layer',
            name: 'Back',
            shapeIds: const ['back-shape'],
            createdAt: time,
            modifiedAt: time,
          ),
          ShapeLayer(
            id: 'front-layer',
            name: 'Front',
            shapeIds: const ['front-shape'],
            createdAt: time,
            modifiedAt: time,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _openShapeLayers(tester);
    await tester.tap(
      find.byKey(const ValueKey('solo-shape-layer-front-layer')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('find-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'Back landmark',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('find-shape-result-back-shape')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solo layer view'), findsNothing);
    expect(find.byKey(const ValueKey('shape-editing-overlay')), findsOneWidget);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('background-shape-layer')),
                )
                .painter
            as ShapeLayerPainter;
    expect(painter.shapes.map((shape) => shape.id), [
      'back-shape',
      'front-shape',
    ]);
  });

  testWidgets('find discloses a hidden shape layer without revealing it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final time = DateTime.utc(2026, 9, 12);
    final shape = BoardShape(
      id: 'hidden-shape',
      type: BoardShapeType.ellipse,
      x: 400,
      y: 300,
      width: 220,
      height: 140,
      lineStartsAtTopLeft: true,
      lineReversed: false,
      fillColorValue: 0xFF90CAF9,
      fillOpacity: 0.2,
      outlineColorValue: 0xFF37474F,
      outlineWidth: 2,
      heading: ShapeHeading(text: 'Hidden landmark'),
      createdAt: time,
      modifiedAt: time,
    );
    final store = _ShapeBoardStore(
      _emptyBoard(
        shapes: [shape],
        shapeLayers: [
          ShapeLayer(
            id: 'hidden-layer',
            name: 'References',
            shapeIds: const ['hidden-shape'],
            createdAt: time,
            modifiedAt: time,
            isVisible: false,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('find-board-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('find-board-field')),
      'landmark',
    );
    await tester.pump();

    expect(find.text('Shape heading · Hidden — References'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('find-shape-result-hidden-shape')),
    );
    await tester.pumpAndSettle();

    expect(store.board!.shapeLayers.single.isVisible, isFalse);
    expect(find.byKey(const ValueKey('shape-side-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('show-active-shape-layer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('background-shape-layer')), findsNothing);
  });

  testWidgets('adds and removes one selected Shape from an existing group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_mixedGroupBoard());
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('shape-side-panel')),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await _openShapeOrder(tester);
    await tester.tap(find.byKey(const ValueKey('shape-row-shape-member')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('add-shape-to-group')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-shape-to-group')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('shape-group-choice-mixed-group')),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.groups.single.memberIds, [
      'note-a',
      'note-b',
      'shape-member',
    ]);
    expect(store.board!.shapeLayers.single.shapeIds, ['shape-member']);

    await tester.tap(find.byKey(const ValueKey('remove-shape-from-group')));
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.groups.single.memberIds, ['note-a', 'note-b']);
    expect(store.board!.shapes.single.id, 'shape-member');
    expect(store.board!.shapeLayers.single.shapeIds, ['shape-member']);
  });

  testWidgets('moves a mixed group and blocks movement for a hidden layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_mixedGroupBoard(includeShape: true));
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('groups-panel-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-row-mixed-group')));
    await tester.pump();
    await tester.timedDrag(
      find.byKey(const ValueKey('selected-group-move-handle')),
      const Offset(40, 30),
      const Duration(milliseconds: 200),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.notes.first.x, 140);
    expect(store.board!.shapes.single.x, 460);

    await tester.tap(find.byKey(const ValueKey('shapes-mode-button')));
    await tester.pumpAndSettle();
    await _openShapeLayers(tester);
    await tester.tap(
      find.byKey(
        const ValueKey('shape-layer-visibility-shape-layer-shape-board'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('groups-panel-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-row-mixed-group')));
    await tester.pump();

    expect(
      find.textContaining('Movement blocked: hidden Shape member'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('selected-group-move-handle')),
      findsNothing,
    );
  });

  testWidgets('copies a mixed group with fresh IDs on the source Shape layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _ShapeBoardStore(_mixedGroupBoard(includeShape: true));
    await tester.pumpWidget(
      MaterialApp(
        home: CanvasExperiment(
          boardStore: store,
          imageAssetStore: _NoImageStore(),
          imagePicker: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('groups-panel-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-row-mixed-group')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 700));

    expect(store.board!.groups, hasLength(2));
    expect(store.board!.shapes, hasLength(2));
    expect(store.board!.shapeLayers.single.shapeIds, hasLength(2));
    final pastedShape = store.board!.shapes.singleWhere(
      (shape) => shape.id != 'shape-member',
    );
    final pastedGroup = store.board!.groups.singleWhere(
      (group) => group.id != 'mixed-group',
    );
    expect(pastedGroup.memberIds, contains(pastedShape.id));
    expect(pastedGroup.memberIds, isNot(contains('shape-member')));
  });
}

BoardDocument _emptyBoard({
  List<BoardShape> shapes = const [],
  List<ShapeLayer>? shapeLayers,
  List<Note> notes = const [],
  List<BoardGroup> groups = const [],
}) {
  final time = DateTime.utc(2026, 9, 9);
  return BoardDocument(
    id: 'shape-board',
    name: 'Shapes',
    createdAt: time,
    modifiedAt: time,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: notes,
    shapes: shapes,
    shapeLayers: shapeLayers,
    groups: groups,
  );
}

BoardDocument _mixedGroupBoard({bool includeShape = false}) {
  final time = DateTime.utc(2026, 9, 21, 12);
  final shape = BoardShape(
    id: 'shape-member',
    type: BoardShapeType.database,
    x: 420,
    y: 220,
    width: 220,
    height: 140,
    fillColorValue: 0xFF90CAF9,
    fillOpacity: 0.5,
    outlineColorValue: 0xFF37474F,
    outlineWidth: 2,
    createdAt: time,
    modifiedAt: time,
  );
  Note note(String id, double x) => Note(
    id: id,
    x: x,
    y: 220,
    width: 220,
    height: 140,
    text: id,
    createdAt: time,
    modifiedAt: time,
  );
  return _emptyBoard(
    notes: [note('note-a', 100), note('note-b', 700)],
    shapes: [shape],
    groups: [
      BoardGroup(
        id: 'mixed-group',
        memberIds: ['note-a', 'note-b', if (includeShape) 'shape-member'],
        isVisible: true,
        name: 'Quest system',
        createdAt: time,
        modifiedAt: time,
      ),
    ],
  );
}

class _ShapeBoardStore implements BoardStore {
  _ShapeBoardStore(this.board);
  BoardDocument? board;
  int saveCount = 0;
  @override
  Future<BoardDocument?> load() async => board;
  @override
  Future<void> save(BoardDocument board) async {
    saveCount++;
    this.board = board;
  }
}

class _NoImageStore implements ImageAssetStore {
  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) async => null;
  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) async => null;
  @override
  Future<File> resolve(String assetPath) async => throw UnimplementedError();
}
