import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Returns Vasmim's application-support directory after preserving any data
/// created by builds whose Windows product name was `freeform`.
Future<Directory> vasmimApplicationSupportDirectory() async {
  final directory = await getApplicationSupportDirectory();
  return migrateLegacyFreeformApplicationSupport(directory);
}

Future<Directory> migrateLegacyFreeformApplicationSupport(
  Directory vasmimDirectory,
) async {
  final legacyDirectory = Directory(
    '${vasmimDirectory.parent.path}${Platform.pathSeparator}freeform',
  );
  if (!await legacyDirectory.exists()) {
    return vasmimDirectory;
  }

  await vasmimDirectory.create(recursive: true);
  if (!await vasmimDirectory.list(followLinks: false).isEmpty) {
    return vasmimDirectory;
  }

  final stagingDirectory = await vasmimDirectory.parent.createTemp(
    '.vasmim-migration-',
  );
  try {
    await _copyDirectory(legacyDirectory, stagingDirectory);
    await vasmimDirectory.delete();
    await stagingDirectory.rename(vasmimDirectory.path);
    return vasmimDirectory;
  } catch (_) {
    if (await stagingDirectory.exists()) {
      await stagingDirectory.delete(recursive: true);
    }
    rethrow;
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = entity.path.replaceAll('\\', '/').split('/').last;
    final targetPath = '${target.path}${Platform.pathSeparator}$name';
    if (entity is File) {
      await entity.copy(targetPath);
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    }
  }
}
