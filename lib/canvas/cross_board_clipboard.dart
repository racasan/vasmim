import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../connector/connector.dart';
import '../group/board_group.dart';
import '../heading/canvas_heading.dart';
import '../image/board_image.dart';
import '../note/note.dart';
import 'cross_board_foreground_snapshot.dart';

typedef CrossBoardImageSnapshotCapturer =
    Future<CrossBoardImageSnapshot> Function({
      required BoardImage image,
      required File sourceFile,
    });

class CrossBoardClipboard {
  CrossBoardClipboardPayload? _payload;
  int _revision = 0;

  CrossBoardClipboardPayload? get payload => _payload;

  bool get hasPayload => _payload != null;
  int get revision => _revision;

  void publish(CrossBoardClipboardPayload payload) {
    final previous = _payload?.foreground;
    _payload = payload;
    _revision++;
    if (previous != null && !identical(previous, payload.foreground)) {
      unawaited(previous.dispose());
    }
  }

  bool publishIfUnchanged(
    CrossBoardClipboardPayload payload, {
    required int revision,
  }) {
    if (_revision != revision) return false;
    publish(payload);
    return true;
  }

  Future<void> clear() {
    final previous = _payload?.foreground;
    _payload = null;
    _revision++;
    return previous?.dispose() ?? Future<void>.value();
  }
}

class CrossBoardClipboardPayload {
  CrossBoardClipboardPayload({
    required this.sourceBoardId,
    required List<Note> notes,
    required List<Connector> connectors,
    required List<CanvasHeading> headings,
    required List<BoardGroup> groups,
    required Set<String> lockedObjectIds,
    this.image,
    this.foreground,
  }) : notes = List.unmodifiable(notes),
       connectors = List.unmodifiable(connectors),
       headings = List.unmodifiable(headings),
       groups = List.unmodifiable(groups),
       lockedObjectIds = Set.unmodifiable(lockedObjectIds) {
    if (foreground != null) {
      if (image != null ||
          notes.isNotEmpty ||
          connectors.isNotEmpty ||
          headings.isNotEmpty ||
          groups.isNotEmpty ||
          lockedObjectIds.isNotEmpty ||
          sourceBoardId.isEmpty) {
        throw ArgumentError('A foreground payload must stand alone.');
      }
      return;
    }
    if (image != null &&
        (notes.isNotEmpty ||
            connectors.isNotEmpty ||
            headings.isNotEmpty ||
            groups.isNotEmpty)) {
      throw ArgumentError(
        'A single-Image cross-Board payload cannot contain other objects.',
      );
    }
    final objectIds = {
      for (final note in notes) note.id,
      for (final heading in headings) heading.id,
      if (image != null) image!.image.id,
    };
    if (sourceBoardId.isEmpty || objectIds.isEmpty) {
      throw ArgumentError(
        'A cross-Board clipboard payload needs a source and content.',
      );
    }
    if (objectIds.length !=
        notes.length + headings.length + (image == null ? 0 : 1)) {
      throw ArgumentError(
        'Cross-Board clipboard object identities must be unique.',
      );
    }
    if (connectors.any(
      (connector) =>
          !notes.any((note) => note.id == connector.objectAId) ||
          !notes.any((note) => note.id == connector.objectBId),
    )) {
      throw ArgumentError(
        'Cross-Board clipboard Connectors must join copied Notes.',
      );
    }
    if (groups.any(
      (group) => group.memberIds.any((id) => !objectIds.contains(id)),
    )) {
      throw ArgumentError(
        'Cross-Board clipboard Groups must contain copied objects.',
      );
    }
    if (lockedObjectIds.any((id) => !objectIds.contains(id))) {
      throw ArgumentError(
        'Cross-Board clipboard locks must target copied objects.',
      );
    }
  }

  final String sourceBoardId;
  final List<Note> notes;
  final List<Connector> connectors;
  final List<CanvasHeading> headings;
  final List<BoardGroup> groups;
  final Set<String> lockedObjectIds;
  final CrossBoardImageSnapshot? image;
  final CrossBoardForegroundSnapshot? foreground;
}

class CrossBoardImageSnapshot {
  CrossBoardImageSnapshot._({required this.image, required Uint8List bytes})
    : _bytes = Uint8List.fromList(bytes);

  final BoardImage image;
  final Uint8List _bytes;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  factory CrossBoardImageSnapshot.fromValidatedBytes({
    required BoardImage image,
    required Uint8List bytes,
  }) {
    _validateSignature(bytes, image.assetPath);
    return CrossBoardImageSnapshot._(image: image, bytes: bytes);
  }

  static Future<CrossBoardImageSnapshot> capture({
    required BoardImage image,
    required File sourceFile,
  }) async {
    final before = await sourceFile.stat();
    final bytes = await sourceFile.readAsBytes();
    final after = await sourceFile.stat();
    if (before.type != FileSystemEntityType.file ||
        after.type != FileSystemEntityType.file ||
        before.size != after.size ||
        before.modified != after.modified) {
      throw const FileSystemException(
        'Managed Image changed while it was being copied.',
      );
    }
    _validateSignature(bytes, image.assetPath);

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width != image.pixelWidth ||
          descriptor.height != image.pixelHeight) {
        throw const FormatException(
          'Managed Image dimensions changed after import.',
        );
      }
    } catch (error) {
      if (error is FormatException) rethrow;
      throw const FormatException('Managed Image data could not be decoded.');
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }

    return CrossBoardImageSnapshot._(image: image, bytes: bytes);
  }

  static void _validateSignature(Uint8List bytes, String assetPath) {
    final lowerPath = assetPath.toLowerCase();
    final isPngPath = lowerPath.endsWith('.png');
    final isJpegPath =
        lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg');
    final isGifPath = lowerPath.endsWith('.gif');
    if (!isPngPath && !isJpegPath && !isGifPath) {
      throw const FormatException(
        'Managed Image type is not PNG, JPEG, or GIF.',
      );
    }
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
    if ((isPngPath && !isPng) ||
        (isJpegPath && !isJpeg) ||
        (isGifPath && !isGif)) {
      throw const FormatException(
        'Managed Image contents do not match the file extension.',
      );
    }
  }
}
