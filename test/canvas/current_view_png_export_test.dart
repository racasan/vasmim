import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/current_view_png_export.dart';

void main() {
  group('currentViewPngSuggestedName', () {
    test('derives a safe PNG name from the Board name', () {
      expect(
        currentViewPngSuggestedName('Act 1: Arrival?'),
        'Act 1_ Arrival_ current view.png',
      );
      expect(currentViewPngSuggestedName('  CON.  '), '_CON current view.png');
      expect(currentViewPngSuggestedName('...'), 'Board current view.png');
    });

    test('derives a safe whole-Board PNG name from the Board name', () {
      expect(
        wholeBoardPngSuggestedName('Act 1: Arrival?'),
        'Act 1_ Arrival_ whole Board.png',
      );
      expect(wholeBoardPngSuggestedName('  CON.  '), '_CON whole Board.png');
      expect(wholeBoardPngSuggestedName('...'), 'Board whole Board.png');
    });
  });

  group('publishCurrentViewPng', () {
    test('publishes a new image without leaving sibling files', () async {
      final directory = await Directory.systemTemp.createTemp(
        'vasmim-current-view-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}${Platform.pathSeparator}view.png');
      final bytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

      await publishCurrentViewPng(target.path, bytes);

      expect(await target.readAsBytes(), bytes);
      expect(await directory.list().length, 1);
    });

    test('atomically replaces an existing image', () async {
      final directory = await Directory.systemTemp.createTemp(
        'vasmim-current-view-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}${Platform.pathSeparator}view.png');
      await target.writeAsBytes([1, 2, 3], flush: true);
      final replacement = Uint8List.fromList([9, 8, 7, 6]);

      await publishCurrentViewPng(target.path, replacement);

      expect(await target.readAsBytes(), replacement);
      expect(await directory.list().length, 1);
    });

    test('fails without creating a missing destination directory', () async {
      final directory = await Directory.systemTemp.createTemp(
        'vasmim-current-view-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final missing = Directory(
        '${directory.path}${Platform.pathSeparator}missing',
      );

      await expectLater(
        publishCurrentViewPng(
          '${missing.path}${Platform.pathSeparator}view.png',
          Uint8List.fromList([1]),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await missing.exists(), isFalse);
    });
  });
}
