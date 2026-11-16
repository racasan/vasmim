import 'package:flutter/material.dart';

import '../connector/connector.dart';
import '../heading/canvas_heading.dart';
import '../image/board_image.dart';
import '../note/note.dart';
import '../shape/board_shape.dart';
import '../shape/shape_layer.dart';
import 'connector_search.dart';
import 'heading_search.dart';
import 'image_search.dart';
import 'note_search.dart';
import 'shape_search.dart';

enum BoardSearchTargetType { note, image, heading, shape, connector }

class BoardSearchTarget {
  const BoardSearchTarget({required this.type, required this.objectId});

  const BoardSearchTarget.note(String noteId)
    : this(type: BoardSearchTargetType.note, objectId: noteId);

  const BoardSearchTarget.image(String imageId)
    : this(type: BoardSearchTargetType.image, objectId: imageId);

  const BoardSearchTarget.heading(String headingId)
    : this(type: BoardSearchTargetType.heading, objectId: headingId);

  const BoardSearchTarget.shape(String shapeId)
    : this(type: BoardSearchTargetType.shape, objectId: shapeId);

  const BoardSearchTarget.connector(String connectorId)
    : this(type: BoardSearchTargetType.connector, objectId: connectorId);

  final BoardSearchTargetType type;
  final String objectId;
}

class BoardSearchDialog extends StatefulWidget {
  const BoardSearchDialog({
    required this.notes,
    required this.headings,
    required this.images,
    required this.connectors,
    required this.shapes,
    required this.shapeLayers,
    this.hiddenObjectIds = const {},
    super.key,
  });

  final List<Note> notes;
  final List<CanvasHeading> headings;
  final List<BoardImage> images;
  final List<Connector> connectors;
  final List<BoardShape> shapes;
  final List<ShapeLayer> shapeLayers;
  final Set<String> hiddenObjectIds;

  @override
  State<BoardSearchDialog> createState() => _BoardSearchDialogState();
}

class _BoardSearchDialogState extends State<BoardSearchDialog> {
  static const _notesMode = 'notes';
  static const _imagesMode = 'images';
  static const _connectionsMode = 'connections';

  String _mode = _notesMode;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isNotesMode = _mode == _notesMode;
    final isImagesMode = _mode == _imagesMode;
    final trimmedQuery = _query.trim();
    final noteResults = isNotesMode
        ? NoteSearch.find(widget.notes, _query)
        : const <NoteSearchResult>[];
    final headingResults = isNotesMode
        ? HeadingSearch.find(widget.headings, _query)
        : const <HeadingSearchResult>[];
    final shapeResults = isNotesMode
        ? ShapeSearch.find(widget.shapes, _query)
        : const <ShapeSearchResult>[];
    final imageResults = isImagesMode
        ? ImageSearch.find(widget.images, _query)
        : const <ImageSearchResult>[];
    final connectorResults = _mode == _connectionsMode
        ? ConnectorSearch.find(widget.connectors, _query)
        : const <ConnectorSearchResult>[];
    final resultCount = isNotesMode
        ? noteResults.length + headingResults.length + shapeResults.length
        : isImagesMode
        ? imageResults.length
        : connectorResults.length;
    final hasSearchableItems = isNotesMode
        ? widget.headings.isNotEmpty ||
              widget.shapes.any((shape) => shape.heading != null) ||
              widget.notes.any(
                (note) =>
                    note.text.trim().isNotEmpty ||
                    (note.title?.isNotEmpty ?? false),
              )
        : isImagesMode
        ? widget.images.isNotEmpty
        : widget.connectors.any((connector) => connector.label != null);

    return AlertDialog(
      key: const ValueKey('find-board-dialog'),
      title: const Text('Find on board'),
      content: SizedBox(
        width: 520,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Choose whether to search notes, images, or connections',
              child: SegmentedButton<String>(
                key: const ValueKey('find-mode-control'),
                segments: const [
                  ButtonSegment(
                    value: _notesMode,
                    icon: Icon(Icons.note_outlined),
                    label: Text('Notes', key: ValueKey('find-mode-notes')),
                  ),
                  ButtonSegment(
                    value: _imagesMode,
                    icon: Icon(Icons.image_outlined),
                    label: Text('Images', key: ValueKey('find-mode-images')),
                  ),
                  ButtonSegment(
                    value: _connectionsMode,
                    icon: Icon(Icons.link),
                    label: Text(
                      'Connections',
                      key: ValueKey('find-mode-connections'),
                    ),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.single);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('find-board-field'),
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: isNotesMode
                    ? 'Words from a note or heading'
                    : isImagesMode
                    ? 'Words from an image caption or filename'
                    : 'Words from a connection label',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (!hasSearchableItems)
              Expanded(
                child: Center(
                  child: Text(
                    isNotesMode
                        ? 'This board has no notes or headings to search.'
                        : isImagesMode
                        ? 'This board has no images to search.'
                        : 'This board has no labeled connections to search.',
                  ),
                ),
              )
            else if (trimmedQuery.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    isNotesMode
                        ? 'Type words from a note or heading to search this board.'
                        : isImagesMode
                        ? 'Type words from an image caption or filename to search this board.'
                        : 'Type words from a connection label to search this board.',
                  ),
                ),
              )
            else if (resultCount == 0)
              Expanded(
                child: Center(
                  child: Text(
                    isNotesMode
                        ? 'No notes or headings match your search.'
                        : isImagesMode
                        ? 'No image captions or filenames match your search.'
                        : 'No connection labels match your search.',
                  ),
                ),
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
                  key: const ValueKey('find-board-result-count'),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('find-board-results'),
                  itemCount: resultCount,
                  itemBuilder: (context, index) {
                    if (isNotesMode) {
                      if (index >= noteResults.length + headingResults.length) {
                        final result =
                            shapeResults[index -
                                noteResults.length -
                                headingResults.length];
                        final layer = widget.shapeLayers.firstWhere(
                          (candidate) =>
                              candidate.shapeIds.contains(result.shape.id),
                        );
                        return ListTile(
                          key: ValueKey('find-shape-result-${result.shape.id}'),
                          leading: const Icon(Icons.category_outlined),
                          title: Text(
                            result.shape.heading!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            layer.isVisible
                                ? 'Shape heading · ${layer.name}'
                                : 'Shape heading · Hidden — ${layer.name}',
                          ),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(BoardSearchTarget.shape(result.shape.id)),
                        );
                      }
                      if (index >= noteResults.length) {
                        final result =
                            headingResults[index - noteResults.length];
                        return ListTile(
                          key: ValueKey(
                            'find-heading-result-${result.heading.id}',
                          ),
                          leading: const Icon(Icons.title),
                          title: Text(
                            result.heading.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            widget.hiddenObjectIds.contains(result.heading.id)
                                ? 'Heading · Hidden group · Show and select'
                                : 'Heading',
                          ),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(BoardSearchTarget.heading(result.heading.id)),
                        );
                      }
                      final result = noteResults[index];
                      return ListTile(
                        key: ValueKey('find-note-result-${result.note.id}'),
                        leading: const Icon(Icons.note_outlined),
                        title: Text(
                          result.title ?? result.excerpt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            widget.hiddenObjectIds.contains(result.note.id)
                            ? const Text(
                                'Note · Hidden group · Show and select',
                              )
                            : result.title == null
                            ? const Text('Note')
                            : Text(
                                result.excerpt.isEmpty
                                    ? 'Note'
                                    : result.excerpt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(BoardSearchTarget.note(result.note.id)),
                      );
                    }
                    if (isImagesMode) {
                      final result = imageResults[index];
                      return ListTile(
                        key: ValueKey('find-image-result-${result.image.id}'),
                        leading: const Icon(Icons.image_outlined),
                        title: Text(
                          result.primaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          widget.hiddenObjectIds.contains(result.image.id)
                              ? 'Image · Hidden group · Show and select'
                              : result.caption == null
                              ? 'Image'
                              : result.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(BoardSearchTarget.image(result.image.id)),
                      );
                    }
                    final result = connectorResults[index];
                    return ListTile(
                      key: ValueKey(
                        'find-connection-result-${result.connector.id}',
                      ),
                      leading: const Icon(Icons.link),
                      title: Text(
                        result.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text('Connection'),
                      onTap: () => Navigator.of(
                        context,
                      ).pop(BoardSearchTarget.connector(result.connector.id)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('close-find-board-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
