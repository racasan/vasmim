import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory runtime;
  late Directory notices;
  late File dll;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_notice_inventory_');
    runtime = await Directory('${root.path}/runtime').create();
    dll = await File('${runtime.path}/pdfium.dll').writeAsBytes([1, 2, 3]);
    notices = await Directory(
      '${runtime.path}/data/native_licenses/pdfium',
    ).create(recursive: true);
    await File('${notices.path}/provenance.json').writeAsString(
      jsonEncode({'dllSha256': '${sha256.convert(await dll.readAsBytes())}'}),
    );
    await File(
      '${notices.path}/LICENSE',
    ).writeAsString('fixture publisher notice');
    final incorporated = File('${notices.path}/licenses/component.txt');
    await incorporated.parent.create();
    await incorporated.writeAsString('fixture incorporated component notice');
  });
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> inspect() => Process.run('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    '${Directory.current.path}/tool/inspect_release_payload.ps1',
    '-ReleaseDirectory',
    runtime.path,
    '-OutputDirectory',
    '${root.path}/inventory',
  ]);

  test(
    'collects incorporated PDFium notices from the actual runtime',
    () async {
      final result = await inspect();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
        await File(
          '${root.path}/inventory/licenses/pdfium/licenses/component.txt',
        ).readAsString(),
        'fixture incorporated component notice',
      );
      expect(
        await File(
          '${root.path}/inventory/licenses/pdfium-LICENSE.txt',
        ).exists(),
        isFalse,
        reason:
            'Do not mix a runtime with an older PDFium source-cache licence.',
      );
    },
  );

  test('collects the clipboard notice aggregate byte for byte', () async {
    final result = await inspect();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final source = await File(
      '${Directory.current.path}/release/CLIPBOARD_THIRD_PARTY_NOTICES.txt',
    ).readAsBytes();
    final collected = await File(
      '${root.path}/inventory/licenses/clipboard-NOTICES.txt',
    ).readAsBytes();
    expect(collected, orderedEquals(source));
    expect(
      await File('${root.path}/inventory/licenses/ANGLE-LICENSE.txt').exists(),
      isFalse,
      reason: 'The public build ships no separate graphics libraries.',
    );
  });

  test(
    'rejects notice provenance belonging to a different PDFium DLL',
    () async {
      await dll.writeAsBytes([9, 8, 7]);
      final result = await inspect();
      expect(result.exitCode, isNot(0));
      expect(
        '${result.stderr}',
        contains('bundled notice provenance do not match'),
      );
      expect(
        await File('${root.path}/inventory/runtime_inventory.json').exists(),
        isFalse,
      );
    },
  );
}
