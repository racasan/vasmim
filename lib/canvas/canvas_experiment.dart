import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../attachment/attachment_asset_store.dart';
import '../attachment/attachment_launcher.dart';
import '../attachment/attachment_path_picker.dart';
import '../attachment/attachment_preview_generator.dart';
import '../attachment/board_attachment.dart';
import '../attachment/interactive_board_attachment.dart';
import '../attachment/pdf_attachment_viewer.dart';
import '../board/board_document.dart';
import '../board/board_paper_tone.dart';
import '../board/board_name_dialog.dart';
import '../board/board_store.dart';
import '../connector/connector.dart';
import '../connector/connector_graph.dart';
import '../connector/connector_geometry.dart';
import '../connector/connector_painter.dart';
import '../image/board_image.dart';
import '../image/clipboard_image_reader.dart';
import '../image/image_asset_store.dart';
import '../image/image_path_picker.dart';
import '../image/interactive_board_image.dart';
import '../image/managed_image_view.dart';
import '../heading/canvas_heading.dart';
import '../heading/canvas_heading_geometry.dart';
import '../heading/canvas_heading_palette.dart';
import '../heading/interactive_canvas_heading.dart';
import '../group/board_group.dart';
import '../group/group_side_panel.dart';
import '../help/vasmim_help_dialog.dart';
import '../note/editable_note.dart';
import '../note/note.dart';
import '../note/note_emphasis.dart';
import '../note/note_link_launcher.dart';
import '../note/note_link_resolver.dart';
import '../note/note_markdown_import.dart';
import '../note/note_text_link.dart';
import '../note/note_multi_website_marker.dart';
import '../note/note_website_marker.dart';
import '../note/note_color_palette.dart';
import '../scene/scene.dart';
import '../scene/scene_viewport_controller.dart';
import '../shape/board_shape.dart';
import '../shape/shape_definition.dart';
import '../shape/shape_layer.dart';
import '../shape/shape_layer_painter.dart';
import '../shape/shape_selection_painter.dart';
import '../shape/shape_side_panel.dart';
import '../thinking/fresh_pair_selector.dart';
import '../youtube/interactive_youtube_embed.dart';
import '../youtube/youtube_embed.dart';
import '../youtube/youtube_thumbnail_fetcher.dart';
import '../youtube/youtube_url.dart';
import 'board_search_dialog.dart';
import 'canvas_paper_painter.dart';
import 'canvas_snap_guide_painter.dart';
import 'canvas_snap_resolver.dart';
import 'canvas_initial_target.dart';
import 'current_view_png_export.dart';
import 'canvas_overview_geometry.dart';
import 'canvas_overview_map.dart';
import 'cross_board_clipboard.dart';
import 'cross_board_foreground_snapshot.dart';

class CanvasExperiment extends StatefulWidget {
  const CanvasExperiment({
    required this.boardStore,
    required this.imageAssetStore,
    required this.imagePicker,
    this.clipboardImageReader = const UnavailableClipboardImageReader(),
    this.imageViewBuilder,
    this.onReturnToLibrary,
    this.initialTarget,
    this.showBlankCanvasPriming = false,
    this.freshPairSelector,
    this.externalUrlLauncher,
    this.websiteIconBuilder,
    this.attachmentAssetStore,
    this.attachmentPicker = pickAttachmentPath,
    this.attachmentLauncher = const SystemAttachmentLauncher(),
    this.attachmentPreviewGenerator = const ManagedAttachmentPreviewGenerator(),
    this.youTubeThumbnailFetcher = const NetworkYouTubeThumbnailFetcher(),
    this.currentViewPngPathPicker = pickCurrentViewPngExportPath,
    this.currentViewPngPublisher = publishCurrentViewPng,
    this.currentViewPngCapturer = captureCurrentViewPng,
    this.currentViewPngClipboardWriter = writeCurrentViewPngToClipboard,
    this.crossBoardClipboard,
    this.isDarkMode = false,
    this.onToggleDarkMode,
    this.crossBoardImageSnapshotCapturer = CrossBoardImageSnapshot.capture,
    super.key,
  });

  final BoardStore boardStore;
  final ImageAssetStore imageAssetStore;
  final ImagePathPicker imagePicker;
  final ClipboardImageReader clipboardImageReader;
  final Widget Function(BoardImage image)? imageViewBuilder;
  final VoidCallback? onReturnToLibrary;
  final CanvasInitialTarget? initialTarget;
  final bool showBlankCanvasPriming;
  final FreshPairSelector? freshPairSelector;
  final ExternalUrlLauncher? externalUrlLauncher;
  final NoteWebsiteMarkerBuilder? websiteIconBuilder;
  final AttachmentAssetStore? attachmentAssetStore;
  final AttachmentPathPicker attachmentPicker;
  final AttachmentLauncher attachmentLauncher;
  final AttachmentPreviewGenerator attachmentPreviewGenerator;
  final YouTubeThumbnailFetcher youTubeThumbnailFetcher;
  final CurrentViewPngPathPicker currentViewPngPathPicker;
  final CurrentViewPngPublisher currentViewPngPublisher;
  final CurrentViewPngCapturer currentViewPngCapturer;
  final CurrentViewPngClipboardWriter currentViewPngClipboardWriter;
  final CrossBoardClipboard? crossBoardClipboard;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;
  final CrossBoardImageSnapshotCapturer crossBoardImageSnapshotCapturer;

  @override
  State<CanvasExperiment> createState() => _CanvasExperimentState();
}

class _CanvasExperimentState extends State<CanvasExperiment>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _canvasWidth = 6000.0;
  static const _canvasHeight = 4500.0;
  static const _noteWidth = 260.0;
  static const _noteHeight = 170.0;
  static const _minimumNoteWidth = 180.0;
  static const _minimumNoteHeight = 120.0;
  static const _maximumInitialImageWidth = 480.0;
  static const _maximumInitialImageHeight = 360.0;
  static const _largeAttachmentBytes = 100 * 1024 * 1024;
  static const _canvasDragThreshold = 6.0;
  static const _sceneTransitionDuration = Duration(milliseconds: 220);
  static const _uuid = Uuid();

  final _viewportKey = GlobalKey();
  final _currentViewExportBoundaryKey = GlobalKey();
  final _wholeBoardExportBoundaryKey = GlobalKey();
  final FocusNode _shortcutFocusNode = FocusNode();
  TransformationController _transformationController =
      TransformationController();
  bool _isPointerOverNoteBody = false;
  late final AnimationController _sceneTransitionController;
  Matrix4? _sceneTransitionStart;
  Matrix4? _sceneTransitionEnd;
  bool _sceneTransitionMarksBoardChanged = false;

  late List<Note> _notes;
  late List<Connector> _connectors;
  late List<BoardImage> _images;
  late List<Scene> _scenes;
  late List<CanvasHeading> _headings;
  late List<BoardAttachment> _attachments;
  late List<YouTubeEmbed> _youTubeEmbeds;
  late List<BoardShape> _shapes;
  late List<ShapeLayer> _shapeLayers;
  late List<BoardGroup> _groups;
  late bool _isSnappingEnabled;
  late BoardPaperTone _paperTone;
  late Set<String> _lockedObjectIds;
  List<CanvasSnapGuide> _snapGuides = const [];
  late String _activeShapeLayerId;
  String? _soloShapeLayerId;
  bool _isGroupsPanelOpen = false;
  late final AttachmentAssetStore _attachmentAssetStore;
  late String _boardId;
  late String _boardName;
  late DateTime _boardCreatedAt;
  late DateTime _boardModifiedAt;
  Set<String> _selectedNoteIds = {};
  Set<String> _selectedImageIds = {};
  String? _playingGifImageId;
  Set<String> _selectedHeadingIds = {};
  Set<String> _selectedAttachmentIds = {};
  Set<String> _selectedYouTubeEmbedIds = {};
  Set<String> _selectedGroupShapeIds = {};
  String? _selectedShapeId;
  bool _isShapesMode = false;
  BoardShapeType? _armedShapeType;
  BoardShape? _shapePreview;
  int _shapeFillColorValue = 0xFF90CAF9;
  bool _isCircleArmed = false;
  double _shapeFillOpacity = 0;
  int _shapeOutlineColorValue = 0xFF37474F;
  double _shapeOutlineWidth = 2;
  Offset? _shapePointerStart;
  BoardShape? _shapeAtGestureStart;
  DateTime? _lastShapeTapAt;
  String? _lastShapeTapId;
  _ShapeGestureMode? _shapeGestureMode;
  int? _shapeResizeHandle;
  _CanvasSnapshot? _pendingShapeStyleSnapshot;
  _CanvasSnapshot? _pendingShapeGestureSnapshot;
  String? _hoveredConnectorId;
  String? _editingNoteId;
  Set<String> _movingNoteIds = {};
  Set<String> _movingImageIds = {};
  Set<String> _movingHeadingIds = {};
  Set<String> _movingAttachmentIds = {};
  Set<String> _movingYouTubeEmbedIds = {};
  Set<String> _movingShapeIds = {};
  Offset? _movePointerStart;
  Map<String, Offset> _notePositionsAtMoveStart = {};
  Map<String, Offset> _imagePositionsAtMoveStart = {};
  Map<String, Offset> _headingPositionsAtMoveStart = {};
  Map<String, Offset> _attachmentPositionsAtMoveStart = {};
  Map<String, Offset> _youTubePositionsAtMoveStart = {};
  Map<String, Offset> _shapePositionsAtMoveStart = {};
  final List<_CanvasSnapshot> _undoStack = [];
  final List<_CanvasSnapshot> _redoStack = [];
  List<Note> _copiedNotes = const [];
  List<Connector> _copiedConnectors = const [];
  List<BoardImage> _copiedImages = const [];
  List<CanvasHeading> _copiedHeadings = const [];
  List<BoardAttachment> _copiedAttachments = const [];
  List<YouTubeEmbed> _copiedYouTubeEmbeds = const [];
  List<BoardShape> _copiedShapes = const [];
  Map<String, String> _copiedShapeLayerIds = const {};
  List<BoardGroup> _copiedGroups = const [];
  Set<String> _copiedLockedObjectIds = const {};
  BoardShape? _copiedShape;
  int _clipboardPasteCount = 0;
  String? _crossBoardClipboardSourceId;
  int _crossBoardCopyGeneration = 0;
  bool _isCrossBoardImagePasteInProgress = false;
  _CanvasSnapshot? _pendingMoveSnapshot;
  bool _moveUndoRecorded = false;
  String? _resizingNoteId;
  Offset? _resizePointerStart;
  Size? _noteSizeAtResizeStart;
  _CanvasSnapshot? _pendingResizeSnapshot;
  bool _resizeUndoRecorded = false;
  String? _resizingImageId;
  Offset? _imageResizePointerStart;
  Size? _imageSizeAtResizeStart;
  _CanvasSnapshot? _pendingImageResizeSnapshot;
  bool _imageResizeUndoRecorded = false;
  _CanvasSnapshot? _pendingTextEditSnapshot;
  String? _pendingTextEditNoteId;
  bool _textEditUndoRecorded = false;
  Timer? _autosaveTimer;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;
  bool _isClosing = false;
  bool _recoveredFromBackup = false;
  Future<void>? _pendingSave;
  Future<AppExitResponse>? _pendingExit;
  bool _isImportingImage = false;
  bool _isImportingAttachment = false;
  bool _isExportingCurrentView = false;
  bool _isExportingWholeBoard = false;
  bool _isContextMenuOpen = false;
  NoteColor _noteCreationColor = NoteColor.yellow;
  late bool _showBlankCanvasPriming;
  CanvasInitialTarget? _pendingInitialTarget;
  int _changeRevision = 0;
  int _savedRevision = 0;
  Matrix4? _walkthroughWorkingTransform;
  String? _storageError;
  int? _canvasPointer;
  _CanvasPointerMode? _canvasPointerMode;
  Offset? _canvasPointerStart;
  Offset? _canvasPointerLast;
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;

  bool get _hasUnsavedChanges => _changeRevision != _savedRevision;

  double get _renderedViewportScale => _isExportingWholeBoard
      ? 1
      : _transformationController.value.getMaxScaleOnAxis();

  int get _offBoardObjectCount =>
      _notes
          .where((value) => !_hiddenGroupMemberIds.contains(value.id))
          .where(_isOffBoardNote)
          .length +
      _images
          .where((value) => !_hiddenGroupMemberIds.contains(value.id))
          .where(_isOffBoardImage)
          .length +
      _headings
          .where((value) => !_hiddenGroupMemberIds.contains(value.id))
          .where(_isOffBoardHeading)
          .length +
      _attachments
          .where((value) => !_hiddenGroupMemberIds.contains(value.id))
          .where(_isOffBoardAttachment)
          .length +
      _youTubeEmbeds
          .where((value) => !_hiddenGroupMemberIds.contains(value.id))
          .where(_isOffBoardYouTubeEmbed)
          .length +
      _shapes
          .where((value) => !_hiddenGroupMemberIds.contains(value.id))
          .where(_isOffBoardShape)
          .length;

  Set<String> get _selectedObjectIds => {
    ..._selectedNoteIds,
    ..._selectedImageIds,
    ..._selectedHeadingIds,
    ..._selectedAttachmentIds,
    ..._selectedYouTubeEmbedIds,
  };

  Set<String> get _selectedMemberIds => {
    ..._selectedObjectIds,
    ..._selectedGroupShapeIds,
  };

  Set<String> get _hiddenGroupMemberIds => {
    for (final group in _groups)
      if (!group.isVisible) ...group.memberIds,
  };

  BoardGroup? _groupForObject(String objectId) =>
      _groups.where((group) => group.memberIds.contains(objectId)).firstOrNull;

  Set<String> _selectionUnitFor(String objectId) =>
      _groupForObject(objectId)?.memberIds.toSet() ?? {objectId};

  BoardGroup? get _exactSelectedGroup {
    final selected = _selectedMemberIds;
    return _groups
        .where(
          (group) =>
              group.memberIds.length == selected.length &&
              selected.containsAll(group.memberIds),
        )
        .firstOrNull;
  }

  bool get _canGroupSelection =>
      _selectedObjectIds.length >= 2 &&
      _selectedObjectIds.every((id) => _groupForObject(id) == null) &&
      !_selectedObjectIds.any(_hiddenGroupMemberIds.contains);

  BoardGroup? get _groupToExtend {
    final selected = _selectedMemberIds;
    final selectedGroups = _groups
        .where(
          (group) =>
              group.isVisible && group.memberIds.every(selected.contains),
        )
        .toList();
    if (selectedGroups.length != 1) return null;
    final group = selectedGroups.single;
    final additions = selected.difference(group.memberIds.toSet());
    if (additions.isEmpty ||
        additions.any((id) => _groupForObject(id) != null)) {
      return null;
    }
    return group;
  }

  List<String> get _selectedObjectIdsInBoardOrder => [
    for (final note in _notes)
      if (_selectedObjectIds.contains(note.id)) note.id,
    for (final image in _images)
      if (_selectedObjectIds.contains(image.id)) image.id,
    for (final heading in _headings)
      if (_selectedObjectIds.contains(heading.id)) heading.id,
    for (final attachment in _attachments)
      if (_selectedObjectIds.contains(attachment.id)) attachment.id,
    for (final embed in _youTubeEmbeds)
      if (_selectedObjectIds.contains(embed.id)) embed.id,
  ];

  void _replaceObjectSelection(Set<String> ids) {
    _selectedNoteIds = {
      for (final note in _notes)
        if (ids.contains(note.id)) note.id,
    };
    _selectedImageIds = {
      for (final image in _images)
        if (ids.contains(image.id)) image.id,
    };
    _selectedHeadingIds = {
      for (final heading in _headings)
        if (ids.contains(heading.id)) heading.id,
    };
    _selectedAttachmentIds = {
      for (final attachment in _attachments)
        if (ids.contains(attachment.id)) attachment.id,
    };
    _selectedYouTubeEmbedIds = {
      for (final embed in _youTubeEmbeds)
        if (ids.contains(embed.id)) embed.id,
    };
    _selectedGroupShapeIds = {
      for (final shape in _shapes)
        if (ids.contains(shape.id)) shape.id,
    };
  }

  void _selectObjectOrGroup(String objectId, {required bool additive}) {
    final unit = _selectionUnitFor(objectId);
    final next = Set<String>.of(_selectedMemberIds);
    if (additive) {
      if (next.containsAll(unit)) {
        next.removeAll(unit);
      } else {
        next.addAll(unit);
      }
    } else {
      next
        ..clear()
        ..addAll(unit);
    }
    _replaceObjectSelection(next);
  }

  void _selectGroup(BoardGroup group) {
    _finishTextEditing();
    setState(() {
      _isShapesMode = false;
      _selectedShapeId = null;
      _replaceObjectSelection(group.memberIds.toSet());
      _editingNoteId = null;
    });
  }

  void _groupSelection() {
    if (!_canGroupSelection) return;
    _finishTextEditing();
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _groups = [
        ..._groups,
        BoardGroup(
          id: _uuid.v4(),
          memberIds: _selectedObjectIds,
          isVisible: true,
          createdAt: now,
          modifiedAt: now,
        ),
      ];
      _isGroupsPanelOpen = true;
      _isShapesMode = false;
    });
    _markBoardChanged();
  }

  void _ungroup([BoardGroup? target]) {
    final group = target ?? _exactSelectedGroup;
    if (group == null) return;
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _groups = _groups.where((candidate) => candidate.id != group.id).toList();
      _replaceObjectSelection(group.memberIds.toSet());
    });
    _markBoardChanged();
  }

  void _addSelectionToGroup() {
    final group = _groupToExtend;
    if (group == null) return;
    final existing = group.memberIds.toSet();
    final additions = _selectedObjectIdsInBoardOrder.where(
      (id) => !existing.contains(id),
    );
    final updated = group.copyWith(
      memberIds: [...group.memberIds, ...additions],
      modifiedAt: DateTime.now().toUtc(),
    );
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _groups = [
        for (final candidate in _groups)
          candidate.id == group.id ? updated : candidate,
      ];
      _replaceObjectSelection(updated.memberIds.toSet());
    });
    _markBoardChanged();
  }

  void _removeObjectFromGroup(String objectId) {
    final group = _groupForObject(objectId);
    if (group == null || !group.isVisible) return;
    final remaining = group.memberIds.where((id) => id != objectId).toList();
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _groups = [
        for (final candidate in _groups)
          if (candidate.id != group.id)
            candidate
          else if (remaining.length >= 2)
            candidate.copyWith(
              memberIds: remaining,
              modifiedAt: DateTime.now().toUtc(),
            ),
      ];
      _replaceObjectSelection({objectId});
    });
    _markBoardChanged();
  }

  Future<void> _addSelectedShapeToGroup() async {
    final shape = _selectedShape;
    if (shape == null || _groupForObject(shape.id) != null) return;
    final availableGroups = _groups.where((group) => group.isVisible).toList();
    if (availableGroups.isEmpty) return;
    final groupId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add Shape to group'),
        children: [
          for (final indexed in availableGroups.indexed)
            SimpleDialogOption(
              key: ValueKey('shape-group-choice-${indexed.$2.id}'),
              onPressed: () => Navigator.of(context).pop(indexed.$2.id),
              child: Text(indexed.$2.name ?? 'Group ${indexed.$1 + 1}'),
            ),
        ],
      ),
    );
    if (!mounted || groupId == null) return;
    final currentShape = _selectedShape;
    final group = _groups
        .where((candidate) => candidate.id == groupId && candidate.isVisible)
        .firstOrNull;
    if (currentShape == null ||
        group == null ||
        _groupForObject(currentShape.id) != null) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    final updated = group.copyWith(
      memberIds: [...group.memberIds, currentShape.id],
      modifiedAt: DateTime.now().toUtc(),
    );
    setState(() {
      _groups = [
        for (final candidate in _groups)
          candidate.id == group.id ? updated : candidate,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Shape added. Open Groups, select the group, and drag its centre handle to move together.',
        ),
      ),
    );
    _markBoardChanged();
  }

  void _removeSelectedShapeFromGroup() {
    final shape = _selectedShape;
    if (shape == null) return;
    _removeObjectFromGroup(shape.id);
    setState(() {
      _selectedShapeId = shape.id;
      _selectedGroupShapeIds = {};
    });
  }

  Future<void> _renameGroup(BoardGroup group) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    var draftName = group.name ?? '';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextFormField(
          key: const ValueKey('group-name-field'),
          initialValue: draftName,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (value) => draftName = value,
          onFieldSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop();
              _setGroupName(group, name);
            }
          },
        ),
        actions: [
          if (group.name != null)
            TextButton(
              key: const ValueKey('group-use-automatic-name-button'),
              onPressed: () {
                Navigator.of(context).pop();
                _setGroupName(group, null);
              },
              child: const Text('Use automatic name'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('save-group-name-button'),
            onPressed: () {
              final name = draftName.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop();
                _setGroupName(group, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _setGroupName(BoardGroup group, String? name) {
    if (!mounted) return;
    final current = _groups.where((value) => value.id == group.id).firstOrNull;
    if (current == null || current.name == name) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _groups = [
        for (final candidate in _groups)
          candidate.id == group.id
              ? candidate.copyWith(
                  name: name,
                  clearName: name == null,
                  modifiedAt: DateTime.now().toUtc(),
                )
              : candidate,
      ];
    });
    _markBoardChanged();
  }

  void _toggleGroupVisibility(BoardGroup group) {
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _groups = [
        for (final candidate in _groups)
          candidate.id == group.id
              ? candidate.copyWith(
                  isVisible: !candidate.isVisible,
                  modifiedAt: now,
                )
              : candidate,
      ];
      if (group.isVisible) {
        if (group.memberIds.contains(_playingGifImageId)) {
          _playingGifImageId = null;
        }
        final selected = Set<String>.of(_selectedObjectIds)
          ..removeAll(group.memberIds);
        _replaceObjectSelection(selected);
      } else {
        _replaceObjectSelection(group.memberIds.toSet());
      }
    });
    _markBoardChanged();
  }

  void _toggleGifPlayback(String imageId) {
    setState(() {
      _playingGifImageId = _playingGifImageId == imageId ? null : imageId;
    });
  }

  void _toggleGroupsPanel() {
    setState(() {
      _isGroupsPanelOpen = !_isGroupsPanelOpen;
      if (_isGroupsPanelOpen) {
        _isShapesMode = false;
        _selectedShapeId = null;
        _selectedGroupShapeIds = {};
      }
    });
  }

  void _togglePositionLock(String objectId) {
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      if (!_lockedObjectIds.remove(objectId)) {
        _lockedObjectIds.add(objectId);
      }
    });
    _markBoardChanged();
  }

  void _toggleSnapping() {
    _endMoving();
    setState(() => _isSnappingEnabled = !_isSnappingEnabled);
    _markBoardChanged();
  }

  void _setPaperTone(BoardPaperTone tone) {
    if (_paperTone == tone) return;
    _endMoving();
    setState(() => _paperTone = tone);
    _markBoardChanged();
  }

  Widget? _websiteMarkerFor(Note note) {
    final websiteUrls = NoteLinkResolver.resolveAll(note.text);
    if (websiteUrls.isEmpty) {
      return null;
    }
    if (websiteUrls.length > 1) {
      return NoteMultiWebsiteMarker(
        key: ValueKey('note-multi-website-marker-${note.id}'),
        linkCount: websiteUrls.length,
      );
    }
    final websiteUrl = websiteUrls.single;
    return KeyedSubtree(
      key: ValueKey('note-website-marker-${note.id}'),
      child: (widget.websiteIconBuilder ?? buildNoteWebsiteMarker)(websiteUrl),
    );
  }

  int? _multiWebsiteLinkCountFor(Note note) {
    final count = NoteLinkResolver.resolveAll(note.text).length;
    return count > 1 ? count : null;
  }

  String get _copySelectionLabel => _selectedObjectIds.length == 1
      ? 'Copy selected object'
      : 'Copy selected objects';

  bool get _hasLocalClipboardObjects =>
      _copiedNotes.isNotEmpty ||
      _copiedImages.isNotEmpty ||
      _copiedHeadings.isNotEmpty ||
      _copiedAttachments.isNotEmpty ||
      _copiedYouTubeEmbeds.isNotEmpty ||
      _copiedShapes.isNotEmpty;

  CrossBoardClipboardPayload? get _availableCrossBoardClipboard {
    final payload = widget.crossBoardClipboard?.payload;
    if (payload == null || payload.sourceBoardId == _boardId) {
      return null;
    }
    return payload;
  }

  void _clearCrossBoardClipboardWithFeedback() {
    final clipboard = widget.crossBoardClipboard;
    if (clipboard == null) return;
    clipboard.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Copied for this Board only. Shapes cannot yet be pasted into another Board.',
          ),
        ),
      );
  }

  String get _noteColorSelectionLabel {
    if (_selectedNoteIds.length == 1) {
      return _selectedImageIds.isEmpty
          ? 'Change note colour'
          : "Change selected note's colour";
    }
    return "Change selected notes' colour";
  }

  String get _connectionSelectionLabel => _selectedPairConnector == null
      ? 'Connect selected objects'
      : 'Remove connection';

  String get _connectionLabelSelectionLabel =>
      _selectedPairConnector?.label == null
      ? 'Add connection label...'
      : 'Edit connection label...';

  Map<String, Rect> get _objectBounds => {
    for (final note in _notes)
      note.id: Rect.fromLTWH(note.x, note.y, note.width, note.height),
    for (final image in _images)
      image.id: Rect.fromLTWH(image.x, image.y, image.width, image.height),
    for (final heading in _headings)
      heading.id: CanvasHeadingGeometry.boundsFor(heading),
    for (final attachment in _attachments)
      attachment.id: Rect.fromLTWH(
        attachment.x,
        attachment.y,
        attachment.width,
        attachment.height,
      ),
    for (final embed in _youTubeEmbeds)
      embed.id: Rect.fromLTWH(embed.x, embed.y, embed.width, embed.height),
  };

  Map<String, Rect> get _visibleObjectBounds => {
    for (final entry in _objectBounds.entries)
      if (!_hiddenGroupMemberIds.contains(entry.key)) entry.key: entry.value,
  };

  Map<String, Rect> get _shapeBounds => {
    for (final shape in _shapes)
      shape.id: Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height),
  };

  Set<String> get _currentlyVisibleShapeIds => {
    for (final layer in _shapeLayers)
      if (layer.isVisible &&
          (_soloShapeLayerId == null || layer.id == _soloShapeLayerId))
        for (final shapeId in layer.shapeIds)
          if (!_hiddenGroupMemberIds.contains(shapeId)) shapeId,
  };

  Map<String, Rect> get _visibleMemberBounds => {
    ..._visibleObjectBounds,
    for (final entry in _shapeBounds.entries)
      if (_currentlyVisibleShapeIds.contains(entry.key)) entry.key: entry.value,
  };

  bool _groupHasUnavailableShapeMember(BoardGroup group) {
    final shapeIds = {for (final shape in _shapes) shape.id};
    return group.memberIds.any(
      (id) => shapeIds.contains(id) && !_currentlyVisibleShapeIds.contains(id),
    );
  }

  Set<String> get _movementBlockedGroupIds => {
    for (final group in _groups)
      if (group.isVisible && _groupHasUnavailableShapeMember(group)) group.id,
  };

  List<Note> get _visibleNotes => [
    for (final note in _notes)
      if (!_hiddenGroupMemberIds.contains(note.id)) note,
  ];

  List<Connector> get _visibleConnectors => [
    for (final connector in _connectors)
      if (!_hiddenGroupMemberIds.contains(connector.objectAId) &&
          !_hiddenGroupMemberIds.contains(connector.objectBId))
        connector,
  ];

  Rect? get _selectedGroupBounds {
    final group = _exactSelectedGroup;
    if (group == null || !group.isVisible) return null;
    final bounds = group.memberIds
        .map((id) => _visibleMemberBounds[id])
        .whereType<Rect>()
        .toList();
    if (bounds.isEmpty) return null;
    var result = bounds.first;
    for (final value in bounds.skip(1)) {
      result = result.expandToInclude(value);
    }
    return result.inflate(10);
  }

  bool get _canMoveSelectedGroup {
    final group = _exactSelectedGroup;
    return group != null &&
        group.isVisible &&
        !_groupHasUnavailableShapeMember(group);
  }

  Rect? get _marqueeRect {
    final start = _marqueeStart;
    final current = _marqueeCurrent;
    if (start == null || current == null) {
      return null;
    }
    return Rect.fromPoints(start, current);
  }

  Connector? get _selectedPairConnector {
    final selectedObjectIds = _selectedObjectIds;
    if (selectedObjectIds.length != 2) {
      return null;
    }
    for (final connector in _connectors) {
      if (selectedObjectIds.contains(connector.objectAId) &&
          selectedObjectIds.contains(connector.objectBId)) {
        return connector;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _attachmentAssetStore =
        widget.attachmentAssetStore ?? FileAttachmentAssetStore();
    WidgetsBinding.instance.addObserver(this);
    _sceneTransitionController =
        AnimationController(vsync: this, duration: _sceneTransitionDuration)
          ..addListener(_advanceSceneTransition)
          ..addStatusListener(_handleSceneTransitionStatus);
    _showBlankCanvasPriming = widget.showBlankCanvasPriming;
    _pendingInitialTarget = widget.initialTarget;
    _initializeNewBoard();
    unawaited(_loadBoard());
  }

  void _initializeNewBoard() {
    _noteCreationColor = NoteColor.yellow;
    final now = DateTime.now().toUtc();
    _boardId = _uuid.v4();
    _boardName = 'Prototype Board';
    _boardCreatedAt = now;
    _boardModifiedAt = now;
    _notes = [_newNoteAt(const Offset(320, 240))];
    _connectors = [];
    _images = [];
    _scenes = [];
    _headings = [];
    _attachments = [];
    _youTubeEmbeds = [];
    _shapes = [];
    _shapeLayers = [
      ShapeLayer.defaultForBoard(
        boardId: _boardId,
        shapeIds: const [],
        createdAt: now,
        modifiedAt: now,
      ),
    ];
    _groups = [];
    _lockedObjectIds = {};
    _isSnappingEnabled = true;
    _paperTone = BoardPaperTone.defaultTone;
    _activeShapeLayerId = _shapeLayers.single.id;
  }

  Future<void> _loadBoard() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final board = await widget.boardStore.load();
      if (!mounted) {
        return;
      }

      if (board == null) {
        setState(() {
          _isLoading = false;
          _changeRevision = 1;
        });
        _scheduleAutosave();
        return;
      }

      final zoom = board.viewportZoom.clamp(0.1, 4.0).toDouble();
      final transform = _viewportTransform(
        x: board.viewportX,
        y: board.viewportY,
        zoom: zoom,
      );
      _transformationController.dispose();
      _transformationController = TransformationController(transform);
      setState(() {
        _noteCreationColor = NoteColor.yellow;
        _boardId = board.id;
        _boardName = board.name;
        _boardCreatedAt = board.createdAt;
        _boardModifiedAt = board.modifiedAt;
        _notes = List.of(board.notes);
        _connectors = List.of(board.connectors);
        _hoveredConnectorId = null;
        _images = List.of(board.images);
        _scenes = List.of(board.scenes);
        _headings = List.of(board.headings);
        _attachments = List.of(board.attachments);
        _youTubeEmbeds = List.of(board.youTubeEmbeds);
        _shapes = List.of(board.shapes);
        _shapeLayers = List.of(board.shapeLayers);
        _groups = List.of(board.groups);
        _lockedObjectIds = Set.of(board.lockedObjectIds);
        _isSnappingEnabled = board.isSnappingEnabled;
        _paperTone = board.paperTone;
        _snapGuides = const [];
        _activeShapeLayerId = board.shapeLayers.last.id;
        _showBlankCanvasPriming =
            _showBlankCanvasPriming && _isPristineBoard(board);
        _isLoading = false;
        _storageError = null;
        _recoveredFromBackup =
            widget.boardStore is FileBoardStore &&
            (widget.boardStore as FileBoardStore).recoveredFromBackup;
      });
      for (final embed in _youTubeEmbeds.where(
        (embed) => embed.thumbnailAssetPath == null,
      )) {
        unawaited(_fetchYouTubeThumbnail(embed.id, embed.videoId));
      }
      for (final attachment in _attachments.where(
        (attachment) => attachment.previewAssetPath == null,
      )) {
        unawaited(_generateAttachmentPreview(attachment.id));
      }
      final initialTarget = _pendingInitialTarget;
      _pendingInitialTarget = null;
      if (initialTarget != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _activateInitialTarget(initialTarget);
          }
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadFailed = true;
        _storageError = 'Could not open saved board';
      });
    }
  }

  Note _newNoteAt(Offset position, {String text = ''}) {
    final now = DateTime.now().toUtc();
    final clampedPosition = _clampNotePosition(
      position,
      width: _noteWidth,
      height: _noteHeight,
    );
    return Note(
      id: _uuid.v4(),
      x: clampedPosition.dx,
      y: clampedPosition.dy,
      width: _noteWidth,
      height: _noteHeight,
      text: text,
      createdAt: now,
      modifiedAt: now,
      color: _noteCreationColor,
    );
  }

  static bool _isPristineBoard(BoardDocument board) {
    return board.notes.length == 1 &&
        board.notes.single.text.trim().isEmpty &&
        board.connectors.isEmpty &&
        board.images.isEmpty &&
        board.scenes.isEmpty &&
        board.headings.isEmpty &&
        board.attachments.isEmpty &&
        board.youTubeEmbeds.isEmpty &&
        board.shapes.isEmpty;
  }

  void _startWritingFromPriming() {
    if (_notes.length != 1) {
      _dismissBlankCanvasPriming();
      return;
    }
    final noteId = _notes.single.id;
    setState(() => _showBlankCanvasPriming = false);
    _beginEditing(noteId);
  }

  void _dismissBlankCanvasPriming() {
    if (_showBlankCanvasPriming) {
      setState(() => _showBlankCanvasPriming = false);
    }
  }

  void _markBoardChanged() {
    if (_loadFailed || _isClosing) return;
    _changeRevision++;
    _boardModifiedAt = DateTime.now().toUtc();
    if (mounted) {
      setState(() {});
    }
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (_loadFailed || _isClosing) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_saveBoard()),
    );
  }

  Future<void> _saveBoard() {
    if (_isLoading || _loadFailed) return Future<void>.value();
    if (_pendingSave != null) return _pendingSave!;
    final completion = Completer<void>();
    _pendingSave = completion.future;
    unawaited(_writePendingBoard(completion));
    return completion.future;
  }

  Future<void> _writePendingBoard(Completer<void> completion) async {
    _autosaveTimer?.cancel();
    setState(() {
      _isSaving = true;
      _storageError = null;
    });
    try {
      do {
        final revision = _changeRevision;
        await widget.boardStore.save(_currentBoardDocument());
        _savedRevision = revision;
        if (!mounted) return;
      } while (_hasUnsavedChanges);
    } catch (_) {
      if (mounted) {
        setState(() => _storageError = 'Save failed');
      }
    } finally {
      _pendingSave = null;
      if (mounted) setState(() => _isSaving = false);
      completion.complete();
    }
  }

  Future<void> _returnToLibrary() async {
    if (_loadFailed) {
      widget.onReturnToLibrary?.call();
      return;
    }
    _finishTextEditing();
    if (_hasUnsavedChanges) {
      await _saveBoard();
    }
    if (mounted && _storageError == null && !_hasUnsavedChanges) {
      widget.onReturnToLibrary?.call();
    }
  }

  Future<void> _showRenameBoardDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => BoardNameDialog(initialName: _boardName),
    );
    if (name != null && name != _boardName && mounted) {
      _boardName = name;
      _markBoardChanged();
    }
    _restoreShortcutFocus();
  }

  BoardDocument _currentBoardDocument() {
    final viewportTransform =
        _walkthroughWorkingTransform ?? _transformationController.value;
    final zoom = viewportTransform.getMaxScaleOnAxis();
    final viewportOrigin = MatrixUtils.transformPoint(
      Matrix4.inverted(viewportTransform),
      Offset.zero,
    );
    return BoardDocument(
      id: _boardId,
      name: _boardName,
      createdAt: _boardCreatedAt,
      modifiedAt: _boardModifiedAt,
      viewportX: viewportOrigin.dx,
      viewportY: viewportOrigin.dy,
      viewportZoom: zoom,
      notes: List.unmodifiable(_notes),
      connectors: List.unmodifiable(_connectors),
      images: List.unmodifiable(_images),
      scenes: List.unmodifiable(_scenes),
      headings: List.unmodifiable(_headings),
      attachments: List.unmodifiable(_attachments),
      youTubeEmbeds: List.unmodifiable(_youTubeEmbeds),
      shapes: List.unmodifiable(_shapes),
      shapeLayers: List.unmodifiable(_shapeLayers),
      groups: List.unmodifiable(_groups),
      isSnappingEnabled: _isSnappingEnabled,
      paperTone: _paperTone,
      lockedObjectIds: _lockedObjectIds,
    );
  }

  String get _saveStatus {
    if (_isLoading) {
      return 'Loading…';
    }
    if (_storageError != null) {
      return _storageError!;
    }
    if (_isSaving) {
      return 'Saving…';
    }
    if (_hasUnsavedChanges) {
      return 'Unsaved';
    }
    return 'Saved';
  }

  Matrix4 _viewportTransform({
    required double x,
    required double y,
    required double zoom,
  }) {
    return Matrix4.diagonal3Values(zoom, zoom, zoom)
      ..setTranslationRaw(-x * zoom, -y * zoom, 0);
  }

  @override
  Future<AppExitResponse> didRequestAppExit() {
    if (_pendingExit != null) return _pendingExit!;
    final result = _prepareToExit();
    _pendingExit = result;
    return result.whenComplete(() => _pendingExit = null);
  }

  Future<AppExitResponse> _prepareToExit() async {
    if (_loadFailed || _isLoading) return AppExitResponse.exit;
    if (_isImportingImage ||
        _isImportingAttachment ||
        _isCrossBoardImagePasteInProgress ||
        _isExportingCurrentView ||
        _isExportingWholeBoard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wait for the current operation to finish, then close Vasmim.',
          ),
        ),
      );
      return AppExitResponse.cancel;
    }
    _finishTextEditing();
    setState(() => _isClosing = true);
    if (_hasUnsavedChanges || _pendingSave != null) await _saveBoard();
    if (!mounted) return AppExitResponse.cancel;
    if (_hasUnsavedChanges || _storageError != null) {
      setState(() => _isClosing = false);
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Your latest changes have not been saved'),
          content: const Text(
            'Vasmim will stay open. Check free disk space and '
            'folder access, then retry saving before closing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep open'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retry save'),
            ),
          ],
        ),
      );
      if (retry == true && mounted) return _prepareToExit();
      return AppExitResponse.cancel;
    }
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasUnsavedChanges &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(_saveBoard());
    }
  }

  void _createNote() {
    final renderBox = _viewportKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) {
      return;
    }

    final viewportCenter = renderBox.size.center(Offset.zero);
    final canvasCenter = _transformationController.toScene(viewportCenter);
    _createNoteAtCanvasCenter(canvasCenter);
  }

  void _createNoteAtCanvasCenter(
    Offset canvasCenter, {
    String text = '',
    bool importMarkdown = false,
  }) {
    final imported =
        importMarkdown && NoteMarkdownImport.looksLikeMarkdown(text)
        ? NoteMarkdownImport.parse(text)
        : null;
    final note = _newNoteAt(
      canvasCenter - const Offset(_noteWidth / 2, _noteHeight / 2),
      text: imported?.text ?? text,
    ).copyWith(emphasis: imported?.emphasis, links: imported?.links);

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _notes = [..._notes, note];
      _showBlankCanvasPriming = false;
      _selectedNoteIds = {note.id};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _editingNoteId = note.id;
    });
    _prepareTextEditUndo(note.id);
    _markBoardChanged();
  }

  Future<void> _createHeadingAt(Offset canvasPoint) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _HeadingTextDialog(),
    );
    if (!mounted || text == null) {
      _restoreShortcutFocus();
      return;
    }
    final now = DateTime.now().toUtc();
    final provisional = CanvasHeading(
      id: _uuid.v4(),
      x: 0,
      y: 0,
      text: text,
      size: CanvasHeadingSize.large,
      background: CanvasHeadingBackground.transparent,
      createdAt: now,
      modifiedAt: now,
    );
    final size = CanvasHeadingGeometry.sizeFor(provisional);
    final position = _clampNotePosition(
      canvasPoint - Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );
    final heading = provisional.copyWith(x: position.dx, y: position.dy);

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _headings = [..._headings, heading];
      _showBlankCanvasPriming = false;
      _selectedNoteIds = {};
      _selectedImageIds = {};
      _selectedHeadingIds = {heading.id};
      _editingNoteId = null;
    });
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  Future<void> _editHeading(CanvasHeading heading) async {
    final edit = await showDialog<_HeadingAppearanceEdit>(
      context: context,
      builder: (context) => _HeadingAppearanceDialog(
        heading: heading,
        isPositionLocked: _lockedObjectIds.contains(heading.id),
      ),
    );
    if (!mounted || edit == null) {
      _restoreShortcutFocus();
      return;
    }
    final current = _headings
        .where((candidate) => candidate.id == heading.id)
        .firstOrNull;
    if (current == null) {
      _restoreShortcutFocus();
      return;
    }
    final size = _lockedObjectIds.contains(heading.id)
        ? current.size
        : edit.size;
    if (current.text == edit.text &&
        current.size == size &&
        current.background == edit.background) {
      _restoreShortcutFocus();
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    final updated = current.copyWith(
      text: edit.text,
      size: size,
      background: edit.background,
      modifiedAt: DateTime.now().toUtc(),
    );
    final dimensions = CanvasHeadingGeometry.sizeFor(updated);
    final position = _clampNotePosition(
      Offset(updated.x, updated.y),
      width: dimensions.width,
      height: dimensions.height,
    );
    setState(() {
      _headings = [
        for (final candidate in _headings)
          candidate.id == heading.id
              ? updated.copyWith(x: position.dx, y: position.dy)
              : candidate,
      ];
    });
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  void _changeSelectedHeadingSize(CanvasHeadingSize size) {
    if (_selectedHeadingIds.isEmpty ||
        !_headings.any(
          (heading) =>
              _selectedHeadingIds.contains(heading.id) &&
              !_lockedObjectIds.contains(heading.id) &&
              heading.size != size,
        )) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _headings = [
        for (final heading in _headings)
          if (_selectedHeadingIds.contains(heading.id) &&
              !_lockedObjectIds.contains(heading.id))
            () {
              final updated = heading.copyWith(size: size, modifiedAt: now);
              final dimensions = CanvasHeadingGeometry.sizeFor(updated);
              final position = _clampNotePosition(
                Offset(updated.x, updated.y),
                width: dimensions.width,
                height: dimensions.height,
              );
              return updated.copyWith(x: position.dx, y: position.dy);
            }()
          else
            heading,
      ];
    });
    _markBoardChanged();
  }

  void _changeSelectedHeadingBackground(CanvasHeadingBackground background) {
    if (_selectedHeadingIds.isEmpty ||
        !_headings.any(
          (heading) =>
              _selectedHeadingIds.contains(heading.id) &&
              heading.background != background,
        )) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _headings = [
        for (final heading in _headings)
          if (_selectedHeadingIds.contains(heading.id))
            heading.copyWith(background: background, modifiedAt: now)
          else
            heading,
      ];
    });
    _markBoardChanged();
  }

  Future<void> _importImage() async {
    if (_isImportingImage) {
      return;
    }
    setState(() {
      _isImportingImage = true;
    });

    try {
      final sourcePath = await widget.imagePicker();
      if (sourcePath == null) {
        return;
      }
      final managedAsset = await widget.imageAssetStore.importPath(sourcePath);
      if (managedAsset == null || !mounted) {
        return;
      }

      final renderBox = _viewportKey.currentContext?.findRenderObject();
      if (renderBox is! RenderBox) {
        return;
      }
      final viewportCenter = renderBox.size.center(Offset.zero);
      final canvasCenter = _transformationController.toScene(viewportCenter);
      _insertManagedImage(managedAsset, canvasCenter);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not import image')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingImage = false;
        });
      }
    }
  }

  void _insertManagedImage(
    ManagedImageAsset managedAsset,
    Offset canvasCenter,
  ) {
    final pixelWidth = managedAsset.pixelWidth.toDouble();
    final pixelHeight = managedAsset.pixelHeight.toDouble();
    final widthScale = _maximumInitialImageWidth / pixelWidth;
    final heightScale = _maximumInitialImageHeight / pixelHeight;
    final displayScale = widthScale < heightScale ? widthScale : heightScale;
    final displayWidth = pixelWidth * displayScale;
    final displayHeight = pixelHeight * displayScale;
    final position = _clampNotePosition(
      canvasCenter - Offset(displayWidth / 2, displayHeight / 2),
      width: displayWidth,
      height: displayHeight,
    );
    final now = DateTime.now().toUtc();
    final image = BoardImage(
      id: _uuid.v4(),
      x: position.dx,
      y: position.dy,
      width: displayWidth,
      height: displayHeight,
      assetPath: managedAsset.assetPath,
      originalFileName: managedAsset.originalFileName,
      pixelWidth: managedAsset.pixelWidth,
      pixelHeight: managedAsset.pixelHeight,
      createdAt: now,
      modifiedAt: now,
    );

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _images = [..._images, image];
      _showBlankCanvasPriming = false;
      _selectedNoteIds = {};
      _selectedImageIds = {image.id};
      _selectedHeadingIds = {};
      _editingNoteId = null;
    });
    _markBoardChanged();
  }

  Future<void> _importAttachment() async {
    if (_isImportingAttachment) return;
    setState(() => _isImportingAttachment = true);
    try {
      final candidate = await _attachmentAssetStore.inspectPath(
        await widget.attachmentPicker(),
      );
      if (candidate == null || !mounted) return;
      if (candidate.byteSize > _largeAttachmentBytes) {
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('large-attachment-dialog'),
            title: const Text('Import large attachment?'),
            content: Text(
              '${candidate.originalFileName} is '
              '${readableByteSize(candidate.byteSize)}. Vasmim will copy it '
              'into this Board, increasing exports and backups by about the '
              'same amount.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('confirm-large-attachment-button'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Import copy'),
              ),
            ],
          ),
        );
        if (approved != true || !mounted) return;
      }
      final managed = await _attachmentAssetStore.importCandidate(candidate);
      if (!mounted) return;
      final renderBox = _viewportKey.currentContext?.findRenderObject();
      if (renderBox is! RenderBox) return;
      final canvasCenter = _transformationController.toScene(
        renderBox.size.center(Offset.zero),
      );
      final position = _clampNotePosition(
        canvasCenter -
            const Offset(
              BoardAttachment.defaultWidth / 2,
              BoardAttachment.defaultHeight / 2,
            ),
        width: BoardAttachment.defaultWidth,
        height: BoardAttachment.defaultHeight,
      );
      final now = DateTime.now().toUtc();
      final attachment = BoardAttachment(
        id: _uuid.v4(),
        x: position.dx,
        y: position.dy,
        width: BoardAttachment.defaultWidth,
        height: BoardAttachment.defaultHeight,
        assetPath: managed.assetPath,
        originalFileName: managed.originalFileName,
        kind: managed.kind,
        byteSize: managed.byteSize,
        createdAt: now,
        modifiedAt: now,
      );
      _finishTextEditing();
      _endMoving();
      _endResizing();
      _endResizingImage();
      _recordUndoSnapshot(_captureSnapshot());
      setState(() {
        _attachments = [..._attachments, attachment];
        _showBlankCanvasPriming = false;
        _selectedNoteIds = {};
        _selectedImageIds = {};
        _selectedHeadingIds = {};
        _selectedAttachmentIds = {attachment.id};
        _editingNoteId = null;
      });
      _markBoardChanged();
      unawaited(_generateAttachmentPreview(attachment.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not import attachment')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingAttachment = false);
      _restoreShortcutFocus();
    }
  }

  Future<void> _generateAttachmentPreview(String attachmentId) async {
    try {
      final attachment = _attachments
          .where((value) => value.id == attachmentId)
          .firstOrNull;
      if (attachment == null || attachment.previewAssetPath != null) return;
      final source = await _attachmentAssetStore.resolve(attachment.assetPath);
      final preview = await widget.attachmentPreviewGenerator.generate(
        attachment,
        source,
      );
      if (preview == null || !mounted) return;
      if (!_attachments.any((value) => value.id == attachmentId)) return;
      final managed = await widget.imageAssetStore.importBytes(
        preview.bytes,
        originalFileName: 'preview-$attachmentId${preview.extension}',
      );
      if (managed == null || !mounted) return;
      if (!_attachments.any((value) => value.id == attachmentId)) return;
      final now = DateTime.now().toUtc();
      setState(() {
        _attachments = [
          for (final value in _attachments)
            if (value.id == attachmentId)
              value.copyWith(
                previewAssetPath: managed.assetPath,
                modifiedAt: now,
              )
            else
              value,
        ];
      });
      _markBoardChanged();
    } catch (_) {
      // Preview imagery is optional; the attachment card remains usable.
    }
  }

  void _createYouTubeEmbedAt(Offset canvasPoint, YouTubeUrl url) {
    final position = _clampNotePosition(
      canvasPoint -
          const Offset(
            YouTubeEmbed.defaultWidth / 2,
            YouTubeEmbed.defaultHeight / 2,
          ),
      width: YouTubeEmbed.defaultWidth,
      height: YouTubeEmbed.defaultHeight,
    );
    final now = DateTime.now().toUtc();
    final embed = YouTubeEmbed(
      id: _uuid.v4(),
      x: position.dx,
      y: position.dy,
      width: YouTubeEmbed.defaultWidth,
      height: YouTubeEmbed.defaultHeight,
      originalUrl: url.originalUrl,
      videoId: url.videoId,
      createdAt: now,
      modifiedAt: now,
    );
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _youTubeEmbeds = [..._youTubeEmbeds, embed];
      _selectedNoteIds = {};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _selectedAttachmentIds = {};
      _selectedYouTubeEmbedIds = {embed.id};
    });
    _markBoardChanged();
    unawaited(_fetchYouTubeThumbnail(embed.id, embed.videoId));
  }

  Future<void> _fetchYouTubeThumbnail(String embedId, String videoId) async {
    try {
      final bytes = await widget.youTubeThumbnailFetcher.fetch(videoId);
      if (bytes == null || !mounted) return;
      if (!_youTubeEmbeds.any((embed) => embed.id == embedId)) return;

      final asset = await widget.imageAssetStore.importBytes(
        bytes,
        originalFileName: 'youtube-$videoId.jpg',
      );
      if (asset == null || !mounted) return;
      final index = _youTubeEmbeds.indexWhere((embed) => embed.id == embedId);
      if (index < 0) return;

      final now = DateTime.now().toUtc();
      setState(() {
        _youTubeEmbeds = [
          for (final embed in _youTubeEmbeds)
            if (embed.id == embedId)
              embed.copyWith(
                thumbnailAssetPath: asset.assetPath,
                modifiedAt: now,
              )
            else
              embed,
        ];
      });
      _markBoardChanged();
    } catch (_) {
      // A thumbnail is decorative. The usable fallback card remains intact.
    }
  }

  Future<void> _openYouTubeExternally(YouTubeEmbed embed) async {
    var opened = false;
    try {
      opened = await (widget.externalUrlLauncher ?? launchNoteLink)(
        Uri.parse(embed.originalUrl),
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open YouTube')));
    }
  }

  void _selectYouTubeEmbed(String id) {
    _finishTextEditing();
    final isAdditive = HardwareKeyboard.instance.isControlPressed;
    setState(() {
      _selectObjectOrGroup(id, additive: isAdditive);
      _editingNoteId = null;
    });
  }

  void _beginMovingYouTubeEmbed(String id, Offset pointer) {
    if (_lockedObjectIds.contains(id)) return;
    if (_groupForObject(id) != null) {
      _beginMovingGroupMember(id, pointer);
      return;
    }
    final embed = _youTubeEmbeds.where((value) => value.id == id).firstOrNull;
    if (embed == null) return;
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _selectedYouTubeEmbedIds = {id};
      _movingYouTubeEmbedIds = {id};
      _youTubePositionsAtMoveStart = {id: Offset(embed.x, embed.y)};
      _movePointerStart = pointer;
    });
  }

  void _moveYouTubeEmbed(String id, Offset pointer) {
    if (!_movingYouTubeEmbedIds.contains(id) || _movePointerStart == null) {
      return;
    }
    if (_pendingMoveSnapshot != null) {
      _moveSelection(pointer);
      return;
    }
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final delta = (pointer - _movePointerStart!) / scale;
    setState(() {
      _youTubeEmbeds = [
        for (final embed in _youTubeEmbeds)
          if (_movingYouTubeEmbedIds.contains(embed.id))
            embed.copyWith(
              x: _clampNotePosition(
                _youTubePositionsAtMoveStart[embed.id]! + delta,
                width: embed.width,
                height: embed.height,
              ).dx,
              y: _clampNotePosition(
                _youTubePositionsAtMoveStart[embed.id]! + delta,
                width: embed.width,
                height: embed.height,
              ).dy,
              modifiedAt: DateTime.now().toUtc(),
            )
          else
            embed,
      ];
    });
  }

  Future<void> _showYouTubeContextMenu(
    Offset position,
    YouTubeEmbed embed,
  ) async {
    if (!_selectedObjectIds.contains(embed.id)) {
      setState(() => _selectObjectOrGroup(embed.id, additive: false));
    }
    final command = await _presentContextMenu<_YouTubeContextCommand>(
      globalPosition: position,
      items: [
        PopupMenuItem(
          key: const ValueKey('youtube-position-lock-menu-item'),
          value: _YouTubeContextCommand.togglePositionLock,
          child: ListTile(
            leading: Icon(
              _lockedObjectIds.contains(embed.id)
                  ? Icons.lock_open_outlined
                  : Icons.lock_outline,
            ),
            title: Text(
              _lockedObjectIds.contains(embed.id)
                  ? 'Unlock position'
                  : 'Lock position',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (_canGroupSelection)
          const PopupMenuItem(
            value: _YouTubeContextCommand.group,
            child: ListTile(
              leading: Icon(Icons.folder_copy_outlined),
              title: Text('Group selection'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_groupToExtend != null)
          const PopupMenuItem(
            value: _YouTubeContextCommand.addToGroup,
            child: ListTile(
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Add to group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_groupForObject(embed.id)?.isVisible == true)
          const PopupMenuItem(
            value: _YouTubeContextCommand.removeFromGroup,
            child: ListTile(
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('Remove from group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_exactSelectedGroup != null)
          const PopupMenuItem(
            value: _YouTubeContextCommand.ungroup,
            child: ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Ungroup'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_exactSelectedGroup?.isVisible == true)
          const PopupMenuItem(
            value: _YouTubeContextCommand.hideGroup,
            child: ListTile(
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Hide group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          key: ValueKey('youtube-open-menu-item'),
          value: _YouTubeContextCommand.open,
          child: ListTile(
            leading: Icon(Icons.open_in_new),
            title: Text('Open in YouTube'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _YouTubeContextCommand.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (command == _YouTubeContextCommand.togglePositionLock) {
      _togglePositionLock(embed.id);
    }
    if (command == _YouTubeContextCommand.group) _groupSelection();
    if (command == _YouTubeContextCommand.addToGroup) _addSelectionToGroup();
    if (command == _YouTubeContextCommand.removeFromGroup) {
      _removeObjectFromGroup(embed.id);
    }
    if (command == _YouTubeContextCommand.ungroup) _ungroup();
    if (command == _YouTubeContextCommand.hideGroup) {
      _toggleGroupVisibility(_exactSelectedGroup!);
    }
    if (command == _YouTubeContextCommand.open) {
      await _openYouTubeExternally(embed);
    }
    if (command == _YouTubeContextCommand.delete) {
      if (!mounted) return;
      _recordUndoSnapshot(_captureSnapshot());
      setState(() {
        _youTubeEmbeds = _youTubeEmbeds
            .where((value) => value.id != embed.id)
            .toList();
        _lockedObjectIds.remove(embed.id);
      });
      _markBoardChanged();
    }
  }

  Future<void> _openAttachment(BoardAttachment attachment) async {
    try {
      final file = await _attachmentAssetStore.resolve(attachment.assetPath);
      if (!await file.exists() || await file.length() != attachment.byteSize) {
        throw const FormatException(
          'Managed attachment is missing or changed.',
        );
      }
      if (attachment.kind == AttachmentKind.pdf) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => PdfAttachmentViewer(
            file: file,
            fileName: attachment.originalFileName,
            onOpenExternally: () async {
              if (!await widget.attachmentLauncher.open(file) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open PDF externally'),
                  ),
                );
              }
            },
          ),
        );
        return;
      }
      if (!await widget.attachmentLauncher.open(file)) {
        throw StateError('The default application refused the attachment.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open attachment')),
        );
      }
    }
    _restoreShortcutFocus();
  }

  Future<void> _showAttachmentContextMenu({
    required Offset globalPosition,
    required BoardAttachment attachment,
  }) async {
    if (!_selectedObjectIds.contains(attachment.id)) {
      setState(() => _selectObjectOrGroup(attachment.id, additive: false));
    }
    final command = await _presentContextMenu<_AttachmentContextCommand>(
      globalPosition: globalPosition,
      items: [
        PopupMenuItem(
          key: const ValueKey('attachment-position-lock-menu-item'),
          value: _AttachmentContextCommand.togglePositionLock,
          child: ListTile(
            leading: Icon(
              _lockedObjectIds.contains(attachment.id)
                  ? Icons.lock_open_outlined
                  : Icons.lock_outline,
            ),
            title: Text(
              _lockedObjectIds.contains(attachment.id)
                  ? 'Unlock position'
                  : 'Lock position',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (_canGroupSelection)
          const PopupMenuItem(
            value: _AttachmentContextCommand.group,
            child: ListTile(
              leading: Icon(Icons.folder_copy_outlined),
              title: Text('Group selection'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_groupToExtend != null)
          const PopupMenuItem(
            value: _AttachmentContextCommand.addToGroup,
            child: ListTile(
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Add to group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_groupForObject(attachment.id)?.isVisible == true)
          const PopupMenuItem(
            value: _AttachmentContextCommand.removeFromGroup,
            child: ListTile(
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('Remove from group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_exactSelectedGroup != null)
          const PopupMenuItem(
            value: _AttachmentContextCommand.ungroup,
            child: ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Ungroup'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_exactSelectedGroup?.isVisible == true)
          const PopupMenuItem(
            value: _AttachmentContextCommand.hideGroup,
            child: ListTile(
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Hide group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          key: const ValueKey('context-open-attachment-menu-item'),
          value: _AttachmentContextCommand.open,
          child: ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(
              attachment.kind == AttachmentKind.video ||
                      attachment.kind == AttachmentKind.audio
                  ? 'Open in default player'
                  : 'Open attachment',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: ValueKey('context-copy-attachment-menu-item'),
          value: _AttachmentContextCommand.copy,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Copy attachment'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: ValueKey('context-duplicate-attachment-menu-item'),
          value: _AttachmentContextCommand.duplicate,
          child: ListTile(
            leading: Icon(Icons.control_point_duplicate_outlined),
            title: Text('Duplicate attachment'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: ValueKey('context-delete-attachment-menu-item'),
          value: _AttachmentContextCommand.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete attachment'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (!mounted || command == null) {
      _restoreShortcutFocus();
      return;
    }
    switch (command) {
      case _AttachmentContextCommand.togglePositionLock:
        _togglePositionLock(attachment.id);
      case _AttachmentContextCommand.group:
        _groupSelection();
      case _AttachmentContextCommand.addToGroup:
        _addSelectionToGroup();
      case _AttachmentContextCommand.removeFromGroup:
        _removeObjectFromGroup(attachment.id);
      case _AttachmentContextCommand.ungroup:
        _ungroup();
      case _AttachmentContextCommand.hideGroup:
        _toggleGroupVisibility(_exactSelectedGroup!);
      case _AttachmentContextCommand.open:
        await _openAttachment(attachment);
      case _AttachmentContextCommand.copy:
        _copySelection();
      case _AttachmentContextCommand.duplicate:
        _duplicateSelection();
      case _AttachmentContextCommand.delete:
        _deleteSelection();
    }
    _restoreShortcutFocus();
  }

  void _selectNote(String noteId) {
    _finishTextEditing();
    final isAdditive = HardwareKeyboard.instance.isControlPressed;
    setState(() {
      _selectObjectOrGroup(noteId, additive: isAdditive);
      _editingNoteId = null;
    });
  }

  void _beginEditing(String noteId) {
    if (_editingNoteId != noteId) {
      _finishTextEditing();
      _prepareTextEditUndo(noteId);
    }
    setState(() {
      _selectedNoteIds = {noteId};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _selectedAttachmentIds = {};
      _selectedYouTubeEmbedIds = {};
      _editingNoteId = noteId;
    });
  }

  void _endEditing(String noteId) {
    if (_editingNoteId == noteId) {
      setState(() {
        _editingNoteId = null;
        _finishTextEditing();
      });
      _restoreShortcutFocus();
    }
  }

  void _restoreShortcutFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingNoteId == null) {
        _shortcutFocusNode.requestFocus();
      }
    });
  }

  void _invokeShortcut(VoidCallback command) {
    if (_isClosing || _loadFailed) return;
    if (ModalRoute.of(context)?.isCurrent == true) {
      command();
    }
  }

  void _beginMoving(String noteId, Offset pointerPosition) {
    if (_groupForObject(noteId) != null) {
      _beginMovingGroupMember(noteId, pointerPosition);
      return;
    }
    _finishTextEditing();
    _endMoving();
    _endResizing();
    final movingNoteIds = _selectedNoteIds.contains(noteId)
        ? Set<String>.of(_selectedNoteIds)
        : <String>{noteId};
    final movingImageIds = _selectedNoteIds.contains(noteId)
        ? Set<String>.of(_selectedImageIds)
        : <String>{};
    final movingHeadingIds = _selectedNoteIds.contains(noteId)
        ? Set<String>.of(_selectedHeadingIds)
        : <String>{};
    final movingAttachmentIds = _selectedNoteIds.contains(noteId)
        ? Set<String>.of(_selectedAttachmentIds)
        : <String>{};
    setState(() {
      _selectedNoteIds = movingNoteIds;
      _selectedImageIds = movingImageIds;
      _selectedHeadingIds = movingHeadingIds;
      _selectedAttachmentIds = movingAttachmentIds;
      _editingNoteId = null;
    });
    _movingNoteIds = movingNoteIds;
    _movingImageIds = movingImageIds;
    _movingHeadingIds = movingHeadingIds;
    _movingAttachmentIds = movingAttachmentIds;
    _movePointerStart = pointerPosition;
    _notePositionsAtMoveStart = {
      for (final note in _notes)
        if (movingNoteIds.contains(note.id)) note.id: Offset(note.x, note.y),
    };
    _imagePositionsAtMoveStart = {
      for (final image in _images)
        if (movingImageIds.contains(image.id))
          image.id: Offset(image.x, image.y),
    };
    _headingPositionsAtMoveStart = {
      for (final heading in _headings)
        if (movingHeadingIds.contains(heading.id))
          heading.id: Offset(heading.x, heading.y),
    };
    _attachmentPositionsAtMoveStart = {
      for (final attachment in _attachments)
        if (movingAttachmentIds.contains(attachment.id))
          attachment.id: Offset(attachment.x, attachment.y),
    };
    _pendingMoveSnapshot = _captureSnapshot();
    _moveUndoRecorded = false;
  }

  void _moveNote(String noteId, Offset pointerPosition) {
    if (!_movingNoteIds.contains(noteId)) {
      return;
    }
    _moveSelection(pointerPosition);
  }

  void _moveSelection(Offset pointerPosition) {
    final lockedMovement = {
      ..._movingNoteIds,
      ..._movingImageIds,
      ..._movingHeadingIds,
      ..._movingAttachmentIds,
      ..._movingYouTubeEmbedIds,
    }.any(_lockedObjectIds.contains);
    if (lockedMovement) return;
    final pointerStart = _movePointerStart;
    if (pointerStart == null ||
        (_movingNoteIds.isEmpty &&
            _movingImageIds.isEmpty &&
            _movingHeadingIds.isEmpty &&
            _movingAttachmentIds.isEmpty &&
            _movingYouTubeEmbedIds.isEmpty &&
            _movingShapeIds.isEmpty)) {
      return;
    }
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final desiredDelta = (pointerPosition - pointerStart) / scale;
    var minimumDx = double.negativeInfinity;
    var minimumDy = double.negativeInfinity;
    var maximumDx = double.infinity;
    var maximumDy = double.infinity;
    Rect? movingBounds;

    void includeBounds(Offset start, double width, double height) {
      final bounds = Rect.fromLTWH(start.dx, start.dy, width, height);
      movingBounds = movingBounds == null
          ? bounds
          : movingBounds!.expandToInclude(bounds);
      minimumDx = minimumDx > -start.dx ? minimumDx : -start.dx;
      minimumDy = minimumDy > -start.dy ? minimumDy : -start.dy;
      final objectMaximumDx = _canvasWidth - start.dx - width;
      final objectMaximumDy = _canvasHeight - start.dy - height;
      maximumDx = maximumDx < objectMaximumDx ? maximumDx : objectMaximumDx;
      maximumDy = maximumDy < objectMaximumDy ? maximumDy : objectMaximumDy;
    }

    for (final note in _notes) {
      if (_movingNoteIds.contains(note.id)) {
        includeBounds(
          _notePositionsAtMoveStart[note.id]!,
          note.width,
          note.height,
        );
      }
    }
    for (final image in _images) {
      if (_movingImageIds.contains(image.id)) {
        includeBounds(
          _imagePositionsAtMoveStart[image.id]!,
          image.width,
          image.height,
        );
      }
    }
    for (final heading in _headings) {
      if (_movingHeadingIds.contains(heading.id)) {
        final size = CanvasHeadingGeometry.sizeFor(heading);
        includeBounds(
          _headingPositionsAtMoveStart[heading.id]!,
          size.width,
          size.height,
        );
      }
    }
    for (final attachment in _attachments) {
      if (_movingAttachmentIds.contains(attachment.id)) {
        includeBounds(
          _attachmentPositionsAtMoveStart[attachment.id]!,
          attachment.width,
          attachment.height,
        );
      }
    }
    for (final embed in _youTubeEmbeds) {
      if (_movingYouTubeEmbedIds.contains(embed.id)) {
        includeBounds(
          _youTubePositionsAtMoveStart[embed.id]!,
          embed.width,
          embed.height,
        );
      }
    }
    for (final shape in _shapes) {
      if (_movingShapeIds.contains(shape.id)) {
        includeBounds(
          _shapePositionsAtMoveStart[shape.id]!,
          shape.width,
          shape.height,
        );
      }
    }

    var delta = Offset(
      desiredDelta.dx.clamp(minimumDx, maximumDx).toDouble(),
      desiredDelta.dy.clamp(minimumDy, maximumDy).toDouble(),
    );
    var guides = const <CanvasSnapGuide>[];
    if (_isSnappingEnabled && movingBounds != null) {
      final movingIds = <String>{
        ..._movingNoteIds,
        ..._movingImageIds,
        ..._movingHeadingIds,
        ..._movingAttachmentIds,
        ..._movingYouTubeEmbedIds,
        ..._movingShapeIds,
      };
      final result = CanvasSnapResolver.resolve(
        movingBounds: movingBounds!,
        desiredDelta: delta,
        peerBounds: [
          for (final entry in _visibleObjectBounds.entries)
            if (!movingIds.contains(entry.key)) entry.value,
        ],
        viewportScale: scale,
        canvasSize: const Size(_canvasWidth, _canvasHeight),
        gridSpacing: LayeredCanvasPaperPainter.minorSpacing,
      );
      delta = result.delta;
      guides = result.guides;
    }
    if (delta == Offset.zero) {
      if (!listEquals(_snapGuides, guides)) {
        setState(() => _snapGuides = guides);
      }
      return;
    }
    if (!_moveUndoRecorded) {
      _recordUndoSnapshot(_pendingMoveSnapshot!);
      _moveUndoRecorded = true;
    }
    final now = DateTime.now().toUtc();
    setState(() {
      _snapGuides = guides;
      _notes = [
        for (final note in _notes)
          if (_movingNoteIds.contains(note.id))
            note.copyWith(
              x: _notePositionsAtMoveStart[note.id]!.dx + delta.dx,
              y: _notePositionsAtMoveStart[note.id]!.dy + delta.dy,
              modifiedAt: now,
            )
          else
            note,
      ];
      _images = [
        for (final image in _images)
          if (_movingImageIds.contains(image.id))
            image.copyWith(
              x: _imagePositionsAtMoveStart[image.id]!.dx + delta.dx,
              y: _imagePositionsAtMoveStart[image.id]!.dy + delta.dy,
              modifiedAt: now,
            )
          else
            image,
      ];
      _headings = [
        for (final heading in _headings)
          if (_movingHeadingIds.contains(heading.id))
            heading.copyWith(
              x: _headingPositionsAtMoveStart[heading.id]!.dx + delta.dx,
              y: _headingPositionsAtMoveStart[heading.id]!.dy + delta.dy,
              modifiedAt: now,
            )
          else
            heading,
      ];
      _attachments = [
        for (final attachment in _attachments)
          if (_movingAttachmentIds.contains(attachment.id))
            attachment.copyWith(
              x: _attachmentPositionsAtMoveStart[attachment.id]!.dx + delta.dx,
              y: _attachmentPositionsAtMoveStart[attachment.id]!.dy + delta.dy,
              modifiedAt: now,
            )
          else
            attachment,
      ];
      _youTubeEmbeds = [
        for (final embed in _youTubeEmbeds)
          if (_movingYouTubeEmbedIds.contains(embed.id))
            embed.copyWith(
              x: _youTubePositionsAtMoveStart[embed.id]!.dx + delta.dx,
              y: _youTubePositionsAtMoveStart[embed.id]!.dy + delta.dy,
              modifiedAt: now,
            )
          else
            embed,
      ];
      _shapes = [
        for (final shape in _shapes)
          if (_movingShapeIds.contains(shape.id))
            shape.copyWith(
              x: _shapePositionsAtMoveStart[shape.id]!.dx + delta.dx,
              y: _shapePositionsAtMoveStart[shape.id]!.dy + delta.dy,
              modifiedAt: now,
            )
          else
            shape,
      ];
    });
    _markBoardChanged();
  }

  void _beginMovingGroup(String objectId, Offset pointerPosition) {
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    final group = _groupForObject(objectId);
    if (group != null && _groupHasUnavailableShapeMember(group)) return;
    final groupIds = _selectionUnitFor(objectId);
    final ids = _selectedMemberIds.containsAll(groupIds)
        ? Set<String>.of(_selectedMemberIds)
        : groupIds;
    setState(() {
      _replaceObjectSelection(ids);
      _editingNoteId = null;
    });
    _movingNoteIds = Set.of(_selectedNoteIds);
    _movingImageIds = Set.of(_selectedImageIds);
    _movingHeadingIds = Set.of(_selectedHeadingIds);
    _movingAttachmentIds = Set.of(_selectedAttachmentIds);
    _movingYouTubeEmbedIds = Set.of(_selectedYouTubeEmbedIds);
    _movingShapeIds = Set.of(_selectedGroupShapeIds);
    _movePointerStart = pointerPosition;
    _notePositionsAtMoveStart = {
      for (final note in _notes)
        if (_movingNoteIds.contains(note.id)) note.id: Offset(note.x, note.y),
    };
    _imagePositionsAtMoveStart = {
      for (final image in _images)
        if (_movingImageIds.contains(image.id))
          image.id: Offset(image.x, image.y),
    };
    _headingPositionsAtMoveStart = {
      for (final heading in _headings)
        if (_movingHeadingIds.contains(heading.id))
          heading.id: Offset(heading.x, heading.y),
    };
    _attachmentPositionsAtMoveStart = {
      for (final attachment in _attachments)
        if (_movingAttachmentIds.contains(attachment.id))
          attachment.id: Offset(attachment.x, attachment.y),
    };
    _youTubePositionsAtMoveStart = {
      for (final embed in _youTubeEmbeds)
        if (_movingYouTubeEmbedIds.contains(embed.id))
          embed.id: Offset(embed.x, embed.y),
    };
    _shapePositionsAtMoveStart = {
      for (final shape in _shapes)
        if (_movingShapeIds.contains(shape.id))
          shape.id: Offset(shape.x, shape.y),
    };
    _pendingMoveSnapshot = _captureSnapshot();
    _moveUndoRecorded = false;
  }

  void _beginMovingGroupMember(String objectId, Offset pointerPosition) {
    if (_lockedObjectIds.contains(objectId)) return;
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    setState(() => _editingNoteId = null);
    _movingNoteIds = {if (_notes.any((note) => note.id == objectId)) objectId};
    _movingImageIds = {
      if (_images.any((image) => image.id == objectId)) objectId,
    };
    _movingHeadingIds = {
      if (_headings.any((heading) => heading.id == objectId)) objectId,
    };
    _movingAttachmentIds = {
      if (_attachments.any((attachment) => attachment.id == objectId)) objectId,
    };
    _movingYouTubeEmbedIds = {
      if (_youTubeEmbeds.any((embed) => embed.id == objectId)) objectId,
    };
    _movePointerStart = pointerPosition;
    _notePositionsAtMoveStart = {
      for (final note in _notes)
        if (_movingNoteIds.contains(note.id)) note.id: Offset(note.x, note.y),
    };
    _imagePositionsAtMoveStart = {
      for (final image in _images)
        if (_movingImageIds.contains(image.id))
          image.id: Offset(image.x, image.y),
    };
    _headingPositionsAtMoveStart = {
      for (final heading in _headings)
        if (_movingHeadingIds.contains(heading.id))
          heading.id: Offset(heading.x, heading.y),
    };
    _attachmentPositionsAtMoveStart = {
      for (final attachment in _attachments)
        if (_movingAttachmentIds.contains(attachment.id))
          attachment.id: Offset(attachment.x, attachment.y),
    };
    _youTubePositionsAtMoveStart = {
      for (final embed in _youTubeEmbeds)
        if (_movingYouTubeEmbedIds.contains(embed.id))
          embed.id: Offset(embed.x, embed.y),
    };
    _pendingMoveSnapshot = _captureSnapshot();
    _moveUndoRecorded = false;
  }

  void _endMoving() {
    final hadSnapGuides = _snapGuides.isNotEmpty;
    _movingNoteIds = {};
    _movingImageIds = {};
    _movingHeadingIds = {};
    _movingAttachmentIds = {};
    _movingYouTubeEmbedIds = {};
    _movingShapeIds = {};
    _movePointerStart = null;
    _notePositionsAtMoveStart = {};
    _imagePositionsAtMoveStart = {};
    _headingPositionsAtMoveStart = {};
    _attachmentPositionsAtMoveStart = {};
    _youTubePositionsAtMoveStart = {};
    _shapePositionsAtMoveStart = {};
    _pendingMoveSnapshot = null;
    _moveUndoRecorded = false;
    _snapGuides = const [];
    if (hadSnapGuides && mounted) {
      setState(() {});
    }
  }

  void _beginResizing(String noteId, Offset pointerPosition) {
    if (_lockedObjectIds.contains(noteId)) return;
    final note = _notes.firstWhere((candidate) => candidate.id == noteId);
    _finishTextEditing();
    _endMoving();
    _endResizing();
    setState(() {
      _selectedNoteIds = {noteId};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _editingNoteId = null;
    });
    _resizingNoteId = noteId;
    _resizePointerStart = pointerPosition;
    _noteSizeAtResizeStart = Size(note.width, note.height);
    _pendingResizeSnapshot = _captureSnapshot();
    _resizeUndoRecorded = false;
  }

  void _resizeNote(String noteId, Offset pointerPosition) {
    final pointerStart = _resizePointerStart;
    final sizeStart = _noteSizeAtResizeStart;
    if (_resizingNoteId != noteId ||
        pointerStart == null ||
        sizeStart == null) {
      return;
    }

    final note = _notes.firstWhere((candidate) => candidate.id == noteId);
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final canvasDelta = (pointerPosition - pointerStart) / scale;
    final availableWidth = _canvasWidth - note.x;
    final availableHeight = _canvasHeight - note.y;
    final maximumWidth = availableWidth < _minimumNoteWidth
        ? _minimumNoteWidth
        : availableWidth;
    final maximumHeight = availableHeight < _minimumNoteHeight
        ? _minimumNoteHeight
        : availableHeight;
    final width = (sizeStart.width + canvasDelta.dx)
        .clamp(_minimumNoteWidth, maximumWidth)
        .toDouble();
    final height = (sizeStart.height + canvasDelta.dy)
        .clamp(_minimumNoteHeight, maximumHeight)
        .toDouble();
    if (width == note.width && height == note.height) {
      return;
    }

    if (!_resizeUndoRecorded) {
      _recordUndoSnapshot(_pendingResizeSnapshot!);
      _resizeUndoRecorded = true;
    }
    _replaceNote(
      noteId,
      (current) => current.copyWith(
        width: width,
        height: height,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _endResizing() {
    _resizingNoteId = null;
    _resizePointerStart = null;
    _noteSizeAtResizeStart = null;
    _pendingResizeSnapshot = null;
    _resizeUndoRecorded = false;
  }

  void _selectImage(String imageId) {
    _finishTextEditing();
    final isAdditive = HardwareKeyboard.instance.isControlPressed;
    setState(() {
      _selectObjectOrGroup(imageId, additive: isAdditive);
      _editingNoteId = null;
    });
  }

  void _selectAttachment(String attachmentId) {
    _finishTextEditing();
    final isAdditive = HardwareKeyboard.instance.isControlPressed;
    setState(() {
      _selectObjectOrGroup(attachmentId, additive: isAdditive);
      _editingNoteId = null;
    });
  }

  void _beginMovingAttachment(String attachmentId, Offset pointerPosition) {
    if (_groupForObject(attachmentId) != null) {
      _beginMovingGroupMember(attachmentId, pointerPosition);
      return;
    }
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    final isSelected = _selectedAttachmentIds.contains(attachmentId);
    final movingNoteIds = isSelected
        ? Set<String>.of(_selectedNoteIds)
        : <String>{};
    final movingImageIds = isSelected
        ? Set<String>.of(_selectedImageIds)
        : <String>{};
    final movingHeadingIds = isSelected
        ? Set<String>.of(_selectedHeadingIds)
        : <String>{};
    final movingAttachmentIds = isSelected
        ? Set<String>.of(_selectedAttachmentIds)
        : <String>{attachmentId};
    setState(() {
      _selectedNoteIds = movingNoteIds;
      _selectedImageIds = movingImageIds;
      _selectedHeadingIds = movingHeadingIds;
      _selectedAttachmentIds = movingAttachmentIds;
      _editingNoteId = null;
    });
    _movingNoteIds = movingNoteIds;
    _movingImageIds = movingImageIds;
    _movingHeadingIds = movingHeadingIds;
    _movingAttachmentIds = movingAttachmentIds;
    _movePointerStart = pointerPosition;
    _notePositionsAtMoveStart = {
      for (final note in _notes)
        if (movingNoteIds.contains(note.id)) note.id: Offset(note.x, note.y),
    };
    _imagePositionsAtMoveStart = {
      for (final image in _images)
        if (movingImageIds.contains(image.id))
          image.id: Offset(image.x, image.y),
    };
    _headingPositionsAtMoveStart = {
      for (final heading in _headings)
        if (movingHeadingIds.contains(heading.id))
          heading.id: Offset(heading.x, heading.y),
    };
    _attachmentPositionsAtMoveStart = {
      for (final attachment in _attachments)
        if (movingAttachmentIds.contains(attachment.id))
          attachment.id: Offset(attachment.x, attachment.y),
    };
    _pendingMoveSnapshot = _captureSnapshot();
    _moveUndoRecorded = false;
  }

  void _moveAttachment(String attachmentId, Offset pointerPosition) {
    if (_movingAttachmentIds.contains(attachmentId)) {
      _moveSelection(pointerPosition);
    }
  }

  void _beginMovingImage(String imageId, Offset pointerPosition) {
    if (_groupForObject(imageId) != null) {
      _beginMovingGroupMember(imageId, pointerPosition);
      return;
    }
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    final movingImageIds = _selectedImageIds.contains(imageId)
        ? Set<String>.of(_selectedImageIds)
        : <String>{imageId};
    final movingNoteIds = _selectedImageIds.contains(imageId)
        ? Set<String>.of(_selectedNoteIds)
        : <String>{};
    final movingHeadingIds = _selectedImageIds.contains(imageId)
        ? Set<String>.of(_selectedHeadingIds)
        : <String>{};
    final movingAttachmentIds = _selectedImageIds.contains(imageId)
        ? Set<String>.of(_selectedAttachmentIds)
        : <String>{};
    setState(() {
      _selectedNoteIds = movingNoteIds;
      _selectedImageIds = movingImageIds;
      _selectedHeadingIds = movingHeadingIds;
      _selectedAttachmentIds = movingAttachmentIds;
      _editingNoteId = null;
    });
    _movingNoteIds = movingNoteIds;
    _movingImageIds = movingImageIds;
    _movingHeadingIds = movingHeadingIds;
    _movingAttachmentIds = movingAttachmentIds;
    _movePointerStart = pointerPosition;
    _notePositionsAtMoveStart = {
      for (final note in _notes)
        if (movingNoteIds.contains(note.id)) note.id: Offset(note.x, note.y),
    };
    _imagePositionsAtMoveStart = {
      for (final image in _images)
        if (movingImageIds.contains(image.id))
          image.id: Offset(image.x, image.y),
    };
    _headingPositionsAtMoveStart = {
      for (final heading in _headings)
        if (movingHeadingIds.contains(heading.id))
          heading.id: Offset(heading.x, heading.y),
    };
    _attachmentPositionsAtMoveStart = {
      for (final attachment in _attachments)
        if (movingAttachmentIds.contains(attachment.id))
          attachment.id: Offset(attachment.x, attachment.y),
    };
    _pendingMoveSnapshot = _captureSnapshot();
    _moveUndoRecorded = false;
  }

  void _moveImage(String imageId, Offset pointerPosition) {
    if (!_movingImageIds.contains(imageId)) {
      return;
    }
    _moveSelection(pointerPosition);
  }

  void _selectHeading(String headingId) {
    _finishTextEditing();
    final isAdditive = HardwareKeyboard.instance.isControlPressed;
    setState(() {
      _selectObjectOrGroup(headingId, additive: isAdditive);
      _editingNoteId = null;
    });
  }

  void _beginMovingHeading(String headingId, Offset pointerPosition) {
    if (_groupForObject(headingId) != null) {
      _beginMovingGroupMember(headingId, pointerPosition);
      return;
    }
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    final isSelected = _selectedHeadingIds.contains(headingId);
    final movingHeadingIds = isSelected
        ? Set<String>.of(_selectedHeadingIds)
        : <String>{headingId};
    final movingNoteIds = isSelected
        ? Set<String>.of(_selectedNoteIds)
        : <String>{};
    final movingImageIds = isSelected
        ? Set<String>.of(_selectedImageIds)
        : <String>{};
    final movingAttachmentIds = isSelected
        ? Set<String>.of(_selectedAttachmentIds)
        : <String>{};
    setState(() {
      _selectedNoteIds = movingNoteIds;
      _selectedImageIds = movingImageIds;
      _selectedHeadingIds = movingHeadingIds;
      _selectedAttachmentIds = movingAttachmentIds;
      _editingNoteId = null;
    });
    _movingNoteIds = movingNoteIds;
    _movingImageIds = movingImageIds;
    _movingHeadingIds = movingHeadingIds;
    _movingAttachmentIds = movingAttachmentIds;
    _movePointerStart = pointerPosition;
    _notePositionsAtMoveStart = {
      for (final note in _notes)
        if (movingNoteIds.contains(note.id)) note.id: Offset(note.x, note.y),
    };
    _imagePositionsAtMoveStart = {
      for (final image in _images)
        if (movingImageIds.contains(image.id))
          image.id: Offset(image.x, image.y),
    };
    _headingPositionsAtMoveStart = {
      for (final heading in _headings)
        if (movingHeadingIds.contains(heading.id))
          heading.id: Offset(heading.x, heading.y),
    };
    _attachmentPositionsAtMoveStart = {
      for (final attachment in _attachments)
        if (movingAttachmentIds.contains(attachment.id))
          attachment.id: Offset(attachment.x, attachment.y),
    };
    _pendingMoveSnapshot = _captureSnapshot();
    _moveUndoRecorded = false;
  }

  void _moveHeading(String headingId, Offset pointerPosition) {
    if (_movingHeadingIds.contains(headingId)) {
      _moveSelection(pointerPosition);
    }
  }

  void _endMovingImage() => _endMoving();

  void _beginResizingImage(String imageId, Offset pointerPosition) {
    if (_lockedObjectIds.contains(imageId)) return;
    final image = _images.firstWhere((candidate) => candidate.id == imageId);
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _resizingImageId = imageId;
    _imageResizePointerStart = pointerPosition;
    _imageSizeAtResizeStart = Size(image.width, image.height);
    _pendingImageResizeSnapshot = _captureSnapshot();
    _imageResizeUndoRecorded = false;
    setState(() {});
  }

  void _resizeImage(String imageId, Offset pointerPosition) {
    final pointerStart = _imageResizePointerStart;
    final sizeStart = _imageSizeAtResizeStart;
    if (_resizingImageId != imageId ||
        pointerStart == null ||
        sizeStart == null) {
      return;
    }

    final image = _images.firstWhere((candidate) => candidate.id == imageId);
    final viewportScale = _transformationController.value.getMaxScaleOnAxis();
    final delta = (pointerPosition - pointerStart) / viewportScale;
    final widthFactor = (sizeStart.width + delta.dx) / sizeStart.width;
    final heightFactor = (sizeStart.height + delta.dy) / sizeStart.height;
    final desiredFactor = (widthFactor - 1).abs() >= (heightFactor - 1).abs()
        ? widthFactor
        : heightFactor;
    final ratio = sizeStart.width / sizeStart.height;
    final availableWidth = _canvasWidth - image.x;
    final availableHeight = _canvasHeight - image.y;
    final maximumWidth = availableWidth < availableHeight * ratio
        ? availableWidth
        : availableHeight * ratio;
    final preferredMinimumWidth = 120.0 > 80.0 * ratio ? 120.0 : 80.0 * ratio;
    final minimumWidth = preferredMinimumWidth < maximumWidth
        ? preferredMinimumWidth
        : maximumWidth;
    final width = (sizeStart.width * desiredFactor)
        .clamp(minimumWidth, maximumWidth)
        .toDouble();
    final height = width / ratio;
    if (width == image.width && height == image.height) {
      return;
    }
    if (!_imageResizeUndoRecorded) {
      _recordUndoSnapshot(_pendingImageResizeSnapshot!);
      _imageResizeUndoRecorded = true;
    }
    _replaceImage(
      imageId,
      (current) => current.copyWith(
        width: width,
        height: height,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _endResizingImage() {
    final wasResizing = _resizingImageId != null;
    _resizingImageId = null;
    _imageResizePointerStart = null;
    _imageSizeAtResizeStart = null;
    _pendingImageResizeSnapshot = null;
    _imageResizeUndoRecorded = false;
    if (wasResizing && mounted) {
      setState(() {});
    }
  }

  void _updateText(String noteId, String text) {
    if (_pendingTextEditNoteId != noteId) {
      _prepareTextEditUndo(noteId);
    }
    if (!_textEditUndoRecorded) {
      _recordUndoSnapshot(_pendingTextEditSnapshot!);
      _textEditUndoRecorded = true;
    }
    if (text.trim().isNotEmpty) {
      _showBlankCanvasPriming = false;
    }
    _replaceNote(
      noteId,
      (note) => note.copyWith(
        text: text,
        emphasis: NoteEmphasis.transformEdit(
          oldText: note.text,
          newText: text,
          ranges: note.emphasis,
        ),
        links: NoteTextLinks.transformEdit(
          oldText: note.text,
          newText: text,
          ranges: note.links,
        ),
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _updateEmphasis(String noteId, List<NoteEmphasisRange> emphasis) {
    if (_pendingTextEditNoteId != noteId) {
      _prepareTextEditUndo(noteId);
    }
    final note = _notes
        .where((candidate) => candidate.id == noteId)
        .firstOrNull;
    if (note == null || listEquals(note.emphasis, emphasis)) {
      return;
    }
    if (!_textEditUndoRecorded) {
      _recordUndoSnapshot(_pendingTextEditSnapshot!);
      _textEditUndoRecorded = true;
    }
    _replaceNote(
      noteId,
      (candidate) => candidate.copyWith(
        emphasis: emphasis,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _updateLinks(String noteId, List<NoteTextLinkRange> links) {
    if (_pendingTextEditNoteId != noteId) {
      _prepareTextEditUndo(noteId);
    }
    final note = _notes
        .where((candidate) => candidate.id == noteId)
        .firstOrNull;
    if (note == null || listEquals(note.links, links)) {
      return;
    }
    if (!_textEditUndoRecorded) {
      _recordUndoSnapshot(_pendingTextEditSnapshot!);
      _textEditUndoRecorded = true;
    }
    _replaceNote(
      noteId,
      (candidate) =>
          candidate.copyWith(links: links, modifiedAt: DateTime.now().toUtc()),
    );
  }

  void _prepareTextEditUndo(String noteId) {
    _pendingTextEditSnapshot = _captureSnapshot(selectedNoteIds: {noteId});
    _pendingTextEditNoteId = noteId;
    _textEditUndoRecorded = false;
  }

  void _finishTextEditing() {
    _pendingTextEditSnapshot = null;
    _pendingTextEditNoteId = null;
    _textEditUndoRecorded = false;
  }

  void _deleteSelection() {
    if (_isShapesMode && _selectedShape != null) {
      _deleteSelectedShape();
      return;
    }
    if (_selectedNoteIds.isEmpty &&
        _selectedImageIds.isEmpty &&
        _selectedHeadingIds.isEmpty &&
        _selectedAttachmentIds.isEmpty &&
        _selectedYouTubeEmbedIds.isEmpty &&
        _selectedGroupShapeIds.isEmpty) {
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    final selectedObjectIds = Set<String>.of(_selectedObjectIds);
    for (final id in List<String>.of(selectedObjectIds)) {
      selectedObjectIds.addAll(_selectionUnitFor(id));
    }
    setState(() {
      _notes = _notes
          .where((note) => !selectedObjectIds.contains(note.id))
          .toList();
      _connectors = _connectors
          .where(
            (connector) =>
                !selectedObjectIds.contains(connector.objectAId) &&
                !selectedObjectIds.contains(connector.objectBId),
          )
          .toList();
      _images = _images
          .where((image) => !selectedObjectIds.contains(image.id))
          .toList();
      if (selectedObjectIds.contains(_playingGifImageId)) {
        _playingGifImageId = null;
      }
      _headings = _headings
          .where((heading) => !selectedObjectIds.contains(heading.id))
          .toList();
      _attachments = _attachments
          .where((attachment) => !selectedObjectIds.contains(attachment.id))
          .toList();
      _youTubeEmbeds = _youTubeEmbeds
          .where((embed) => !selectedObjectIds.contains(embed.id))
          .toList();
      _shapes = _shapes
          .where((shape) => !selectedObjectIds.contains(shape.id))
          .toList();
      _shapeLayers = [
        for (final layer in _shapeLayers)
          layer.copyWith(
            shapeIds: layer.shapeIds
                .where((id) => !selectedObjectIds.contains(id))
                .toList(),
            modifiedAt: DateTime.now().toUtc(),
          ),
      ];
      _groups = _groups
          .where((group) => !group.memberIds.any(selectedObjectIds.contains))
          .toList();
      _lockedObjectIds = _lockedObjectIds.difference(selectedObjectIds);
      _selectedNoteIds = {};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _selectedAttachmentIds = {};
      _selectedYouTubeEmbedIds = {};
      _selectedGroupShapeIds = {};
      _editingNoteId = null;
    });
    _markBoardChanged();
  }

  void _toggleSelectedConnection() {
    final selectedObjectIds = _selectedObjectIds;
    if (selectedObjectIds.length != 2) {
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    final existingConnector = _selectedPairConnector;
    setState(() {
      if (existingConnector != null) {
        _connectors = _connectors
            .where((connector) => connector.id != existingConnector.id)
            .toList();
      } else {
        final objectIds = selectedObjectIds.toList()..sort();
        final now = DateTime.now().toUtc();
        _connectors = [
          ..._connectors,
          Connector(
            id: _uuid.v4(),
            objectAId: objectIds.first,
            objectBId: objectIds.last,
            createdAt: now,
            modifiedAt: now,
          ),
        ];
      }
      _editingNoteId = null;
    });
    _markBoardChanged();
  }

  Future<void> _editSelectedConnectionLabel() async {
    final connector = _selectedPairConnector;
    if (connector == null) {
      return;
    }
    await _editConnectionLabel(connector);
  }

  Future<void> _editConnectionLabel(Connector connector) async {
    _setHoveredConnector(connector.id, false);
    final result = await showDialog<_ConnectionLabelResult>(
      context: context,
      builder: (context) =>
          _ConnectionLabelDialog(initialLabel: connector.label),
    );
    if (!mounted || result == null) {
      _restoreShortcutFocus();
      return;
    }
    final currentConnector = _connectors
        .where((candidate) => candidate.id == connector.id)
        .firstOrNull;
    if (currentConnector == null || currentConnector.label == result.label) {
      _restoreShortcutFocus();
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _connectors = [
        for (final candidate in _connectors)
          if (candidate.id == connector.id)
            candidate.copyWith(
              label: result.label,
              clearLabel: result.label == null,
              modifiedAt: now,
            )
          else
            candidate,
      ];
    });
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  Future<void> _connectSelectedObjectsWithLabel() async {
    final objectIds = _selectedObjectIds.toList()..sort();
    if (objectIds.length != 2 || _selectedPairConnector != null) {
      return;
    }
    final result = await showDialog<_ConnectionLabelResult>(
      context: context,
      builder: (context) => const _ConnectionLabelDialog(),
    );
    final label = result?.label;
    if (!mounted || label == null) {
      _restoreShortcutFocus();
      return;
    }
    final selectedObjectIds = _selectedObjectIds;
    final selectionUnchanged =
        selectedObjectIds.length == 2 &&
        objectIds.every(selectedObjectIds.contains);
    if (!selectionUnchanged || _selectedPairConnector != null) {
      _restoreShortcutFocus();
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _connectors = [
        ..._connectors,
        Connector(
          id: _uuid.v4(),
          objectAId: objectIds.first,
          objectBId: objectIds.last,
          label: label,
          createdAt: now,
          modifiedAt: now,
        ),
      ];
      _editingNoteId = null;
    });
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  void _removeConnection(Connector connector) {
    if (!_connectors.any((candidate) => candidate.id == connector.id)) {
      return;
    }
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _connectors = _connectors
          .where((candidate) => candidate.id != connector.id)
          .toList();
      if (_hoveredConnectorId == connector.id) {
        _hoveredConnectorId = null;
      }
      _editingNoteId = null;
    });
    _markBoardChanged();
  }

  void _setHoveredConnector(String connectorId, bool isHovered) {
    final nextHoveredConnectorId = isHovered
        ? connectorId
        : _hoveredConnectorId == connectorId
        ? null
        : _hoveredConnectorId;
    if (_hoveredConnectorId == nextHoveredConnectorId) {
      return;
    }
    setState(() {
      _hoveredConnectorId = nextHoveredConnectorId;
    });
  }

  void _changeSelectedNoteColor(NoteColor color) {
    if (_selectedNoteIds.isEmpty) {
      return;
    }
    _noteCreationColor = color;
    final hasChange = _notes.any(
      (note) => _selectedNoteIds.contains(note.id) && note.color != color,
    );
    if (!hasChange) {
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _notes = [
        for (final note in _notes)
          if (_selectedNoteIds.contains(note.id))
            note.copyWith(color: color, modifiedAt: now)
          else
            note,
      ];
    });
    _markBoardChanged();
  }

  void _copySelection() {
    final crossBoardCopyGeneration = ++_crossBoardCopyGeneration;
    if (_isShapesMode && _selectedShape != null) {
      setState(() {
        _copiedShape = _selectedShape;
        _copiedShapes = const [];
        _copiedShapeLayerIds = const {};
        _clipboardPasteCount = 0;
        _crossBoardClipboardSourceId = null;
      });
      _clearCrossBoardClipboardWithFeedback();
      return;
    }
    if (_selectedNoteIds.isEmpty &&
        _selectedImageIds.isEmpty &&
        _selectedHeadingIds.isEmpty &&
        _selectedAttachmentIds.isEmpty &&
        _selectedYouTubeEmbedIds.isEmpty &&
        _selectedGroupShapeIds.isEmpty) {
      return;
    }

    _finishTextEditing();
    final selectedObjectIds = Set<String>.of(_selectedMemberIds);
    for (final id in _selectedObjectIds) {
      selectedObjectIds.addAll(_selectionUnitFor(id));
    }
    final copiedNotes = [
      for (final note in _notes)
        if (selectedObjectIds.contains(note.id)) note,
    ];
    final copiedConnectors = [
      for (final connector in _connectors)
        if (selectedObjectIds.contains(connector.objectAId) &&
            selectedObjectIds.contains(connector.objectBId))
          connector,
    ];
    final copiedImages = [
      for (final image in _images)
        if (selectedObjectIds.contains(image.id)) image,
    ];
    final copiedHeadings = [
      for (final heading in _headings)
        if (selectedObjectIds.contains(heading.id)) heading,
    ];
    final copiedAttachments = [
      for (final attachment in _attachments)
        if (selectedObjectIds.contains(attachment.id)) attachment,
    ];
    final copiedYouTubeEmbeds = [
      for (final embed in _youTubeEmbeds)
        if (selectedObjectIds.contains(embed.id)) embed,
    ];
    final copiedShapes = [
      for (final shape in _shapes)
        if (selectedObjectIds.contains(shape.id)) shape,
    ];
    final copiedGroups = [
      for (final group in _groups)
        if (group.memberIds.every(selectedObjectIds.contains)) group,
    ];
    final copiedLockedObjectIds = _lockedObjectIds.intersection(
      selectedObjectIds,
    );
    setState(() {
      _copiedNotes = copiedNotes;
      _copiedConnectors = copiedConnectors;
      _copiedImages = copiedImages;
      _copiedHeadings = copiedHeadings;
      _copiedAttachments = copiedAttachments;
      _copiedYouTubeEmbeds = copiedYouTubeEmbeds;
      _copiedShapes = copiedShapes;
      _copiedShapeLayerIds = {
        for (final shape in _shapes)
          if (selectedObjectIds.contains(shape.id))
            shape.id: _shapeLayerIdFor(shape.id)!,
      };
      _copiedGroups = copiedGroups;
      _copiedLockedObjectIds = copiedLockedObjectIds;
      _copiedShape = null;
      _clipboardPasteCount = 0;
      _crossBoardClipboardSourceId = null;
    });
    final isCrossBoardEligible = copiedShapes.isEmpty;
    final crossBoardClipboard = widget.crossBoardClipboard;
    if (crossBoardClipboard == null) return;
    final isSingleImageCrossBoardEligible =
        copiedImages.length == 1 &&
        copiedNotes.isEmpty &&
        copiedConnectors.isEmpty &&
        copiedHeadings.isEmpty &&
        copiedAttachments.isEmpty &&
        copiedYouTubeEmbeds.isEmpty &&
        copiedShapes.isEmpty &&
        copiedGroups.isEmpty;
    if (isSingleImageCrossBoardEligible) {
      crossBoardClipboard.clear();
      final clipboardRevision = crossBoardClipboard.revision;
      unawaited(
        _publishCrossBoardImage(
          image: copiedImages.single,
          isLocked: copiedLockedObjectIds.contains(copiedImages.single.id),
          generation: crossBoardCopyGeneration,
          clipboardRevision: clipboardRevision,
        ),
      );
      return;
    }
    if (!isCrossBoardEligible) {
      _clearCrossBoardClipboardWithFeedback();
      return;
    }
    if (copiedImages.isNotEmpty ||
        copiedAttachments.isNotEmpty ||
        copiedYouTubeEmbeds.isNotEmpty) {
      crossBoardClipboard.clear();
      final clipboardRevision = crossBoardClipboard.revision;
      unawaited(
        _publishCrossBoardForeground(
          notes: copiedNotes,
          connectors: copiedConnectors,
          images: copiedImages,
          headings: copiedHeadings,
          attachments: copiedAttachments,
          youTubeEmbeds: copiedYouTubeEmbeds,
          groups: copiedGroups,
          lockedObjectIds: copiedLockedObjectIds,
          generation: crossBoardCopyGeneration,
          clipboardRevision: clipboardRevision,
        ),
      );
      return;
    }
    crossBoardClipboard.publish(
      CrossBoardClipboardPayload(
        sourceBoardId: _boardId,
        notes: copiedNotes,
        connectors: copiedConnectors,
        headings: copiedHeadings,
        groups: copiedGroups,
        lockedObjectIds: copiedLockedObjectIds,
      ),
    );
    final copiedObjectCount = copiedNotes.length + copiedHeadings.length;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: 440,
          content: Text(
            'Copied $copiedObjectCount ${copiedObjectCount == 1 ? 'object' : 'objects'} for this and other Boards.',
          ),
        ),
      );
  }

  Future<void> _publishCrossBoardForeground({
    required List<Note> notes,
    required List<Connector> connectors,
    required List<BoardImage> images,
    required List<CanvasHeading> headings,
    required List<BoardAttachment> attachments,
    required List<YouTubeEmbed> youTubeEmbeds,
    required List<BoardGroup> groups,
    required Set<String> lockedObjectIds,
    required int generation,
    required int clipboardRevision,
  }) async {
    CrossBoardForegroundSnapshot? snapshot;
    try {
      snapshot = await CrossBoardForegroundSnapshot.capture(
        notes: notes,
        connectors: connectors,
        images: images,
        headings: headings,
        attachments: attachments,
        youTubeEmbeds: youTubeEmbeds,
        groups: groups,
        lockedObjectIds: lockedObjectIds,
        resolveImage: widget.imageAssetStore.resolve,
        resolveAttachment: _attachmentAssetStore.resolve,
      );
      if (generation != _crossBoardCopyGeneration) {
        await snapshot.dispose();
        return;
      }
      final didPublish = widget.crossBoardClipboard?.publishIfUnchanged(
        CrossBoardClipboardPayload(
          sourceBoardId: _boardId,
          notes: const [],
          connectors: const [],
          headings: const [],
          groups: const [],
          lockedObjectIds: const {},
          foreground: snapshot,
        ),
        revision: clipboardRevision,
      );
      if (didPublish != true) {
        await snapshot.dispose();
        return;
      }
      snapshot =
          null; // The application clipboard now owns the temporary files.
      if (!mounted) return;
      final count =
          notes.length +
          images.length +
          headings.length +
          attachments.length +
          youTubeEmbeds.length;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 440,
            content: Text(
              'Copied $count ${count == 1 ? 'object' : 'objects'} for this and other Boards.',
            ),
          ),
        );
    } catch (_) {
      if (snapshot != null) await snapshot.dispose();
      if (!mounted || generation != _crossBoardCopyGeneration) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 520,
            content: Text(
              'Could not copy every managed file to other Boards. Nothing is available for cross-Board Paste.',
            ),
          ),
        );
    }
  }

  Future<void> _publishCrossBoardImage({
    required BoardImage image,
    required bool isLocked,
    required int generation,
    required int clipboardRevision,
  }) async {
    try {
      final sourceFile = await widget.imageAssetStore.resolve(image.assetPath);
      final snapshot = await widget.crossBoardImageSnapshotCapturer(
        image: image,
        sourceFile: sourceFile,
      );
      if (generation != _crossBoardCopyGeneration) return;
      final didPublish = widget.crossBoardClipboard?.publishIfUnchanged(
        CrossBoardClipboardPayload(
          sourceBoardId: _boardId,
          notes: const [],
          connectors: const [],
          headings: const [],
          groups: const [],
          lockedObjectIds: isLocked ? {image.id} : const {},
          image: snapshot,
        ),
        revision: clipboardRevision,
      );
      if (didPublish != true) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 440,
            content: Text('Copied 1 Image for this and other Boards.'),
          ),
        );
    } catch (_) {
      if (!mounted || generation != _crossBoardCopyGeneration) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 520,
            content: Text(
              'Could not copy this Image to other Boards. It remains available for Paste on this Board.',
            ),
          ),
        );
    }
  }

  void _duplicateSelection() {
    _copySelection();
    _pasteClipboard();
  }

  void _pasteClipboard() {
    if (_isShapesMode && _copiedShape != null) {
      if (!_activeShapeLayer.isVisible) return;
      final source = _copiedShape!;
      _recordUndoSnapshot(_captureSnapshot());
      final now = DateTime.now().toUtc();
      final offset = 32.0 * (_clipboardPasteCount + 1);
      final x = (source.x + offset)
          .clamp(0.0, _canvasWidth - source.width)
          .toDouble();
      final y = (source.y + offset)
          .clamp(0.0, _canvasHeight - source.height)
          .toDouble();
      final pasted = BoardShape(
        id: _uuid.v4(),
        type: source.type,
        x: x,
        y: y,
        width: source.width,
        height: source.height,
        lineStartsAtTopLeft: source.lineStartsAtTopLeft,
        lineReversed: source.lineReversed,
        routeAxis: source.routeAxis,
        spinePosition: source.spinePosition,
        fillColorValue: source.fillColorValue,
        fillOpacity: source.fillOpacity,
        outlineColorValue: source.outlineColorValue,
        outlineWidth: source.outlineWidth,
        heading: source.heading,
        createdAt: now,
        modifiedAt: now,
      );
      setState(() {
        _shapes = [..._shapes, pasted];
        _replaceShapeLayerLocally(
          _activeShapeLayer.copyWith(
            shapeIds: [..._activeShapeLayer.shapeIds, pasted.id],
            modifiedAt: now,
          ),
        );
        _selectedShapeId = pasted.id;
        _clipboardPasteCount++;
      });
      _markBoardChanged();
      return;
    }
    if (!_hasLocalClipboardObjects) {
      final payload = _availableCrossBoardClipboard;
      if (payload != null) {
        if (payload.foreground != null) {
          unawaited(_prepareCrossBoardForegroundPaste(payload));
          return;
        }
        if (payload.image != null) {
          unawaited(_prepareCrossBoardImagePaste(payload));
          return;
        }
        _copiedNotes = payload.notes;
        _copiedConnectors = payload.connectors;
        _copiedImages = const [];
        _copiedHeadings = payload.headings;
        _copiedAttachments = const [];
        _copiedYouTubeEmbeds = const [];
        _copiedShapes = const [];
        _copiedShapeLayerIds = const {};
        _copiedGroups = payload.groups;
        _copiedLockedObjectIds = payload.lockedObjectIds;
        _copiedShape = null;
        _clipboardPasteCount = 0;
        _crossBoardClipboardSourceId = payload.sourceBoardId;
      }
    }
    if (_copiedNotes.isEmpty &&
        _copiedImages.isEmpty &&
        _copiedHeadings.isEmpty &&
        _copiedAttachments.isEmpty &&
        _copiedYouTubeEmbeds.isEmpty &&
        _copiedShapes.isEmpty) {
      return;
    }

    Offset? destinationCenter;
    if (_crossBoardClipboardSourceId != null) {
      final renderBox = _viewportKey.currentContext?.findRenderObject();
      if (renderBox is! RenderBox) return;
      destinationCenter = _transformationController.toScene(
        renderBox.size.center(Offset.zero),
      );
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    final offset = _crossBoardClipboardSourceId == null
        ? 32.0 * (_clipboardPasteCount + 1)
        : 32.0 * _clipboardPasteCount;
    final pasteDelta = _pastedGroupOffset(
      offset,
      destinationCenter: destinationCenter,
    );
    final pastedNoteIds = {
      for (final source in _copiedNotes) source.id: _uuid.v4(),
    };
    final pastedImageIds = {
      for (final source in _copiedImages) source.id: _uuid.v4(),
    };
    final pastedHeadingIds = {
      for (final source in _copiedHeadings) source.id: _uuid.v4(),
    };
    final pastedAttachmentIds = {
      for (final source in _copiedAttachments) source.id: _uuid.v4(),
    };
    final pastedYouTubeIds = {
      for (final source in _copiedYouTubeEmbeds) source.id: _uuid.v4(),
    };
    final pastedShapeIds = {
      for (final source in _copiedShapes) source.id: _uuid.v4(),
    };
    final allPastedIds = {
      ...pastedNoteIds,
      ...pastedImageIds,
      ...pastedHeadingIds,
      ...pastedAttachmentIds,
      ...pastedYouTubeIds,
      ...pastedShapeIds,
    };
    final pastedObjectIds = {...pastedNoteIds, ...pastedImageIds};
    final pastedNotes = [
      for (final source in _copiedNotes)
        Note(
          id: pastedNoteIds[source.id]!,
          x: source.x + pasteDelta.dx,
          y: source.y + pasteDelta.dy,
          width: source.width,
          height: source.height,
          text: source.text,
          createdAt: now,
          modifiedAt: now,
          color: source.color,
          title: source.title,
          emphasis: source.emphasis,
          links: source.links,
        ),
    ];
    final pastedConnectors = [
      for (final source in _copiedConnectors)
        Connector(
          id: _uuid.v4(),
          objectAId: pastedObjectIds[source.objectAId]!,
          objectBId: pastedObjectIds[source.objectBId]!,
          label: source.label,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final pastedImages = [
      for (final source in _copiedImages)
        BoardImage(
          id: pastedImageIds[source.id]!,
          x: source.x + pasteDelta.dx,
          y: source.y + pasteDelta.dy,
          width: source.width,
          height: source.height,
          assetPath: source.assetPath,
          originalFileName: source.originalFileName,
          pixelWidth: source.pixelWidth,
          pixelHeight: source.pixelHeight,
          caption: source.caption,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final pastedHeadings = [
      for (final source in _copiedHeadings)
        CanvasHeading(
          id: pastedHeadingIds[source.id]!,
          x: source.x + pasteDelta.dx,
          y: source.y + pasteDelta.dy,
          text: source.text,
          size: source.size,
          background: source.background,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final pastedAttachments = [
      for (final source in _copiedAttachments)
        BoardAttachment(
          id: pastedAttachmentIds[source.id]!,
          x: source.x + pasteDelta.dx,
          y: source.y + pasteDelta.dy,
          width: source.width,
          height: source.height,
          assetPath: source.assetPath,
          originalFileName: source.originalFileName,
          kind: source.kind,
          byteSize: source.byteSize,
          previewAssetPath: source.previewAssetPath,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final pastedYouTubeEmbeds = [
      for (final source in _copiedYouTubeEmbeds)
        YouTubeEmbed(
          id: pastedYouTubeIds[source.id]!,
          x: source.x + pasteDelta.dx,
          y: source.y + pasteDelta.dy,
          width: source.width,
          height: source.height,
          originalUrl: source.originalUrl,
          videoId: source.videoId,
          thumbnailAssetPath: source.thumbnailAssetPath,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final pastedShapes = [
      for (final source in _copiedShapes)
        BoardShape(
          id: pastedShapeIds[source.id]!,
          type: source.type,
          x: source.x + pasteDelta.dx,
          y: source.y + pasteDelta.dy,
          width: source.width,
          height: source.height,
          lineStartsAtTopLeft: source.lineStartsAtTopLeft,
          lineReversed: source.lineReversed,
          routeAxis: source.routeAxis,
          spinePosition: source.spinePosition,
          fillColorValue: source.fillColorValue,
          fillOpacity: source.fillOpacity,
          outlineColorValue: source.outlineColorValue,
          outlineWidth: source.outlineWidth,
          heading: source.heading,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final preservedPastedGroups = [
      for (final source in _copiedGroups)
        BoardGroup(
          id: _uuid.v4(),
          memberIds: source.memberIds.map((id) => allPastedIds[id]!),
          isVisible: true,
          name: source.name,
          createdAt: now,
          modifiedAt: now,
        ),
    ];
    final isCrossBoardPaste = _crossBoardClipboardSourceId != null;
    final completeSourceGroup = _copiedGroups
        .where(
          (group) =>
              group.memberIds.length == allPastedIds.length &&
              group.memberIds.every(allPastedIds.containsKey),
        )
        .firstOrNull;
    final pastedGroups = isCrossBoardPaste && allPastedIds.length >= 2
        ? [
            BoardGroup(
              id: _uuid.v4(),
              memberIds: completeSourceGroup == null
                  ? allPastedIds.values
                  : completeSourceGroup.memberIds.map(
                      (id) => allPastedIds[id]!,
                    ),
              isVisible: true,
              name: completeSourceGroup?.name,
              createdAt: now,
              modifiedAt: now,
            ),
          ]
        : preservedPastedGroups;
    _clipboardPasteCount++;
    setState(() {
      _notes = [..._notes, ...pastedNotes];
      _connectors = [..._connectors, ...pastedConnectors];
      _images = [..._images, ...pastedImages];
      _headings = [..._headings, ...pastedHeadings];
      _attachments = [..._attachments, ...pastedAttachments];
      _youTubeEmbeds = [..._youTubeEmbeds, ...pastedYouTubeEmbeds];
      _shapes = [..._shapes, ...pastedShapes];
      _shapeLayers = [
        for (final layer in _shapeLayers)
          layer.copyWith(
            shapeIds: [
              ...layer.shapeIds,
              for (final source in _copiedShapes)
                if (_copiedShapeLayerIds[source.id] == layer.id)
                  pastedShapeIds[source.id]!,
            ],
            modifiedAt: now,
          ),
      ];
      _groups = [..._groups, ...pastedGroups];
      _lockedObjectIds = {
        ..._lockedObjectIds,
        for (final sourceId in _copiedLockedObjectIds) allPastedIds[sourceId]!,
      };
      _showBlankCanvasPriming = false;
      _selectedNoteIds = pastedNotes.map((note) => note.id).toSet();
      _selectedImageIds = pastedImages.map((image) => image.id).toSet();
      _selectedHeadingIds = pastedHeadings.map((heading) => heading.id).toSet();
      _selectedAttachmentIds = pastedAttachments
          .map((attachment) => attachment.id)
          .toSet();
      _selectedYouTubeEmbedIds = pastedYouTubeEmbeds
          .map((embed) => embed.id)
          .toSet();
      _selectedGroupShapeIds = pastedShapes.map((shape) => shape.id).toSet();
      _editingNoteId = null;
    });
    _markBoardChanged();
  }

  Future<void> _prepareCrossBoardForegroundPaste(
    CrossBoardClipboardPayload payload,
  ) async {
    if (_isCrossBoardImagePasteInProgress) return;
    final snapshot = payload.foreground;
    if (snapshot == null) return;
    _isCrossBoardImagePasteInProgress = true;
    final publishedFiles = <File>[];
    try {
      final imagePaths = <String, String>{};
      final imageOriginalNames = <String, String>{
        for (final image in snapshot.images)
          image.assetPath: image.originalFileName,
      };
      final requiredImagePaths = <String>{
        ...snapshot.images.map((image) => image.assetPath),
        ...snapshot.attachments
            .map((attachment) => attachment.previewAssetPath)
            .whereType<String>(),
        ...snapshot.youTubeEmbeds
            .map((embed) => embed.thumbnailAssetPath)
            .whereType<String>(),
      };
      for (final path in requiredImagePaths) {
        final name = imageOriginalNames[path] ?? path.split('/').last;
        final asset = await widget.imageAssetStore.importBytes(
          snapshot.imageBytes(path),
          originalFileName: name,
        );
        if (asset == null) {
          throw const FormatException('Image publication failed.');
        }
        imagePaths[path] = asset.assetPath;
        publishedFiles.add(
          await widget.imageAssetStore.resolve(asset.assetPath),
        );
      }
      final attachmentPaths = <String, String>{};
      for (final attachment in snapshot.attachments) {
        if (attachmentPaths.containsKey(attachment.assetPath)) continue;
        final staged = snapshot.attachmentFile(attachment.assetPath);
        final asset = await _attachmentAssetStore.importCandidate(
          AttachmentImportCandidate(
            sourcePath: staged.path,
            originalFileName: attachment.originalFileName,
            kind: attachment.kind,
            byteSize: attachment.byteSize,
          ),
        );
        attachmentPaths[attachment.assetPath] = asset.assetPath;
        publishedFiles.add(
          await _attachmentAssetStore.resolve(asset.assetPath),
        );
      }
      if (!mounted ||
          !identical(widget.crossBoardClipboard?.payload, payload)) {
        throw StateError('The clipboard changed during Paste.');
      }
      _copiedNotes = snapshot.notes;
      _copiedConnectors = snapshot.connectors;
      _copiedImages = [
        for (final source in snapshot.images)
          BoardImage(
            id: source.id,
            x: source.x,
            y: source.y,
            width: source.width,
            height: source.height,
            assetPath: imagePaths[source.assetPath]!,
            originalFileName: source.originalFileName,
            pixelWidth: source.pixelWidth,
            pixelHeight: source.pixelHeight,
            caption: source.caption,
            createdAt: source.createdAt,
            modifiedAt: source.modifiedAt,
          ),
      ];
      _copiedHeadings = snapshot.headings;
      _copiedAttachments = [
        for (final source in snapshot.attachments)
          BoardAttachment(
            id: source.id,
            x: source.x,
            y: source.y,
            width: source.width,
            height: source.height,
            assetPath: attachmentPaths[source.assetPath]!,
            originalFileName: source.originalFileName,
            kind: source.kind,
            byteSize: source.byteSize,
            previewAssetPath: source.previewAssetPath == null
                ? null
                : imagePaths[source.previewAssetPath]!,
            createdAt: source.createdAt,
            modifiedAt: source.modifiedAt,
          ),
      ];
      _copiedYouTubeEmbeds = [
        for (final source in snapshot.youTubeEmbeds)
          YouTubeEmbed(
            id: source.id,
            x: source.x,
            y: source.y,
            width: source.width,
            height: source.height,
            originalUrl: source.originalUrl,
            videoId: source.videoId,
            thumbnailAssetPath: source.thumbnailAssetPath == null
                ? null
                : imagePaths[source.thumbnailAssetPath]!,
            createdAt: source.createdAt,
            modifiedAt: source.modifiedAt,
          ),
      ];
      _copiedShapes = const [];
      _copiedShapeLayerIds = const {};
      _copiedGroups = snapshot.groups;
      _copiedLockedObjectIds = snapshot.lockedObjectIds;
      _copiedShape = null;
      _clipboardPasteCount = 0;
      _crossBoardClipboardSourceId = payload.sourceBoardId;
      _pasteClipboard();
    } catch (_) {
      for (final file in publishedFiles.reversed) {
        if (!file.isAbsolute) continue;
        try {
          if (Platform.isWindows) {
            await Process.run('attrib', ['-R', file.path]);
          }
          if (await file.exists()) await file.delete();
        } catch (_) {
          // A failed cleanup leaves an unreferenced asset, never a partial Board.
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              width: 520,
              content: Text(
                'Could not publish every copied file on this Board. Nothing was pasted; try again.',
              ),
            ),
          );
      }
    } finally {
      _isCrossBoardImagePasteInProgress = false;
    }
  }

  Future<void> _prepareCrossBoardImagePaste(
    CrossBoardClipboardPayload payload,
  ) async {
    if (_isCrossBoardImagePasteInProgress) return;
    final snapshot = payload.image;
    if (snapshot == null) return;
    _isCrossBoardImagePasteInProgress = true;
    try {
      final managedAsset = await widget.imageAssetStore.importBytes(
        snapshot.bytes,
        originalFileName: snapshot.image.originalFileName,
      );
      if (!mounted || managedAsset == null) {
        if (mounted) _showCrossBoardImagePasteFailure();
        return;
      }
      final source = snapshot.image;
      _copiedNotes = const [];
      _copiedConnectors = const [];
      _copiedImages = [
        BoardImage(
          id: source.id,
          x: source.x,
          y: source.y,
          width: source.width,
          height: source.height,
          assetPath: managedAsset.assetPath,
          originalFileName: source.originalFileName,
          pixelWidth: managedAsset.pixelWidth,
          pixelHeight: managedAsset.pixelHeight,
          caption: source.caption,
          createdAt: source.createdAt,
          modifiedAt: source.modifiedAt,
        ),
      ];
      _copiedHeadings = const [];
      _copiedAttachments = const [];
      _copiedYouTubeEmbeds = const [];
      _copiedShapes = const [];
      _copiedShapeLayerIds = const {};
      _copiedGroups = const [];
      _copiedLockedObjectIds = payload.lockedObjectIds;
      _copiedShape = null;
      _clipboardPasteCount = 0;
      _crossBoardClipboardSourceId = payload.sourceBoardId;
      _pasteClipboard();
    } catch (_) {
      if (mounted) _showCrossBoardImagePasteFailure();
    } finally {
      _isCrossBoardImagePasteInProgress = false;
    }
  }

  void _showCrossBoardImagePasteFailure() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          width: 500,
          content: Text(
            'Could not publish the copied Image on this Board. Nothing was pasted; try again.',
          ),
        ),
      );
  }

  Offset _pastedGroupOffset(double offset, {Offset? destinationCenter}) {
    final bounds = <Rect>[
      for (final note in _copiedNotes)
        Rect.fromLTWH(note.x, note.y, note.width, note.height),
      for (final image in _copiedImages)
        Rect.fromLTWH(image.x, image.y, image.width, image.height),
      for (final heading in _copiedHeadings)
        CanvasHeadingGeometry.boundsFor(heading),
      for (final attachment in _copiedAttachments)
        Rect.fromLTWH(
          attachment.x,
          attachment.y,
          attachment.width,
          attachment.height,
        ),
      for (final embed in _copiedYouTubeEmbeds)
        Rect.fromLTWH(embed.x, embed.y, embed.width, embed.height),
      for (final shape in _copiedShapes)
        Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height),
    ];
    var left = bounds.first.left;
    var top = bounds.first.top;
    var right = bounds.first.right;
    var bottom = bounds.first.bottom;
    for (final objectBounds in bounds.skip(1)) {
      left = objectBounds.left < left ? objectBounds.left : left;
      top = objectBounds.top < top ? objectBounds.top : top;
      right = objectBounds.right > right ? objectBounds.right : right;
      bottom = objectBounds.bottom > bottom ? objectBounds.bottom : bottom;
    }
    if (destinationCenter != null) {
      final sourceCenter = Offset((left + right) / 2, (top + bottom) / 2);
      final desired = destinationCenter - sourceCenter + Offset(offset, offset);
      return Offset(
        desired.dx.clamp(-left, _canvasWidth - right).toDouble(),
        desired.dy.clamp(-top, _canvasHeight - bottom).toDouble(),
      );
    }
    final forward = Offset(
      offset.clamp(-left, _canvasWidth - right).toDouble(),
      offset.clamp(-top, _canvasHeight - bottom).toDouble(),
    );
    if (forward != Offset.zero) {
      return forward;
    }
    return Offset(
      (-offset).clamp(-left, _canvasWidth - right).toDouble(),
      (-offset).clamp(-top, _canvasHeight - bottom).toDouble(),
    );
  }

  void _handleClipboardCommand(_ClipboardCommand command) {
    switch (command) {
      case _ClipboardCommand.copy:
        _copySelection();
      case _ClipboardCommand.paste:
        _pasteClipboard();
    }
  }

  RelativeRect _contextMenuPosition(
    BuildContext context,
    Offset globalPosition,
  ) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final localPosition = overlayBox.globalToLocal(globalPosition);
    return RelativeRect.fromRect(
      Rect.fromLTWH(localPosition.dx, localPosition.dy, 0, 0),
      Offset.zero & overlayBox.size,
    );
  }

  Future<T?> _presentContextMenu<T>({
    required Offset globalPosition,
    required List<PopupMenuEntry<T>> items,
  }) async {
    if (_isContextMenuOpen) {
      return null;
    }
    _isContextMenuOpen = true;
    try {
      return await showMenu<T>(
        context: context,
        position: _contextMenuPosition(context, globalPosition),
        items: items,
      );
    } finally {
      _isContextMenuOpen = false;
      _restoreShortcutFocus();
    }
  }

  Future<void> _showContextNoteColorMenu(Offset globalPosition) async {
    final color = await _presentContextMenu<NoteColor>(
      globalPosition: globalPosition,
      items: [
        for (final color in NoteColor.values)
          PopupMenuItem(
            key: ValueKey('context-note-color-${color.name}'),
            value: color,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.backgroundColor,
                    border: Border.all(color: color.borderColor),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(color.label),
              ],
            ),
          ),
      ],
    );
    if (mounted && color != null) {
      _changeSelectedNoteColor(color);
    }
  }

  Future<void> _showHeadingSizeMenu(Offset globalPosition) async {
    final size = await _presentContextMenu<CanvasHeadingSize>(
      globalPosition: globalPosition,
      items: [
        for (final size in CanvasHeadingSize.values)
          PopupMenuItem(
            key: ValueKey('context-heading-size-${size.name}'),
            value: size,
            child: Text(size.label),
          ),
      ],
    );
    if (mounted && size != null) {
      _changeSelectedHeadingSize(size);
    }
  }

  Future<void> _showHeadingBackgroundMenu(Offset globalPosition) async {
    final background = await _presentContextMenu<CanvasHeadingBackground>(
      globalPosition: globalPosition,
      items: [
        for (final background in CanvasHeadingBackground.values)
          PopupMenuItem(
            key: ValueKey('context-heading-background-${background.name}'),
            value: background,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: background.color,
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(background.label),
              ],
            ),
          ),
      ],
    );
    if (mounted && background != null) {
      _changeSelectedHeadingBackground(background);
    }
  }

  void _selectObjectForContextMenu({
    String? noteId,
    String? imageId,
    String? headingId,
  }) {
    assert([noteId, imageId, headingId].where((id) => id != null).length == 1);
    final objectId = noteId ?? imageId ?? headingId!;
    final isAlreadySelected = _selectedObjectIds.contains(objectId);
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    setState(() {
      if (!isAlreadySelected) {
        _selectObjectOrGroup(objectId, additive: false);
      }
      _editingNoteId = null;
    });
  }

  Set<String> _connectedComponentFor(String seedObjectId) {
    return connectedObjectIds(
      seedObjectId: seedObjectId,
      objectIds: {
        for (final note in _notes) note.id,
        for (final image in _images) image.id,
      },
      connectors: _connectors,
    );
  }

  void _selectConnectedObjects(String seedObjectId) {
    final component = _connectedComponentFor(seedObjectId);
    if (component.length < 2) {
      return;
    }
    final selectedIds = <String>{
      for (final id in component) ..._selectionUnitFor(id),
    };
    if (_selectedObjectIds.length == selectedIds.length &&
        _selectedObjectIds.containsAll(selectedIds)) {
      return;
    }
    setState(() {
      _replaceObjectSelection(selectedIds);
      _editingNoteId = null;
    });
  }

  Future<void> _showObjectContextMenu({
    required Offset globalPosition,
    String? noteId,
    String? imageId,
    String? headingId,
  }) async {
    if (_isContextMenuOpen) {
      return;
    }
    _selectObjectForContextMenu(
      noteId: noteId,
      imageId: imageId,
      headingId: headingId,
    );
    final contextObjectId = noteId ?? imageId ?? headingId!;
    final canSelectConnected =
        headingId == null && _connectedComponentFor(contextObjectId).length > 1;
    final noteLinks = _resolveNoteLinks(noteId);
    final contextNote = noteId == null
        ? null
        : _notes.where((note) => note.id == noteId).firstOrNull;
    final contextImage = imageId == null
        ? null
        : _images.where((image) => image.id == imageId).firstOrNull;
    final contextHeading = headingId == null
        ? null
        : _headings.where((heading) => heading.id == headingId).firstOrNull;
    final command = await _presentContextMenu(
      globalPosition: globalPosition,
      items: [
        if (contextImage?.isGif == true)
          PopupMenuItem(
            key: const ValueKey('context-gif-playback-menu-item'),
            value: _ContextMenuCommand.toggleGifPlayback,
            child: ListTile(
              leading: Icon(
                _playingGifImageId == contextImage!.id
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              title: Text(
                _playingGifImageId == contextImage.id
                    ? 'Pause GIF'
                    : 'Play GIF',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          key: const ValueKey('context-position-lock-menu-item'),
          value: _ContextMenuCommand.togglePositionLock,
          child: ListTile(
            leading: Icon(
              _lockedObjectIds.contains(contextObjectId)
                  ? Icons.lock_open_outlined
                  : Icons.lock_outline,
            ),
            title: Text(
              _lockedObjectIds.contains(contextObjectId)
                  ? 'Unlock position'
                  : 'Lock position',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (_canGroupSelection)
          const PopupMenuItem(
            key: ValueKey('context-group-menu-item'),
            value: _ContextMenuCommand.group,
            child: ListTile(
              leading: Icon(Icons.folder_copy_outlined),
              title: Text('Group selection'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_groupToExtend != null)
          const PopupMenuItem(
            key: ValueKey('context-add-to-group-menu-item'),
            value: _ContextMenuCommand.addToGroup,
            child: ListTile(
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Add to group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_groupForObject(contextObjectId)?.isVisible == true)
          const PopupMenuItem(
            key: ValueKey('context-remove-from-group-menu-item'),
            value: _ContextMenuCommand.removeFromGroup,
            child: ListTile(
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('Remove from group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_exactSelectedGroup != null)
          const PopupMenuItem(
            key: ValueKey('context-ungroup-menu-item'),
            value: _ContextMenuCommand.ungroup,
            child: ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Ungroup'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_exactSelectedGroup?.isVisible == true)
          const PopupMenuItem(
            key: ValueKey('context-hide-group-menu-item'),
            value: _ContextMenuCommand.hideGroup,
            child: ListTile(
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Hide group'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          key: const ValueKey('context-copy-menu-item'),
          value: _ContextMenuCommand.copy,
          child: ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(_copySelectionLabel),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('context-paste-menu-item'),
          value: _ContextMenuCommand.paste,
          enabled:
              _copiedNotes.isNotEmpty ||
              _copiedImages.isNotEmpty ||
              _copiedHeadings.isNotEmpty ||
              _copiedAttachments.isNotEmpty ||
              _copiedYouTubeEmbeds.isNotEmpty,
          child: const ListTile(
            leading: Icon(Icons.content_paste_outlined),
            title: Text('Paste objects'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (noteLinks.length == 1)
          const PopupMenuItem(
            key: ValueKey('context-open-link-menu-item'),
            value: _ContextMenuCommand.openLink,
            child: ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('Open link'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (noteLinks.length > 1)
          const PopupMenuItem(
            key: ValueKey('context-open-links-menu-item'),
            value: _ContextMenuCommand.openLinks,
            child: ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('Open links...'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (contextNote != null)
          PopupMenuItem(
            key: const ValueKey('context-note-title-menu-item'),
            value: _ContextMenuCommand.editNoteTitle,
            child: ListTile(
              leading: const Icon(Icons.title),
              title: Text(
                contextNote.title == null ? 'Add title...' : 'Edit title...',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (contextImage != null)
          PopupMenuItem(
            key: const ValueKey('context-image-caption-menu-item'),
            value: _ContextMenuCommand.editImageCaption,
            child: ListTile(
              leading: const Icon(Icons.closed_caption_outlined),
              title: Text(
                contextImage.caption == null
                    ? 'Add caption...'
                    : 'Edit caption...',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (contextImage?.caption != null)
          const PopupMenuItem(
            key: ValueKey('context-remove-image-caption-menu-item'),
            value: _ContextMenuCommand.removeImageCaption,
            child: ListTile(
              leading: Icon(Icons.closed_caption_off_outlined),
              title: Text('Remove caption'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (contextHeading != null)
          const PopupMenuItem(
            key: ValueKey('context-heading-edit-menu-item'),
            value: _ContextMenuCommand.editHeading,
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit heading...'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (contextHeading != null)
          PopupMenuItem(
            key: const ValueKey('context-heading-size-menu-item'),
            value: _ContextMenuCommand.changeHeadingSize,
            enabled: !_lockedObjectIds.contains(contextHeading.id),
            child: const ListTile(
              leading: Icon(Icons.format_size),
              title: Text('Heading size'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (contextHeading != null)
          const PopupMenuItem(
            key: ValueKey('context-heading-background-menu-item'),
            value: _ContextMenuCommand.changeHeadingBackground,
            child: ListTile(
              leading: Icon(Icons.format_color_fill_outlined),
              title: Text('Heading background'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          key: ValueKey('context-duplicate-menu-item'),
          value: _ContextMenuCommand.duplicate,
          child: ListTile(
            leading: Icon(Icons.control_point_duplicate_outlined),
            title: Text('Duplicate selection'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (canSelectConnected)
          const PopupMenuItem(
            key: ValueKey('context-select-connected-menu-item'),
            value: _ContextMenuCommand.selectConnected,
            child: ListTile(
              leading: Icon(Icons.hub_outlined),
              title: Text('Select connected objects'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_selectedNoteIds.isNotEmpty)
          PopupMenuItem(
            key: const ValueKey('context-note-color-menu-item'),
            value: _ContextMenuCommand.changeNoteColor,
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(_noteColorSelectionLabel),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_selectedHeadingIds.isEmpty && _selectedObjectIds.length == 2)
          PopupMenuItem(
            key: const ValueKey('context-connection-menu-item'),
            value: _ContextMenuCommand.toggleConnection,
            child: ListTile(
              leading: Icon(
                _selectedPairConnector == null
                    ? Icons.add_link
                    : Icons.link_off,
              ),
              title: Text(_connectionSelectionLabel),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_selectedHeadingIds.isEmpty &&
            _selectedObjectIds.length == 2 &&
            _selectedPairConnector == null)
          const PopupMenuItem(
            key: ValueKey('context-connect-with-label-menu-item'),
            value: _ContextMenuCommand.connectWithLabel,
            child: ListTile(
              leading: Icon(Icons.new_label_outlined),
              title: Text('Connect with label...'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_selectedPairConnector != null)
          PopupMenuItem(
            key: const ValueKey('context-connection-label-menu-item'),
            value: _ContextMenuCommand.editConnectionLabel,
            child: ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(_connectionLabelSelectionLabel),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          key: ValueKey('context-delete-menu-item'),
          value: _ContextMenuCommand.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete selection'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (!mounted || command == null) {
      return;
    }
    switch (command) {
      case _ContextMenuCommand.togglePositionLock:
        _togglePositionLock(contextObjectId);
      case _ContextMenuCommand.group:
        _groupSelection();
      case _ContextMenuCommand.addToGroup:
        _addSelectionToGroup();
      case _ContextMenuCommand.removeFromGroup:
        _removeObjectFromGroup(contextObjectId);
      case _ContextMenuCommand.ungroup:
        _ungroup();
      case _ContextMenuCommand.hideGroup:
        _toggleGroupVisibility(_exactSelectedGroup!);
      case _ContextMenuCommand.copy:
        _copySelection();
      case _ContextMenuCommand.paste:
        _pasteClipboard();
      case _ContextMenuCommand.openLink:
        await _openNoteLink(noteId!);
      case _ContextMenuCommand.openLinks:
        await _chooseNoteLink(noteId!);
      case _ContextMenuCommand.editNoteTitle:
        await _editNoteTitle(contextNote!);
      case _ContextMenuCommand.editImageCaption:
        await _editImageCaption(contextImage!);
      case _ContextMenuCommand.toggleGifPlayback:
        _toggleGifPlayback(contextImage!.id);
      case _ContextMenuCommand.removeImageCaption:
        _removeImageCaption(contextImage!);
      case _ContextMenuCommand.editHeading:
        await _editHeading(contextHeading!);
      case _ContextMenuCommand.changeHeadingSize:
        await _showHeadingSizeMenu(globalPosition);
      case _ContextMenuCommand.changeHeadingBackground:
        await _showHeadingBackgroundMenu(globalPosition);
      case _ContextMenuCommand.duplicate:
        _duplicateSelection();
      case _ContextMenuCommand.selectConnected:
        _selectConnectedObjects(contextObjectId);
      case _ContextMenuCommand.changeNoteColor:
        await _showContextNoteColorMenu(globalPosition);
      case _ContextMenuCommand.toggleConnection:
        _toggleSelectedConnection();
      case _ContextMenuCommand.connectWithLabel:
        await _connectSelectedObjectsWithLabel();
      case _ContextMenuCommand.editConnectionLabel:
        await _editSelectedConnectionLabel();
      case _ContextMenuCommand.delete:
        _deleteSelection();
    }
  }

  Future<void> _editNoteTitle(Note note) async {
    final result = await showDialog<_NoteTitleResult>(
      context: context,
      builder: (context) => _NoteTitleDialog(initialTitle: note.title),
    );
    if (!mounted || result == null) {
      _restoreShortcutFocus();
      return;
    }
    final currentNote = _notes
        .where((candidate) => candidate.id == note.id)
        .firstOrNull;
    if (currentNote == null || currentNote.title == result.title) {
      _restoreShortcutFocus();
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    _replaceNote(
      note.id,
      (candidate) => candidate.copyWith(
        title: result.title,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
    _restoreShortcutFocus();
  }

  Future<void> _editImageCaption(BoardImage image) async {
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => _ImageCaptionDialog(initialCaption: image.caption),
    );
    if (!mounted || caption == null) {
      _restoreShortcutFocus();
      return;
    }
    final currentImage = _images
        .where((candidate) => candidate.id == image.id)
        .firstOrNull;
    if (currentImage == null || currentImage.caption == caption) {
      _restoreShortcutFocus();
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    _replaceImage(
      image.id,
      (candidate) => candidate.copyWith(
        caption: caption,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
    _restoreShortcutFocus();
  }

  void _removeImageCaption(BoardImage image) {
    if (image.caption == null) {
      return;
    }
    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    _replaceImage(
      image.id,
      (candidate) =>
          candidate.copyWith(caption: null, modifiedAt: DateTime.now().toUtc()),
    );
    _restoreShortcutFocus();
  }

  List<Uri> _resolveNoteLinks(String? noteId) {
    if (noteId == null) {
      return const [];
    }
    for (final note in _notes) {
      if (note.id == noteId) {
        return NoteLinkResolver.resolveAll(note.text);
      }
    }
    return const [];
  }

  Uri? _resolveNoteLink(String? noteId) {
    final urls = _resolveNoteLinks(noteId);
    return urls.length == 1 ? urls.single : null;
  }

  Future<void> _chooseNoteLink(String noteId) async {
    final urls = _resolveNoteLinks(noteId);
    if (urls.length < 2) {
      return;
    }
    final url = await showDialog<Uri>(
      context: context,
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: Focus(
          autofocus: true,
          child: SimpleDialog(
            title: const Text('Open a link'),
            children: [
              for (var index = 0; index < urls.length; index++)
                SimpleDialogOption(
                  key: ValueKey('note-link-choice-$index'),
                  onPressed: () => Navigator.of(context).pop(urls[index]),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link),
                    title: Text(
                      urls[index].host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      urls[index].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (url != null && mounted) {
      await _launchNoteLink(url);
    } else {
      _restoreShortcutFocus();
    }
  }

  Future<void> _openNoteLink(String noteId) async {
    final url = _resolveNoteLink(noteId);
    if (url == null) {
      return;
    }

    await _launchNoteLink(url);
  }

  Future<void> _launchNoteLink(
    Uri url, {
    bool restoreShortcutFocus = true,
  }) async {
    var opened = false;
    try {
      opened = await (widget.externalUrlLauncher ?? launchNoteLink)(url);
    } catch (_) {
      opened = false;
    }
    if (!mounted) {
      return;
    }
    if (!opened) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
    if (restoreShortcutFocus) {
      _restoreShortcutFocus();
    }
  }

  Future<void> _showConnectionContextMenu({
    required Offset globalPosition,
    required Connector connector,
  }) async {
    if (_isContextMenuOpen) {
      return;
    }
    _setHoveredConnector(connector.id, false);
    final command = await _presentContextMenu(
      globalPosition: globalPosition,
      items: [
        PopupMenuItem(
          key: const ValueKey('connection-context-label-menu-item'),
          value: _ConnectionContextMenuCommand.editLabel,
          child: ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(
              connector.label == null
                  ? 'Add connection label...'
                  : 'Edit connection label...',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          key: ValueKey('connection-context-remove-menu-item'),
          value: _ConnectionContextMenuCommand.remove,
          child: ListTile(
            leading: Icon(Icons.link_off),
            title: Text('Remove connection'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (!mounted || command == null) {
      return;
    }
    final currentConnector = _connectors
        .where((candidate) => candidate.id == connector.id)
        .firstOrNull;
    if (currentConnector == null) {
      return;
    }
    switch (command) {
      case _ConnectionContextMenuCommand.editLabel:
        await _editConnectionLabel(currentConnector);
      case _ConnectionContextMenuCommand.remove:
        _removeConnection(currentConnector);
    }
  }

  Future<void> _showCanvasContextMenu(TapUpDetails details) async {
    if (_editingNoteId != null || _isExportingCurrentView) {
      return;
    }
    final clipboardResults = await Future.wait<Object?>([
      _readClipboardText(),
      _hasClipboardImage(),
    ]);
    final clipboardText = clipboardResults[0] as String?;
    final hasClipboardImage = clipboardResults[1] as bool;
    final pasteableWebsites = clipboardText == null
        ? null
        : _resolvePasteableWebsites(clipboardText);
    final pasteableWebsite = pasteableWebsites?.length == 1
        ? pasteableWebsites!.single
        : null;
    final pasteableYouTube = pasteableWebsite == null
        ? null
        : YouTubeUrl.parse(pasteableWebsite.toString());
    final pasteableWebsiteList = (pasteableWebsites?.length ?? 0) > 1
        ? pasteableWebsites
        : null;
    final pasteableText = clipboardText == null
        ? null
        : NoteLinkResolver.resolvePlainTextFallback(clipboardText);
    if (!mounted) {
      return;
    }
    final canvasPoint = _transformationController.toScene(
      details.localPosition,
    );
    final command = await _presentContextMenu<_CanvasContextMenuCommand>(
      globalPosition: details.globalPosition,
      items: [
        const PopupMenuItem(
          key: ValueKey('context-add-note-menu-item'),
          value: _CanvasContextMenuCommand.addNoteHere,
          child: ListTile(
            leading: Icon(Icons.note_add_outlined),
            title: Text('Add note here'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          key: ValueKey('context-add-heading-menu-item'),
          value: _CanvasContextMenuCommand.addHeadingHere,
          child: ListTile(
            leading: Icon(Icons.title),
            title: Text('Add heading here'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (hasClipboardImage)
          const PopupMenuItem(
            key: ValueKey('context-paste-image-menu-item'),
            value: _CanvasContextMenuCommand.pasteImageHere,
            child: ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text('Paste image here'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (pasteableYouTube != null)
          const PopupMenuItem(
            key: ValueKey('context-embed-youtube-menu-item'),
            value: _CanvasContextMenuCommand.embedYouTubeHere,
            child: ListTile(
              leading: Icon(Icons.play_circle_outline),
              title: Text('Embed YouTube here'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (pasteableWebsite != null)
          const PopupMenuItem(
            key: ValueKey('context-paste-website-menu-item'),
            value: _CanvasContextMenuCommand.pasteWebsiteHere,
            child: ListTile(
              leading: Icon(Icons.language),
              title: Text('Paste website here'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (pasteableWebsiteList != null)
          PopupMenuItem(
            key: const ValueKey('context-paste-website-list-menu-item'),
            value: _CanvasContextMenuCommand.pasteWebsiteListHere,
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text('Paste ${pasteableWebsiteList.length} websites here'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (pasteableText != null)
          const PopupMenuItem(
            key: ValueKey('context-paste-text-menu-item'),
            value: _CanvasContextMenuCommand.pasteTextHere,
            child: ListTile(
              leading: Icon(Icons.content_paste_go_outlined),
              title: Text('Paste text here'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          key: const ValueKey('context-paste-menu-item'),
          value: _CanvasContextMenuCommand.paste,
          enabled:
              _copiedNotes.isNotEmpty ||
              _copiedImages.isNotEmpty ||
              _copiedHeadings.isNotEmpty,
          child: const ListTile(
            leading: Icon(Icons.content_paste_outlined),
            title: Text('Paste objects'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: ValueKey('context-share-board-image-menu-item'),
          value: _CanvasContextMenuCommand.shareBoardImage,
          child: ListTile(
            leading: Icon(Icons.ios_share_outlined),
            title: Text('Share Board image...'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (!mounted || command == null) {
      return;
    }
    switch (command) {
      case _CanvasContextMenuCommand.addNoteHere:
        _createNoteAtCanvasCenter(canvasPoint);
      case _CanvasContextMenuCommand.addHeadingHere:
        await _createHeadingAt(canvasPoint);
      case _CanvasContextMenuCommand.pasteImageHere:
        await _pasteClipboardImageAt(canvasPoint);
      case _CanvasContextMenuCommand.pasteWebsiteHere:
        await _pasteWebsiteAt(canvasPoint);
      case _CanvasContextMenuCommand.embedYouTubeHere:
        _createYouTubeEmbedAt(canvasPoint, pasteableYouTube!);
      case _CanvasContextMenuCommand.pasteWebsiteListHere:
        await _pasteWebsiteListAt(
          canvasPoint,
          expectedCount: pasteableWebsiteList!.length,
        );
      case _CanvasContextMenuCommand.pasteTextHere:
        await _pasteTextAt(canvasPoint, expectedText: pasteableText!);
      case _CanvasContextMenuCommand.paste:
        _pasteClipboard();
      case _CanvasContextMenuCommand.shareBoardImage:
        await _showImageSharingDialog();
    }
  }

  Future<void> _showImageSharingDialog() async {
    final command = await showDialog<_ImageSharingCommand>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('image-sharing-dialog'),
        title: Row(
          children: [
            const Expanded(child: Text('Share Board image')),
            IconButton(
              key: const ValueKey('close-image-sharing-dialog'),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current view',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('share-current-view-save'),
                      autofocus: true,
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _ImageSharingCommand.exportCurrentView,
                      ),
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Save PNG...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('share-current-view-copy'),
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _ImageSharingCommand.copyCurrentView,
                      ),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copy image'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Whole Board (${_canvasWidth.toInt()} × ${_canvasHeight.toInt()})',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('share-whole-board-save'),
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _ImageSharingCommand.exportWholeBoard,
                      ),
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Save PNG...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('share-whole-board-copy'),
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _ImageSharingCommand.copyWholeBoard,
                      ),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copy image'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('share-image-cancel'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || command == null) {
      if (mounted) {
        _restoreShortcutFocus();
      }
      return;
    }
    switch (command) {
      case _ImageSharingCommand.exportCurrentView:
        await _exportCurrentViewAsPng();
      case _ImageSharingCommand.copyCurrentView:
        await _copyCurrentViewAsImage();
      case _ImageSharingCommand.exportWholeBoard:
        await _exportWholeBoardAsPng();
      case _ImageSharingCommand.copyWholeBoard:
        await _copyWholeBoardAsImage();
    }
  }

  Future<void> _exportCurrentViewAsPng() async {
    if (_isLoading || _editingNoteId != null || _isExportingCurrentView) {
      return;
    }
    final path = await widget.currentViewPngPathPicker(
      currentViewPngSuggestedName(_boardName),
    );
    if (!mounted || path == null) {
      if (mounted) {
        _restoreShortcutFocus();
      }
      return;
    }

    try {
      setState(() => _isExportingCurrentView = true);
      final bytes = await _captureCleanCurrentViewPng();
      await widget.currentViewPngPublisher(path, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Current view exported')),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Could not export current view')),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingCurrentView = false);
        _restoreShortcutFocus();
      }
    }
  }

  Future<void> _copyCurrentViewAsImage() async {
    if (_isLoading || _editingNoteId != null || _isExportingCurrentView) {
      return;
    }
    try {
      setState(() => _isExportingCurrentView = true);
      final bytes = await _captureCleanCurrentViewPng();
      await widget.currentViewPngClipboardWriter(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Current view copied')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Could not copy current view')),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingCurrentView = false);
        _restoreShortcutFocus();
      }
    }
  }

  Future<Uint8List> _captureCleanCurrentViewPng() async {
    final cleanFramePainted = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cleanFramePainted.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    await cleanFramePainted.future;
    if (!mounted) {
      throw StateError('Current view capture was interrupted');
    }
    final boundary = _currentViewExportBoundaryKey.currentContext
        ?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Current view export surface is unavailable');
    }
    return widget.currentViewPngCapturer(
      boundary,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  Future<void> _exportWholeBoardAsPng() async {
    if (_isLoading || _editingNoteId != null || _isExportingCurrentView) {
      return;
    }
    final path = await widget.currentViewPngPathPicker(
      wholeBoardPngSuggestedName(_boardName),
    );
    if (!mounted || path == null) {
      if (mounted) {
        _restoreShortcutFocus();
      }
      return;
    }

    try {
      setState(() {
        _isExportingCurrentView = true;
        _isExportingWholeBoard = true;
      });
      final bytes = await _captureCleanWholeBoardPng();
      await widget.currentViewPngPublisher(path, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Whole Board exported')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Could not export whole Board')),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingCurrentView = false;
          _isExportingWholeBoard = false;
        });
        _restoreShortcutFocus();
      }
    }
  }

  Future<Uint8List> _captureCleanWholeBoardPng() async {
    final cleanFramePainted = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cleanFramePainted.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    await cleanFramePainted.future;
    if (!mounted) {
      throw StateError('Whole Board capture was interrupted');
    }
    final boundary = _wholeBoardExportBoundaryKey.currentContext
        ?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Whole Board export surface is unavailable');
    }
    return widget.currentViewPngCapturer(boundary, 1);
  }

  Future<void> _copyWholeBoardAsImage() async {
    if (_isLoading || _editingNoteId != null || _isExportingCurrentView) {
      return;
    }
    try {
      setState(() {
        _isExportingCurrentView = true;
        _isExportingWholeBoard = true;
      });
      final bytes = await _captureCleanWholeBoardPng();
      await widget.currentViewPngClipboardWriter(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Whole Board copied')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Could not copy whole Board')),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingCurrentView = false;
          _isExportingWholeBoard = false;
        });
        _restoreShortcutFocus();
      }
    }
  }

  Future<String?> _readClipboardText() async {
    try {
      final data = await Clipboard.getData(
        Clipboard.kTextPlain,
      ).timeout(const Duration(milliseconds: 100));
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasClipboardImage() async {
    try {
      return await widget.clipboardImageReader.hasImage().timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _pasteClipboardImageAt(Offset canvasPoint) async {
    if (_isImportingImage) {
      return;
    }
    setState(() {
      _isImportingImage = true;
    });

    try {
      final payload = await widget.clipboardImageReader.readImage();
      if (!mounted) {
        return;
      }
      if (payload == null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Clipboard image changed')),
          );
        _restoreShortcutFocus();
        return;
      }
      final managedAsset = await widget.imageAssetStore.importBytes(
        payload.pngBytes,
        originalFileName: payload.suggestedFileName,
      );
      if (!mounted || managedAsset == null) {
        return;
      }
      _insertManagedImage(managedAsset, canvasPoint);
      _restoreShortcutFocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Could not paste image')),
          );
        _restoreShortcutFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingImage = false;
        });
      }
    }
  }

  List<Uri>? _resolvePasteableWebsites(String text) {
    final websiteList = NoteLinkResolver.resolveWholeList(text);
    if (websiteList != null) {
      return websiteList;
    }
    final website = NoteLinkResolver.resolveWhole(text);
    return website == null ? null : [website];
  }

  Future<List<Uri>?> _readPasteableWebsites() async {
    final text = await _readClipboardText();
    return text == null ? null : _resolvePasteableWebsites(text);
  }

  Future<void> _pasteWebsiteAt(Offset canvasPoint) async {
    final websites = await _readPasteableWebsites();
    if (!mounted) {
      return;
    }
    if (websites == null || websites.length != 1) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('No website address to paste')),
        );
      _restoreShortcutFocus();
      return;
    }
    _createNoteAtCanvasCenter(canvasPoint, text: websites.single.toString());
  }

  Future<void> _pasteWebsiteListAt(
    Offset canvasPoint, {
    required int expectedCount,
  }) async {
    final websites = await _readPasteableWebsites();
    if (!mounted) {
      return;
    }
    if (websites == null || websites.length != expectedCount) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Website list changed')));
      _restoreShortcutFocus();
      return;
    }
    _createNoteAtCanvasCenter(
      canvasPoint,
      text: websites.map((website) => website.toString()).join('\n'),
    );
  }

  Future<void> _pasteTextAt(
    Offset canvasPoint, {
    required String expectedText,
  }) async {
    final clipboardText = await _readClipboardText();
    final text = clipboardText == null
        ? null
        : NoteLinkResolver.resolvePlainTextFallback(clipboardText);
    if (!mounted) {
      return;
    }
    if (text == null || text != expectedText) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Clipboard text changed')));
      _restoreShortcutFocus();
      return;
    }
    _createNoteAtCanvasCenter(canvasPoint, text: text, importMarkdown: true);
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _redoStack.add(_captureSnapshot());
    final snapshot = _undoStack.removeLast();
    _restoreSnapshot(snapshot);
    _markBoardChanged();
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endMovingImage();
    _endResizingImage();
    _undoStack.add(_captureSnapshot());
    final snapshot = _redoStack.removeLast();
    _restoreSnapshot(snapshot);
    _markBoardChanged();
  }

  void _recoverOffBoardObjects() {
    if (_offBoardObjectCount == 0) {
      return;
    }

    _finishTextEditing();
    _endMoving();
    _endResizing();
    _endResizingImage();
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _editingNoteId = null;
      _notes = [
        for (final note in _notes)
          if (_isOffBoardNote(note))
            () {
              final position = _clampNotePosition(
                Offset(note.x, note.y),
                width: note.width,
                height: note.height,
              );
              return note.copyWith(
                x: position.dx,
                y: position.dy,
                modifiedAt: now,
              );
            }()
          else
            note,
      ];
      _images = [
        for (final image in _images)
          if (_isOffBoardImage(image))
            () {
              final position = _clampNotePosition(
                Offset(image.x, image.y),
                width: image.width,
                height: image.height,
              );
              return image.copyWith(
                x: position.dx,
                y: position.dy,
                modifiedAt: now,
              );
            }()
          else
            image,
      ];
      _headings = [
        for (final heading in _headings)
          if (_isOffBoardHeading(heading))
            () {
              final size = CanvasHeadingGeometry.sizeFor(heading);
              final position = _clampNotePosition(
                Offset(heading.x, heading.y),
                width: size.width,
                height: size.height,
              );
              return heading.copyWith(
                x: position.dx,
                y: position.dy,
                modifiedAt: now,
              );
            }()
          else
            heading,
      ];
      _attachments = [
        for (final attachment in _attachments)
          if (_isOffBoardAttachment(attachment))
            () {
              final position = _clampNotePosition(
                Offset(attachment.x, attachment.y),
                width: attachment.width,
                height: attachment.height,
              );
              return attachment.copyWith(
                x: position.dx,
                y: position.dy,
                modifiedAt: now,
              );
            }()
          else
            attachment,
      ];
      _youTubeEmbeds = [
        for (final embed in _youTubeEmbeds)
          if (_isOffBoardYouTubeEmbed(embed))
            () {
              final position = _clampNotePosition(
                Offset(embed.x, embed.y),
                width: embed.width,
                height: embed.height,
              );
              return embed.copyWith(
                x: position.dx,
                y: position.dy,
                modifiedAt: now,
              );
            }()
          else
            embed,
      ];
      _shapes = [
        for (final shape in _shapes)
          if (_isOffBoardShape(shape))
            () {
              final position = _clampNotePosition(
                Offset(shape.x, shape.y),
                width: shape.width,
                height: shape.height,
              );
              return shape.copyWith(
                x: position.dx,
                y: position.dy,
                modifiedAt: now,
              );
            }()
          else
            shape,
      ];
    });
    _markBoardChanged();
    _zoomToFit(markChanged: false, preferSelection: false);
  }

  bool _isOffBoardNote(Note note) {
    return note.x < 0 ||
        note.y < 0 ||
        note.x + note.width > _canvasWidth ||
        note.y + note.height > _canvasHeight;
  }

  bool _isOffBoardImage(BoardImage image) {
    return image.x < 0 ||
        image.y < 0 ||
        image.x + image.width > _canvasWidth ||
        image.y + image.height > _canvasHeight;
  }

  bool _isOffBoardHeading(CanvasHeading heading) {
    final bounds = CanvasHeadingGeometry.boundsFor(heading);
    return bounds.left < 0 ||
        bounds.top < 0 ||
        bounds.right > _canvasWidth ||
        bounds.bottom > _canvasHeight;
  }

  bool _isOffBoardAttachment(BoardAttachment attachment) {
    return attachment.x < 0 ||
        attachment.y < 0 ||
        attachment.x + attachment.width > _canvasWidth ||
        attachment.y + attachment.height > _canvasHeight;
  }

  bool _isOffBoardYouTubeEmbed(YouTubeEmbed embed) =>
      embed.x < 0 ||
      embed.y < 0 ||
      embed.x + embed.width > _canvasWidth ||
      embed.y + embed.height > _canvasHeight;

  bool _isOffBoardShape(BoardShape shape) =>
      shape.x < 0 ||
      shape.y < 0 ||
      shape.x + shape.width > _canvasWidth ||
      shape.y + shape.height > _canvasHeight;

  Offset _clampNotePosition(
    Offset position, {
    required double width,
    required double height,
  }) {
    final maxX = width < _canvasWidth ? _canvasWidth - width : 0.0;
    final maxY = height < _canvasHeight ? _canvasHeight - height : 0.0;
    return Offset(
      position.dx.clamp(0.0, maxX).toDouble(),
      position.dy.clamp(0.0, maxY).toDouble(),
    );
  }

  void _zoomToFit({bool markChanged = true, bool preferSelection = true}) {
    if (_visibleObjectBounds.isEmpty && _visibleOrderedShapes.isEmpty) {
      return;
    }

    final selectedBounds = <Rect>[
      for (final note in _notes)
        if (_selectedNoteIds.contains(note.id) &&
            !_hiddenGroupMemberIds.contains(note.id))
          Rect.fromLTWH(note.x, note.y, note.width, note.height),
      for (final image in _images)
        if (_selectedImageIds.contains(image.id) &&
            !_hiddenGroupMemberIds.contains(image.id))
          Rect.fromLTWH(image.x, image.y, image.width, image.height),
      for (final heading in _headings)
        if (_selectedHeadingIds.contains(heading.id) &&
            !_hiddenGroupMemberIds.contains(heading.id))
          CanvasHeadingGeometry.boundsFor(heading),
      for (final attachment in _attachments)
        if (_selectedAttachmentIds.contains(attachment.id) &&
            !_hiddenGroupMemberIds.contains(attachment.id))
          Rect.fromLTWH(
            attachment.x,
            attachment.y,
            attachment.width,
            attachment.height,
          ),
      for (final embed in _youTubeEmbeds)
        if (_selectedYouTubeEmbedIds.contains(embed.id) &&
            !_hiddenGroupMemberIds.contains(embed.id))
          Rect.fromLTWH(embed.x, embed.y, embed.width, embed.height),
      if (_selectedShape case final shape?)
        Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height),
    ];
    final allBounds = <Rect>[
      for (final note in _notes)
        if (!_hiddenGroupMemberIds.contains(note.id))
          Rect.fromLTWH(note.x, note.y, note.width, note.height),
      for (final image in _images)
        if (!_hiddenGroupMemberIds.contains(image.id))
          Rect.fromLTWH(image.x, image.y, image.width, image.height),
      for (final heading in _headings)
        if (!_hiddenGroupMemberIds.contains(heading.id))
          CanvasHeadingGeometry.boundsFor(heading),
      for (final attachment in _attachments)
        if (!_hiddenGroupMemberIds.contains(attachment.id))
          Rect.fromLTWH(
            attachment.x,
            attachment.y,
            attachment.width,
            attachment.height,
          ),
      for (final embed in _youTubeEmbeds)
        if (!_hiddenGroupMemberIds.contains(embed.id))
          Rect.fromLTWH(embed.x, embed.y, embed.width, embed.height),
      for (final shape in _visibleOrderedShapes)
        Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height),
    ];
    final isFittingSelection = preferSelection && selectedBounds.isNotEmpty;
    final objectsToFit = isFittingSelection ? selectedBounds : allBounds;

    final renderBox = _viewportKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) {
      return;
    }

    var bounds = objectsToFit.first;
    for (final objectBounds in objectsToFit.skip(1)) {
      bounds = bounds.expandToInclude(objectBounds);
    }

    const padding = 48.0;
    final availableWidth = renderBox.size.width - padding * 2;
    final availableHeight = renderBox.size.height - padding * 2;
    final horizontalScale = availableWidth / bounds.width;
    final verticalScale = availableHeight / bounds.height;
    final fitScale = horizontalScale < verticalScale
        ? horizontalScale
        : verticalScale;
    final scale = fitScale.clamp(0.1, 1.0).toDouble();
    final viewportCenter = renderBox.size.center(Offset.zero);
    final translation = viewportCenter - bounds.center * scale;

    final transform = Matrix4.diagonal3Values(scale, scale, scale)
      ..setTranslationRaw(translation.dx, translation.dy, 0);
    _transformationController.value = transform;
    if (isFittingSelection) {
      _clearSelection();
    }
    if (markChanged) {
      _markBoardChanged();
    }
  }

  void _recenterFromOverview(Offset canvasPoint) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    _transformationController.value =
        CanvasOverviewGeometry.recenteredTransform(
          currentTransform: _transformationController.value,
          viewportSize: renderObject.size,
          canvasPoint: canvasPoint,
        );
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  Offset? _selectNoteSearchTarget(String noteId) {
    final noteIndex = _notes.indexWhere((note) => note.id == noteId);
    if (noteIndex < 0) {
      return null;
    }
    final note = _notes[noteIndex];
    setState(() {
      _selectObjectOrGroup(note.id, additive: false);
      _editingNoteId = null;
    });
    return Offset(note.x + note.width / 2, note.y + note.height / 2);
  }

  Offset? _selectImageSearchTarget(String imageId) {
    final imageIndex = _images.indexWhere((image) => image.id == imageId);
    if (imageIndex < 0) {
      return null;
    }
    final image = _images[imageIndex];
    setState(() {
      _selectObjectOrGroup(image.id, additive: false);
      _editingNoteId = null;
    });
    return Offset(image.x + image.width / 2, image.y + image.height / 2);
  }

  Offset? _selectHeadingSearchTarget(String headingId) {
    final headingIndex = _headings.indexWhere(
      (heading) => heading.id == headingId,
    );
    if (headingIndex < 0) {
      return null;
    }
    final heading = _headings[headingIndex];
    setState(() {
      _selectObjectOrGroup(heading.id, additive: false);
      _editingNoteId = null;
    });
    return CanvasHeadingGeometry.boundsFor(heading).center;
  }

  Offset? _selectShapeSearchTarget(String shapeId) {
    final index = _shapes.indexWhere((shape) => shape.id == shapeId);
    if (index < 0) {
      return null;
    }
    final shape = _shapes[index];
    final layerId = _shapeLayerIdFor(shape.id);
    if (layerId == null) return null;
    final layer = _shapeLayers.firstWhere(
      (candidate) => candidate.id == layerId,
    );
    setState(() {
      _isShapesMode = true;
      _activeShapeLayerId = layerId;
      _armedShapeType = null;
      _selectedShapeId =
          layer.isVisible && !_hiddenGroupMemberIds.contains(shape.id)
          ? shape.id
          : null;
      _selectedNoteIds = {};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _selectedAttachmentIds = {};
      _selectedYouTubeEmbedIds = {};
      _selectedGroupShapeIds = {};
      _editingNoteId = null;
    });
    return Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height).center;
  }

  Offset? _selectConnectorSearchTarget(String connectorId) {
    final connectorIndex = _connectors.indexWhere(
      (connector) => connector.id == connectorId,
    );
    if (connectorIndex < 0) {
      return null;
    }
    final connector = _connectors[connectorIndex];
    final objectBounds = _objectBounds;
    final firstBounds = objectBounds[connector.objectAId];
    final secondBounds = objectBounds[connector.objectBId];
    if (firstBounds == null || secondBounds == null) {
      return null;
    }
    final endpointIds = {connector.objectAId, connector.objectBId};
    final selectedNoteIds = {
      for (final note in _notes)
        if (endpointIds.contains(note.id)) note.id,
    };
    final selectedImageIds = {
      for (final image in _images)
        if (endpointIds.contains(image.id)) image.id,
    };
    if (selectedNoteIds.length + selectedImageIds.length != 2) {
      return null;
    }
    final selectedIds = <String>{
      for (final id in endpointIds) ..._selectionUnitFor(id),
    };
    setState(() {
      _replaceObjectSelection(selectedIds);
      _editingNoteId = null;
    });
    final segment = ConnectorGeometry.betweenRects(firstBounds, secondBounds);
    return Offset(
      (segment.start.dx + segment.end.dx) / 2,
      (segment.start.dy + segment.end.dy) / 2,
    );
  }

  void _activateInitialTarget(CanvasInitialTarget target) {
    if (target.type == CanvasInitialTargetType.scene) {
      final sceneIndex = _scenes.indexWhere(
        (scene) => scene.id == target.objectId,
      );
      if (sceneIndex < 0) {
        return;
      }
      SceneViewportController.activate(
        transformationController: _transformationController,
        scene: _scenes[sceneIndex],
      );
      _markBoardChanged();
      _restoreShortcutFocus();
      return;
    }
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    final targetObjectIds = switch (target.type) {
      CanvasInitialTargetType.connector =>
        _connectors
            .where((connector) => connector.id == target.objectId)
            .expand((connector) => [connector.objectAId, connector.objectBId])
            .toSet(),
      CanvasInitialTargetType.note ||
      CanvasInitialTargetType.image ||
      CanvasInitialTargetType.heading => {target.objectId},
      CanvasInitialTargetType.shape ||
      CanvasInitialTargetType.scene => const <String>{},
    };
    final hiddenTargetGroups = _groups
        .where(
          (group) =>
              !group.isVisible && group.memberIds.any(targetObjectIds.contains),
        )
        .toList();
    if (hiddenTargetGroups.isNotEmpty) {
      final hiddenGroupIds = hiddenTargetGroups
          .map((group) => group.id)
          .toSet();
      final now = DateTime.now().toUtc();
      setState(() {
        _groups = [
          for (final group in _groups)
            if (hiddenGroupIds.contains(group.id))
              group.copyWith(isVisible: true, modifiedAt: now)
            else
              group,
        ];
      });
      _markBoardChanged();
    }
    final canvasPoint = switch (target.type) {
      CanvasInitialTargetType.note => _selectNoteSearchTarget(target.objectId),
      CanvasInitialTargetType.image => _selectImageSearchTarget(
        target.objectId,
      ),
      CanvasInitialTargetType.heading => _selectHeadingSearchTarget(
        target.objectId,
      ),
      CanvasInitialTargetType.shape => _selectShapeSearchTarget(
        target.objectId,
      ),
      CanvasInitialTargetType.connector => _selectConnectorSearchTarget(
        target.objectId,
      ),
      CanvasInitialTargetType.scene => null,
    };
    if (canvasPoint == null) {
      return;
    }
    _transformationController.value =
        CanvasOverviewGeometry.recenteredTransform(
          currentTransform: _transformationController.value,
          viewportSize: renderObject.size,
          canvasPoint: canvasPoint,
        );
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  Future<void> _showFindOnBoardDialog() async {
    if (_isLoading || _editingNoteId != null) {
      return;
    }
    final target = await showDialog<BoardSearchTarget>(
      context: context,
      builder: (context) => BoardSearchDialog(
        notes: List.unmodifiable(_notes),
        headings: List.unmodifiable(_headings),
        images: List.unmodifiable(_images),
        connectors: List.unmodifiable(_connectors),
        shapes: List.unmodifiable(_shapes),
        shapeLayers: List.unmodifiable(_shapeLayers),
        hiddenObjectIds: _hiddenGroupMemberIds,
      ),
    );
    if (!mounted) {
      return;
    }
    if (target == null) {
      _restoreShortcutFocus();
      return;
    }
    final hiddenGroup = _groupForObject(target.objectId);
    if (hiddenGroup != null && !hiddenGroup.isVisible) {
      _toggleGroupVisibility(hiddenGroup);
    }
    _exitShapeLayerSolo();
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      _restoreShortcutFocus();
      return;
    }
    late final Offset canvasPoint;
    switch (target.type) {
      case BoardSearchTargetType.note:
        final noteCanvasPoint = _selectNoteSearchTarget(target.objectId);
        if (noteCanvasPoint == null) {
          _restoreShortcutFocus();
          return;
        }
        canvasPoint = noteCanvasPoint;
      case BoardSearchTargetType.image:
        final imageCanvasPoint = _selectImageSearchTarget(target.objectId);
        if (imageCanvasPoint == null) {
          _restoreShortcutFocus();
          return;
        }
        canvasPoint = imageCanvasPoint;
      case BoardSearchTargetType.heading:
        final headingCanvasPoint = _selectHeadingSearchTarget(target.objectId);
        if (headingCanvasPoint == null) {
          _restoreShortcutFocus();
          return;
        }
        canvasPoint = headingCanvasPoint;
      case BoardSearchTargetType.shape:
        final shapeCanvasPoint = _selectShapeSearchTarget(target.objectId);
        if (shapeCanvasPoint == null) {
          _restoreShortcutFocus();
          return;
        }
        canvasPoint = shapeCanvasPoint;
      case BoardSearchTargetType.connector:
        final connectorCanvasPoint = _selectConnectorSearchTarget(
          target.objectId,
        );
        if (connectorCanvasPoint == null) {
          _restoreShortcutFocus();
          return;
        }
        canvasPoint = connectorCanvasPoint;
    }
    _transformationController.value =
        CanvasOverviewGeometry.recenteredTransform(
          currentTransform: _transformationController.value,
          viewportSize: renderObject.size,
          canvasPoint: canvasPoint,
        );
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  String get _zoomToFitTooltip {
    final selectedNoteCount = _selectedNoteIds.length;
    final selectedImageCount = _selectedImageIds.length;
    final selectedHeadingCount = _selectedHeadingIds.length;
    final selectedAttachmentCount = _selectedAttachmentIds.length;

    if ([
          selectedNoteCount,
          selectedImageCount,
          selectedHeadingCount,
          selectedAttachmentCount,
        ].where((count) => count > 0).length >
        1) {
      return 'Zoom to fit selection';
    }
    if (selectedNoteCount == 1) {
      return 'Zoom to fit selected note';
    }
    if (selectedNoteCount > 1) {
      return 'Zoom to fit selected notes';
    }
    if (selectedImageCount == 1) {
      return 'Zoom to fit selected image';
    }
    if (selectedImageCount > 1) {
      return 'Zoom to fit selected images';
    }
    if (selectedHeadingCount == 1) {
      return 'Zoom to fit selected heading';
    }
    if (selectedHeadingCount > 1) {
      return 'Zoom to fit selected headings';
    }
    if (selectedAttachmentCount == 1) {
      return 'Zoom to fit selected attachment';
    }
    if (selectedAttachmentCount > 1) {
      return 'Zoom to fit selected attachments';
    }
    return _images.isEmpty && _headings.isEmpty && _attachments.isEmpty
        ? 'Zoom to fit all notes'
        : 'Zoom to fit all objects';
  }

  Future<String?> _promptForSceneName({Scene? scene}) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _SceneNameDialog(scene: scene),
    );
  }

  void _createScene(String name) {
    final now = DateTime.now().toUtc();
    final scene = SceneViewportController.capture(
      transformationController: _transformationController,
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      modifiedAt: now,
    );
    _recordUndoSnapshot(_captureSnapshot());
    setState(() => _scenes = [..._scenes, scene]);
    _markBoardChanged();
  }

  void _activateScene(Scene scene) {
    _startSceneTransition(scene, markBoardChanged: true);
  }

  void _activateSceneForWalkthrough(Scene scene) {
    _startSceneTransition(scene, markBoardChanged: false);
  }

  bool get _sceneTransitionsDisabled {
    return MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  void _startSceneTransition(Scene scene, {required bool markBoardChanged}) {
    final target = SceneViewportController.transformFor(scene);
    _cancelSceneTransition();
    if (_sceneTransitionsDisabled) {
      _transformationController.value = target;
      if (markBoardChanged) {
        _markBoardChanged();
      }
      return;
    }
    _sceneTransitionStart = Matrix4.copy(_transformationController.value);
    _sceneTransitionEnd = target;
    _sceneTransitionMarksBoardChanged = markBoardChanged;
    _sceneTransitionController.forward(from: 0);
  }

  void _advanceSceneTransition() {
    final start = _sceneTransitionStart;
    final end = _sceneTransitionEnd;
    if (start == null || end == null) {
      return;
    }
    final progress = Curves.easeOutCubic.transform(
      _sceneTransitionController.value,
    );
    _transformationController.value = Matrix4Tween(
      begin: start,
      end: end,
    ).transform(progress);
  }

  void _handleSceneTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _finishSceneTransition();
    }
  }

  void _finishSceneTransition() {
    final end = _sceneTransitionEnd;
    final markBoardChanged = _sceneTransitionMarksBoardChanged;
    _sceneTransitionController.stop();
    _sceneTransitionStart = null;
    _sceneTransitionEnd = null;
    _sceneTransitionMarksBoardChanged = false;
    if (end == null) {
      return;
    }
    _transformationController.value = Matrix4.copy(end);
    if (markBoardChanged && mounted) {
      _markBoardChanged();
    }
  }

  void _cancelSceneTransition() {
    _sceneTransitionController.stop();
    _sceneTransitionStart = null;
    _sceneTransitionEnd = null;
    _sceneTransitionMarksBoardChanged = false;
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations &&
        _sceneTransitionEnd != null) {
      _finishSceneTransition();
    }
  }

  Future<void> _showSceneWalkthrough({String? initialSceneId}) async {
    if (_scenes.length < 2 || _walkthroughWorkingTransform != null) {
      return;
    }
    final initialIndex = initialSceneId == null
        ? 0
        : _scenes.indexWhere((scene) => scene.id == initialSceneId);
    if (initialIndex < 0) {
      return;
    }
    final workingTransform = Matrix4.copy(_transformationController.value);
    _walkthroughWorkingTransform = workingTransform;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Scene Walkthrough',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (routeContext, _, _) => _SceneWalkthrough(
          scenes: List.unmodifiable(_scenes),
          initialIndex: initialIndex,
          onSceneChanged: _activateSceneForWalkthrough,
        ),
      );
    } finally {
      if (mounted) {
        _cancelSceneTransition();
        _transformationController.value = Matrix4.copy(workingTransform);
        _walkthroughWorkingTransform = null;
        _restoreShortcutFocus();
      }
    }
  }

  void _renameScene(Scene scene, String name) {
    if (name == scene.name) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _scenes = [
        for (final current in _scenes)
          current.id == scene.id
              ? current.copyWith(name: name, modifiedAt: now)
              : current,
      ];
    });
    _markBoardChanged();
  }

  void _moveScene(Scene scene, int offset) {
    final currentIndex = _scenes.indexWhere(
      (current) => current.id == scene.id,
    );
    final targetIndex = currentIndex + offset;
    if (currentIndex == -1 ||
        (offset != -1 && offset != 1) ||
        targetIndex < 0 ||
        targetIndex >= _scenes.length) {
      return;
    }

    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      final reordered = List<Scene>.of(_scenes);
      final displaced = reordered[targetIndex];
      reordered[targetIndex] = reordered[currentIndex];
      reordered[currentIndex] = displaced;
      _scenes = reordered;
    });
    _markBoardChanged();
  }

  bool _sceneMatchesCurrentView(Scene scene) {
    return SceneViewportController.matches(
      transformationController: _transformationController,
      scene: scene,
    );
  }

  Future<bool> _confirmSceneViewUpdate(Scene scene) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Update saved scene?'),
            content: Text(
              'Replace the saved location and zoom for "${scene.name}" with '
              'the current view? Canvas objects will not be changed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('confirm-update-scene-view-button'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Update scene'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _updateSceneView(Scene scene) {
    final index = _scenes.indexWhere((current) => current.id == scene.id);
    if (index == -1) {
      return;
    }
    final current = _scenes[index];
    if (_sceneMatchesCurrentView(current)) {
      return;
    }

    final updated = SceneViewportController.updatedFromViewport(
      transformationController: _transformationController,
      scene: current,
      modifiedAt: DateTime.now().toUtc(),
    );
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _scenes = [
        for (final candidate in _scenes)
          candidate.id == current.id ? updated : candidate,
      ];
    });
    _markBoardChanged();
  }

  void _deleteScene(Scene scene) {
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _scenes = [
        for (final current in _scenes)
          if (current.id != scene.id) current,
      ];
    });
    _markBoardChanged();
  }

  Future<bool> _confirmSceneDeletion(Scene scene) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete saved scene?'),
            content: Text(
              'Delete “${scene.name}”? Canvas objects will not be changed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('confirm-delete-scene-button'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete scene'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showScenesDialog() async {
    var createdScene = false;
    final walkthroughRequest = await showDialog<_SceneWalkthroughRequest>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: const Text('Scenes'),
          content: SizedBox(
            width: 440,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Scenes save a canvas location and zoom, not canvas objects.',
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const ValueKey('save-current-view-scene-button'),
                  onPressed: () async {
                    final name = await _promptForSceneName();
                    if (name != null && mounted && dialogContext.mounted) {
                      _createScene(name);
                      createdScene = true;
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save current view'),
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: _scenes.length >= 2
                      ? 'Walk through saved scenes in order'
                      : 'Save at least two scenes to start a walkthrough',
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('start-scene-walkthrough-button'),
                    onPressed: _scenes.length >= 2
                        ? () => Navigator.of(
                            dialogContext,
                          ).pop(const _SceneWalkthroughRequest())
                        : null,
                    icon: const Icon(Icons.slideshow_outlined),
                    label: const Text('Start walkthrough'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _scenes.isEmpty
                      ? const Center(child: Text('No saved scenes yet'))
                      : ListView.builder(
                          key: const ValueKey('scene-list'),
                          itemCount: _scenes.length,
                          itemBuilder: (context, index) {
                            final scene = _scenes[index];
                            return ListTile(
                              key: ValueKey('scene-${scene.id}'),
                              leading: const Icon(Icons.bookmark_outline),
                              title: Text(scene.name),
                              subtitle: _sceneMatchesCurrentView(scene)
                                  ? Row(
                                      key: ValueKey(
                                        'current-view-scene-${scene.id}',
                                      ),
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text('Current view'),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                _activateScene(scene);
                              },
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  PopupMenuButton<_SceneActionCommand>(
                                    key: ValueKey('reorder-scene-${scene.id}'),
                                    tooltip: 'Scene actions for ${scene.name}',
                                    onSelected: (command) async {
                                      switch (command) {
                                        case _SceneActionCommand.updateView:
                                          if (await _confirmSceneViewUpdate(
                                                scene,
                                              ) &&
                                              mounted) {
                                            _updateSceneView(scene);
                                            refreshDialog(() {});
                                          }
                                          break;
                                        case _SceneActionCommand
                                            .startWalkthrough:
                                          Navigator.of(dialogContext).pop(
                                            _SceneWalkthroughRequest(
                                              sceneId: scene.id,
                                            ),
                                          );
                                          break;
                                        case _SceneActionCommand.earlier:
                                          _moveScene(scene, -1);
                                          refreshDialog(() {});
                                          break;
                                        case _SceneActionCommand.later:
                                          _moveScene(scene, 1);
                                          refreshDialog(() {});
                                          break;
                                        case _SceneActionCommand.rename:
                                          final name =
                                              await _promptForSceneName(
                                                scene: scene,
                                              );
                                          if (name != null && mounted) {
                                            _renameScene(scene, name);
                                            refreshDialog(() {});
                                          }
                                          break;
                                        case _SceneActionCommand.delete:
                                          if (await _confirmSceneDeletion(
                                                scene,
                                              ) &&
                                              mounted) {
                                            _deleteScene(scene);
                                            refreshDialog(() {});
                                          }
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        key: ValueKey(
                                          'update-scene-view-${scene.id}',
                                        ),
                                        value: _SceneActionCommand.updateView,
                                        enabled: !_sceneMatchesCurrentView(
                                          scene,
                                        ),
                                        child: const ListTile(
                                          leading: Icon(Icons.update_outlined),
                                          title: Text('Update to current view'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        key: ValueKey(
                                          'start-walkthrough-here-${scene.id}',
                                        ),
                                        value: _SceneActionCommand
                                            .startWalkthrough,
                                        enabled: _scenes.length >= 2,
                                        child: const ListTile(
                                          leading: Icon(
                                            Icons.play_circle_outline,
                                          ),
                                          title: Text('Start walkthrough here'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        key: ValueKey(
                                          'move-scene-earlier-${scene.id}',
                                        ),
                                        value: _SceneActionCommand.earlier,
                                        enabled: index > 0,
                                        child: const ListTile(
                                          leading: Icon(Icons.arrow_upward),
                                          title: Text('Move earlier'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        key: ValueKey(
                                          'move-scene-later-${scene.id}',
                                        ),
                                        value: _SceneActionCommand.later,
                                        enabled: index < _scenes.length - 1,
                                        child: const ListTile(
                                          leading: Icon(Icons.arrow_downward),
                                          title: Text('Move later'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        key: ValueKey(
                                          'rename-scene-${scene.id}',
                                        ),
                                        value: _SceneActionCommand.rename,
                                        child: const ListTile(
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Rename'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        key: ValueKey(
                                          'delete-scene-${scene.id}',
                                        ),
                                        value: _SceneActionCommand.delete,
                                        child: const ListTile(
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Delete'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (walkthroughRequest != null && mounted) {
      await _showSceneWalkthrough(initialSceneId: walkthroughRequest.sceneId);
    } else if (createdScene && mounted) {
      _restoreShortcutFocus();
    }
  }

  Future<void> _showFreshPairDialog() async {
    final selector = widget.freshPairSelector ?? FreshPairSelector();
    final candidateNotes = _visibleNotes;
    var pair = selector.select(candidateNotes);
    if (pair == null) {
      return;
    }

    final selectedPair = await showDialog<FreshPair>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) {
          final firstNote = candidateNotes.firstWhere(
            (note) => note.id == pair!.firstNoteId,
          );
          final secondNote = candidateNotes.firstWhere(
            (note) => note.id == pair!.secondNoteId,
          );
          return AlertDialog(
            key: const ValueKey('fresh-pair-dialog'),
            title: const Text('Fresh Pair'),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Place two notes side by side and see what they suggest. '
                    'Vasmim will not change or connect them.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FreshPairNoteCard(
                          label: 'First note',
                          note: firstNote,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FreshPairNoteCard(
                          label: 'Second note',
                          note: secondNote,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('close-fresh-pair-button'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('another-fresh-pair-button'),
                onPressed: () {
                  final nextPair = selector.select(
                    candidateNotes,
                    previousPair: pair,
                  );
                  if (nextPair != null) {
                    refreshDialog(() => pair = nextPair);
                  }
                },
                icon: const Icon(Icons.shuffle),
                label: const Text('Another pair'),
              ),
              FilledButton(
                key: const ValueKey('use-fresh-pair-button'),
                onPressed: () => Navigator.of(dialogContext).pop(pair),
                child: const Text('Use this pair'),
              ),
            ],
          );
        },
      ),
    );

    if (selectedPair == null || !mounted) {
      return;
    }
    final availableNoteIds = _visibleNotes.map((note) => note.id).toSet();
    if (!availableNoteIds.containsAll(selectedPair.noteIds)) {
      return;
    }
    _finishTextEditing();
    final selectedIds = <String>{
      for (final id in selectedPair.noteIds) ..._selectionUnitFor(id),
    };
    setState(() {
      _replaceObjectSelection(selectedIds);
      _editingNoteId = null;
    });
  }

  _CanvasSnapshot _captureSnapshot({Set<String>? selectedNoteIds}) {
    return _CanvasSnapshot(
      notes: List.unmodifiable(_notes),
      connectors: List.unmodifiable(_connectors),
      images: List.unmodifiable(_images),
      scenes: List.unmodifiable(_scenes),
      headings: List.unmodifiable(_headings),
      attachments: List.unmodifiable(_attachments),
      youTubeEmbeds: List.unmodifiable(_youTubeEmbeds),
      shapes: List.unmodifiable(_shapes),
      shapeLayers: List.unmodifiable(_shapeLayers),
      groups: List.unmodifiable(_groups),
      lockedObjectIds: Set.unmodifiable(_lockedObjectIds),
      activeShapeLayerId: _activeShapeLayerId,
      selectedNoteIds: Set.unmodifiable(selectedNoteIds ?? _selectedNoteIds),
      selectedImageIds: Set.unmodifiable(_selectedImageIds),
      selectedHeadingIds: Set.unmodifiable(_selectedHeadingIds),
      selectedAttachmentIds: Set.unmodifiable(_selectedAttachmentIds),
      selectedYouTubeEmbedIds: Set.unmodifiable(_selectedYouTubeEmbedIds),
      selectedGroupShapeIds: Set.unmodifiable(_selectedGroupShapeIds),
      selectedShapeId: _selectedShapeId,
    );
  }

  void _recordUndoSnapshot(_CanvasSnapshot snapshot) {
    _undoStack.add(snapshot);
    _redoStack.clear();
  }

  void _restoreSnapshot(_CanvasSnapshot snapshot) {
    setState(() {
      _notes = List.of(snapshot.notes);
      _connectors = List.of(snapshot.connectors);
      _images = List.of(snapshot.images);
      _scenes = List.of(snapshot.scenes);
      _headings = List.of(snapshot.headings);
      _attachments = List.of(snapshot.attachments);
      _youTubeEmbeds = List.of(snapshot.youTubeEmbeds);
      _shapes = List.of(snapshot.shapes);
      _shapeLayers = List.of(snapshot.shapeLayers);
      _groups = List.of(snapshot.groups);
      _lockedObjectIds = Set.of(snapshot.lockedObjectIds);
      final soloLayer = snapshot.shapeLayers
          .where((layer) => layer.id == _soloShapeLayerId && layer.isVisible)
          .firstOrNull;
      if (soloLayer != null) {
        _activeShapeLayerId = soloLayer.id;
      } else {
        _soloShapeLayerId = null;
        _activeShapeLayerId =
            snapshot.shapeLayers.any(
              (layer) => layer.id == snapshot.activeShapeLayerId,
            )
            ? snapshot.activeShapeLayerId
            : snapshot.shapeLayers.last.id;
      }
      _selectedNoteIds = Set.of(snapshot.selectedNoteIds);
      _selectedImageIds = Set.of(snapshot.selectedImageIds);
      _selectedHeadingIds = Set.of(snapshot.selectedHeadingIds);
      _selectedAttachmentIds = Set.of(snapshot.selectedAttachmentIds);
      _selectedYouTubeEmbedIds = Set.of(snapshot.selectedYouTubeEmbedIds);
      _selectedGroupShapeIds = Set.of(snapshot.selectedGroupShapeIds);
      _selectedShapeId = snapshot.selectedShapeId;
      _editingNoteId = null;
    });
  }

  void _replaceNote(String noteId, Note Function(Note note) update) {
    setState(() {
      _notes = [
        for (final note in _notes) note.id == noteId ? update(note) : note,
      ];
    });
    _markBoardChanged();
  }

  void _replaceImage(
    String imageId,
    BoardImage Function(BoardImage image) update,
  ) {
    setState(() {
      _images = [
        for (final image in _images)
          image.id == imageId ? update(image) : image,
      ];
    });
    _markBoardChanged();
  }

  ShapeLayer get _activeShapeLayer {
    for (final layer in _shapeLayers) {
      if (layer.id == _activeShapeLayerId) return layer;
    }
    return _shapeLayers.last;
  }

  String? _shapeLayerIdFor(String shapeId) {
    for (final layer in _shapeLayers) {
      if (layer.shapeIds.contains(shapeId)) return layer.id;
    }
    return null;
  }

  List<BoardShape> get _activeLayerShapes {
    final byId = {for (final shape in _shapes) shape.id: shape};
    return [
      for (final id in _activeShapeLayer.shapeIds)
        if (byId[id] != null && !_hiddenGroupMemberIds.contains(id)) byId[id]!,
    ];
  }

  List<BoardShape> get _visibleOrderedShapes {
    final byId = {for (final shape in _shapes) shape.id: shape};
    return [
      for (final layer in _shapeLayers)
        if (layer.isVisible &&
            (_soloShapeLayerId == null || layer.id == _soloShapeLayerId))
          for (final id in layer.shapeIds)
            if (byId[id] != null && !_hiddenGroupMemberIds.contains(id))
              byId[id]!,
    ];
  }

  Map<String, double> get _visibleShapeLayerOpacities => {
    for (final layer in _shapeLayers)
      if (layer.isVisible &&
          (_soloShapeLayerId == null || layer.id == _soloShapeLayerId))
        for (final shapeId in layer.shapeIds)
          if (!_hiddenGroupMemberIds.contains(shapeId)) shapeId: layer.opacity,
  };

  void _replaceShapeLayerLocally(ShapeLayer replacement) {
    _shapeLayers = [
      for (final layer in _shapeLayers)
        if (layer.id == replacement.id) replacement else layer,
    ];
  }

  BoardShape? get _selectedShape {
    final id = _selectedShapeId;
    if (id == null ||
        !_activeShapeLayer.isVisible ||
        _hiddenGroupMemberIds.contains(id) ||
        !_activeShapeLayer.shapeIds.contains(id)) {
      return null;
    }
    for (final shape in _shapes) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  void _toggleShapesMode() {
    _finishTextEditing();
    setState(() {
      _isShapesMode = !_isShapesMode;
      if (_isShapesMode) _isGroupsPanelOpen = false;
      if (!_isShapesMode) _soloShapeLayerId = null;
      _armedShapeType = null;
      _shapePreview = null;
      _selectedShapeId = _isShapesMode ? _selectedShapeId : null;
      _selectedNoteIds = {};
      _selectedImageIds = {};
      _selectedHeadingIds = {};
      _selectedAttachmentIds = {};
      _selectedYouTubeEmbedIds = {};
      _selectedGroupShapeIds = {};
    });
  }

  void _armShape(BoardShapeType? type) {
    if (!_activeShapeLayer.isVisible) return;
    setState(() {
      _armedShapeType = type;
      _isCircleArmed = false;
      _shapePreview = null;
    });
  }

  void _armCircle() {
    _armShape(BoardShapeType.ellipse);
    setState(() => _isCircleArmed = true);
  }

  Offset _snapShapePoint(Offset point) {
    if (!_isSnappingEnabled) return point;
    const spacing = LayeredCanvasPaperPainter.minorSpacing;
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final threshold = 8 / scale;
    double snap(double value, Iterable<double> peers) {
      final grid = (value / spacing).round() * spacing;
      final gridDistance = (grid - value).abs();
      var best = gridDistance <= threshold ? grid.toDouble() : value;
      var distance = gridDistance <= threshold ? gridDistance : threshold;
      for (final peer in peers) {
        final candidateDistance = (peer - value).abs();
        if (candidateDistance <= threshold && candidateDistance <= distance) {
          best = peer;
          distance = candidateDistance;
        }
      }
      return best;
    }

    final peers = [
      for (final entry in _visibleObjectBounds.entries)
        if (entry.key != _selectedShapeId) entry.value,
    ];
    return Offset(
      snap(point.dx, [
        for (final bounds in peers) ...[
          bounds.left,
          bounds.center.dx,
          bounds.right,
        ],
      ]),
      snap(point.dy, [
        for (final bounds in peers) ...[
          bounds.top,
          bounds.center.dy,
          bounds.bottom,
        ],
      ]),
    );
  }

  BoardShape _shapeFromEndpoints({
    required BoardShapeType type,
    required Offset start,
    required Offset end,
    String? id,
    DateTime? createdAt,
    bool inferClosedCrossAxis = false,
  }) {
    var targetEnd = end;
    if (inferClosedCrossAxis &&
        type == BoardShapeType.ellipse &&
        _isCircleArmed) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final side = math.max(dx.abs(), dy.abs());
      final xDirection = dx < 0 ? -1.0 : 1.0;
      final yDirection = dy < 0 ? -1.0 : 1.0;
      final availableX = xDirection < 0 ? start.dx : _canvasWidth - start.dx;
      final availableY = yDirection < 0 ? start.dy : _canvasHeight - start.dy;
      final fitted = math.min(side, math.min(availableX, availableY));
      targetEnd = Offset(
        start.dx + fitted * xDirection,
        start.dy + fitted * yDirection,
      );
    }
    if (inferClosedCrossAxis &&
        !_isCircleArmed &&
        (type.supportsFill ||
            type == BoardShapeType.curvedLine ||
            type == BoardShapeType.multiBendLine)) {
      final delta = end - start;
      final horizontal = delta.dx.abs();
      final vertical = delta.dy.abs();
      if (horizontal >= BoardShape.minimumClosedWidth &&
          vertical < BoardShape.minimumClosedHeight) {
        final inferred = math.max(
          BoardShape.minimumClosedHeight,
          horizontal * 0.6,
        );
        final direction = delta.dy < 0
            ? -1.0
            : start.dy + inferred <= _canvasHeight
            ? 1.0
            : -1.0;
        targetEnd = Offset(end.dx, start.dy + inferred * direction);
      } else if (vertical >= BoardShape.minimumClosedHeight &&
          horizontal < BoardShape.minimumClosedWidth) {
        final inferred = math.max(
          BoardShape.minimumClosedWidth,
          vertical / 0.6,
        );
        final direction = delta.dx < 0
            ? -1.0
            : start.dx + inferred <= _canvasWidth
            ? 1.0
            : -1.0;
        targetEnd = Offset(start.dx + inferred * direction, end.dy);
      }
    }
    final first = Offset(
      start.dx.clamp(0, _canvasWidth).toDouble(),
      start.dy.clamp(0, _canvasHeight).toDouble(),
    );
    final second = Offset(
      targetEnd.dx.clamp(0, _canvasWidth).toDouble(),
      targetEnd.dy.clamp(0, _canvasHeight).toDouble(),
    );
    final rect = Rect.fromPoints(first, second);
    final now = DateTime.now().toUtc();
    final sameDiagonal =
        (first.dx <= second.dx && first.dy <= second.dy) ||
        (first.dx >= second.dx && first.dy >= second.dy);
    final baseStart = sameDiagonal ? rect.topLeft : rect.topRight;
    final reversed = (baseStart - first).distance > 0.01;
    return BoardShape(
      id: id ?? _uuid.v4(),
      type: type,
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
      lineStartsAtTopLeft: sameDiagonal,
      lineReversed: reversed,
      fillColorValue: _shapeFillColorValue,
      fillOpacity: type.supportsFill ? _shapeFillOpacity : 0,
      outlineColorValue: _shapeOutlineColorValue,
      outlineWidth: _shapeOutlineWidth,
      heading: null,
      createdAt: createdAt ?? now,
      modifiedAt: now,
    );
  }

  bool _shapeHasUsefulSize(BoardShape shape) => shape.isOpen
      ? math.sqrt(shape.width * shape.width + shape.height * shape.height) >=
            BoardShape.minimumLineLength
      : shape.width >= BoardShape.minimumClosedWidth &&
            shape.height >= BoardShape.minimumClosedHeight;

  void _handleShapePointerDown(PointerDownEvent event) {
    if (!_isShapesMode ||
        !_activeShapeLayer.isVisible ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final rawPoint = _transformationController.toScene(event.localPosition);
    final armed = _armedShapeType;
    final point = armed == null ? rawPoint : _snapShapePoint(rawPoint);
    _shapePointerStart = point;
    if (armed != null) {
      _shapeGestureMode = _ShapeGestureMode.drawing;
      setState(
        () => _shapePreview = _shapeFromEndpoints(
          type: armed,
          start: point,
          end: point,
          inferClosedCrossAxis: true,
        ),
      );
      return;
    }
    final selected = _selectedShape;
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (selected != null) {
      final handles = shapeHandlePositions(selected);
      for (var index = 0; index < handles.length; index++) {
        if ((handles[index] - point).distance <= 10 / scale) {
          _shapeGestureMode = _ShapeGestureMode.resizing;
          _shapeResizeHandle = index;
          _shapeAtGestureStart = selected;
          _pendingShapeGestureSnapshot = _captureSnapshot();
          return;
        }
      }
      if ((shapeMoveHandlePosition(selected) - point).distance <= 14 / scale) {
        _shapeGestureMode = _ShapeGestureMode.moving;
        _shapeAtGestureStart = selected;
        _pendingShapeGestureSnapshot = _captureSnapshot();
        return;
      }
    }
    BoardShape? hit;
    for (final shape in _activeLayerShapes.reversed) {
      if (ShapeDefinition.forType(
        shape.type,
      ).hitTest(shape, point, 8 / scale)) {
        hit = shape;
        break;
      }
    }
    setState(() => _selectedShapeId = hit?.id);
    if (hit != null) {
      final now = DateTime.now();
      final isDoubleTap =
          hit.heading != null &&
          _lastShapeTapId == hit.id &&
          _lastShapeTapAt != null &&
          now.difference(_lastShapeTapAt!) <= const Duration(milliseconds: 350);
      _lastShapeTapAt = now;
      _lastShapeTapId = hit.id;
      if (isDoubleTap) {
        _shapePointerStart = null;
        unawaited(_editShapeHeading());
        return;
      }
      _shapeGestureMode = _ShapeGestureMode.moving;
      _shapeAtGestureStart = hit;
      _pendingShapeGestureSnapshot = _captureSnapshot();
    }
  }

  void _handleShapePointerMove(PointerMoveEvent event) {
    if (!_isShapesMode || _shapeGestureMode == null) return;
    final rawPoint = _transformationController.toScene(event.localPosition);
    final point = _shapeGestureMode == _ShapeGestureMode.moving
        ? rawPoint
        : _snapShapePoint(rawPoint);
    final start = _shapePointerStart;
    if (start == null) return;
    switch (_shapeGestureMode!) {
      case _ShapeGestureMode.drawing:
        final type = _armedShapeType;
        if (type != null) {
          setState(
            () => _shapePreview = _shapeFromEndpoints(
              type: type,
              start: start,
              end: point,
              inferClosedCrossAxis: true,
            ),
          );
        }
      case _ShapeGestureMode.moving:
        final original = _shapeAtGestureStart;
        if (original == null) return;
        var delta = point - start;
        var guides = const <CanvasSnapGuide>[];
        if (_isSnappingEnabled) {
          final result = CanvasSnapResolver.resolve(
            movingBounds: Rect.fromLTWH(
              original.x,
              original.y,
              original.width,
              original.height,
            ),
            desiredDelta: delta,
            peerBounds: [
              for (final entry in _visibleObjectBounds.entries)
                if (entry.key != original.id) entry.value,
            ],
            viewportScale: _transformationController.value.getMaxScaleOnAxis(),
            canvasSize: const Size(_canvasWidth, _canvasHeight),
            gridSpacing: LayeredCanvasPaperPainter.minorSpacing,
          );
          delta = result.delta;
          guides = result.guides;
        }
        final x = (original.x + delta.dx)
            .clamp(0.0, _canvasWidth - original.width)
            .toDouble();
        final y = (original.y + delta.dy)
            .clamp(0.0, _canvasHeight - original.height)
            .toDouble();
        setState(() {
          _snapGuides = guides;
          _replaceShapeLocally(
            original.copyWith(x: x, y: y, modifiedAt: DateTime.now().toUtc()),
          );
        });
      case _ShapeGestureMode.resizing:
        final original = _shapeAtGestureStart;
        if (original == null) return;
        _resizeShapeFromHandle(original, _shapeResizeHandle!, point);
    }
  }

  void _replaceShapeLocally(BoardShape replacement) {
    _shapes = [
      for (final shape in _shapes)
        if (shape.id == replacement.id) replacement else shape,
    ];
  }

  void _resizeShapeFromHandle(BoardShape original, int handle, Offset point) {
    if (original.isOpen) {
      final definition = ShapeDefinition.forType(original.type);
      final endpoints = definition.lineEndpoints(original);
      if (original.isOrthogonal && handle == 1) {
        final start = endpoints.$1;
        final end = endpoints.$2;
        final denominator =
            original.routeAxis == OrthogonalRouteAxis.horizontalFirst
            ? end.dx - start.dx
            : end.dy - start.dy;
        if (denominator.abs() < 0.01) return;
        final coordinate =
            original.routeAxis == OrthogonalRouteAxis.horizontalFirst
            ? point.dx
            : point.dy;
        final origin = original.routeAxis == OrthogonalRouteAxis.horizontalFirst
            ? start.dx
            : start.dy;
        final spinePosition = ((coordinate - origin) / denominator)
            .clamp(0.0, 1.0)
            .toDouble();
        setState(
          () => _replaceShapeLocally(
            original.copyWith(
              spinePosition: spinePosition,
              modifiedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        return;
      }
      final start = handle == 0 ? point : endpoints.$1;
      final end = handle == (original.isOrthogonal ? 2 : 1)
          ? point
          : endpoints.$2;
      final resized =
          _shapeFromEndpoints(
            type: original.type,
            start: start,
            end: end,
            id: original.id,
            createdAt: original.createdAt,
          ).copyWith(
            routeAxis: original.routeAxis,
            spinePosition: original.spinePosition,
            fillColorValue: original.fillColorValue,
            fillOpacity: original.fillOpacity,
            outlineColorValue: original.outlineColorValue,
            outlineWidth: original.outlineWidth,
            heading: original.heading,
          );
      if (_shapeHasUsefulSize(resized)) {
        setState(() => _replaceShapeLocally(resized));
      }
      return;
    }
    var left = original.x;
    var top = original.y;
    var right = original.x + original.width;
    var bottom = original.y + original.height;
    if ({0, 7, 6}.contains(handle)) {
      left = point.dx
          .clamp(0, right - BoardShape.minimumClosedWidth)
          .toDouble();
    }
    if ({2, 3, 4}.contains(handle)) {
      right = point.dx
          .clamp(left + BoardShape.minimumClosedWidth, _canvasWidth)
          .toDouble();
    }
    if ({0, 1, 2}.contains(handle)) {
      top = point.dy
          .clamp(0, bottom - BoardShape.minimumClosedHeight)
          .toDouble();
    }
    if ({4, 5, 6}.contains(handle)) {
      bottom = point.dy
          .clamp(top + BoardShape.minimumClosedHeight, _canvasHeight)
          .toDouble();
    }
    setState(
      () => _replaceShapeLocally(
        original.copyWith(
          x: left,
          y: top,
          width: right - left,
          height: bottom - top,
          modifiedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  void _handleShapePointerUp(PointerEvent event) {
    final mode = _shapeGestureMode;
    if (mode == null) return;
    if (mode == _ShapeGestureMode.drawing) {
      final preview = _shapePreview;
      if (preview != null && _shapeHasUsefulSize(preview)) {
        _recordUndoSnapshot(_captureSnapshot());
        setState(() {
          _shapes = [..._shapes, preview];
          _replaceShapeLayerLocally(
            _activeShapeLayer.copyWith(
              shapeIds: [..._activeShapeLayer.shapeIds, preview.id],
              modifiedAt: DateTime.now().toUtc(),
            ),
          );
          _selectedShapeId = preview.id;
          _shapePreview = null;
          _armedShapeType = null;
          _isCircleArmed = false;
        });
        _markBoardChanged();
      } else {
        setState(() => _shapePreview = null);
      }
    } else if (_shapeAtGestureStart != null &&
        _selectedShape != _shapeAtGestureStart &&
        _pendingShapeGestureSnapshot != null) {
      _recordUndoSnapshot(_pendingShapeGestureSnapshot!);
      _markBoardChanged();
    }
    _shapePointerStart = null;
    _shapeAtGestureStart = null;
    _shapeGestureMode = null;
    _shapeResizeHandle = null;
    _pendingShapeGestureSnapshot = null;
    if (_snapGuides.isNotEmpty) setState(() => _snapGuides = const []);
  }

  void _cancelShapeGesture() {
    final original = _shapeAtGestureStart;
    setState(() {
      if (original != null) _replaceShapeLocally(original);
      _shapePreview = null;
      _shapePointerStart = null;
      _shapeAtGestureStart = null;
      _shapeGestureMode = null;
      _shapeResizeHandle = null;
      _armedShapeType = null;
      _isCircleArmed = false;
      _pendingShapeGestureSnapshot = null;
      _snapGuides = const [];
    });
  }

  void _selectShape(String id) => setState(() {
    _selectedShapeId =
        _activeShapeLayer.isVisible && _activeShapeLayer.shapeIds.contains(id)
        ? id
        : null;
    _armedShapeType = null;
  });

  void _selectShapeLayer(String id) {
    final layer = _shapeLayers.where((layer) => layer.id == id).firstOrNull;
    if (layer == null || (_soloShapeLayerId != null && !layer.isVisible)) {
      return;
    }
    if (id == _activeShapeLayerId && _soloShapeLayerId == id) return;
    setState(() {
      _activeShapeLayerId = id;
      if (_soloShapeLayerId != null) _soloShapeLayerId = id;
      _selectedShapeId = null;
      _armedShapeType = null;
      _shapePreview = null;
    });
  }

  void _toggleSoloShapeLayer(String id) {
    final layer = _shapeLayers.where((layer) => layer.id == id).firstOrNull;
    if (layer == null || !layer.isVisible) return;
    setState(() {
      _soloShapeLayerId = _soloShapeLayerId == id ? null : id;
      _activeShapeLayerId = id;
      _selectedShapeId = null;
      _armedShapeType = null;
      _shapePreview = null;
      _shapePointerStart = null;
      _shapeAtGestureStart = null;
      _shapeGestureMode = null;
      _shapeResizeHandle = null;
      _pendingShapeGestureSnapshot = null;
    });
  }

  void _exitShapeLayerSolo() {
    if (_soloShapeLayerId == null) return;
    setState(() => _soloShapeLayerId = null);
  }

  void _addShapeLayer() {
    if (_soloShapeLayerId != null) return;
    final existing = {
      for (final layer in _shapeLayers) layer.name.toLowerCase(),
    };
    var number = 1;
    String name;
    do {
      name = 'Shape layer $number';
      number++;
    } while (existing.contains(name.toLowerCase()));
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    final layer = ShapeLayer(
      id: _uuid.v4(),
      name: name,
      shapeIds: const [],
      createdAt: now,
      modifiedAt: now,
    );
    setState(() {
      _shapeLayers = [..._shapeLayers, layer];
      _activeShapeLayerId = layer.id;
      _selectedShapeId = null;
      _armedShapeType = null;
    });
    _markBoardChanged();
  }

  void _toggleShapeLayerVisibility(String id) {
    if (_soloShapeLayerId != null) return;
    final layer = _shapeLayers
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (layer == null) return;
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _replaceShapeLayerLocally(
        layer.copyWith(
          isVisible: !layer.isVisible,
          modifiedAt: DateTime.now().toUtc(),
        ),
      );
      if (layer.id == _activeShapeLayerId) {
        _selectedShapeId = null;
        _armedShapeType = null;
        _shapePreview = null;
        _shapePointerStart = null;
        _shapeAtGestureStart = null;
        _shapeGestureMode = null;
        _shapeResizeHandle = null;
        _pendingShapeGestureSnapshot = null;
      }
    });
    _markBoardChanged();
  }

  void _setShapeLayerOpacity(String id, double opacity) {
    final layer = _shapeLayers
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (layer == null ||
        !layer.isVisible ||
        !ShapeLayer.supportedOpacities.contains(opacity) ||
        layer.opacity == opacity) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _replaceShapeLayerLocally(
        layer.copyWith(opacity: opacity, modifiedAt: DateTime.now().toUtc()),
      );
      _activeShapeLayerId = layer.id;
      if (_soloShapeLayerId != null) _soloShapeLayerId = layer.id;
      _selectedShapeId = null;
      _armedShapeType = null;
      _shapePreview = null;
    });
    _markBoardChanged();
  }

  Future<void> _renameActiveShapeLayer() async {
    final active = _activeShapeLayer;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _ShapeLayerNameDialog(
        initialName: active.name,
        unavailableNames: {
          for (final layer in _shapeLayers)
            if (layer.id != active.id) layer.name.toLowerCase(),
        },
      ),
    );
    if (!mounted || name == null || name == active.name) {
      _restoreShortcutFocus();
      return;
    }
    if (_activeShapeLayerId != active.id) {
      _restoreShortcutFocus();
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    setState(
      () => _replaceShapeLayerLocally(
        active.copyWith(name: name, modifiedAt: DateTime.now().toUtc()),
      ),
    );
    _markBoardChanged();
    _restoreShortcutFocus();
  }

  void _moveActiveShapeLayer(int offset) {
    final index = _shapeLayers.indexWhere(
      (layer) => layer.id == _activeShapeLayerId,
    );
    final target = index + offset;
    if (index < 0 || target < 0 || target >= _shapeLayers.length) return;
    _recordUndoSnapshot(_captureSnapshot());
    final reordered = List<ShapeLayer>.of(_shapeLayers);
    final active = reordered[index].copyWith(
      modifiedAt: DateTime.now().toUtc(),
    );
    reordered[index] = reordered[target];
    reordered[target] = active;
    setState(() => _shapeLayers = reordered);
    _markBoardChanged();
  }

  void _deleteActiveShapeLayer() {
    if (_soloShapeLayerId != null) return;
    final active = _activeShapeLayer;
    if (_shapeLayers.length <= 1 || active.shapeIds.isNotEmpty) return;
    final index = _shapeLayers.indexOf(active);
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      _shapeLayers = _shapeLayers
          .where((layer) => layer.id != active.id)
          .toList();
      _activeShapeLayerId =
          _shapeLayers[math.min(index, _shapeLayers.length - 1)].id;
      _selectedShapeId = null;
      _armedShapeType = null;
    });
    _markBoardChanged();
  }

  void _moveSelectedShapeToLayer(String targetLayerId) {
    final selected = _selectedShape;
    final source = _activeShapeLayer;
    final target = _shapeLayers
        .where((layer) => layer.id == targetLayerId)
        .firstOrNull;
    if (selected == null ||
        target == null ||
        !target.isVisible ||
        target.id == source.id) {
      return;
    }
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _replaceShapeLayerLocally(
        source.copyWith(
          shapeIds: source.shapeIds.where((id) => id != selected.id).toList(),
          modifiedAt: now,
        ),
      );
      _replaceShapeLayerLocally(
        target.copyWith(
          shapeIds: [...target.shapeIds, selected.id],
          modifiedAt: now,
        ),
      );
      _activeShapeLayerId = target.id;
      if (_soloShapeLayerId != null) _soloShapeLayerId = target.id;
      _selectedShapeId = selected.id;
      _armedShapeType = null;
    });
    _markBoardChanged();
  }

  void _deleteSelectedShape() {
    final selected = _selectedShape;
    if (selected == null) return;
    _recordUndoSnapshot(_captureSnapshot());
    final now = DateTime.now().toUtc();
    setState(() {
      _shapes = _shapes.where((shape) => shape.id != selected.id).toList();
      _replaceShapeLayerLocally(
        _activeShapeLayer.copyWith(
          shapeIds: _activeShapeLayer.shapeIds
              .where((id) => id != selected.id)
              .toList(),
          modifiedAt: now,
        ),
      );
      final group = _groupForObject(selected.id);
      if (group != null) {
        final remaining = group.memberIds
            .where((id) => id != selected.id)
            .toList();
        _groups = [
          for (final candidate in _groups)
            if (candidate.id != group.id)
              candidate
            else if (remaining.length >= 2)
              candidate.copyWith(memberIds: remaining, modifiedAt: now),
        ];
      }
      _selectedShapeId = null;
    });
    _markBoardChanged();
  }

  void _moveSelectedShapeInLayer(int offset) {
    final selected = _selectedShape;
    if (selected == null) return;
    final ids = _activeShapeLayer.shapeIds;
    final index = ids.indexOf(selected.id);
    final target = index + offset;
    if (target < 0 || target >= ids.length) return;
    _recordUndoSnapshot(_captureSnapshot());
    setState(() {
      final reordered = List<String>.of(ids);
      final displaced = reordered[target];
      reordered[target] = reordered[index];
      reordered[index] = displaced;
      _replaceShapeLayerLocally(
        _activeShapeLayer.copyWith(
          shapeIds: reordered,
          modifiedAt: DateTime.now().toUtc(),
        ),
      );
    });
    _markBoardChanged();
  }

  void _updateSelectedShape(BoardShape Function(BoardShape) update) {
    final selected = _selectedShape;
    if (selected == null) return;
    _recordUndoSnapshot(_captureSnapshot());
    setState(() => _replaceShapeLocally(update(selected)));
    _markBoardChanged();
  }

  Future<void> _editShapeHeading() async {
    final selected = _selectedShape;
    if (selected == null) return;
    final text = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ShapeHeadingDialog(initialText: selected.heading?.text),
    );
    if (!mounted || text == null) return;
    final current = _selectedShape;
    if (current == null) return;
    final existing = current.heading;
    final heading =
        existing?.copyWith(text: text) ??
        ShapeHeading(
          text: text,
          colorValue: widget.isDarkMode ? 0xFFFFFFFF : 0xFF000000,
          placement: current.isOpen
              ? ShapeHeadingPlacement.above
              : ShapeHeadingPlacement.insideTop,
        );
    _updateSelectedShape(
      (shape) =>
          shape.copyWith(heading: heading, modifiedAt: DateTime.now().toUtc()),
    );
  }

  void _removeShapeHeading() => _updateSelectedShape(
    (shape) =>
        shape.copyWith(removeHeading: true, modifiedAt: DateTime.now().toUtc()),
  );

  void _updateShapeHeading(ShapeHeading Function(ShapeHeading) update) {
    final heading = _selectedShape?.heading;
    if (heading == null) return;
    _updateSelectedShape(
      (shape) => shape.copyWith(
        heading: update(heading),
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _chooseShapeColor(_ShapeColorTarget target) async {
    final shape = _selectedShape;
    if (shape == null) return;
    final initial = switch (target) {
      _ShapeColorTarget.fill => shape.fillColorValue,
      _ShapeColorTarget.outline => shape.outlineColorValue,
      _ShapeColorTarget.heading => shape.heading?.colorValue ?? 0xFF263238,
    };
    final value = await showShapeColorDialog(context, initial);
    if (!mounted || value == null) return;
    switch (target) {
      case _ShapeColorTarget.fill:
        _shapeFillColorValue = value;
        final fillOpacity = shape.fillOpacity == 0 ? 1.0 : shape.fillOpacity;
        _shapeFillOpacity = fillOpacity;
        _updateSelectedShape(
          (shape) => shape.copyWith(
            fillColorValue: value,
            fillOpacity: fillOpacity,
            modifiedAt: DateTime.now().toUtc(),
          ),
        );
      case _ShapeColorTarget.outline:
        _shapeOutlineColorValue = value;
        _updateSelectedShape(
          (shape) => shape.copyWith(
            outlineColorValue: value,
            modifiedAt: DateTime.now().toUtc(),
          ),
        );
      case _ShapeColorTarget.heading:
        _updateShapeHeading((heading) => heading.copyWith(colorValue: value));
    }
  }

  void _beginShapeFillOpacity() {
    if (_selectedShape != null) {
      _pendingShapeStyleSnapshot = _captureSnapshot();
    }
  }

  void _changeShapeFillOpacity(double value) {
    final selected = _selectedShape;
    if (selected == null) return;
    _shapeFillOpacity = value;
    setState(
      () => _replaceShapeLocally(
        selected.copyWith(
          fillOpacity: value,
          modifiedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  void _endShapeFillOpacity() {
    final snapshot = _pendingShapeStyleSnapshot;
    _pendingShapeStyleSnapshot = null;
    if (snapshot == null) return;
    _recordUndoSnapshot(snapshot);
    _markBoardChanged();
  }

  bool _isBlankCanvasPosition(Offset viewportPosition) {
    final scenePosition = _transformationController.toScene(viewportPosition);
    final selectedGroupBounds = _selectedGroupBounds;
    if (selectedGroupBounds != null &&
        Rect.fromCenter(
          center: selectedGroupBounds.center,
          width: 30,
          height: 30,
        ).contains(scenePosition)) {
      return false;
    }
    final objectBounds = _objectBounds;
    if (objectBounds.values.any((bounds) => bounds.contains(scenePosition))) {
      return false;
    }

    final scale = _transformationController.value.getMaxScaleOnAxis();
    final connectorHitDistance = 12 / scale;
    for (final connector in _connectors) {
      final first = objectBounds[connector.objectAId];
      final second = objectBounds[connector.objectBId];
      if (first == null || second == null) {
        continue;
      }
      final segment = ConnectorGeometry.betweenRects(first, second);
      if (_distanceToSegment(scenePosition, segment.start, segment.end) <=
          connectorHitDistance) {
        return false;
      }
    }
    return true;
  }

  void _handleCanvasHover(PointerHoverEvent event) {
    if (_isShapesMode) {
      if (_isPointerOverNoteBody) {
        setState(() => _isPointerOverNoteBody = false);
      }
      return;
    }
    final canvasPosition = _transformationController.toScene(
      event.localPosition,
    );
    final isOverNoteBody = _notes.any((note) {
      final bodyHeight = note.height - EditableNote.headerHeight;
      return bodyHeight > 0 &&
          Rect.fromLTWH(
            note.x,
            note.y + EditableNote.headerHeight,
            note.width,
            bodyHeight,
          ).contains(canvasPosition);
    });
    if (_isPointerOverNoteBody != isOverNoteBody) {
      setState(() => _isPointerOverNoteBody = isOverNoteBody);
    }
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    if (segment.distanceSquared == 0) {
      return (point - start).distance;
    }
    final projection =
        ((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
        segment.distanceSquared;
    final nearest = start + segment * projection.clamp(0.0, 1.0);
    return (point - nearest).distance;
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    if (!_isShapesMode &&
        !_isLoading &&
        event.kind == PointerDeviceKind.mouse &&
        event.buttons == kPrimaryMouseButton &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        _isBlankCanvasPosition(event.localPosition)) {
      final point = _transformationController.toScene(event.localPosition);
      final scale = _transformationController.value.getMaxScaleOnAxis();
      final hit = _visibleOrderedShapes.reversed
          .where(
            (shape) => ShapeDefinition.forType(
              shape.type,
            ).hitTest(shape, point, 8 / scale),
          )
          .firstOrNull;
      if (hit != null) {
        _toggleShapesMode();
        _selectShapeLayer(_shapeLayerIdFor(hit.id)!);
      }
    }
    if (_isShapesMode && event.buttons == kPrimaryMouseButton) {
      _handleShapePointerDown(event);
      return;
    }
    if (event.kind != PointerDeviceKind.mouse ||
        _canvasPointer != null ||
        (!_isShapesMode && !_isBlankCanvasPosition(event.localPosition))) {
      return;
    }
    final mode = switch (event.buttons) {
      kPrimaryMouseButton => _CanvasPointerMode.primaryCandidate,
      kSecondaryMouseButton => _CanvasPointerMode.secondaryCandidate,
      _ => null,
    };
    if (mode == null) {
      return;
    }
    _canvasPointer = event.pointer;
    _canvasPointerMode = mode;
    _canvasPointerStart = event.localPosition;
    _canvasPointerLast = event.localPosition;
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    if (_isShapesMode && _shapeGestureMode != null) {
      _handleShapePointerMove(event);
      return;
    }
    if (event.pointer != _canvasPointer) {
      return;
    }
    final start = _canvasPointerStart;
    final last = _canvasPointerLast;
    var mode = _canvasPointerMode;
    if (start == null || last == null || mode == null) {
      return;
    }

    if (mode == _CanvasPointerMode.primaryCandidate ||
        mode == _CanvasPointerMode.secondaryCandidate) {
      if ((event.localPosition - start).distance < _canvasDragThreshold) {
        _canvasPointerLast = event.localPosition;
        return;
      }
      if (mode == _CanvasPointerMode.primaryCandidate) {
        _finishTextEditing();
        mode = _CanvasPointerMode.marquee;
        setState(() {
          _canvasPointerMode = mode;
          _marqueeStart = start;
          _marqueeCurrent = event.localPosition;
        });
      } else {
        mode = _CanvasPointerMode.panning;
        _canvasPointerMode = mode;
        _panCanvas(event.localPosition - start);
      }
    } else if (mode == _CanvasPointerMode.marquee) {
      setState(() => _marqueeCurrent = event.localPosition);
    } else if (mode == _CanvasPointerMode.panning) {
      _panCanvas(event.localPosition - last);
    }
    _canvasPointerLast = event.localPosition;
  }

  void _panCanvas(Offset delta) {
    final transform = Matrix4.copy(_transformationController.value);
    transform.setTranslationRaw(
      transform.storage[12] + delta.dx,
      transform.storage[13] + delta.dy,
      transform.storage[14],
    );
    _transformationController.value = transform;
  }

  void _handleCanvasPointerUp(PointerEvent event) {
    if (_isShapesMode && _shapeGestureMode != null) {
      _handleShapePointerUp(event);
      return;
    }
    if (event.pointer != _canvasPointer) {
      return;
    }
    final mode = _canvasPointerMode;
    if (mode == _CanvasPointerMode.marquee) {
      _completeMarquee();
    } else if (mode == _CanvasPointerMode.panning) {
      _markBoardChanged();
    }
    _resetCanvasPointer();
  }

  void _handleCanvasPointerCancel(PointerEvent event) {
    if (_isShapesMode && _shapeGestureMode != null) {
      _cancelShapeGesture();
      return;
    }
    if (event.pointer != _canvasPointer) {
      return;
    }
    final wasPanning = _canvasPointerMode == _CanvasPointerMode.panning;
    _cancelMarquee();
    _resetCanvasPointer();
    if (wasPanning) {
      _markBoardChanged();
    }
  }

  void _completeMarquee() {
    final viewportRect = _marqueeRect;
    if (viewportRect == null) {
      return;
    }
    final sceneRect = Rect.fromPoints(
      _transformationController.toScene(viewportRect.topLeft),
      _transformationController.toScene(viewportRect.bottomRight),
    );
    bool touches(Rect bounds) =>
        sceneRect.left <= bounds.right &&
        sceneRect.right >= bounds.left &&
        sceneRect.top <= bounds.bottom &&
        sceneRect.bottom >= bounds.top;

    _finishTextEditing();
    final selectedIds = <String>{
      for (final note in _notes)
        if (!_hiddenGroupMemberIds.contains(note.id) &&
            touches(Rect.fromLTWH(note.x, note.y, note.width, note.height)))
          note.id,
      for (final image in _images)
        if (!_hiddenGroupMemberIds.contains(image.id) &&
            touches(Rect.fromLTWH(image.x, image.y, image.width, image.height)))
          image.id,
      for (final heading in _headings)
        if (!_hiddenGroupMemberIds.contains(heading.id) &&
            touches(CanvasHeadingGeometry.boundsFor(heading)))
          heading.id,
      for (final attachment in _attachments)
        if (!_hiddenGroupMemberIds.contains(attachment.id) &&
            touches(
              Rect.fromLTWH(
                attachment.x,
                attachment.y,
                attachment.width,
                attachment.height,
              ),
            ))
          attachment.id,
      for (final embed in _youTubeEmbeds)
        if (!_hiddenGroupMemberIds.contains(embed.id) &&
            touches(Rect.fromLTWH(embed.x, embed.y, embed.width, embed.height)))
          embed.id,
    };
    for (final id in List<String>.of(selectedIds)) {
      selectedIds.addAll(_selectionUnitFor(id));
    }
    setState(() {
      _replaceObjectSelection(selectedIds);
      _editingNoteId = null;
      _marqueeStart = null;
      _marqueeCurrent = null;
    });
  }

  void _cancelMarquee() {
    if (_canvasPointerMode != _CanvasPointerMode.marquee) {
      return;
    }
    setState(() {
      _canvasPointerMode = _CanvasPointerMode.cancelled;
      _marqueeStart = null;
      _marqueeCurrent = null;
    });
  }

  void _resetCanvasPointer() {
    _canvasPointer = null;
    _canvasPointerMode = null;
    _canvasPointerStart = null;
    _canvasPointerLast = null;
    if (_marqueeStart != null || _marqueeCurrent != null) {
      setState(() {
        _marqueeStart = null;
        _marqueeCurrent = null;
      });
    }
  }

  void _clearSelection() {
    if (_selectedNoteIds.isNotEmpty ||
        _selectedImageIds.isNotEmpty ||
        _selectedHeadingIds.isNotEmpty ||
        _selectedAttachmentIds.isNotEmpty ||
        _selectedYouTubeEmbedIds.isNotEmpty ||
        _editingNoteId != null ||
        _snapGuides.isNotEmpty) {
      _finishTextEditing();
      setState(() {
        _selectedNoteIds = {};
        _selectedImageIds = {};
        _selectedHeadingIds = {};
        _selectedAttachmentIds = {};
        _selectedYouTubeEmbedIds = {};
        _editingNoteId = null;
        _snapGuides = const [];
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _cancelSceneTransition();
    _sceneTransitionController.dispose();
    if (!_loadFailed && _hasUnsavedChanges && !_isSaving) {
      unawaited(
        widget.boardStore
            .save(_currentBoardDocument())
            .catchError((Object _, StackTrace _) {}),
      );
    }
    _transformationController.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Could not open saved board')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your stored Board has not been replaced. Check that its '
                  'folder is available, or restore a verified exported backup.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadBoard,
                  child: const Text('Retry opening'),
                ),
                if (widget.onReturnToLibrary != null)
                  TextButton(
                    onPressed: _returnToLibrary,
                    child: const Text('Return to Library'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return AbsorbPointer(absorbing: _isClosing, child: _buildEditor(context));
  }

  Widget _buildEditor(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
              _invokeShortcut(_undo),
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
              _invokeShortcut(_redo),
        if (_editingNoteId == null)
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): () =>
              _invokeShortcut(_redo),
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.keyC, control: true): () =>
              _invokeShortcut(_copySelection),
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
              _invokeShortcut(_pasteClipboard),
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.delete): () =>
              _invokeShortcut(_deleteSelection),
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              _invokeShortcut(_showFindOnBoardDialog),
        if (_editingNoteId == null)
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_isShapesMode) {
              _cancelShapeGesture();
            } else {
              _cancelMarquee();
            }
          },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _invokeShortcut(_saveBoard),
      },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: Scaffold(
          bottomNavigationBar: _isClosing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Saving your changes before closing…'),
                )
              : _storageError != null && !_isLoading
              ? MaterialBanner(
                  content: const Text(
                    'Your latest changes have not been saved. '
                    'Keep Vasmim open, check disk space and folder access, '
                    'then retry.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: _isSaving ? null : _saveBoard,
                      child: const Text('Retry save'),
                    ),
                  ],
                )
              : _recoveredFromBackup
              ? MaterialBanner(
                  content: const Text(
                    'Recovered the previous saved copy. '
                    'Check your most recent edits. The original file is preserved.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _recoveredFromBackup = false),
                      child: const Text('Understood'),
                    ),
                  ],
                )
              : null,
          appBar: AppBar(
            title: GestureDetector(
              onDoubleTap: _showRenameBoardDialog,
              child: Text(
                _boardName,
                key: const ValueKey('active-board-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: [
              if (widget.onToggleDarkMode != null)
                IconButton(
                  key: const ValueKey('board-appearance-toggle'),
                  tooltip: widget.isDarkMode
                      ? 'Use light mode'
                      : 'Use dark mode',
                  onPressed: widget.onToggleDarkMode,
                  icon: Icon(
                    widget.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              IconButton(
                key: const ValueKey('rename-active-board-button'),
                onPressed: _isLoading || _isSaving
                    ? null
                    : _showRenameBoardDialog,
                tooltip: 'Rename board',
                icon: const Icon(Icons.edit_outlined),
              ),
              if (widget.onReturnToLibrary != null)
                IconButton(
                  key: const ValueKey('return-to-library-button'),
                  onPressed: _isLoading || _isSaving ? null : _returnToLibrary,
                  tooltip: 'Return to board library',
                  icon: const Icon(Icons.arrow_back),
                ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width < 900 ? 0 : 4,
                  ),
                  child: Tooltip(
                    message: _saveStatus,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width < 900 ? 28 : 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _saveStatus,
                          key: const ValueKey('save-status'),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('save-board-button'),
                onPressed: _isLoading || _isSaving ? null : _saveBoard,
                tooltip: 'Save board now (Ctrl+S)',
                icon: const Icon(Icons.save_outlined),
              ),
              IconButton(
                key: const ValueKey('undo-button'),
                onPressed: _isLoading || _undoStack.isEmpty ? null : _undo,
                tooltip: 'Undo (Ctrl+Z)',
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const ValueKey('redo-button'),
                onPressed: _isLoading || _redoStack.isEmpty ? null : _redo,
                tooltip: 'Redo (Ctrl+Y or Ctrl+Shift+Z)',
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                key: const ValueKey('delete-note-button'),
                onPressed:
                    _isLoading ||
                        (_selectedNoteIds.isEmpty &&
                            _selectedImageIds.isEmpty &&
                            _selectedHeadingIds.isEmpty &&
                            _selectedAttachmentIds.isEmpty &&
                            _selectedYouTubeEmbedIds.isEmpty &&
                            _selectedShape == null)
                    ? null
                    : _deleteSelection,
                tooltip: _selectedImageIds.isEmpty
                    ? 'Delete selected notes (Delete)'
                    : 'Delete selection (Delete)',
                icon: const Icon(Icons.delete_outline),
              ),
              PopupMenuButton<NoteColor>(
                key: const ValueKey('note-color-button'),
                enabled: !_isLoading && _selectedNoteIds.isNotEmpty,
                tooltip: 'Change note colour',
                icon: const Icon(Icons.palette_outlined),
                onSelected: _changeSelectedNoteColor,
                itemBuilder: (context) => [
                  for (final color in NoteColor.values)
                    PopupMenuItem(
                      key: ValueKey('note-color-${color.name}'),
                      value: color,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: color.backgroundColor,
                              border: Border.all(color: color.borderColor),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(color.label),
                        ],
                      ),
                    ),
                ],
              ),
              PopupMenuButton<_ClipboardCommand>(
                key: const ValueKey('clipboard-menu-button'),
                enabled:
                    !_isLoading &&
                    (_selectedNoteIds.isNotEmpty ||
                        _selectedImageIds.isNotEmpty ||
                        _selectedHeadingIds.isNotEmpty ||
                        _selectedAttachmentIds.isNotEmpty ||
                        _selectedYouTubeEmbedIds.isNotEmpty ||
                        _selectedShape != null ||
                        _copiedNotes.isNotEmpty ||
                        _copiedImages.isNotEmpty ||
                        _copiedHeadings.isNotEmpty ||
                        _copiedAttachments.isNotEmpty ||
                        _copiedYouTubeEmbeds.isNotEmpty ||
                        _availableCrossBoardClipboard != null ||
                        (_copiedShape != null &&
                            (!_isShapesMode || _activeShapeLayer.isVisible))),
                tooltip: 'Copy or paste canvas objects (Ctrl+C / Ctrl+V)',
                icon: const Icon(Icons.content_copy_outlined),
                onSelected: _handleClipboardCommand,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    key: const ValueKey('copy-note-menu-item'),
                    value: _ClipboardCommand.copy,
                    enabled:
                        _selectedNoteIds.isNotEmpty ||
                        _selectedImageIds.isNotEmpty ||
                        _selectedHeadingIds.isNotEmpty ||
                        _selectedAttachmentIds.isNotEmpty ||
                        _selectedYouTubeEmbedIds.isNotEmpty ||
                        _selectedShape != null,
                    child: ListTile(
                      leading: const Icon(Icons.copy_outlined),
                      title: Text(_copySelectionLabel),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    key: const ValueKey('paste-note-menu-item'),
                    value: _ClipboardCommand.paste,
                    enabled:
                        _copiedNotes.isNotEmpty ||
                        _copiedImages.isNotEmpty ||
                        _copiedHeadings.isNotEmpty ||
                        _copiedAttachments.isNotEmpty ||
                        _copiedYouTubeEmbeds.isNotEmpty ||
                        _availableCrossBoardClipboard != null ||
                        (_copiedShape != null &&
                            (!_isShapesMode || _activeShapeLayer.isVisible)),
                    child: const ListTile(
                      leading: Icon(Icons.content_paste_outlined),
                      title: Text('Paste objects'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const ValueKey('scenes-button'),
                onPressed: _isLoading ? null : _showScenesDialog,
                tooltip: 'Saved scenes',
                icon: const Icon(Icons.bookmarks_outlined),
              ),
              IconButton(
                key: const ValueKey('fresh-pair-button'),
                onPressed:
                    _isLoading || !FreshPairSelector.canSelect(_visibleNotes)
                    ? null
                    : _showFreshPairDialog,
                tooltip: FreshPairSelector.canSelect(_visibleNotes)
                    ? 'Fresh Pair: surface two written notes'
                    : 'Add at least three written notes to use Fresh Pair',
                icon: const Icon(Icons.shuffle),
              ),
              IconButton(
                key: const ValueKey('zoom-to-fit-button'),
                onPressed:
                    _isLoading ||
                        (_visibleObjectBounds.isEmpty && _shapes.isEmpty)
                    ? null
                    : _zoomToFit,
                tooltip: _zoomToFitTooltip,
                icon: const Icon(Icons.fit_screen_outlined),
              ),
              IconButton(
                key: const ValueKey('shapes-mode-button'),
                onPressed: _isLoading ? null : _toggleShapesMode,
                tooltip: _isShapesMode ? 'Close Shapes mode' : 'Shapes',
                isSelected: _isShapesMode,
                icon: const Icon(Icons.category_outlined),
              ),
              IconButton(
                key: const ValueKey('groups-panel-button'),
                onPressed: _isLoading ? null : _toggleGroupsPanel,
                tooltip: _isGroupsPanelOpen ? 'Close Groups' : 'Groups',
                isSelected: _isGroupsPanelOpen,
                icon: const Icon(Icons.folder_copy_outlined),
              ),
              IconButton(
                key: const ValueKey('import-image-button'),
                onPressed: _isLoading || _isImportingImage
                    ? null
                    : _importImage,
                tooltip: 'Import PNG or JPEG image',
                icon: _isImportingImage
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
              ),
              IconButton(
                key: const ValueKey('import-attachment-button'),
                onPressed: _isLoading || _isImportingAttachment
                    ? null
                    : _importAttachment,
                tooltip: 'Import reference file',
                icon: _isImportingAttachment
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file_outlined),
              ),
              if (MediaQuery.sizeOf(context).width < 900)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    key: const ValueKey('create-note-button'),
                    onPressed: _isLoading ? null : _createNote,
                    tooltip: 'New note',
                    icon: const Icon(Icons.note_add_outlined),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    key: const ValueKey('create-note-button'),
                    onPressed: _isLoading ? null : _createNote,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('New note'),
                  ),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportSize = Size(
                      math.max(
                        0,
                        constraints.maxWidth -
                            (_isShapesMode
                                ? 320
                                : _isGroupsPanelOpen
                                ? 300
                                : 0),
                      ),
                      constraints.maxHeight,
                    );
                    final colorScheme = Theme.of(context).colorScheme;
                    return Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  key: const ValueKey(
                                    'canvas-interaction-surface',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _clearSelection,
                                  onSecondaryTapUp: _showCanvasContextMenu,
                                  child: Listener(
                                    onPointerHover: _handleCanvasHover,
                                    onPointerDown: _handleCanvasPointerDown,
                                    onPointerMove: (event) {
                                      _handleCanvasPointerMove(event);
                                      final imageId = _resizingImageId;
                                      if (imageId != null) {
                                        _resizeImage(imageId, event.position);
                                      }
                                    },
                                    onPointerUp: (event) {
                                      _handleCanvasPointerUp(event);
                                      _endResizingImage();
                                    },
                                    onPointerCancel: (event) {
                                      _handleCanvasPointerCancel(event);
                                      _endResizingImage();
                                    },
                                    child: RepaintBoundary(
                                      key: _currentViewExportBoundaryKey,
                                      child: ColoredBox(
                                        key: const ValueKey(
                                          'current-view-export-surface',
                                        ),
                                        color:
                                            LayeredCanvasPaperPainter.paperColorFor(
                                              _paperTone,
                                              isDark: widget.isDarkMode,
                                            ),
                                        child: InteractiveViewer(
                                          key: _viewportKey,
                                          transformationController:
                                              _transformationController,
                                          boundaryMargin: const EdgeInsets.all(
                                            double.infinity,
                                          ),
                                          constrained: false,
                                          minScale: 0.2,
                                          maxScale: 4,
                                          panEnabled: false,
                                          scaleEnabled:
                                              _resizingImageId == null &&
                                              !_isPointerOverNoteBody,
                                          onInteractionEnd: (_) =>
                                              _markBoardChanged(),
                                          child: RepaintBoundary(
                                            key: _wholeBoardExportBoundaryKey,
                                            child: SizedBox(
                                              key: const ValueKey(
                                                'whole-board-export-surface',
                                              ),
                                              width: _canvasWidth,
                                              height: _canvasHeight,
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: AnimatedBuilder(
                                                      animation:
                                                          _transformationController,
                                                      builder: (context, _) =>
                                                          CustomPaint(
                                                            painter: LayeredCanvasPaperPainter(
                                                              isDark: widget
                                                                  .isDarkMode,
                                                              tone: _paperTone,
                                                              viewportScale:
                                                                  _renderedViewportScale,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  if (_visibleOrderedShapes
                                                          .isNotEmpty ||
                                                      _shapePreview != null)
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        child: CustomPaint(
                                                          key: const ValueKey(
                                                            'background-shape-layer',
                                                          ),
                                                          painter: ShapeLayerPainter(
                                                            brightness:
                                                                Theme.of(
                                                                  context,
                                                                ).brightness,
                                                            shapes:
                                                                _visibleOrderedShapes,
                                                            opacityByShapeId:
                                                                _visibleShapeLayerOpacities,
                                                            preview:
                                                                _isExportingCurrentView
                                                                ? null
                                                                : _shapePreview,
                                                            previewOpacity:
                                                                _activeShapeLayer
                                                                    .opacity,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_visibleConnectors
                                                      .isNotEmpty)
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        child: AnimatedBuilder(
                                                          animation:
                                                              _transformationController,
                                                          builder: (context, child) {
                                                            return CustomPaint(
                                                              key: const ValueKey(
                                                                'connector-layer',
                                                              ),
                                                              painter: ConnectorPainter(
                                                                objectBounds:
                                                                    _visibleObjectBounds,
                                                                connectors:
                                                                    _visibleConnectors,
                                                                hoveredConnectorId:
                                                                    _isExportingCurrentView
                                                                    ? null
                                                                    : _hoveredConnectorId,
                                                                viewportScale:
                                                                    _renderedViewportScale,
                                                                isDark: widget
                                                                    .isDarkMode,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  if (_visibleConnectors
                                                      .isNotEmpty)
                                                    Positioned.fill(
                                                      child: AnimatedBuilder(
                                                        animation:
                                                            _transformationController,
                                                        builder: (context, child) {
                                                          final objectBounds =
                                                              _visibleObjectBounds;
                                                          final viewportScale =
                                                              _renderedViewportScale;
                                                          return Stack(
                                                            children: [
                                                              for (final connector
                                                                  in _visibleConnectors)
                                                                _ConnectionLineLabelTarget(
                                                                  connector:
                                                                      connector,
                                                                  segment: ConnectorGeometry.betweenRects(
                                                                    objectBounds[connector
                                                                        .objectAId]!,
                                                                    objectBounds[connector
                                                                        .objectBId]!,
                                                                  ),
                                                                  viewportScale:
                                                                      viewportScale,
                                                                  onTap: () =>
                                                                      _editConnectionLabel(
                                                                        connector,
                                                                      ),
                                                                  onSecondaryTapDown:
                                                                      (
                                                                        globalPosition,
                                                                      ) => _showConnectionContextMenu(
                                                                        globalPosition:
                                                                            globalPosition,
                                                                        connector:
                                                                            connector,
                                                                      ),
                                                                  onHoverChanged:
                                                                      (
                                                                        isHovered,
                                                                      ) => _setHoveredConnector(
                                                                        connector
                                                                            .id,
                                                                        isHovered,
                                                                      ),
                                                                ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  if (_visibleConnectors.any(
                                                    (connector) =>
                                                        connector.label != null,
                                                  ))
                                                    Positioned.fill(
                                                      child: AnimatedBuilder(
                                                        animation:
                                                            _transformationController,
                                                        builder: (context, child) {
                                                          final objectBounds =
                                                              _visibleObjectBounds;
                                                          final viewportScale =
                                                              _renderedViewportScale;
                                                          return Stack(
                                                            children: [
                                                              for (final connector
                                                                  in _visibleConnectors)
                                                                if (connector
                                                                        .label !=
                                                                    null)
                                                                  _ConnectionLabelView(
                                                                    connector:
                                                                        connector,
                                                                    segment: ConnectorGeometry.betweenRects(
                                                                      objectBounds[connector
                                                                          .objectAId]!,
                                                                      objectBounds[connector
                                                                          .objectBId]!,
                                                                    ),
                                                                    viewportScale:
                                                                        viewportScale,
                                                                    onTap: () =>
                                                                        _editConnectionLabel(
                                                                          connector,
                                                                        ),
                                                                    onSecondaryTapDown:
                                                                        (
                                                                          globalPosition,
                                                                        ) => _showConnectionContextMenu(
                                                                          globalPosition:
                                                                              globalPosition,
                                                                          connector:
                                                                              connector,
                                                                        ),
                                                                    onHoverChanged:
                                                                        (
                                                                          isHovered,
                                                                        ) => _setHoveredConnector(
                                                                          connector
                                                                              .id,
                                                                          isHovered,
                                                                        ),
                                                                  ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  for (final attachment
                                                      in _attachments)
                                                    if (!_hiddenGroupMemberIds
                                                        .contains(
                                                          attachment.id,
                                                        ))
                                                      Positioned(
                                                        key: ValueKey(
                                                          'positioned-attachment-${attachment.id}',
                                                        ),
                                                        left: attachment.x,
                                                        top: attachment.y,
                                                        child: InteractiveBoardAttachment(
                                                          key: ValueKey(
                                                            attachment.id,
                                                          ),
                                                          attachment:
                                                              attachment,
                                                          assetStore: widget
                                                              .imageAssetStore,
                                                          showMediaControls:
                                                              !_isExportingCurrentView &&
                                                              !_isExportingWholeBoard &&
                                                              !_isShapesMode,
                                                          isSelected:
                                                              !_isExportingCurrentView &&
                                                              _selectedAttachmentIds
                                                                  .contains(
                                                                    attachment
                                                                        .id,
                                                                  ),
                                                          onSelect: () =>
                                                              _selectAttachment(
                                                                attachment.id,
                                                              ),
                                                          onOpen: () =>
                                                              _openAttachment(
                                                                attachment,
                                                              ),
                                                          onSecondaryTapDown:
                                                              (
                                                                details,
                                                              ) => _showAttachmentContextMenu(
                                                                globalPosition:
                                                                    details
                                                                        .globalPosition,
                                                                attachment:
                                                                    attachment,
                                                              ),
                                                          onBeginMoving:
                                                              (position) =>
                                                                  _beginMovingAttachment(
                                                                    attachment
                                                                        .id,
                                                                    position,
                                                                  ),
                                                          onMove: (position) =>
                                                              _moveAttachment(
                                                                attachment.id,
                                                                position,
                                                              ),
                                                          onEndMoving:
                                                              _endMoving,
                                                        ),
                                                      ),
                                                  for (final embed
                                                      in _youTubeEmbeds)
                                                    if (!_hiddenGroupMemberIds
                                                        .contains(embed.id))
                                                      Positioned(
                                                        key: ValueKey(
                                                          'positioned-youtube-${embed.id}',
                                                        ),
                                                        left: embed.x,
                                                        top: embed.y,
                                                        child: InteractiveYouTubeEmbed(
                                                          key: ValueKey(
                                                            embed.id,
                                                          ),
                                                          embed: embed,
                                                          assetStore: widget
                                                              .imageAssetStore,
                                                          showInteractionChrome:
                                                              !_isExportingCurrentView &&
                                                              !_isExportingWholeBoard &&
                                                              !_isShapesMode,
                                                          isSelected:
                                                              !_isExportingCurrentView &&
                                                              _selectedYouTubeEmbedIds
                                                                  .contains(
                                                                    embed.id,
                                                                  ),
                                                          onSelect: () =>
                                                              _selectYouTubeEmbed(
                                                                embed.id,
                                                              ),
                                                          onOpen: () =>
                                                              _openYouTubeExternally(
                                                                embed,
                                                              ),
                                                          onSecondaryTapDown:
                                                              (
                                                                details,
                                                              ) => _showYouTubeContextMenu(
                                                                details
                                                                    .globalPosition,
                                                                embed,
                                                              ),
                                                          onBeginMoving:
                                                              (position) =>
                                                                  _beginMovingYouTubeEmbed(
                                                                    embed.id,
                                                                    position,
                                                                  ),
                                                          onMove: (position) =>
                                                              _moveYouTubeEmbed(
                                                                embed.id,
                                                                position,
                                                              ),
                                                          onEndMoving:
                                                              _endMoving,
                                                        ),
                                                      ),
                                                  for (final heading
                                                      in _headings)
                                                    if (!_hiddenGroupMemberIds
                                                        .contains(heading.id))
                                                      Positioned(
                                                        key: ValueKey(
                                                          'positioned-heading-${heading.id}',
                                                        ),
                                                        left: heading.x,
                                                        top: heading.y,
                                                        child: InteractiveCanvasHeading(
                                                          key: ValueKey(
                                                            heading.id,
                                                          ),
                                                          heading: heading,
                                                          isSelected:
                                                              !_isExportingCurrentView &&
                                                              _selectedHeadingIds
                                                                  .contains(
                                                                    heading.id,
                                                                  ),
                                                          showInteractionChrome:
                                                              !_isExportingCurrentView,
                                                          onSelect: () =>
                                                              _selectHeading(
                                                                heading.id,
                                                              ),
                                                          onEdit: () =>
                                                              _editHeading(
                                                                heading,
                                                              ),
                                                          onSecondaryTapDown:
                                                              (
                                                                details,
                                                              ) => _showObjectContextMenu(
                                                                globalPosition:
                                                                    details
                                                                        .globalPosition,
                                                                headingId:
                                                                    heading.id,
                                                              ),
                                                          onBeginMoving:
                                                              (position) =>
                                                                  _beginMovingHeading(
                                                                    heading.id,
                                                                    position,
                                                                  ),
                                                          onMove: (position) =>
                                                              _moveHeading(
                                                                heading.id,
                                                                position,
                                                              ),
                                                          onEndMoving:
                                                              _endMoving,
                                                        ),
                                                      ),
                                                  for (final image in _images)
                                                    if (!_hiddenGroupMemberIds
                                                        .contains(image.id))
                                                      Positioned(
                                                        key: ValueKey(
                                                          'positioned-image-${image.id}',
                                                        ),
                                                        left: image.x,
                                                        top: image.y,
                                                        child: InteractiveBoardImage(
                                                          key: ValueKey(
                                                            image.id,
                                                          ),
                                                          image: image,
                                                          isSelected:
                                                              !_isExportingCurrentView &&
                                                              _selectedImageIds
                                                                  .contains(
                                                                    image.id,
                                                                  ),
                                                          canResize:
                                                              !_isExportingCurrentView &&
                                                              _selectedObjectIds
                                                                      .length ==
                                                                  1,
                                                          onSelect: () =>
                                                              _selectImage(
                                                                image.id,
                                                              ),
                                                          onSecondaryTapDown:
                                                              (
                                                                details,
                                                              ) => _showObjectContextMenu(
                                                                globalPosition:
                                                                    details
                                                                        .globalPosition,
                                                                imageId:
                                                                    image.id,
                                                              ),
                                                          onBeginMoving:
                                                              (position) =>
                                                                  _beginMovingImage(
                                                                    image.id,
                                                                    position,
                                                                  ),
                                                          onMove: (position) =>
                                                              _moveImage(
                                                                image.id,
                                                                position,
                                                              ),
                                                          onEndMoving:
                                                              _endMovingImage,
                                                          onBeginResizing:
                                                              (position) =>
                                                                  _beginResizingImage(
                                                                    image.id,
                                                                    position,
                                                                  ),
                                                          child:
                                                              widget
                                                                  .imageViewBuilder
                                                                  ?.call(
                                                                    image,
                                                                  ) ??
                                                              ManagedImageView(
                                                                image: image,
                                                                assetStore: widget
                                                                    .imageAssetStore,
                                                                isPlaying:
                                                                    _playingGifImageId ==
                                                                        image
                                                                            .id &&
                                                                    !_isExportingCurrentView &&
                                                                    !_isExportingWholeBoard,
                                                                onTogglePlayback:
                                                                    _isExportingCurrentView ||
                                                                        _isExportingWholeBoard ||
                                                                        _isShapesMode
                                                                    ? null
                                                                    : () => _toggleGifPlayback(
                                                                        image
                                                                            .id,
                                                                      ),
                                                              ),
                                                        ),
                                                      ),
                                                  for (final note in _notes)
                                                    if (!_hiddenGroupMemberIds
                                                        .contains(note.id))
                                                      Positioned(
                                                        key: ValueKey(
                                                          'positioned-note-${note.id}',
                                                        ),
                                                        left: note.x,
                                                        top: note.y,
                                                        child: EditableNote(
                                                          key: ValueKey(
                                                            note.id,
                                                          ),
                                                          note: note,
                                                          isSelected:
                                                              !_isExportingCurrentView &&
                                                              _selectedNoteIds
                                                                  .contains(
                                                                    note.id,
                                                                  ),
                                                          isEditing:
                                                              _editingNoteId ==
                                                              note.id,
                                                          showInteractionChrome:
                                                              !_isExportingCurrentView,
                                                          onSelect: () =>
                                                              _selectNote(
                                                                note.id,
                                                              ),
                                                          onEditTitle: () {
                                                            _selectNote(
                                                              note.id,
                                                            );
                                                            _editNoteTitle(
                                                              note,
                                                            );
                                                          },
                                                          onSecondaryTapDown:
                                                              (
                                                                details,
                                                              ) => _showObjectContextMenu(
                                                                globalPosition:
                                                                    details
                                                                        .globalPosition,
                                                                noteId: note.id,
                                                              ),
                                                          onBeginEditing: () =>
                                                              _beginEditing(
                                                                note.id,
                                                              ),
                                                          onEndEditing: () =>
                                                              _endEditing(
                                                                note.id,
                                                              ),
                                                          onBeginMoving:
                                                              (position) =>
                                                                  _beginMoving(
                                                                    note.id,
                                                                    position,
                                                                  ),
                                                          onMove: (position) =>
                                                              _moveNote(
                                                                note.id,
                                                                position,
                                                              ),
                                                          onEndMoving:
                                                              _endMoving,
                                                          onBeginResizing:
                                                              (position) =>
                                                                  _beginResizing(
                                                                    note.id,
                                                                    position,
                                                                  ),
                                                          onResize:
                                                              (position) =>
                                                                  _resizeNote(
                                                                    note.id,
                                                                    position,
                                                                  ),
                                                          onEndResizing:
                                                              _endResizing,
                                                          onTextChanged:
                                                              (text) =>
                                                                  _updateText(
                                                                    note.id,
                                                                    text,
                                                                  ),
                                                          onEmphasisChanged:
                                                              (emphasis) =>
                                                                  _updateEmphasis(
                                                                    note.id,
                                                                    emphasis,
                                                                  ),
                                                          onLinksChanged:
                                                              (links) =>
                                                                  _updateLinks(
                                                                    note.id,
                                                                    links,
                                                                  ),
                                                          onOpenLink: (url) =>
                                                              _launchNoteLink(
                                                                url,
                                                                restoreShortcutFocus:
                                                                    false,
                                                              ),
                                                          websiteMarker:
                                                              _websiteMarkerFor(
                                                                note,
                                                              ),
                                                          websiteHost:
                                                              NoteLinkResolver.resolveSingle(
                                                                note.text,
                                                              )?.host,
                                                          multiWebsiteLinkCount:
                                                              _multiWebsiteLinkCountFor(
                                                                note,
                                                              ),
                                                        ),
                                                      ),
                                                  for (final entry
                                                      in _visibleObjectBounds
                                                          .entries)
                                                    if (!_isExportingCurrentView &&
                                                        _lockedObjectIds
                                                            .contains(
                                                              entry.key,
                                                            ))
                                                      Positioned(
                                                        key: ValueKey(
                                                          'position-lock-indicator-${entry.key}',
                                                        ),
                                                        left:
                                                            entry.value.right -
                                                            25,
                                                        top:
                                                            entry.value.top + 5,
                                                        child: IgnorePointer(
                                                          child: DecoratedBox(
                                                            decoration: BoxDecoration(
                                                              color: colorScheme
                                                                  .surface
                                                                  .withValues(
                                                                    alpha: 0.9,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    3,
                                                                  ),
                                                              child: Icon(
                                                                Icons.lock,
                                                                size: 14,
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  if (!_isExportingCurrentView)
                                                    if (_selectedGroupBounds
                                                        case final bounds?)
                                                      Positioned.fromRect(
                                                        rect: bounds,
                                                        child: IgnorePointer(
                                                          child: DecoratedBox(
                                                            key: const ValueKey(
                                                              'selected-group-outline',
                                                            ),
                                                            decoration: BoxDecoration(
                                                              border: Border.all(
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                                width: 2,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  if (!_isExportingCurrentView)
                                                    if (_canMoveSelectedGroup)
                                                      if (_selectedGroupBounds
                                                          case final bounds?)
                                                        Positioned(
                                                          left:
                                                              bounds.center.dx -
                                                              15,
                                                          top:
                                                              bounds.center.dy -
                                                              15,
                                                          width: 30,
                                                          height: 30,
                                                          child: Tooltip(
                                                            message:
                                                                'Move group',
                                                            child: MouseRegion(
                                                              cursor:
                                                                  SystemMouseCursors
                                                                      .move,
                                                              child: GestureDetector(
                                                                key: const ValueKey(
                                                                  'selected-group-move-handle',
                                                                ),
                                                                behavior:
                                                                    HitTestBehavior
                                                                        .opaque,
                                                                onPanDown: (details) {
                                                                  _beginMovingGroup(
                                                                    _exactSelectedGroup!
                                                                        .memberIds
                                                                        .first,
                                                                    details
                                                                        .globalPosition,
                                                                  );
                                                                },
                                                                onPanUpdate:
                                                                    (
                                                                      details,
                                                                    ) => _moveSelection(
                                                                      details
                                                                          .globalPosition,
                                                                    ),
                                                                onPanEnd: (_) =>
                                                                    _endMoving(),
                                                                onPanCancel:
                                                                    _endMoving,
                                                                child: DecoratedBox(
                                                                  decoration: BoxDecoration(
                                                                    color: colorScheme
                                                                        .primary,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border: Border.all(
                                                                      color: colorScheme
                                                                          .onPrimary,
                                                                      width: 2,
                                                                    ),
                                                                    boxShadow: const [
                                                                      BoxShadow(
                                                                        blurRadius:
                                                                            3,
                                                                        color: Color(
                                                                          0x55000000,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: Icon(
                                                                    Icons
                                                                        .open_with,
                                                                    size: 17,
                                                                    color: colorScheme
                                                                        .onPrimary,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                  if (!_isExportingCurrentView &&
                                                      _snapGuides.isNotEmpty)
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        child: AnimatedBuilder(
                                                          animation:
                                                              _transformationController,
                                                          builder: (context, child) => CustomPaint(
                                                            key: const ValueKey(
                                                              'canvas-snap-guides',
                                                            ),
                                                            painter: CanvasSnapGuidePainter(
                                                              guides:
                                                                  _snapGuides,
                                                              viewportScale:
                                                                  _transformationController
                                                                      .value
                                                                      .getMaxScaleOnAxis(),
                                                              color: colorScheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (!_isExportingCurrentView &&
                                                      _isShapesMode)
                                                    Positioned.fill(
                                                      child: MouseRegion(
                                                        cursor:
                                                            _armedShapeType ==
                                                                null
                                                            ? SystemMouseCursors
                                                                  .basic
                                                            : SystemMouseCursors
                                                                  .precise,
                                                        child: Listener(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          child: AnimatedBuilder(
                                                            animation:
                                                                _transformationController,
                                                            builder: (context, child) => CustomPaint(
                                                              key: const ValueKey(
                                                                'shape-editing-overlay',
                                                              ),
                                                              painter: ShapeSelectionPainter(
                                                                shape:
                                                                    _selectedShape,
                                                                scale: _transformationController
                                                                    .value
                                                                    .getMaxScaleOnAxis(),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_marqueeRect case final marqueeRect?)
                                Positioned.fromRect(
                                  rect: marqueeRect,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      key: const ValueKey('selection-marquee'),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        border: Border.all(
                                          color: colorScheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 16,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _ZoomIndicator(
                                          transformationController:
                                              _transformationController,
                                        ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'Find on board (Ctrl+F)',
                                          child: TextButton.icon(
                                            key: const ValueKey(
                                              'find-board-button',
                                            ),
                                            style: TextButton.styleFrom(
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(alpha: 0.92),
                                            ),
                                            onPressed:
                                                _isLoading ||
                                                    _editingNoteId != null
                                                ? null
                                                : _showFindOnBoardDialog,
                                            icon: const Icon(
                                              Icons.search,
                                              size: 20,
                                            ),
                                            label: const Text('Find on board'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const _InteractionHint(),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right:
                                    CanvasOverviewMap.overviewSize.width + 32,
                                child: Material(
                                  elevation: 2,
                                  color: _isSnappingEnabled
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surface.withValues(
                                          alpha: 0.94,
                                        ),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    key: const ValueKey(
                                      'snapping-toggle-button',
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : _toggleSnapping,
                                    tooltip: _isSnappingEnabled
                                        ? 'Turn snapping off'
                                        : 'Turn snapping on',
                                    isSelected: _isSnappingEnabled,
                                    icon: Icon(
                                      Icons.grid_4x4,
                                      color: _isSnappingEnabled
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right:
                                    CanvasOverviewMap.overviewSize.width + 88,
                                child: Material(
                                  elevation: 2,
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.94,
                                  ),
                                  shape: const CircleBorder(),
                                  child: PopupMenuButton<BoardPaperTone>(
                                    key: const ValueKey('paper-tone-button'),
                                    tooltip:
                                        'Choose paper colour for this Board',
                                    enabled: !_isLoading,
                                    onSelected: _setPaperTone,
                                    icon: const Icon(Icons.palette_outlined),
                                    itemBuilder: (context) => [
                                      for (final tone in BoardPaperTone.values)
                                        CheckedPopupMenuItem<BoardPaperTone>(
                                          key: ValueKey(
                                            'paper-tone-${tone.name}',
                                          ),
                                          value: tone,
                                          checked: _paperTone == tone,
                                          child: Text(tone.label),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right:
                                    CanvasOverviewMap.overviewSize.width + 144,
                                child: Material(
                                  elevation: 2,
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.94,
                                  ),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    key: const ValueKey('board-help-button'),
                                    tooltip: 'Help and shortcuts',
                                    onPressed: () => showVasmimHelp(context),
                                    icon: const Icon(Icons.help_outline),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: _offBoardObjectCount > 0 ? 72 : 16,
                                right: 16,
                                child: CanvasOverviewMap(
                                  transformationController:
                                      _transformationController,
                                  viewportSize: viewportSize,
                                  boardSize: const Size(
                                    _canvasWidth,
                                    _canvasHeight,
                                  ),
                                  paperTone: _paperTone,
                                  objects: [
                                    for (final shape in _visibleOrderedShapes)
                                      CanvasOverviewObject(
                                        id: shape.id,
                                        bounds: Rect.fromLTWH(
                                          shape.x,
                                          shape.y,
                                          shape.width,
                                          shape.height,
                                        ),
                                        color: Color(
                                          shape.outlineColorValue,
                                        ).withValues(alpha: 0.45),
                                        isSelected:
                                            _selectedShapeId == shape.id,
                                      ),
                                    for (final note in _notes)
                                      if (!_hiddenGroupMemberIds.contains(
                                        note.id,
                                      ))
                                        CanvasOverviewObject(
                                          id: note.id,
                                          bounds: Rect.fromLTWH(
                                            note.x,
                                            note.y,
                                            note.width,
                                            note.height,
                                          ),
                                          color: note.color.backgroundColor,
                                          isSelected: _selectedNoteIds.contains(
                                            note.id,
                                          ),
                                        ),
                                    for (final image in _images)
                                      if (!_hiddenGroupMemberIds.contains(
                                        image.id,
                                      ))
                                        CanvasOverviewObject(
                                          id: image.id,
                                          bounds: Rect.fromLTWH(
                                            image.x,
                                            image.y,
                                            image.width,
                                            image.height,
                                          ),
                                          color: colorScheme.secondaryContainer,
                                          isSelected: _selectedImageIds
                                              .contains(image.id),
                                        ),
                                    for (final heading in _headings)
                                      if (!_hiddenGroupMemberIds.contains(
                                        heading.id,
                                      ))
                                        CanvasOverviewObject(
                                          id: heading.id,
                                          bounds:
                                              CanvasHeadingGeometry.boundsFor(
                                                heading,
                                              ),
                                          color:
                                              heading.background.color ==
                                                  Colors.transparent
                                              ? colorScheme.primary.withValues(
                                                  alpha: 0.55,
                                                )
                                              : heading.background.color,
                                          isSelected: _selectedHeadingIds
                                              .contains(heading.id),
                                        ),
                                    for (final attachment in _attachments)
                                      if (!_hiddenGroupMemberIds.contains(
                                        attachment.id,
                                      ))
                                        CanvasOverviewObject(
                                          id: attachment.id,
                                          bounds: Rect.fromLTWH(
                                            attachment.x,
                                            attachment.y,
                                            attachment.width,
                                            attachment.height,
                                          ),
                                          color:
                                              attachment.kind ==
                                                  AttachmentKind.pdf
                                              ? const Color(0xffb83a32)
                                              : const Color(0xff50569d),
                                          isSelected: _selectedAttachmentIds
                                              .contains(attachment.id),
                                        ),
                                    for (final embed in _youTubeEmbeds)
                                      if (!_hiddenGroupMemberIds.contains(
                                        embed.id,
                                      ))
                                        CanvasOverviewObject(
                                          id: embed.id,
                                          bounds: Rect.fromLTWH(
                                            embed.x,
                                            embed.y,
                                            embed.width,
                                            embed.height,
                                          ),
                                          color: const Color(0xfff44336),
                                          isSelected: _selectedYouTubeEmbedIds
                                              .contains(embed.id),
                                        ),
                                  ],
                                  links: [
                                    for (final connector in _visibleConnectors)
                                      CanvasOverviewLink(
                                        objectAId: connector.objectAId,
                                        objectBId: connector.objectBId,
                                      ),
                                  ],
                                  onRecenter: _recenterFromOverview,
                                ),
                              ),
                              if (_showBlankCanvasPriming)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: _BlankCanvasPrimingCard(
                                      onStartWriting: _startWritingFromPriming,
                                      onDismiss: _dismissBlankCanvasPriming,
                                    ),
                                  ),
                                ),
                              if (_selectedHeadingIds.isEmpty &&
                                  _selectedNoteIds.length +
                                          _selectedImageIds.length ==
                                      2)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: _selectedPairConnector == null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FilledButton.tonalIcon(
                                              key: const ValueKey(
                                                'connector-with-label-button',
                                              ),
                                              onPressed:
                                                  _connectSelectedObjectsWithLabel,
                                              icon: const Icon(
                                                Icons.new_label_outlined,
                                              ),
                                              label: const Text(
                                                'Connect with label...',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.tonalIcon(
                                              key: const ValueKey(
                                                'connector-toggle-button',
                                              ),
                                              onPressed:
                                                  _toggleSelectedConnection,
                                              icon: const Icon(Icons.add_link),
                                              label: const Text(
                                                'Connect selected objects',
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FilledButton.tonalIcon(
                                              key: const ValueKey(
                                                'connector-label-button',
                                              ),
                                              onPressed:
                                                  _editSelectedConnectionLabel,
                                              icon: const Icon(
                                                Icons.label_outline,
                                              ),
                                              label: Text(
                                                _connectionLabelSelectionLabel,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.tonalIcon(
                                              key: const ValueKey(
                                                'connector-toggle-button',
                                              ),
                                              onPressed:
                                                  _toggleSelectedConnection,
                                              icon: const Icon(Icons.link_off),
                                              label: const Text(
                                                'Remove connection',
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              if (_offBoardObjectCount > 0)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: FilledButton.tonalIcon(
                                    key: const ValueKey('recover-notes-button'),
                                    onPressed: _recoverOffBoardObjects,
                                    icon: const Icon(Icons.move_down_outlined),
                                    label: Text(
                                      _offBoardObjectCount == 1
                                          ? 'Recover off-board object'
                                          : 'Recover $_offBoardObjectCount off-board objects',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isShapesMode)
                          ShapeSidePanel(
                            shapes: _activeLayerShapes,
                            layers: _shapeLayers,
                            activeLayerId: _activeShapeLayerId,
                            soloLayerId: _soloShapeLayerId,
                            selectedShapeId: _selectedShapeId,
                            armedType: _armedShapeType,
                            onArm: _armShape,
                            isCircleArmed: _isCircleArmed,
                            onArmCircle: _armCircle,
                            onSelect: _selectShape,
                            onSelectLayer: _selectShapeLayer,
                            onToggleLayerVisibility:
                                _toggleShapeLayerVisibility,
                            onLayerOpacity: _setShapeLayerOpacity,
                            onToggleSoloLayer: _toggleSoloShapeLayer,
                            onExitSolo: _exitShapeLayerSolo,
                            onAddLayer: _addShapeLayer,
                            onRenameLayer: _renameActiveShapeLayer,
                            onMoveLayerForward: () => _moveActiveShapeLayer(1),
                            onMoveLayerBackward: () =>
                                _moveActiveShapeLayer(-1),
                            onDeleteLayer: _deleteActiveShapeLayer,
                            onMoveShapeToLayer: _moveSelectedShapeToLayer,
                            onClose: _toggleShapesMode,
                            onDuplicate: _duplicateSelection,
                            onDelete: _deleteSelectedShape,
                            canAddSelectedToGroup:
                                _selectedShape != null &&
                                _groupForObject(_selectedShape!.id) == null &&
                                _groups.any((group) => group.isVisible),
                            canRemoveSelectedFromGroup:
                                _selectedShape != null &&
                                _groupForObject(
                                      _selectedShape!.id,
                                    )?.isVisible ==
                                    true,
                            onAddSelectedToGroup: () =>
                                unawaited(_addSelectedShapeToGroup()),
                            onRemoveSelectedFromGroup:
                                _removeSelectedShapeFromGroup,
                            onMoveForward: () => _moveSelectedShapeInLayer(1),
                            onMoveBackward: () => _moveSelectedShapeInLayer(-1),
                            onFillColor: () =>
                                _chooseShapeColor(_ShapeColorTarget.fill),
                            onOutlineColor: () =>
                                _chooseShapeColor(_ShapeColorTarget.outline),
                            onHeadingColor: () =>
                                _chooseShapeColor(_ShapeColorTarget.heading),
                            onFillOpacityStart: _beginShapeFillOpacity,
                            onFillOpacityChanged: _changeShapeFillOpacity,
                            onFillOpacityEnd: _endShapeFillOpacity,
                            onOutlineWidth: (value) {
                              _shapeOutlineWidth = value;
                              _updateSelectedShape(
                                (shape) => shape.copyWith(
                                  outlineWidth: value,
                                  modifiedAt: DateTime.now().toUtc(),
                                ),
                              );
                            },
                            onRouteAxis: (value) => _updateSelectedShape(
                              (shape) => shape.copyWith(
                                routeAxis: value,
                                modifiedAt: DateTime.now().toUtc(),
                              ),
                            ),
                            onEditHeading: _editShapeHeading,
                            onRemoveHeading: _removeShapeHeading,
                            onHeadingSize: (value) => _updateShapeHeading(
                              (heading) => heading.copyWith(fontSize: value),
                            ),
                            onHeadingAlignment: (value) => _updateShapeHeading(
                              (heading) => heading.copyWith(alignment: value),
                            ),
                            onHeadingPlacement: (value) => _updateShapeHeading(
                              (heading) => heading.copyWith(placement: value),
                            ),
                          ),
                        if (_isGroupsPanelOpen)
                          GroupSidePanel(
                            groups: _groups,
                            selectedMemberIds: _selectedMemberIds,
                            movementBlockedGroupIds: _movementBlockedGroupIds,
                            onSelect: _selectGroup,
                            onToggleVisibility: _toggleGroupVisibility,
                            onUngroup: _ungroup,
                            onRename: _renameGroup,
                            onClose: _toggleGroupsPanel,
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SceneWalkthrough extends StatefulWidget {
  const _SceneWalkthrough({
    required this.scenes,
    required this.initialIndex,
    required this.onSceneChanged,
  });

  final List<Scene> scenes;
  final int initialIndex;
  final ValueChanged<Scene> onSceneChanged;

  @override
  State<_SceneWalkthrough> createState() => _SceneWalkthroughState();
}

class _SceneWalkthroughState extends State<_SceneWalkthrough> {
  final FocusNode _focusNode = FocusNode();
  late int _sceneIndex;

  @override
  void initState() {
    super.initState();
    _sceneIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSceneChanged(widget.scenes[_sceneIndex]);
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _moveBy(int delta) {
    final nextIndex = _sceneIndex + delta;
    if (nextIndex < 0 || nextIndex >= widget.scenes.length) {
      return;
    }
    setState(() => _sceneIndex = nextIndex);
    widget.onSceneChanged(widget.scenes[nextIndex]);
  }

  void _exit() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final scene = widget.scenes[_sceneIndex];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _moveBy(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _moveBy(1),
        const SingleActivator(LogicalKeyboardKey.escape): _exit,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Material(
          key: const ValueKey('scene-walkthrough'),
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ModalBarrier(dismissible: false, color: Colors.transparent),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Card(
                        elevation: 8,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.slideshow_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scene.name,
                                      key: const ValueKey(
                                        'scene-walkthrough-name',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${_sceneIndex + 1} / ${widget.scenes.length}',
                                      key: const ValueKey(
                                        'scene-walkthrough-position',
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: const ValueKey(
                                  'scene-walkthrough-previous',
                                ),
                                tooltip: 'Previous scene (Left Arrow)',
                                onPressed: _sceneIndex == 0
                                    ? null
                                    : () => _moveBy(-1),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              IconButton(
                                key: const ValueKey('scene-walkthrough-next'),
                                tooltip: 'Next scene (Right Arrow)',
                                onPressed:
                                    _sceneIndex == widget.scenes.length - 1
                                    ? null
                                    : () => _moveBy(1),
                                icon: const Icon(Icons.arrow_forward),
                              ),
                              const SizedBox(width: 4),
                              FilledButton(
                                key: const ValueKey('scene-walkthrough-exit'),
                                onPressed: _exit,
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreshPairNoteCard extends StatelessWidget {
  const _FreshPairNoteCard({required this.label, required this.note});

  final String label;
  final Note note;

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xff29251d);
    return Card(
      key: ValueKey('fresh-pair-note-${note.id}'),
      margin: EdgeInsets.zero,
      color: note.color.backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: note.color.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: note.color.borderColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Canvas position ${note.x.round()}, ${note.y.round()}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: textColor),
            ),
            const SizedBox(height: 12),
            Text(
              _excerpt(note.text),
              key: ValueKey('fresh-pair-excerpt-${note.id}'),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  static String _excerpt(String text) {
    final collapsed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.length <= 280) {
      return collapsed;
    }
    return '${collapsed.substring(0, 279)}…';
  }
}

class _BlankCanvasPrimingCard extends StatelessWidget {
  const _BlankCanvasPrimingCard({
    required this.onStartWriting,
    required this.onDismiss,
  });

  final VoidCallback onStartWriting;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('blank-canvas-priming-card'),
      elevation: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start anywhere', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'What has your attention right now?',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'A thought, question, fragment, or pasted text is enough.',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('dismiss-blank-canvas-priming'),
                    onPressed: onDismiss,
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('start-writing-from-priming'),
                    onPressed: onStartWriting,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Start writing'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractionHint extends StatelessWidget {
  const _InteractionHint();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'New note creates at viewport centre  •  Ctrl+click adds selection  •  Fit follows a multi-selection',
        ),
      ),
    );
  }
}

class _ZoomIndicator extends StatelessWidget {
  const _ZoomIndicator({required this.transformationController});

  final TransformationController transformationController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transformationController,
      builder: (context, child) {
        final percentage =
            (transformationController.value.getMaxScaleOnAxis() * 100).round();
        return Semantics(
          container: true,
          label: 'Canvas zoom: $percentage percent',
          readOnly: true,
          excludeSemantics: true,
          child: Material(
            key: const ValueKey('zoom-indicator'),
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.92),
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '$percentage%',
                key: const ValueKey('zoom-percentage'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionLineLabelTarget extends StatelessWidget {
  const _ConnectionLineLabelTarget({
    required this.connector,
    required this.segment,
    required this.viewportScale,
    required this.onTap,
    required this.onSecondaryTapDown,
    required this.onHoverChanged,
  });

  static const _screenHitWidth = 18.0;

  final Connector connector;
  final ConnectorSegment segment;
  final double viewportScale;
  final VoidCallback onTap;
  final ValueChanged<Offset> onSecondaryTapDown;
  final ValueChanged<bool> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final delta = segment.end - segment.start;
    final hitWidth = _screenHitWidth / viewportScale;
    final action = connector.label == null
        ? 'Add connection label'
        : 'Edit connection label';
    final semanticsLabel = connector.label == null
        ? 'Unlabeled connection. Add connection label'
        : 'Connection: ${connector.label}. Edit connection label';
    return Positioned(
      left: segment.start.dx,
      top: segment.start.dy - hitWidth / 2,
      child: Transform.rotate(
        angle: math.atan2(delta.dy, delta.dx),
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          label: semanticsLabel,
          button: true,
          onTap: onTap,
          excludeSemantics: true,
          child: Tooltip(
            message: action,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHoverChanged(true),
              onExit: (_) => onHoverChanged(false),
              child: GestureDetector(
                key: ValueKey('connection-line-label-target-${connector.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onSecondaryTapDown: (details) =>
                    onSecondaryTapDown(details.globalPosition),
                child: SizedBox(width: delta.distance, height: hitWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionLabelView extends StatelessWidget {
  const _ConnectionLabelView({
    required this.connector,
    required this.segment,
    required this.viewportScale,
    required this.onTap,
    required this.onSecondaryTapDown,
    required this.onHoverChanged,
  });

  final Connector connector;
  final ConnectorSegment segment;
  final double viewportScale;
  final VoidCallback onTap;
  final ValueChanged<Offset> onSecondaryTapDown;
  final ValueChanged<bool> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    const markerThreshold = 0.35;
    final midpoint = Offset(
      (segment.start.dx + segment.end.dx) / 2,
      (segment.start.dy + segment.end.dy) / 2,
    );
    final showMarker = viewportScale < markerThreshold;
    final inverseScale = viewportScale > 1 || showMarker
        ? 1 / viewportScale
        : 1.0;
    return Positioned(
      left: midpoint.dx,
      top: midpoint.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.scale(
          scale: inverseScale,
          child: Semantics(
            container: true,
            label: 'Connection label: ${connector.label}',
            button: true,
            onTap: onTap,
            excludeSemantics: true,
            child: Tooltip(
              message: 'Edit connection label',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => onHoverChanged(true),
                onExit: (_) => onHoverChanged(false),
                child: GestureDetector(
                  key: ValueKey('connector-label-control-${connector.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onSecondaryTapDown: (details) =>
                      onSecondaryTapDown(details.globalPosition),
                  child: Transform.scale(
                    key: ValueKey('connector-label-${connector.id}'),
                    scale: 1,
                    child: showMarker
                        ? SizedBox.square(
                            dimension: 32,
                            child: Center(
                              child: Container(
                                key: ValueKey(
                                  'connector-label-marker-${connector.id}',
                                ),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.surface,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              connector.label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasSnapshot {
  const _CanvasSnapshot({
    required this.notes,
    required this.connectors,
    required this.images,
    required this.scenes,
    required this.headings,
    required this.attachments,
    required this.youTubeEmbeds,
    required this.shapes,
    required this.shapeLayers,
    required this.groups,
    required this.lockedObjectIds,
    required this.activeShapeLayerId,
    required this.selectedNoteIds,
    required this.selectedImageIds,
    required this.selectedHeadingIds,
    required this.selectedAttachmentIds,
    required this.selectedYouTubeEmbedIds,
    required this.selectedGroupShapeIds,
    required this.selectedShapeId,
  });

  final List<Note> notes;
  final List<Connector> connectors;
  final List<BoardImage> images;
  final List<Scene> scenes;
  final List<CanvasHeading> headings;
  final List<BoardAttachment> attachments;
  final List<YouTubeEmbed> youTubeEmbeds;
  final List<BoardShape> shapes;
  final List<ShapeLayer> shapeLayers;
  final List<BoardGroup> groups;
  final Set<String> lockedObjectIds;
  final String activeShapeLayerId;
  final Set<String> selectedNoteIds;
  final Set<String> selectedImageIds;
  final Set<String> selectedHeadingIds;
  final Set<String> selectedAttachmentIds;
  final Set<String> selectedYouTubeEmbedIds;
  final Set<String> selectedGroupShapeIds;
  final String? selectedShapeId;
}

enum _ShapeGestureMode { drawing, moving, resizing }

enum _ShapeColorTarget { fill, outline, heading }

class _ShapeLayerNameDialog extends StatefulWidget {
  const _ShapeLayerNameDialog({
    required this.initialName,
    required this.unavailableNames,
  });

  final String initialName;
  final Set<String> unavailableNames;

  @override
  State<_ShapeLayerNameDialog> createState() => _ShapeLayerNameDialogState();
}

class _ShapeLayerNameDialogState extends State<_ShapeLayerNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    String name;
    try {
      name = ShapeLayer.normalizeName(_controller.text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    if (widget.unavailableNames.contains(name.toLowerCase())) {
      setState(() => _error = 'Shape layer names must be unique.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename shape layer'),
      content: TextField(
        key: const ValueKey('shape-layer-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: ShapeLayer.maximumNameCharacters,
        decoration: InputDecoration(labelText: 'Layer name', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-shape-layer-name'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ShapeHeadingDialog extends StatefulWidget {
  const _ShapeHeadingDialog({this.initialText});

  final String? initialText;

  @override
  State<_ShapeHeadingDialog> createState() => _ShapeHeadingDialogState();
}

class _ShapeHeadingDialogState extends State<_ShapeHeadingDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final text = ShapeHeading.normalizeText(_controller.text);
      if (text == null) throw const FormatException('Enter a heading.');
      Navigator.pop(context, text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialText == null ? 'Add shape heading' : 'Edit shape heading',
    ),
    content: TextField(
      key: const ValueKey('shape-heading-field'),
      controller: _controller,
      autofocus: true,
      maxLines: 1,
      maxLength: ShapeHeading.maximumCharacters,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      decoration: InputDecoration(labelText: 'Heading text', errorText: _error),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('save-shape-heading'),
        onPressed: _submit,
        child: const Text('Save heading'),
      ),
    ],
  );
}

class _SceneNameDialog extends StatefulWidget {
  const _SceneNameDialog({this.scene});

  final Scene? scene;

  @override
  State<_SceneNameDialog> createState() => _SceneNameDialogState();
}

class _ConnectionLabelResult {
  const _ConnectionLabelResult(this.label);

  final String? label;
}

class _NoteTitleResult {
  const _NoteTitleResult(this.title);

  final String? title;
}

class _NoteTitleDialog extends StatefulWidget {
  const _NoteTitleDialog({this.initialTitle});

  final String? initialTitle;

  @override
  State<_NoteTitleDialog> createState() => _NoteTitleDialogState();
}

class _NoteTitleDialogState extends State<_NoteTitleDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final title = Note.normalizeTitle(_controller.text);
      Navigator.of(context).pop(_NoteTitleResult(title));
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTitle != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit note title' : 'Add note title'),
      content: TextField(
        key: const ValueKey('note-title-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        maxLength: Note.maximumTitleCharacters,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        decoration: InputDecoration(
          labelText: 'Note title',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-note-title-button'),
          onPressed: _submit,
          child: Text(isEditing ? 'Save title' : 'Add title'),
        ),
      ],
    );
  }
}

class _HeadingAppearanceEdit {
  const _HeadingAppearanceEdit({
    required this.text,
    required this.size,
    required this.background,
  });

  final String text;
  final CanvasHeadingSize size;
  final CanvasHeadingBackground background;
}

class _HeadingAppearanceDialog extends StatefulWidget {
  const _HeadingAppearanceDialog({
    required this.heading,
    required this.isPositionLocked,
  });

  final CanvasHeading heading;
  final bool isPositionLocked;

  @override
  State<_HeadingAppearanceDialog> createState() =>
      _HeadingAppearanceDialogState();
}

class _HeadingAppearanceDialogState extends State<_HeadingAppearanceDialog> {
  late final TextEditingController _controller;
  late CanvasHeadingSize _size;
  late CanvasHeadingBackground _background;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.heading.text);
    _size = widget.heading.size;
    _background = widget.heading.background;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final text = CanvasHeading.normalizeText(_controller.text);
      if (text == null) {
        throw const FormatException('A heading cannot be empty.');
      }
      Navigator.of(context).pop(
        _HeadingAppearanceEdit(
          text: text,
          size: _size,
          background: _background,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('heading-appearance-dialog'),
      title: const Text('Edit heading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('heading-appearance-text-field'),
            controller: _controller,
            autofocus: true,
            maxLines: 1,
            maxLength: CanvasHeading.maximumTextCharacters,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: InputDecoration(
              labelText: 'Heading text',
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CanvasHeadingSize>(
            key: const ValueKey('heading-appearance-size'),
            initialValue: _size,
            decoration: InputDecoration(
              labelText: 'Text size',
              helperText: widget.isPositionLocked
                  ? 'Unlock position to change size'
                  : null,
            ),
            items: [
              for (final size in CanvasHeadingSize.values)
                DropdownMenuItem(value: size, child: Text(size.label)),
            ],
            onChanged: widget.isPositionLocked
                ? null
                : (size) {
                    if (size != null) setState(() => _size = size);
                  },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CanvasHeadingBackground>(
            key: const ValueKey('heading-appearance-background'),
            initialValue: _background,
            decoration: const InputDecoration(labelText: 'Background'),
            items: [
              for (final background in CanvasHeadingBackground.values)
                DropdownMenuItem(
                  value: background,
                  child: Text(background.label),
                ),
            ],
            onChanged: (background) {
              if (background != null) {
                setState(() => _background = background);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-heading-appearance-button'),
          onPressed: _submit,
          child: const Text('Save heading'),
        ),
      ],
    );
  }
}

class _HeadingTextDialog extends StatefulWidget {
  const _HeadingTextDialog();

  @override
  State<_HeadingTextDialog> createState() => _HeadingTextDialogState();
}

class _HeadingTextDialogState extends State<_HeadingTextDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final text = CanvasHeading.normalizeText(_controller.text);
      if (text == null) {
        throw const FormatException('A heading cannot be empty.');
      }
      Navigator.of(context).pop(text);
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('heading-text-dialog'),
      title: const Text('Add heading'),
      content: TextField(
        key: const ValueKey('heading-text-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        maxLength: CanvasHeading.maximumTextCharacters,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        decoration: InputDecoration(
          labelText: 'Heading text',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-heading-text-button'),
          onPressed: _submit,
          child: const Text('Add heading'),
        ),
      ],
    );
  }
}

class _ImageCaptionDialog extends StatefulWidget {
  const _ImageCaptionDialog({this.initialCaption});

  final String? initialCaption;

  @override
  State<_ImageCaptionDialog> createState() => _ImageCaptionDialogState();
}

class _ImageCaptionDialogState extends State<_ImageCaptionDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final caption = BoardImage.normalizeCaption(_controller.text);
      if (caption == null) {
        throw const FormatException('An image caption cannot be empty.');
      }
      Navigator.of(context).pop(caption);
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialCaption != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit image caption' : 'Add image caption'),
      content: TextField(
        key: const ValueKey('image-caption-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        maxLength: BoardImage.maximumCaptionCharacters,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        decoration: InputDecoration(
          labelText: 'Image caption',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-image-caption-button'),
          onPressed: _submit,
          child: Text(isEditing ? 'Save caption' : 'Add caption'),
        ),
      ],
    );
  }
}

class _ConnectionLabelDialog extends StatefulWidget {
  const _ConnectionLabelDialog({this.initialLabel});

  final String? initialLabel;

  @override
  State<_ConnectionLabelDialog> createState() => _ConnectionLabelDialogState();
}

class _ConnectionLabelDialogState extends State<_ConnectionLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _controller.text.trim();
    Navigator.of(
      context,
    ).pop(_ConnectionLabelResult(label.isEmpty ? null : label));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialLabel != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit connection label' : 'Add connection label'),
      content: TextField(
        key: const ValueKey('connection-label-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        maxLength: 80,
        inputFormatters: [
          LengthLimitingTextInputFormatter(80),
          FilteringTextInputFormatter.deny(RegExp(r'[\r\n\u2028\u2029]')),
        ],
        decoration: const InputDecoration(labelText: 'Connection label'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-connection-label-button'),
          onPressed: _submit,
          child: Text(isEditing ? 'Save label' : 'Add label'),
        ),
      ],
    );
  }
}

class _SceneNameDialogState extends State<_SceneNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.scene?.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a scene name');
    } else {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.scene == null ? 'Save current view' : 'Rename scene'),
      content: TextField(
        key: const ValueKey('scene-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Scene name',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-scene-name-button'),
          onPressed: _submit,
          child: Text(widget.scene == null ? 'Save scene' : 'Rename'),
        ),
      ],
    );
  }
}

enum _ClipboardCommand { copy, paste }

enum _CanvasPointerMode {
  primaryCandidate,
  secondaryCandidate,
  marquee,
  panning,
  cancelled,
}

enum _ConnectionContextMenuCommand { editLabel, remove }

class _SceneWalkthroughRequest {
  const _SceneWalkthroughRequest({this.sceneId});

  final String? sceneId;
}

enum _SceneActionCommand {
  updateView,
  startWalkthrough,
  earlier,
  later,
  rename,
  delete,
}

enum _ContextMenuCommand {
  togglePositionLock,
  group,
  addToGroup,
  removeFromGroup,
  ungroup,
  hideGroup,
  copy,
  paste,
  openLink,
  openLinks,
  editNoteTitle,
  editImageCaption,
  toggleGifPlayback,
  removeImageCaption,
  editHeading,
  changeHeadingSize,
  changeHeadingBackground,
  duplicate,
  selectConnected,
  changeNoteColor,
  toggleConnection,
  connectWithLabel,
  editConnectionLabel,
  delete,
}

enum _CanvasContextMenuCommand {
  addNoteHere,
  addHeadingHere,
  pasteImageHere,
  pasteWebsiteHere,
  pasteWebsiteListHere,
  pasteTextHere,
  embedYouTubeHere,
  paste,
  shareBoardImage,
}

enum _ImageSharingCommand {
  exportCurrentView,
  copyCurrentView,
  exportWholeBoard,
  copyWholeBoard,
}

enum _AttachmentContextCommand {
  togglePositionLock,
  group,
  addToGroup,
  removeFromGroup,
  ungroup,
  hideGroup,
  open,
  copy,
  duplicate,
  delete,
}

enum _YouTubeContextCommand {
  togglePositionLock,
  group,
  addToGroup,
  removeFromGroup,
  ungroup,
  hideGroup,
  open,
  delete,
}
