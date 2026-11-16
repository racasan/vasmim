import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cmake = findCmake();
  late Directory root;
  late File archive;
  late File dll;
  late File notice;
  late File script;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_pdfium_pin_');
    archive = await File('${root.path}/package.tgz').writeAsBytes([1, 2, 3]);
    dll = File('${root.path}/source/bin/pdfium.dll');
    notice = File('${root.path}/source/licenses/pdfium.txt');
    for (final file in [dll, notice]) {
      await file.parent.create(recursive: true);
      await file.writeAsString('controlled fixture ${file.path}');
    }
    final manifest = File('${root.path}/package.sha256');
    await manifest.writeAsString(
      '${sha256.convert(await dll.readAsBytes())}  bin/pdfium.dll\n'
      '${sha256.convert(await notice.readAsBytes())}  licenses/pdfium.txt\n',
    );
    final repository = Directory.current.path.replaceAll('\\', '/');
    final fixture = root.path.replaceAll('\\', '/');
    script = await File('${root.path}/verify.cmake').writeAsString(
      'cmake_minimum_required(VERSION 3.15)\n'
      'include("$repository/windows/pdfium/verify.cmake")\n'
      'set(VASMIM_PDFIUM_PIN_DIRECTORY "$fixture")\n'
      'set(VASMIM_PDFIUM_ARCHIVE_SHA256 "${sha256.convert(await archive.readAsBytes())}")\n'
      'vasmim_verify_pdfium("$fixture/source" "$fixture/package.tgz")\n',
    );
  });
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> verify() => Process.run(cmake, ['-P', script.path]);

  test('verified package is accepted', () async {
    final result = await verify();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('changed archive is rejected before package use', () async {
    await archive.writeAsBytes([4, 5, 6]);
    final result = await verify();
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('archive SHA-256 does not match'));
  });

  test('stale or changed native DLL is rejected', () async {
    await dll.writeAsString('stale binary');
    final result = await verify();
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('SHA-256 mismatch: bin/pdfium.dll'));
  });

  test('missing third-party notice prevents verification', () async {
    await notice.delete();
    final result = await verify();
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('package file is missing'));
  });
}

String findCmake() {
  final override = Platform.environment['VASMIM_CMAKE'];
  if (override != null) return override;
  // Flutter locates Visual Studio's CMake even when cmake is absent from PATH.
  // Keep the normal `flutter test` command usable in that same environment.
  final installerRoot = Platform.environment['ProgramFiles(x86)'];
  if (installerRoot != null) {
    final locator = File(
      '$installerRoot/Microsoft Visual Studio/Installer/vswhere.exe',
    );
    if (locator.existsSync()) {
      final result = Process.runSync(locator.path, [
        '-latest',
        '-products',
        '*',
        '-requires',
        'Microsoft.VisualStudio.Component.VC.CMake.Project',
        '-find',
        r'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
      ]);
      final found = '${result.stdout}'.trim().split(RegExp(r'[\r\n]+')).first;
      if (result.exitCode == 0 && File(found).existsSync()) return found;
    }
  }
  return 'cmake';
}
