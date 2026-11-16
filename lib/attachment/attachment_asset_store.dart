import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'board_attachment.dart';

class AttachmentImportCandidate {
  const AttachmentImportCandidate({
    required this.sourcePath,
    required this.originalFileName,
    required this.kind,
    required this.byteSize,
  });

  final String sourcePath;
  final String originalFileName;
  final AttachmentKind kind;
  final int byteSize;
}

class ManagedAttachmentAsset {
  const ManagedAttachmentAsset({
    required this.assetPath,
    required this.originalFileName,
    required this.kind,
    required this.byteSize,
  });

  final String assetPath;
  final String originalFileName;
  final AttachmentKind kind;
  final int byteSize;
}

abstract interface class AttachmentAssetStore {
  Future<AttachmentImportCandidate?> inspectPath(String? sourcePath);
  Future<ManagedAttachmentAsset> importCandidate(
    AttachmentImportCandidate candidate,
  );
  Future<File> resolve(String assetPath);
}

class FileAttachmentAssetStore implements AttachmentAssetStore {
  FileAttachmentAssetStore({
    Future<Directory> Function()? directoryProvider,
    String Function()? idGenerator,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _idGenerator = idGenerator ?? const Uuid().v4;

  FileAttachmentAssetStore.scoped({
    required Future<Directory> Function() boardDirectoryProvider,
    String Function()? idGenerator,
  }) : _directoryProvider = boardDirectoryProvider,
       _idGenerator = idGenerator ?? const Uuid().v4;

  final Future<Directory> Function() _directoryProvider;
  final String Function() _idGenerator;

  static Future<void> validateCandidate(AttachmentImportCandidate candidate) =>
      _validateSignature(File(candidate.sourcePath), candidate.kind);

  @override
  Future<AttachmentImportCandidate?> inspectPath(String? sourcePath) async {
    if (sourcePath == null) return null;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'File does not exist.',
      );
    }
    final originalFileName = _fileName(source.path);
    final kind = AttachmentKind.fromFileName(originalFileName);
    final byteSize = await source.length();
    if (byteSize <= 0) {
      throw const FormatException('An attachment cannot be empty.');
    }
    return AttachmentImportCandidate(
      sourcePath: source.path,
      originalFileName: originalFileName,
      kind: kind,
      byteSize: byteSize,
    );
  }

  @override
  Future<ManagedAttachmentAsset> importCandidate(
    AttachmentImportCandidate candidate,
  ) async {
    final source = File(candidate.sourcePath);
    if (!await source.exists() || await source.length() != candidate.byteSize) {
      throw const FormatException(
        'The selected attachment changed before import.',
      );
    }
    await _validateSignature(source, candidate.kind);
    final extension =
        '.${candidate.originalFileName.split('.').last.toLowerCase()}';
    final root = await _directoryProvider();
    final assetDirectory = Directory(
      '${root.path}${Platform.pathSeparator}assets',
    );
    await assetDirectory.create(recursive: true);
    final id = _safeGeneratedId(_idGenerator());
    var suffix = 0;
    late File target;
    do {
      final suffixText = suffix == 0 ? '' : '-$suffix';
      target = File(
        '${assetDirectory.path}${Platform.pathSeparator}$id$suffixText$extension',
      );
      suffix++;
    } while (await target.exists());
    final partial = File('${target.path}.partial');
    try {
      await source.openRead().pipe(partial.openWrite());
      if (await partial.length() != candidate.byteSize) {
        throw const FormatException('The attachment copy was incomplete.');
      }
      await partial.rename(target.path);
      await _makeReadOnly(target);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    return ManagedAttachmentAsset(
      assetPath: 'assets/${_fileName(target.path)}',
      originalFileName: candidate.originalFileName,
      kind: candidate.kind,
      byteSize: candidate.byteSize,
    );
  }

  @override
  Future<File> resolve(String assetPath) async {
    final normalized = assetPath.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (segments.length != 2 ||
        segments.first != 'assets' ||
        !RegExp(
          r'^[A-Za-z0-9_-]+\.(pdf|doc|docx|xls|xlsx|mp4|m4v|mov|mkv|avi|webm|mp3|wav|m4a|flac|ogg)$',
          caseSensitive: false,
        ).hasMatch(segments.last)) {
      throw ArgumentError.value(
        assetPath,
        'assetPath',
        'Unsafe attachment path.',
      );
    }
    final root = await _directoryProvider();
    final file = File(
      '${root.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}${segments.last}',
    );
    if (await file.exists()) await _makeReadOnly(file);
    return file;
  }

  static Future<void> _validateSignature(File file, AttachmentKind kind) async {
    final access = await file.open();
    try {
      final bytes = await access.read(16);
      final pdf =
          bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
      final compoundOffice =
          bytes.length >= 8 &&
          bytes[0] == 0xd0 &&
          bytes[1] == 0xcf &&
          bytes[2] == 0x11 &&
          bytes[3] == 0xe0 &&
          bytes[4] == 0xa1 &&
          bytes[5] == 0xb1 &&
          bytes[6] == 0x1a &&
          bytes[7] == 0xe1;
      final zip =
          bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4b &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04;
      final riffAvi =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.skip(8).take(4)) == 'AVI ';
      final ebml =
          bytes.length >= 4 &&
          bytes[0] == 0x1a &&
          bytes[1] == 0x45 &&
          bytes[2] == 0xdf &&
          bytes[3] == 0xa3;
      final isoMedia =
          bytes.length >= 8 &&
          String.fromCharCodes(bytes.skip(4).take(4)) == 'ftyp';
      final mp3 =
          bytes.length >= 3 && String.fromCharCodes(bytes.take(3)) == 'ID3' ||
          bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
      final wave =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.skip(8).take(4)) == 'WAVE';
      final flac =
          bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == 'fLaC';
      final ogg =
          bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == 'OggS';
      final audioValid = switch (file.path.split('.').last.toLowerCase()) {
        'mp3' => mp3,
        'wav' => wave,
        'm4a' => isoMedia,
        'flac' => flac,
        'ogg' => ogg,
        _ => false,
      };
      final validOffice = switch (kind) {
        AttachmentKind.word =>
          file.path.toLowerCase().endsWith('.doc')
              ? compoundOffice
              : zip && await _zipHasEntry(file, 'word/document.xml'),
        AttachmentKind.spreadsheet =>
          file.path.toLowerCase().endsWith('.xls')
              ? compoundOffice
              : zip && await _zipHasEntry(file, 'xl/workbook.xml'),
        _ => true,
      };
      if ((kind == AttachmentKind.pdf && !pdf) ||
          ((kind == AttachmentKind.word ||
                  kind == AttachmentKind.spreadsheet) &&
              !validOffice) ||
          (kind == AttachmentKind.video && !riffAvi && !ebml && !isoMedia) ||
          (kind == AttachmentKind.audio && !audioValid)) {
        throw const FormatException(
          'Attachment contents do not match the selected file type.',
        );
      }
    } finally {
      await access.close();
    }
  }

  static Future<bool> _zipHasEntry(File file, String expected) async {
    InputFileStream? input;
    try {
      input = InputFileStream(file.path);
      final decoder = ZipDecoder();
      decoder.decodeStream(input);
      return decoder.directory.fileHeaders.any(
        (header) => header.filename == expected,
      );
    } catch (_) {
      return false;
    } finally {
      await input?.close();
    }
  }

  static Future<void> _makeReadOnly(File file) async {
    if (!Platform.isWindows) return;
    final result = await Process.run('attrib', ['+R', file.path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Could not protect managed attachment.',
        file.path,
      );
    }
  }

  static String _fileName(String path) =>
      path.replaceAll('\\', '/').split('/').last;
  static String _safeGeneratedId(String value) {
    final safe = value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    if (safe.isEmpty) throw StateError('Attachment asset ID cannot be empty.');
    return safe;
  }
}
