import 'package:flutter/material.dart';

import 'board_document.dart';
import 'library_connector_search.dart';
import 'library_heading_search.dart';
import 'library_image_search.dart';
import 'library_note_search.dart';
import 'library_scene_search.dart';
import 'library_shape_search.dart';
import 'library_search_target.dart';

enum LibrarySearchMode { notes, images, connections, scenes }

class LibrarySearchDialog extends StatefulWidget {
  const LibrarySearchDialog({required this.orderedBoards, super.key});

  final List<BoardDocument> orderedBoards;

  @override
  State<LibrarySearchDialog> createState() => _LibrarySearchDialogState();
}

class _LibrarySearchDialogState extends State<LibrarySearchDialog> {
  LibrarySearchMode _mode = LibrarySearchMode.notes;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _query.trim();
    final noteResults = _mode == LibrarySearchMode.notes
        ? LibraryNoteSearch.find(widget.orderedBoards, _query)
        : const <LibraryNoteSearchResult>[];
    final headingResults = _mode == LibrarySearchMode.notes
        ? LibraryHeadingSearch.find(widget.orderedBoards, _query)
        : const <LibraryHeadingSearchResult>[];
    final shapeResults = _mode == LibrarySearchMode.notes
        ? LibraryShapeSearch.find(widget.orderedBoards, _query)
        : const <LibraryShapeSearchResult>[];
    final imageResults = _mode == LibrarySearchMode.images
        ? LibraryImageSearch.find(widget.orderedBoards, _query)
        : const <LibraryImageSearchResult>[];
    final connectorResults = _mode == LibrarySearchMode.connections
        ? LibraryConnectorSearch.find(widget.orderedBoards, _query)
        : const <LibraryConnectorSearchResult>[];
    final sceneResults = _mode == LibrarySearchMode.scenes
        ? LibrarySceneSearch.find(widget.orderedBoards, _query)
        : const <LibrarySceneSearchResult>[];
    final hasWrittenNotes = widget.orderedBoards.any(
      (board) =>
          board.headings.isNotEmpty ||
          board.shapes.any((shape) => shape.heading != null) ||
          board.notes.any(
            (note) =>
                note.text.trim().isNotEmpty ||
                (note.title?.isNotEmpty ?? false),
          ),
    );
    final hasImages = widget.orderedBoards.any(
      (board) => board.images.isNotEmpty,
    );
    final hasLabeledConnections = widget.orderedBoards.any(
      (board) => board.connectors.any((connector) => connector.label != null),
    );
    final hasScenes = widget.orderedBoards.any(
      (board) => board.scenes.isNotEmpty,
    );
    final resultCount = switch (_mode) {
      LibrarySearchMode.notes =>
        noteResults.length + headingResults.length + shapeResults.length,
      LibrarySearchMode.images => imageResults.length,
      LibrarySearchMode.connections => connectorResults.length,
      LibrarySearchMode.scenes => sceneResults.length,
    };

    return AlertDialog(
      key: const ValueKey('library-note-search-dialog'),
      title: const Text('Find across boards'),
      content: SizedBox(
        width: 560,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label:
                  'Choose whether to search notes, images, connections, or Scenes across boards',
              child: SegmentedButton<LibrarySearchMode>(
                key: const ValueKey('library-search-mode'),
                segments: const [
                  ButtonSegment(
                    value: LibrarySearchMode.notes,
                    icon: Icon(Icons.note_outlined),
                    label: Text('Notes'),
                  ),
                  ButtonSegment(
                    value: LibrarySearchMode.images,
                    icon: Icon(Icons.image_outlined),
                    label: Text('Images'),
                  ),
                  ButtonSegment(
                    value: LibrarySearchMode.connections,
                    icon: Icon(Icons.link),
                    label: Text('Connections'),
                  ),
                  ButtonSegment(
                    value: LibrarySearchMode.scenes,
                    icon: Icon(Icons.bookmark_outline),
                    label: Text('Scenes'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.single);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('library-note-search-field'),
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: switch (_mode) {
                  LibrarySearchMode.notes => 'Words from a note or heading',
                  LibrarySearchMode.images =>
                    'Words from an image caption or filename',
                  LibrarySearchMode.connections =>
                    'Words from a connection label',
                  LibrarySearchMode.scenes => 'Words from a Scene name',
                },
                helperText: 'Searches all healthy boards in this Library',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_mode == LibrarySearchMode.notes && !hasWrittenNotes)
              const Expanded(
                child: Center(
                  child: Text(
                    'This Library has no notes or headings to search.',
                  ),
                ),
              )
            else if (_mode == LibrarySearchMode.images && !hasImages)
              const Expanded(
                child: Center(
                  child: Text('This Library has no images to search.'),
                ),
              )
            else if (_mode == LibrarySearchMode.connections &&
                !hasLabeledConnections)
              const Expanded(
                child: Center(
                  child: Text(
                    'This Library has no labeled connections to search.',
                  ),
                ),
              )
            else if (_mode == LibrarySearchMode.scenes && !hasScenes)
              const Expanded(
                child: Center(
                  child: Text('This Library has no Scenes to search.'),
                ),
              )
            else if (trimmedQuery.isEmpty)
              Expanded(
                child: Center(
                  child: Text(switch (_mode) {
                    LibrarySearchMode.notes =>
                      'Type words from a note or heading to search every healthy board.',
                    LibrarySearchMode.images =>
                      'Type words from an image caption or filename to search every healthy board.',
                    LibrarySearchMode.connections =>
                      'Type words from a connection label to search every healthy board.',
                    LibrarySearchMode.scenes =>
                      'Type words from a Scene name to search every healthy board.',
                  }),
                ),
              )
            else if (resultCount == 0)
              Expanded(
                child: Center(
                  child: Text(switch (_mode) {
                    LibrarySearchMode.notes =>
                      'No notes or headings across boards match your search.',
                    LibrarySearchMode.images =>
                      'No image captions or filenames across boards match your search.',
                    LibrarySearchMode.connections =>
                      'No connection labels across boards match your search.',
                    LibrarySearchMode.scenes =>
                      'No Scene names across boards match your search.',
                  }),
                ),
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
                  key: const ValueKey('library-note-search-result-count'),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('library-note-search-results'),
                  itemCount: resultCount,
                  itemBuilder: (context, index) {
                    if (_mode == LibrarySearchMode.notes) {
                      if (index >= noteResults.length + headingResults.length) {
                        final result =
                            shapeResults[index -
                                noteResults.length -
                                headingResults.length];
                        final layer = result.board.shapeLayers.firstWhere(
                          (candidate) =>
                              candidate.shapeIds.contains(result.shape.id),
                        );
                        return ListTile(
                          key: ValueKey(
                            'library-shape-result-'
                            '${result.board.id}-${result.shape.id}',
                          ),
                          leading: const Icon(Icons.category_outlined),
                          title: Text(
                            result.shape.heading!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            layer.isVisible
                                ? '${layer.name}\n${_boardContext(result.board)}'
                                : 'Hidden — ${layer.name}\n${_boardContext(result.board)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(
                            LibrarySearchTarget.shape(
                              boardId: result.board.id,
                              shapeId: result.shape.id,
                              query: _query,
                            ),
                          ),
                        );
                      }
                      if (index >= noteResults.length) {
                        final result =
                            headingResults[index - noteResults.length];
                        return ListTile(
                          key: ValueKey(
                            'library-heading-result-'
                            '${result.board.id}-${result.heading.id}',
                          ),
                          leading: const Icon(Icons.title),
                          title: Text(
                            result.heading.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _foregroundContext(result.board, result.heading.id),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(
                            LibrarySearchTarget.heading(
                              boardId: result.board.id,
                              headingId: result.heading.id,
                              query: _query,
                            ),
                          ),
                        );
                      }
                      final result = noteResults[index];
                      return ListTile(
                        key: ValueKey(
                          'library-note-result-'
                          '${result.board.id}-${result.note.id}',
                        ),
                        leading: const Icon(Icons.note_outlined),
                        title: Text(
                          result.note.title ?? result.excerpt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _foregroundContext(
                            result.board,
                            result.note.id,
                            detail:
                                result.note.title == null ||
                                    result.excerpt.isEmpty
                                ? null
                                : result.excerpt,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(
                          LibrarySearchTarget.note(
                            boardId: result.board.id,
                            noteId: result.note.id,
                            query: _query,
                          ),
                        ),
                      );
                    }
                    if (_mode == LibrarySearchMode.images) {
                      final result = imageResults[index];
                      return ListTile(
                        key: ValueKey(
                          'library-image-result-'
                          '${result.board.id}-${result.image.id}',
                        ),
                        leading: const Icon(Icons.image_outlined),
                        title: Text(
                          result.primaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _foregroundContext(
                            result.board,
                            result.image.id,
                            detail: result.caption == null
                                ? null
                                : result.fileName,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(
                          LibrarySearchTarget.image(
                            boardId: result.board.id,
                            imageId: result.image.id,
                            query: _query,
                          ),
                        ),
                      );
                    }
                    if (_mode == LibrarySearchMode.connections) {
                      final result = connectorResults[index];
                      return ListTile(
                        key: ValueKey(
                          'library-connection-result-'
                          '${result.board.id}-${result.connector.id}',
                        ),
                        leading: const Icon(Icons.link),
                        title: Text(
                          result.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _connectorContext(
                            result.board,
                            result.connector.objectAId,
                            result.connector.objectBId,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(
                          LibrarySearchTarget.connector(
                            boardId: result.board.id,
                            connectorId: result.connector.id,
                            query: _query,
                          ),
                        ),
                      );
                    }
                    final result = sceneResults[index];
                    return ListTile(
                      key: ValueKey(
                        'library-scene-result-'
                        '${result.board.id}-${result.scene.id}',
                      ),
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _boardContext(result.board),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(
                        LibrarySearchTarget.scene(
                          boardId: result.board.id,
                          sceneId: result.scene.id,
                          query: _query,
                        ),
                      ),
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
          key: const ValueKey('close-library-note-search-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  static String _boardContext(BoardDocument board) {
    return 'Board: ${board.name}\nModified ${_formatDate(board.modifiedAt)}';
  }

  static bool _isHiddenGroupMember(BoardDocument board, String objectId) =>
      board.groups.any(
        (group) => !group.isVisible && group.memberIds.contains(objectId),
      );

  static String _foregroundContext(
    BoardDocument board,
    String objectId, {
    String? detail,
  }) {
    if (_isHiddenGroupMember(board, objectId)) {
      return [
        ?detail,
        'Hidden group · Show and select',
        'Board: ${board.name}',
      ].join('\n');
    }
    return detail == null
        ? _boardContext(board)
        : '$detail\n${_boardContext(board)}';
  }

  static String _connectorContext(
    BoardDocument board,
    String firstObjectId,
    String secondObjectId,
  ) {
    if (_isHiddenGroupMember(board, firstObjectId) ||
        _isHiddenGroupMember(board, secondObjectId)) {
      return 'Hidden group · Show and select\n${_boardContext(board)}';
    }
    return _boardContext(board);
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
