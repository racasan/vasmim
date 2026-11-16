import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/heading/interactive_canvas_heading.dart';

void main() {
  testWidgets('keeps coloured heading text dark in dark mode', (tester) async {
    final timestamp = DateTime.utc(2026, 9, 23);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Column(
            children: [
              for (final background in [
                CanvasHeadingBackground.transparent,
                CanvasHeadingBackground.yellow,
              ])
                InteractiveCanvasHeading(
                  heading: CanvasHeading(
                    id: background.name,
                    x: 0,
                    y: 0,
                    text: background.name,
                    size: CanvasHeadingSize.small,
                    background: background,
                    createdAt: timestamp,
                    modifiedAt: timestamp,
                  ),
                  isSelected: false,
                  onSelect: () {},
                  onEdit: () {},
                  onSecondaryTapDown: (_) {},
                  onBeginMoving: (_) {},
                  onMove: (_) {},
                  onEndMoving: () {},
                ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('transparent')).style!.color,
      ThemeData.dark().colorScheme.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('yellow')).style!.color,
      const Color(0xFF242424),
    );
  });

  testWidgets('centres heading text within its complete bounds', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 9, 8);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveCanvasHeading(
            heading: CanvasHeading(
              id: 'heading',
              x: 0,
              y: 0,
              text: 'Centred heading',
              size: CanvasHeadingSize.extraLarge,
              background: CanvasHeadingBackground.green,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
            isSelected: false,
            onSelect: () {},
            onEdit: () {},
            onSecondaryTapDown: (_) {},
            onBeginMoving: (_) {},
            onMove: (_) {},
            onEndMoving: () {},
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(InteractiveCanvasHeading),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final text = tester.widget<Text>(find.text('Centred heading'));

    expect(container.alignment, Alignment.center);
    expect(text.textAlign, TextAlign.center);
  });
}
