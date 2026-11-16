import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/vasmim_application_support.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'vasmim_application_support_test_',
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('copies legacy Freeform data without removing the source', () async {
    final legacy = Directory('${root.path}/freeform');
    final target = Directory('${root.path}/Vasmim');
    await File('${legacy.path}/boards/board-1/board.json')
        .create(recursive: true)
        .then((file) => file.writeAsString('{"formatVersion":4}'));
    await target.create();

    final result = await migrateLegacyFreeformApplicationSupport(target);

    expect(result.path, target.path);
    expect(
      await File('${target.path}/boards/board-1/board.json').readAsString(),
      '{"formatVersion":4}',
    );
    expect(
      await File('${legacy.path}/boards/board-1/board.json').exists(),
      isTrue,
    );
  });

  test(
    'does not merge legacy data into a non-empty Vasmim directory',
    () async {
      final legacy = Directory('${root.path}/freeform');
      final target = Directory('${root.path}/Vasmim');
      await File(
        '${legacy.path}/board.json',
      ).create(recursive: true).then((file) => file.writeAsString('legacy'));
      await File(
        '${target.path}/board.json',
      ).create(recursive: true).then((file) => file.writeAsString('current'));

      await migrateLegacyFreeformApplicationSupport(target);

      expect(await File('${target.path}/board.json').readAsString(), 'current');
      expect(await File('${legacy.path}/board.json').readAsString(), 'legacy');
    },
  );
}
