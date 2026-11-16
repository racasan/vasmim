import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/appearance/app_appearance_store.dart';

void main() {
  test('stores one app appearance choice across store instances', () async {
    final directory = await Directory.systemTemp.createTemp('vasmim-theme-');
    addTearDown(() => directory.delete(recursive: true));
    final first = FileAppAppearanceStore(
      directoryProvider: () async => directory,
    );
    final second = FileAppAppearanceStore(
      directoryProvider: () async => directory,
    );

    expect(await first.readDarkMode(), isFalse);
    await first.writeDarkMode(true);
    expect(await second.readDarkMode(), isTrue);
    await second.writeDarkMode(false);
    expect(await first.readDarkMode(), isFalse);
  });

  test('rejects an invalid saved appearance', () async {
    final directory = await Directory.systemTemp.createTemp('vasmim-theme-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}${FileAppAppearanceStore.fileName}',
    );
    await file.writeAsString('{"version":1,"darkMode":"yes"}');
    final store = FileAppAppearanceStore(
      directoryProvider: () async => directory,
    );

    expect(store.readDarkMode(), throwsFormatException);
  });
}
