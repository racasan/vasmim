import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../attachment/attachment_asset_store.dart';
import '../attachment/board_attachment.dart';
import '../connector/connector.dart';
import '../group/board_group.dart';
import '../heading/canvas_heading.dart';
import '../image/board_image.dart';
import '../note/note.dart';
import '../youtube/youtube_embed.dart';

/// A source-independent, application-lifetime snapshot of foreground content.
/// Large attachments are spooled to a private temporary directory.
class CrossBoardForegroundSnapshot {
  CrossBoardForegroundSnapshot._({
    required this.notes,
    required this.connectors,
    required this.images,
    required this.headings,
    required this.attachments,
    required this.youTubeEmbeds,
    required this.groups,
    required this.lockedObjectIds,
    required this._imageBytes,
    required this._attachmentFiles,
    required this.temporaryDirectory,
  });

  final List<Note> notes;
  final List<Connector> connectors;
  final List<BoardImage> images;
  final List<CanvasHeading> headings;
  final List<BoardAttachment> attachments;
  final List<YouTubeEmbed> youTubeEmbeds;
  final List<BoardGroup> groups;
  final Set<String> lockedObjectIds;
  final Map<String, Uint8List> _imageBytes;
  final Map<String, File> _attachmentFiles;
  final Directory temporaryDirectory;

  Uint8List imageBytes(String assetPath) =>
      Uint8List.fromList(_imageBytes[assetPath]!);

  File attachmentFile(String assetPath) => _attachmentFiles[assetPath]!;

  Future<void> dispose() async {
    if (await temporaryDirectory.exists()) {
      if (Platform.isWindows) {
        for (final file in _attachmentFiles.values) {
          await Process.run('attrib', ['-R', file.path]);
        }
      }
      await temporaryDirectory.delete(recursive: true);
    }
  }

  static Future<CrossBoardForegroundSnapshot> capture({
    required List<Note> notes,
    required List<Connector> connectors,
    required List<BoardImage> images,
    required List<CanvasHeading> headings,
    required List<BoardAttachment> attachments,
    required List<YouTubeEmbed> youTubeEmbeds,
    required List<BoardGroup> groups,
    required Set<String> lockedObjectIds,
    required Future<File> Function(String assetPath) resolveImage,
    required Future<File> Function(String assetPath) resolveAttachment,
  }) async {
    final objectIds = <String>{
      ...notes.map((note) => note.id),
      ...images.map((image) => image.id),
      ...headings.map((heading) => heading.id),
      ...attachments.map((attachment) => attachment.id),
      ...youTubeEmbeds.map((embed) => embed.id),
    };
    final objectCount =
        notes.length +
        images.length +
        headings.length +
        attachments.length +
        youTubeEmbeds.length;
    final connectorIds = {
      ...notes.map((note) => note.id),
      ...images.map((image) => image.id),
    };
    if (objectIds.isEmpty ||
        objectIds.length != objectCount ||
        connectors.any(
          (connector) =>
              !connectorIds.contains(connector.objectAId) ||
              !connectorIds.contains(connector.objectBId),
        ) ||
        groups.any(
          (group) => group.memberIds.any((id) => !objectIds.contains(id)),
        ) ||
        lockedObjectIds.any((id) => !objectIds.contains(id))) {
      throw ArgumentError('Invalid cross-Board foreground selection.');
    }
    final directory = await Directory.systemTemp.createTemp('vasmim-copy-');
    try {
      final imageBytes = <String, Uint8List>{};
      final attachmentFiles = <String, File>{};
      final imagePaths = <String>{
        ...images.map((image) => image.assetPath),
        ...attachments
            .map((attachment) => attachment.previewAssetPath)
            .whereType<String>(),
        ...youTubeEmbeds
            .map((embed) => embed.thumbnailAssetPath)
            .whereType<String>(),
      };
      for (final path in imagePaths) {
        final source = await resolveImage(path);
        final bytes = await _readStable(source);
        ui.ImmutableBuffer? buffer;
        ui.ImageDescriptor? descriptor;
        try {
          buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          for (final image in images.where(
            (image) => image.assetPath == path,
          )) {
            if (descriptor.width != image.pixelWidth ||
                descriptor.height != image.pixelHeight) {
              throw const FormatException(
                'Managed Image dimensions changed after import.',
              );
            }
          }
        } catch (error) {
          if (error is FormatException) rethrow;
          throw const FormatException('Managed image could not be decoded.');
        } finally {
          descriptor?.dispose();
          buffer?.dispose();
        }
        imageBytes[path] = bytes;
      }
      for (final attachment in attachments) {
        final path = attachment.assetPath;
        if (attachmentFiles.containsKey(path)) continue;
        final source = await resolveAttachment(path);
        final before = await source.stat();
        if (before.type != FileSystemEntityType.file ||
            before.size != attachment.byteSize) {
          throw const FormatException(
            'Managed Attachment changed before Copy.',
          );
        }
        final extension = attachment.assetPath.split('.').last.toLowerCase();
        final target = File(
          '${directory.path}${Platform.pathSeparator}'
          '${attachmentFiles.length}.$extension',
        );
        await source.copy(target.path);
        if (Platform.isWindows) {
          final result = await Process.run('attrib', ['-R', target.path]);
          if (result.exitCode != 0) {
            throw const FileSystemException(
              'Could not prepare temporary Attachment snapshot.',
            );
          }
        }
        final after = await source.stat();
        if (after.size != before.size ||
            after.modified != before.modified ||
            await target.length() != before.size) {
          throw const FormatException(
            'Managed Attachment changed during Copy.',
          );
        }
        await FileAttachmentAssetStore.validateCandidate(
          AttachmentImportCandidate(
            sourcePath: target.path,
            originalFileName: attachment.originalFileName,
            kind: attachment.kind,
            byteSize: attachment.byteSize,
          ),
        );
        attachmentFiles[path] = target;
      }
      return CrossBoardForegroundSnapshot._(
        notes: List.unmodifiable(notes),
        connectors: List.unmodifiable(connectors),
        images: List.unmodifiable(images),
        headings: List.unmodifiable(headings),
        attachments: List.unmodifiable(attachments),
        youTubeEmbeds: List.unmodifiable(youTubeEmbeds),
        groups: List.unmodifiable(groups),
        lockedObjectIds: Set.unmodifiable(lockedObjectIds),
        imageBytes: imageBytes,
        attachmentFiles: attachmentFiles,
        temporaryDirectory: directory,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  static Future<Uint8List> _readStable(File source) async {
    final before = await source.stat();
    if (before.type != FileSystemEntityType.file || before.size <= 0) {
      throw const FormatException('Managed image is missing or empty.');
    }
    final bytes = await source.readAsBytes();
    final after = await source.stat();
    if (before.size != bytes.length ||
        before.size != after.size ||
        before.modified != after.modified) {
      throw const FormatException('Managed image changed during Copy.');
    }
    return bytes;
  }
}
