import 'package:flutter/material.dart';

import '../heading/canvas_heading_geometry.dart';
import '../heading/canvas_heading_palette.dart';
import '../canvas/canvas_overview_map.dart';
import '../canvas/canvas_paper_painter.dart';
import '../note/note_color_palette.dart';
import '../attachment/board_attachment.dart';
import 'board_document.dart';
import 'board_paper_tone.dart';

class BoardPreviewDialog extends StatelessWidget {
  const BoardPreviewDialog({required this.board, super.key});

  static const previewSize = Size(480, 360);
  static const boardSize = Size(4000, 3000);
  static const representativeViewportSize = Size(800, 600);

  final BoardDocument board;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transform =
        Matrix4.diagonal3Values(
          board.viewportZoom,
          board.viewportZoom,
          board.viewportZoom,
        )..setTranslationRaw(
          -board.viewportX * board.viewportZoom,
          -board.viewportY * board.viewportZoom,
          0,
        );
    final objects = [
      for (final note in board.notes)
        CanvasOverviewObject(
          id: note.id,
          bounds: Rect.fromLTWH(note.x, note.y, note.width, note.height),
          color: note.color.backgroundColor,
        ),
      for (final image in board.images)
        CanvasOverviewObject(
          id: image.id,
          bounds: Rect.fromLTWH(image.x, image.y, image.width, image.height),
          color: colorScheme.secondaryContainer,
        ),
      for (final heading in board.headings)
        CanvasOverviewObject(
          id: heading.id,
          bounds: CanvasHeadingGeometry.boundsFor(heading),
          color: heading.background.color == Colors.transparent
              ? colorScheme.primary.withValues(alpha: 0.55)
              : heading.background.color,
        ),
    ];
    final links = [
      for (final connector in board.connectors)
        CanvasOverviewLink(
          objectAId: connector.objectAId,
          objectBId: connector.objectBId,
        ),
    ];

    return AlertDialog(
      key: const ValueKey('board-preview-dialog'),
      title: Text(board.name),
      content: Semantics(
        image: true,
        label:
            'Board preview showing ${objects.length} objects and the saved viewport',
        excludeSemantics: true,
        child: SizedBox.fromSize(
          size: previewSize,
          child: CustomPaint(
            key: const ValueKey('board-preview-paint'),
            painter: CanvasOverviewPainter(
              boardSize: boardSize,
              overviewSize: previewSize,
              viewportSize: representativeViewportSize,
              transform: transform,
              objects: objects,
              links: links,
              backgroundColor: board.paperTone == BoardPaperTone.defaultTone
                  ? colorScheme.surfaceContainerHighest
                  : LayeredCanvasPaperPainter.paperColorFor(
                      board.paperTone,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
              borderColor: colorScheme.outlineVariant,
              linkColor: colorScheme.outline,
              viewportColor: colorScheme.primary,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('close-board-preview-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        FilledButton(
          key: const ValueKey('open-board-preview-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open board'),
        ),
      ],
    );
  }
}

class BoardLibraryThumbnail extends StatelessWidget {
  const BoardLibraryThumbnail({required this.board, super.key});

  static const thumbnailSize = Size(72, 48);

  final BoardDocument board;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hiddenMemberIds = {
      for (final group in board.groups)
        if (!group.isVisible) ...group.memberIds,
    };
    final visibleShapeIds = {
      for (final layer in board.shapeLayers)
        if (layer.isVisible) ...layer.shapeIds,
    };
    final objects = [
      for (final shape in board.shapes)
        if (visibleShapeIds.contains(shape.id) &&
            !hiddenMemberIds.contains(shape.id))
          CanvasOverviewObject(
            id: shape.id,
            bounds: Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height),
            color: Color(shape.outlineColorValue).withValues(alpha: 0.45),
          ),
      for (final note in board.notes)
        if (!hiddenMemberIds.contains(note.id))
          CanvasOverviewObject(
            id: note.id,
            bounds: Rect.fromLTWH(note.x, note.y, note.width, note.height),
            color: note.color.backgroundColor,
          ),
      for (final image in board.images)
        if (!hiddenMemberIds.contains(image.id))
          CanvasOverviewObject(
            id: image.id,
            bounds: Rect.fromLTWH(image.x, image.y, image.width, image.height),
            color: colorScheme.secondaryContainer,
          ),
      for (final heading in board.headings)
        if (!hiddenMemberIds.contains(heading.id))
          CanvasOverviewObject(
            id: heading.id,
            bounds: CanvasHeadingGeometry.boundsFor(heading),
            color: heading.background.color == Colors.transparent
                ? colorScheme.primary.withValues(alpha: 0.55)
                : heading.background.color,
          ),
      for (final attachment in board.attachments)
        if (!hiddenMemberIds.contains(attachment.id))
          CanvasOverviewObject(
            id: attachment.id,
            bounds: Rect.fromLTWH(
              attachment.x,
              attachment.y,
              attachment.width,
              attachment.height,
            ),
            color: attachment.kind == AttachmentKind.pdf
                ? const Color(0xffb83a32)
                : const Color(0xff50569d),
          ),
      for (final embed in board.youTubeEmbeds)
        if (!hiddenMemberIds.contains(embed.id))
          CanvasOverviewObject(
            id: embed.id,
            bounds: Rect.fromLTWH(embed.x, embed.y, embed.width, embed.height),
            color: const Color(0xfff44336),
          ),
    ];
    final visibleIds = {for (final object in objects) object.id};
    final links = [
      for (final connector in board.connectors)
        if (visibleIds.contains(connector.objectAId) &&
            visibleIds.contains(connector.objectBId))
          CanvasOverviewLink(
            objectAId: connector.objectAId,
            objectBId: connector.objectBId,
          ),
    ];

    return Semantics(
      image: true,
      label: 'Whole-board thumbnail showing ${objects.length} objects',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          key: ValueKey('board-thumbnail-${board.id}'),
          size: thumbnailSize,
          painter: CanvasOverviewPainter(
            boardSize: BoardPreviewDialog.boardSize,
            overviewSize: thumbnailSize,
            viewportSize: BoardPreviewDialog.representativeViewportSize,
            transform: Matrix4.identity(),
            objects: objects,
            links: links,
            backgroundColor: board.paperTone == BoardPaperTone.defaultTone
                ? colorScheme.surfaceContainerHighest
                : LayeredCanvasPaperPainter.paperColorFor(
                    board.paperTone,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
            borderColor: colorScheme.outlineVariant,
            linkColor: colorScheme.outline,
            viewportColor: colorScheme.primary,
            showViewport: false,
          ),
        ),
      ),
    );
  }
}
