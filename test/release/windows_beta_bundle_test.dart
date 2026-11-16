import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory runtime;
  late Directory licenses;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_beta_test_');
    runtime = Directory('${root.path}/runtime');
    for (final name in const [
      'vasmim.exe',
      'flutter_windows.dll',
      'file_selector_windows_plugin.dll',
      'irondash_engine_context_plugin.dll',
      'pdfium.dll',
      'pdfx_plugin.dll',
      'super_native_extensions.dll',
      'super_native_extensions_plugin.dll',
      'url_launcher_windows_plugin.dll',
      'data/app.so',
      'data/icudtl.dat',
      'data/flutter_assets/AssetManifest.bin',
      'data/flutter_assets/NOTICES.Z',
    ]) {
      final file = File('${runtime.path}/$name');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
    }
    await File(
      '${runtime.path}/native_assets.json',
    ).writeAsString('{"format-version":[1,0,0],"native-assets":{}}');
    licenses = Directory('${root.path}/licenses');
    final notice = File('${licenses.path}/pdfium/licenses/component.txt');
    await notice.parent.create(recursive: true);
    await notice.writeAsString('controlled component notice');
    await File(
      '${licenses.path}/flutter-LICENSE.txt',
    ).writeAsString('controlled engine notice');
  });
  tearDown(() async => root.delete(recursive: true));

  Future<ProcessResult> package({String? licensePath}) =>
      Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        '${Directory.current.path}/tool/package_windows_beta.ps1',
        '-ReleaseDirectory',
        runtime.path,
        '-OutputDirectory',
        '${root.path}/output',
        '-LicenseDirectory',
        licensePath ?? licenses.path,
      ]);

  Future<Set<String>> packagedPaths() async {
    final zip = await Directory(
      '${root.path}/output',
    ).list().where((e) => e.path.endsWith('.zip')).cast<File>().single;
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    return archive.files.map((e) => e.name.replaceAll('\\', '/')).toSet();
  }

  test(
    'public package carries documents, the licence and every notice',
    () async {
      final result = await package();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final paths = await packagedPaths();
      bool has(String suffix) => paths.any((name) => name.endsWith(suffix));
      expect(has('/LICENSE.txt'), isTrue);
      expect(has('/PRIVACY.md'), isTrue);
      expect(has('/THIRD_PARTY_NOTICES.md'), isTrue);
      expect(has('/RELEASE_NOTES.md'), isTrue);
      expect(has('/third_party_licenses/flutter-LICENSE.txt'), isTrue);
      expect(
        has('/third_party_licenses/pdfium/licenses/component.txt'),
        isTrue,
      );
      expect(has('/TERMS_DRAFT.md'), isFalse);
      expect(has('/PRIVATE_CANDIDATE.txt'), isFalse);
    },
  );

  test('unlisted DLLs cannot enter the package', () async {
    for (final name in const [
      'webview_flutter_windows_plugin.dll',
      'libmpv-2.dll',
    ]) {
      final extra = File('${runtime.path}/$name');
      await extra.writeAsBytes([1]);
      final result = await package();
      expect(result.exitCode, isNot(0), reason: name);
      expect('${result.stderr}', contains('Unexpected runtime file'));
      expect(await Directory('${root.path}/output').exists(), isFalse);
      await extra.delete();
    }
  });

  test('a missing runtime file prevents packaging', () async {
    await File('${runtime.path}/pdfium.dll').delete();
    final result = await package();
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('Required current runtime payload'));
  });

  test('a runtime containing a local user path is rejected', () async {
    await File(
      '${runtime.path}/data/app.so',
    ).writeAsString(r'compiled from C:\Users\someone\project');
    final result = await package();
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('local user path remains'));
    expect(await Directory('${root.path}/output').exists(), isFalse);
  });

  test('packaging without collected notices is rejected', () async {
    final empty = await Directory('${root.path}/empty').create();
    final result = await package(licensePath: empty.path);
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('licence directory is empty'));
    expect(await Directory('${root.path}/output').exists(), isFalse);
  });

  test('unreviewed licence directories remain rejected', () async {
    await Directory('${licenses.path}/private').create(recursive: true);
    final result = await package();
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('Unexpected licence subdirectory'));
    expect(await Directory('${root.path}/output').exists(), isFalse);
  });
}
