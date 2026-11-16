import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory releaseDirectory;
  late Directory outputDirectory;
  late Directory nativeAssetsSearchDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_alpha_bundle_test_');
    releaseDirectory = Directory(
      '${root.path}${Platform.pathSeparator}release fixture',
    );
    outputDirectory = Directory(
      '${root.path}${Platform.pathSeparator}artifact output',
    );
    nativeAssetsSearchDirectory = Directory(
      '${root.path}${Platform.pathSeparator}flutter build metadata',
    );
    await _writeRuntimeFixture(releaseDirectory);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'packages one complete versioned runtime and matching checksum',
    () async {
      final result = await _runPackager(releaseDirectory, outputDirectory);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final files = await outputDirectory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      expect(files.map((file) => _basename(file.path)).toSet(), {
        'Vasmim-Windows-0.1.0-beta.2+3-x64.zip',
        'Vasmim-Windows-0.1.0-beta.2+3-x64.zip.sha256',
      });

      final zipFile = File(
        '${outputDirectory.path}${Platform.pathSeparator}'
        'Vasmim-Windows-0.1.0-beta.2+3-x64.zip',
      );
      final archive = ZipDecoder().decodeBytes(
        await zipFile.readAsBytes(),
        verify: true,
      );
      final paths = archive.files
          .map((entry) => entry.name.replaceAll('\\', '/'))
          .toSet();
      const bundleRoot = 'Vasmim-Windows-0.1.0-beta.2+3-x64';
      expect(paths, contains('$bundleRoot/vasmim.exe'));
      expect(paths, contains('$bundleRoot/flutter_windows.dll'));
      expect(paths, contains('$bundleRoot/file_selector_windows_plugin.dll'));
      expect(paths, contains('$bundleRoot/native_assets.json'));
      expect(paths, contains('$bundleRoot/data/app.so'));
      expect(paths, contains('$bundleRoot/data/icudtl.dat'));
      expect(paths, contains('$bundleRoot/RELEASE_NOTES.md'));

      final checksum = await File('${zipFile.path}.sha256').readAsString();
      final match = RegExp(
        r'^([A-F0-9]{64})  Vasmim-Windows-0\.1\.0-beta\.2\+3-x64\.zip\r?\n?$',
      ).firstMatch(checksum);
      expect(match, isNotNull);
      final hashResult = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-Command',
          r'(Get-FileHash -Algorithm SHA256 -LiteralPath '
              r'$env:VASMIM_TEST_ZIP).Hash',
        ],
        environment: {...Platform.environment, 'VASMIM_TEST_ZIP': zipFile.path},
      );
      expect(
        hashResult.exitCode,
        0,
        reason: '${hashResult.stdout}\n${hashResult.stderr}',
      );
      expect((hashResult.stdout as String).trim(), match!.group(1));
    },
  );

  test(
    'refuses an incomplete Flutter runtime with an actionable path',
    () async {
      await File(
        '${releaseDirectory.path}${Platform.pathSeparator}flutter_windows.dll',
      ).delete();

      final result = await _runPackager(releaseDirectory, outputDirectory);

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('flutter_windows.dll'),
      );
      expect(await outputDirectory.exists(), isFalse);
    },
  );

  test(
    'refuses a non-empty artifact directory instead of deleting it',
    () async {
      await outputDirectory.create(recursive: true);
      final sentinel = File(
        '${outputDirectory.path}${Platform.pathSeparator}keep-me.txt',
      );
      await sentinel.writeAsString('user-owned');

      final result = await _runPackager(releaseDirectory, outputDirectory);

      expect(result.exitCode, isNot(0));
      expect('${result.stdout}\n${result.stderr}', contains('must be empty'));
      expect(await sentinel.readAsString(), 'user-owned');
    },
  );

  test(
    'stages valid generated native-assets metadata when release root omits it',
    () async {
      await File(
        '${releaseDirectory.path}${Platform.pathSeparator}native_assets.json',
      ).delete();
      final generatedMetadata = File(
        '${nativeAssetsSearchDirectory.path}${Platform.pathSeparator}'
        'current-build${Platform.pathSeparator}native_assets.json',
      );
      await generatedMetadata.parent.create(recursive: true);
      await generatedMetadata.writeAsString(_validNativeAssetsJson);

      final result = await _runPackager(
        releaseDirectory,
        outputDirectory,
        nativeAssetsSearchDirectory: nativeAssetsSearchDirectory,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final zipFile = File(
        '${outputDirectory.path}${Platform.pathSeparator}'
        'Vasmim-Windows-0.1.0-beta.2+3-x64.zip',
      );
      final archive = ZipDecoder().decodeBytes(
        await zipFile.readAsBytes(),
        verify: true,
      );
      final metadataEntry = archive.files.singleWhere(
        (entry) =>
            entry.name.replaceAll('\\', '/').endsWith('/native_assets.json'),
      );
      expect(
        String.fromCharCodes(metadataEntry.content as List<int>),
        _validNativeAssetsJson,
      );
    },
  );

  test('refuses content-ambiguous generated native-assets metadata', () async {
    await File(
      '${releaseDirectory.path}${Platform.pathSeparator}native_assets.json',
    ).delete();
    await _writeGeneratedMetadata(
      nativeAssetsSearchDirectory,
      'build-a',
      _validNativeAssetsJson,
    );
    await _writeGeneratedMetadata(
      nativeAssetsSearchDirectory,
      'build-b',
      '{"format-version":[1,0,0],"native-assets":{"different":{}}}',
    );

    final result = await _runPackager(
      releaseDirectory,
      outputDirectory,
      nativeAssetsSearchDirectory: nativeAssetsSearchDirectory,
    );

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('content-ambiguous'));
    expect(await outputDirectory.exists(), isFalse);
  });

  test('refuses malformed generated native-assets metadata', () async {
    await File(
      '${releaseDirectory.path}${Platform.pathSeparator}native_assets.json',
    ).delete();
    await _writeGeneratedMetadata(
      nativeAssetsSearchDirectory,
      'current-build',
      'not json',
    );

    final result = await _runPackager(
      releaseDirectory,
      outputDirectory,
      nativeAssetsSearchDirectory: nativeAssetsSearchDirectory,
    );

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('malformed'));
    expect(await outputDirectory.exists(), isFalse);
  });

  test('refuses malformed release-root native-assets metadata', () async {
    await File(
      '${releaseDirectory.path}${Platform.pathSeparator}native_assets.json',
    ).writeAsString('null');

    final result = await _runPackager(releaseDirectory, outputDirectory);

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('malformed'));
    expect(await outputDirectory.exists(), isFalse);
  });

  test('refuses missing generated native-assets metadata', () async {
    await File(
      '${releaseDirectory.path}${Platform.pathSeparator}native_assets.json',
    ).delete();

    final result = await _runPackager(
      releaseDirectory,
      outputDirectory,
      nativeAssetsSearchDirectory: nativeAssetsSearchDirectory,
    );

    expect(result.exitCode, isNot(0));
    expect(
      '${result.stdout}\n${result.stderr}',
      contains('native-assets metadata is missing'),
    );
    expect(await outputDirectory.exists(), isFalse);
  });

  test('Windows resources use neutral Vasmim metadata', () async {
    final resources = await File(
      '${Directory.current.path}${Platform.pathSeparator}windows'
      '${Platform.pathSeparator}runner${Platform.pathSeparator}Runner.rc',
    ).readAsString();

    expect(resources, isNot(contains('com.example')));
    expect(resources, contains('VALUE "CompanyName", "Vasmim Project"'));
    expect(resources, contains('Copyright (C) 2026 racasan.'));
  });
}

Future<ProcessResult> _runPackager(
  Directory releaseDirectory,
  Directory outputDirectory, {
  Directory? nativeAssetsSearchDirectory,
}) {
  final scriptPath =
      '${Directory.current.path}${Platform.pathSeparator}tool'
      '${Platform.pathSeparator}package_windows_alpha.ps1';
  final arguments = [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    scriptPath,
    '-SkipBuild',
    '-ReleaseDirectory',
    releaseDirectory.path,
    '-OutputDirectory',
    outputDirectory.path,
    if (nativeAssetsSearchDirectory != null) ...[
      '-NativeAssetsSearchDirectory',
      nativeAssetsSearchDirectory.path,
    ],
  ];
  return Process.run('powershell.exe', arguments);
}

Future<void> _writeRuntimeFixture(Directory directory) async {
  for (final relativePath in const [
    'vasmim.exe',
    'flutter_windows.dll',
    'file_selector_windows_plugin.dll',
    'native_assets.json',
    'data/app.so',
    'data/icudtl.dat',
    'data/flutter_assets/AssetManifest.bin',
  ]) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    await file.parent.create(recursive: true);
    if (relativePath == 'native_assets.json') {
      await file.writeAsString(_validNativeAssetsJson);
    } else {
      await file.writeAsBytes([1, 2, 3]);
    }
  }
}

Future<void> _writeGeneratedMetadata(
  Directory searchDirectory,
  String buildName,
  String contents,
) async {
  final file = File(
    '${searchDirectory.path}${Platform.pathSeparator}$buildName'
    '${Platform.pathSeparator}native_assets.json',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

const _validNativeAssetsJson = '{"format-version":[1,0,0],"native-assets":{}}';

String _basename(String path) => path.split(Platform.pathSeparator).last;
