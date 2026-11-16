import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ManagedImageAsset {
  const ManagedImageAsset({
    required this.assetPath,
    required this.originalFileName,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final String assetPath;
  final String originalFileName;
  final int pixelWidth;
  final int pixelHeight;
}

abstract interface class ImageAssetStore {
  Future<ManagedImageAsset?> importPath(String? sourcePath);

  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  });

  Future<File> resolve(String assetPath);
}

class FileImageAssetStore implements ImageAssetStore {
  FileImageAssetStore({
    Future<Directory> Function()? directoryProvider,
    String Function()? idGenerator,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _idGenerator = idGenerator ?? const Uuid().v4;

  FileImageAssetStore.scoped({
    required Future<Directory> Function() boardDirectoryProvider,
    String Function()? idGenerator,
  }) : _directoryProvider = boardDirectoryProvider,
       _idGenerator = idGenerator ?? const Uuid().v4;

  static const _assetDirectoryName = 'assets';
  static const maximumImageBytes = 64 * 1024 * 1024;
  static const maximumImagePixels = 40 * 1000 * 1000;

  final Future<Directory> Function() _directoryProvider;
  final String Function() _idGenerator;

  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) async {
    if (sourcePath == null) {
      return null;
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'File does not exist.',
      );
    }

    final originalFileName = _fileName(source.path);
    if (await source.length() > maximumImageBytes) {
      throw const FormatException('Images must be 64 MiB or smaller.');
    }
    final bytes = await source.readAsBytes();
    return _importBytes(bytes, originalFileName: originalFileName);
  }

  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) async {
    if (bytes == null) {
      return null;
    }
    return _importBytes(bytes, originalFileName: _fileName(originalFileName));
  }

  Future<ManagedImageAsset> _importBytes(
    Uint8List bytes, {
    required String originalFileName,
  }) async {
    if (bytes.length > maximumImageBytes) {
      throw const FormatException('Images must be 64 MiB or smaller.');
    }
    final extension = _supportedExtension(originalFileName);
    _validateSignature(bytes, extension);
    final dimensions = await _decodeDimensions(
      bytes,
      validateFirstFrame: extension == '.gif',
    );

    final root = await _directoryProvider();
    final assetDirectory = Directory(
      '${root.path}${Platform.pathSeparator}$_assetDirectoryName',
    );
    await assetDirectory.create(recursive: true);

    final generatedId = _safeGeneratedId(_idGenerator());
    var suffix = 0;
    late File target;
    do {
      final suffixText = suffix == 0 ? '' : '-$suffix';
      target = File(
        '${assetDirectory.path}${Platform.pathSeparator}'
        '$generatedId$suffixText$extension',
      );
      suffix += 1;
    } while (await target.exists());

    final partial = File('${target.path}.partial');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(target.path);
    } catch (_) {
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
    return ManagedImageAsset(
      assetPath: '$_assetDirectoryName/${_fileName(target.path)}',
      originalFileName: originalFileName,
      pixelWidth: dimensions.width,
      pixelHeight: dimensions.height,
    );
  }

  @override
  Future<File> resolve(String assetPath) async {
    final normalizedPath = assetPath.replaceAll('\\', '/');
    final segments = normalizedPath.split('/');
    if (segments.length != 2 ||
        segments.first != _assetDirectoryName ||
        !RegExp(
          r'^[A-Za-z0-9_-]+\.(png|jpe?g|gif)$',
          caseSensitive: false,
        ).hasMatch(segments.last)) {
      throw ArgumentError.value(
        assetPath,
        'assetPath',
        'Expected a managed path under assets/.',
      );
    }

    final root = await _directoryProvider();
    return File(
      '${root.path}${Platform.pathSeparator}$_assetDirectoryName'
      '${Platform.pathSeparator}${segments.last}',
    );
  }

  static String _fileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  static String _supportedExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final extension = dotIndex < 0
        ? ''
        : fileName.substring(dotIndex).toLowerCase();
    if (extension != '.png' &&
        extension != '.jpg' &&
        extension != '.jpeg' &&
        extension != '.gif') {
      throw const FormatException(
        'Only PNG, JPEG, and GIF images are supported.',
      );
    }
    return extension;
  }

  static void _validateSignature(Uint8List bytes, String extension) {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    final isJpeg =
        bytes.length >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[bytes.length - 2] == 0xff &&
        bytes[bytes.length - 1] == 0xd9;
    final isGif =
        bytes.length >= 13 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61;

    if ((extension == '.png' && !isPng) ||
        ((extension == '.jpg' || extension == '.jpeg') && !isJpeg) ||
        (extension == '.gif' && !isGif)) {
      throw const FormatException(
        'Image contents do not match the file extension.',
      );
    }
  }

  static Future<({int width, int height})> _decodeDimensions(
    Uint8List bytes, {
    bool validateFirstFrame = false,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width * descriptor.height > maximumImagePixels) {
        throw const FormatException(
          'Images must contain at most 40 million pixels.',
        );
      }
      if (validateFirstFrame) {
        codec = await descriptor.instantiateCodec();
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      }
      return (width: descriptor.width, height: descriptor.height);
    } catch (_) {
      throw const FormatException('Image data could not be decoded.');
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static String _safeGeneratedId(String value) {
    final safeValue = value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    if (safeValue.isEmpty) {
      throw StateError('The image asset ID generator returned an empty ID.');
    }
    return safeValue;
  }
}
