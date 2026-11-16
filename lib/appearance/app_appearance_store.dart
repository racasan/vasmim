import 'dart:convert';
import 'dart:io';

import '../board/vasmim_application_support.dart';

abstract class AppAppearanceStore {
  Future<bool> readDarkMode();

  Future<void> writeDarkMode(bool isDark);
}

class MemoryAppAppearanceStore implements AppAppearanceStore {
  MemoryAppAppearanceStore({this.isDark = false});

  bool isDark;

  @override
  Future<bool> readDarkMode() async => isDark;

  @override
  Future<void> writeDarkMode(bool isDark) async => this.isDark = isDark;
}

class FileAppAppearanceStore implements AppAppearanceStore {
  FileAppAppearanceStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? vasmimApplicationSupportDirectory;

  static const fileName = 'app_appearance.json';
  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<bool> readDarkMode() async {
    final file = await _file();
    if (!await file.exists()) return false;
    final value = jsonDecode(await file.readAsString());
    if (value is! Map || value['version'] != 1 || value['darkMode'] is! bool) {
      throw const FormatException('App appearance preference is invalid.');
    }
    return value['darkMode'] as bool;
  }

  @override
  Future<void> writeDarkMode(bool isDark) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'darkMode': isDark}),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
