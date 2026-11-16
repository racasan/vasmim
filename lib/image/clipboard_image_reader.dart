import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ClipboardImagePayload {
  const ClipboardImagePayload({
    required this.pngBytes,
    required this.suggestedFileName,
  });

  final Uint8List pngBytes;
  final String suggestedFileName;
}

abstract interface class ClipboardImageReader {
  Future<bool> hasImage();

  Future<ClipboardImagePayload?> readImage();
}

class UnavailableClipboardImageReader implements ClipboardImageReader {
  const UnavailableClipboardImageReader();

  @override
  Future<bool> hasImage() async => false;

  @override
  Future<ClipboardImagePayload?> readImage() async => null;
}

class SystemClipboardImageReader implements ClipboardImageReader {
  static const _readTimeout = Duration(seconds: 5);
  static const _maximumImageBytes = 50 * 1024 * 1024;

  String? _eligibleDigest;

  @override
  Future<bool> hasImage() async {
    _eligibleDigest = null;
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return false;
    }
    try {
      final reader = await clipboard.read().timeout(_readTimeout);
      if (!reader.canProvide(Formats.png)) {
        return false;
      }
      final image = await _readCurrentImage(reader).timeout(_readTimeout);
      if (image == null) {
        return false;
      }
      _eligibleDigest = sha256.convert(image.pngBytes).toString();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ClipboardImagePayload?> readImage() async {
    final eligibleDigest = _eligibleDigest;
    _eligibleDigest = null;
    if (eligibleDigest == null) {
      return null;
    }
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return null;
    }

    final reader = await clipboard.read().timeout(_readTimeout);
    final image = await _readCurrentImage(reader);
    if (image == null ||
        sha256.convert(image.pngBytes).toString() != eligibleDigest) {
      return null;
    }

    return image;
  }

  Future<ClipboardImagePayload?> _readCurrentImage(
    ClipboardReader reader,
  ) async {
    if (!reader.canProvide(Formats.png)) {
      return null;
    }

    final suggestedName = await reader.getSuggestedName().timeout(
      _readTimeout,
      onTimeout: () => null,
    );
    final image = await _readPng(reader).timeout(_readTimeout);
    if (image == null) {
      return null;
    }
    return ClipboardImagePayload(
      pngBytes: image.bytes,
      suggestedFileName: _pngFileName(image.fileName ?? suggestedName),
    );
  }

  Future<({Uint8List bytes, String? fileName})?> _readPng(
    ClipboardReader reader,
  ) {
    final completer = Completer<({Uint8List bytes, String? fileName})?>();
    final progress = reader.getFile(
      Formats.png,
      (file) async {
        try {
          final declaredSize = file.fileSize;
          if (declaredSize != null && declaredSize > _maximumImageBytes) {
            throw const FormatException('Clipboard image is too large.');
          }
          final bytes = await file.readAll();
          if (bytes.length > _maximumImageBytes) {
            throw const FormatException('Clipboard image is too large.');
          }
          if (!completer.isCompleted) {
            completer.complete((bytes: bytes, fileName: file.fileName));
          }
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    if (progress == null) {
      completer.complete(null);
    }
    return completer.future;
  }

  static String _pngFileName(String? suggestedName) {
    final leafName = suggestedName
        ?.replaceAll('\\', '/')
        .split('/')
        .last
        .trim();
    final withoutExtension = leafName == null || leafName.isEmpty
        ? 'Clipboard image'
        : leafName.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final safeStem = withoutExtension
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return '${safeStem.isEmpty ? 'Clipboard image' : safeStem}.png';
  }
}
