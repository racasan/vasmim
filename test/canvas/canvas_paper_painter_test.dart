import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_paper_tone.dart';
import 'package:vasmim/canvas/canvas_paper_painter.dart';

void main() {
  test('uses the existing pale paper fill and 80-unit board spacing', () {
    expect(LayeredCanvasPaperPainter.paperColor, const Color(0xFFF7F8FC));
    expect(LayeredCanvasPaperPainter.minorSpacing, 80);
  });

  test('builds minor dots with a stronger anchor at every fifth interval', () {
    const painter = LayeredCanvasPaperPainter();

    final dots = painter.dotsFor(const Size(400, 400));

    expect(dots, hasLength(36));
    expect(
      dots.where((dot) => dot.isAnchor).map((dot) => dot.position),
      containsAll(<Offset>[
        Offset.zero,
        const Offset(400, 0),
        const Offset(0, 400),
        const Offset(400, 400),
      ]),
    );
    expect(
      dots
          .where((dot) => !dot.isAnchor)
          .every(
            (dot) =>
                dot.radius == LayeredCanvasPaperPainter.minorDotRadius &&
                dot.color == LayeredCanvasPaperPainter.minorDotColor,
          ),
      isTrue,
    );
    expect(
      dots
          .where((dot) => dot.isAnchor)
          .every(
            (dot) =>
                dot.radius == LayeredCanvasPaperPainter.anchorDotRadius &&
                dot.color == LayeredCanvasPaperPainter.anchorDotColor,
          ),
      isTrue,
    );
  });

  test('keeps the background painter stable across equivalent builds', () {
    const painter = LayeredCanvasPaperPainter();

    expect(painter.shouldRepaint(const LayeredCanvasPaperPainter()), isFalse);
  });

  test('anchors the faint grid to board coordinates at every zoom', () {
    const zoomedOut = LayeredCanvasPaperPainter(viewportScale: 0.2);
    const zoomedIn = LayeredCanvasPaperPainter(viewportScale: 4);
    final size = const Size(800, 400);
    final lines = zoomedOut.linesFor(size);

    expect(zoomedIn.linesFor(size).length, lines.length);
    expect(
      lines.where((line) => line.start.dy == 0).map((line) => line.start.dx),
      containsAll([0, 80, 400, 800]),
    );
    expect(
      lines.where((line) => line.isAnchor).map((line) => line.start),
      containsAll([Offset.zero, const Offset(400, 0), const Offset(0, 400)]),
    );
    expect(zoomedOut.shouldRepaint(zoomedIn), isTrue);
    expect(
      const LayeredCanvasPaperPainter(
        isDark: true,
      ).shouldRepaint(const LayeredCanvasPaperPainter()),
      isTrue,
    );
  });

  test(
    'paper tones keep paired light and dark shades without moving the grid',
    () {
      const defaultPainter = LayeredCanvasPaperPainter();
      const warmPainter = LayeredCanvasPaperPainter(tone: BoardPaperTone.warm);
      const darkWarmPainter = LayeredCanvasPaperPainter(
        tone: BoardPaperTone.warm,
        isDark: true,
      );
      expect(
        LayeredCanvasPaperPainter.paperColorFor(
          BoardPaperTone.defaultTone,
          isDark: false,
        ),
        LayeredCanvasPaperPainter.paperColor,
      );
      expect(
        LayeredCanvasPaperPainter.paperColorFor(
          BoardPaperTone.warm,
          isDark: false,
        ),
        isNot(LayeredCanvasPaperPainter.paperColor),
      );
      expect(
        LayeredCanvasPaperPainter.paperColorFor(
          BoardPaperTone.warm,
          isDark: true,
        ),
        isNot(LayeredCanvasPaperPainter.darkPaperColor),
      );
      expect(
        warmPainter.linesFor(const Size(400, 400)).length,
        defaultPainter.linesFor(const Size(400, 400)).length,
      );
      expect(
        warmPainter.dotsFor(const Size(400, 400)).first.position,
        defaultPainter.dotsFor(const Size(400, 400)).first.position,
      );
      expect(defaultPainter.shouldRepaint(warmPainter), isTrue);
      expect(warmPainter.shouldRepaint(darkWarmPainter), isTrue);
    },
  );
}
