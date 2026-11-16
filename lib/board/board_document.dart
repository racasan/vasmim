import 'package:characters/characters.dart';

import '../attachment/board_attachment.dart';
import '../connector/connector.dart';
import '../heading/canvas_heading.dart';
import '../group/board_group.dart';
import '../image/board_image.dart';
import '../note/note.dart';
import '../note/note_emphasis.dart';
import '../note/note_text_link.dart';
import '../scene/scene.dart';
import '../shape/board_shape.dart';
import '../shape/shape_layer.dart';
import '../youtube/youtube_embed.dart';
import 'board_paper_tone.dart';

class BoardDocument {
  BoardDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.viewportX,
    required this.viewportY,
    required this.viewportZoom,
    required List<Note> notes,
    List<Connector> connectors = const [],
    List<BoardImage> images = const [],
    List<Scene> scenes = const [],
    List<CanvasHeading> headings = const [],
    List<BoardAttachment> attachments = const [],
    List<YouTubeEmbed> youTubeEmbeds = const [],
    List<BoardShape> shapes = const [],
    List<ShapeLayer>? shapeLayers,
    List<BoardGroup> groups = const [],
    this.isSnappingEnabled = false,
    this.paperTone = BoardPaperTone.defaultTone,
    Iterable<String> lockedObjectIds = const [],
    bool allowShapeGroupMembers = true,
  }) : notes = List.unmodifiable(notes),
       connectors = List.unmodifiable(connectors),
       images = List.unmodifiable(images),
       scenes = List.unmodifiable(scenes),
       headings = List.unmodifiable(headings),
       attachments = List.unmodifiable(attachments),
       youTubeEmbeds = List.unmodifiable(youTubeEmbeds),
       shapes = List.unmodifiable(shapes),
       shapeLayers = List.unmodifiable(
         shapeLayers ??
             [
               ShapeLayer.defaultForBoard(
                 boardId: id,
                 shapeIds: shapes.map((shape) => shape.id),
                 createdAt: createdAt,
                 modifiedAt: modifiedAt,
               ),
             ],
       ),
       groups = List.unmodifiable(groups),
       lockedObjectIds = List.unmodifiable(lockedObjectIds) {
    final invalidReason =
        _invalidNoteReason(this.notes) ??
        _invalidImageReason(this.notes, this.images) ??
        _invalidHeadingReason(this.notes, this.images, this.headings) ??
        _invalidAttachmentReason(
          this.notes,
          this.images,
          this.headings,
          this.attachments,
        ) ??
        _invalidYouTubeEmbedReason(
          this.notes,
          this.images,
          this.headings,
          this.attachments,
          this.youTubeEmbeds,
        ) ??
        _invalidShapeReason(
          this.notes,
          this.images,
          this.headings,
          this.attachments,
          this.youTubeEmbeds,
          this.shapes,
        ) ??
        _invalidShapeLayerReason(this.shapes, this.shapeLayers) ??
        _invalidGroupReason(
          this.notes,
          this.images,
          this.headings,
          this.attachments,
          this.youTubeEmbeds,
          this.shapes,
          this.groups,
          allowShapeGroupMembers: allowShapeGroupMembers,
        ) ??
        _invalidLockedObjectReason(
          this.notes,
          this.images,
          this.headings,
          this.attachments,
          this.youTubeEmbeds,
          this.lockedObjectIds,
        ) ??
        _invalidConnectorReason(this.notes, this.images, this.connectors) ??
        _invalidSceneReason(this.scenes);
    if (invalidReason != null) {
      throw ArgumentError(invalidReason);
    }
  }

  static const currentFormatVersion = 31;
  static const minimumViewportZoom = 0.1;
  static const maximumViewportZoom = 4.0;

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final double viewportX;
  final double viewportY;
  final double viewportZoom;
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
  final bool isSnappingEnabled;
  final BoardPaperTone paperTone;
  final List<String> lockedObjectIds;

  BoardDocument copyWith({
    String? name,
    DateTime? modifiedAt,
    bool? isSnappingEnabled,
    BoardPaperTone? paperTone,
    Iterable<String>? lockedObjectIds,
  }) {
    return BoardDocument(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      viewportX: viewportX,
      viewportY: viewportY,
      viewportZoom: viewportZoom,
      notes: notes,
      connectors: connectors,
      images: images,
      scenes: scenes,
      headings: headings,
      attachments: attachments,
      youTubeEmbeds: youTubeEmbeds,
      shapes: shapes,
      shapeLayers: shapeLayers,
      groups: groups,
      isSnappingEnabled: isSnappingEnabled ?? this.isSnappingEnabled,
      paperTone: paperTone ?? this.paperTone,
      lockedObjectIds: lockedObjectIds ?? this.lockedObjectIds,
    );
  }

  Map<String, Object> toJson() {
    return {
      'formatVersion': currentFormatVersion,
      'board': {
        'id': id,
        'name': name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'modifiedAt': modifiedAt.toUtc().toIso8601String(),
      },
      'viewport': {'x': viewportX, 'y': viewportY, 'zoom': viewportZoom},
      'notes': notes.map((note) => note.toJson()).toList(),
      'connectors': connectors.map((connector) => connector.toJson()).toList(),
      'images': images.map((image) => image.toJson()).toList(),
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
      'headings': headings.map((heading) => heading.toJson()).toList(),
      'attachments': attachments.map((value) => value.toJson()).toList(),
      'youTubeEmbeds': youTubeEmbeds.map((value) => value.toJson()).toList(),
      'shapes': shapes.map((value) => value.toJson()).toList(),
      'shapeLayers': shapeLayers.map((value) => value.toJson()).toList(),
      'groups': groups.map((value) => value.toJson()).toList(),
      'snapping': {'enabled': isSnappingEnabled},
      'paperTone': paperTone.name,
      'lockedObjectIds': lockedObjectIds.toList(),
    };
  }

  factory BoardDocument.fromJson(Map<String, dynamic> json) {
    final formatVersion = json['formatVersion'];
    if (formatVersion is! int ||
        formatVersion < 1 ||
        formatVersion > currentFormatVersion) {
      throw FormatException('Unsupported board format version: $formatVersion');
    }

    final board = Map<String, dynamic>.from(json['board'] as Map);
    final viewport = Map<String, dynamic>.from(json['viewport'] as Map);
    final notes = json['notes'] as List;
    final connectors = formatVersion < 2
        ? const <dynamic>[]
        : json['connectors'] as List;
    final images = formatVersion >= 3
        ? json['images'] as List
        : const <dynamic>[];
    final scenes = formatVersion >= 4
        ? json['scenes'] as List
        : const <dynamic>[];
    final headings = formatVersion >= 12
        ? json['headings'] as List
        : const <dynamic>[];
    final attachments = formatVersion >= 13
        ? json['attachments'] as List
        : const <dynamic>[];
    final youTubeEmbeds = formatVersion >= 14
        ? json['youTubeEmbeds'] as List
        : const <dynamic>[];
    final shapes = formatVersion >= 15
        ? json['shapes'] as List
        : const <dynamic>[];
    final shapeLayers = formatVersion >= 20
        ? json['shapeLayers'] as List
        : null;
    final groups = formatVersion >= 23
        ? json['groups'] as List
        : const <dynamic>[];
    final snapping = formatVersion >= 25
        ? Map<String, dynamic>.from(json['snapping'] as Map)
        : null;
    final lockedObjectIds = formatVersion >= 26
        ? json['lockedObjectIds'] as List
        : const <dynamic>[];

    try {
      return BoardDocument(
        id: board['id'] as String,
        name: board['name'] as String,
        createdAt: DateTime.parse(board['createdAt'] as String).toUtc(),
        modifiedAt: DateTime.parse(board['modifiedAt'] as String).toUtc(),
        viewportX: (viewport['x'] as num).toDouble(),
        viewportY: (viewport['y'] as num).toDouble(),
        viewportZoom: (viewport['zoom'] as num).toDouble(),
        notes: [
          for (final note in notes)
            Note.fromJson(
              Map<String, dynamic>.from(note as Map),
              readTitle: formatVersion >= 7,
              readEmphasis: formatVersion >= 8,
              readItalic: formatVersion >= 11,
              readLinks: formatVersion >= 9,
            ),
        ],
        connectors: [
          for (final connector in connectors)
            Connector.fromJson(
              Map<String, dynamic>.from(connector as Map),
              legacyNoteEndpoints: formatVersion < 5,
              readLabel: formatVersion >= 6,
            ),
        ],
        images: [
          for (final image in images)
            BoardImage.fromJson(
              Map<String, dynamic>.from(image as Map),
              readCaption: formatVersion >= 10,
            ),
        ],
        scenes: [
          for (final scene in scenes)
            Scene.fromJson(Map<String, dynamic>.from(scene as Map)),
        ],
        headings: [
          for (final heading in headings)
            CanvasHeading.fromJson(Map<String, dynamic>.from(heading as Map)),
        ],
        attachments: [
          for (final attachment in attachments)
            BoardAttachment.fromJson(
              Map<String, dynamic>.from(attachment as Map),
              readPreview: formatVersion >= 14,
              readAudio: formatVersion >= 31,
            ),
        ],
        youTubeEmbeds: [
          for (final embed in youTubeEmbeds)
            YouTubeEmbed.fromJson(Map<String, dynamic>.from(embed as Map)),
        ],
        shapes: [
          for (final shape in shapes)
            BoardShape.fromJson(
              Map<String, dynamic>.from(shape as Map),
              readExpandedTypes: formatVersion >= 16,
              readOrthogonalTypes: formatVersion >= 17,
              readDoubleEndedTypes: formatVersion >= 18,
              readBlockArrowTypes: formatVersion >= 19,
              readFlowchartTypes: formatVersion >= 27,
              readCatalogueTypes: formatVersion >= 30,
            ),
        ],
        shapeLayers: shapeLayers == null
            ? null
            : [
                for (final layer in shapeLayers)
                  ShapeLayer.fromJson(
                    Map<String, dynamic>.from(layer as Map),
                    readVisibility: formatVersion >= 21,
                    readOpacity: formatVersion >= 22,
                  ),
              ],
        groups: [
          for (final group in groups)
            BoardGroup.fromJson(
              Map<String, dynamic>.from(group as Map),
              readName: formatVersion >= 24,
            ),
        ],
        allowShapeGroupMembers: formatVersion >= 28,
        isSnappingEnabled: snapping == null
            ? false
            : snapping['enabled'] as bool,
        paperTone: formatVersion >= 29
            ? BoardPaperTone.values.byName(json['paperTone'] as String)
            : BoardPaperTone.defaultTone,
        lockedObjectIds: lockedObjectIds.cast<String>(),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid board data: ${error.message}');
    } on TypeError catch (error) {
      throw FormatException('Invalid board data: $error');
    }
  }

  static String? _invalidNoteReason(List<Note> notes) {
    final noteIds = <String>{};
    for (final note in notes) {
      if (note.id.isEmpty || !noteIds.add(note.id)) {
        return 'Note identifiers must be non-empty and unique.';
      }
      final title = note.title;
      if (title != null &&
          (title.isEmpty ||
              title != title.trim() ||
              title.characters.length > Note.maximumTitleCharacters ||
              RegExp(r'[\r\n\u2028\u2029]').hasMatch(title))) {
        return 'A note title must be trimmed, single-line, non-empty, and at most 80 characters.';
      }
      final emphasisReason = NoteEmphasis.invalidReason(
        note.text,
        note.emphasis,
      );
      if (emphasisReason != null) {
        return emphasisReason;
      }
      final linkReason = NoteTextLinks.invalidReason(note.text, note.links);
      if (linkReason != null) {
        return linkReason;
      }
    }
    return null;
  }

  static String? _invalidConnectorReason(
    List<Note> notes,
    List<BoardImage> images,
    List<Connector> connectors,
  ) {
    final objectIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
    };
    final connectorIds = <String>{};
    final connectedPairs = <(String, String)>{};

    for (final connector in connectors) {
      if (!connectorIds.add(connector.id)) {
        return 'Connector identifiers must be unique.';
      }
      if (connector.objectAId == connector.objectBId) {
        return 'A connector cannot link an object to itself.';
      }
      if (!objectIds.contains(connector.objectAId) ||
          !objectIds.contains(connector.objectBId)) {
        return 'Every connector endpoint must reference an existing canvas object.';
      }
      final label = connector.label;
      if (label != null &&
          (label.isEmpty ||
              label != label.trim() ||
              label.characters.length > 80 ||
              RegExp(r'[\r\n\u2028\u2029]').hasMatch(label))) {
        return 'A connector label must be trimmed, single-line, non-empty, and at most 80 characters.';
      }

      final pair = connector.objectAId.compareTo(connector.objectBId) < 0
          ? (connector.objectAId, connector.objectBId)
          : (connector.objectBId, connector.objectAId);
      if (!connectedPairs.add(pair)) {
        return 'An object pair can have only one connector.';
      }
    }

    return null;
  }

  static String? _invalidHeadingReason(
    List<Note> notes,
    List<BoardImage> images,
    List<CanvasHeading> headings,
  ) {
    final objectIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
    };
    for (final heading in headings) {
      if (heading.id.isEmpty || !objectIds.add(heading.id)) {
        return 'Heading identifiers must be non-empty and unique across canvas objects.';
      }
      if (!heading.x.isFinite || !heading.y.isFinite) {
        return 'Heading geometry must contain finite coordinates.';
      }
      String? normalizedText;
      try {
        normalizedText = CanvasHeading.normalizeText(heading.text);
      } on FormatException {
        return 'A heading must be trimmed, single-line, non-empty, and at most 80 characters.';
      }
      if (normalizedText == null || normalizedText != heading.text) {
        return 'A heading must be trimmed, single-line, non-empty, and at most 80 characters.';
      }
    }
    return null;
  }

  static String? _invalidImageReason(
    List<Note> notes,
    List<BoardImage> images,
  ) {
    final objectIds = notes.map((note) => note.id).toSet();
    for (final image in images) {
      if (image.id.isEmpty || !objectIds.add(image.id)) {
        return 'Image identifiers must be non-empty and unique across canvas objects.';
      }
      if (!image.x.isFinite ||
          !image.y.isFinite ||
          !image.width.isFinite ||
          !image.height.isFinite ||
          image.width <= 0 ||
          image.height <= 0) {
        return 'Image geometry must contain finite coordinates and positive dimensions.';
      }
      if (image.pixelWidth <= 0 || image.pixelHeight <= 0) {
        return 'Image pixel dimensions must be positive.';
      }
      if (image.originalFileName.isEmpty) {
        return 'An image must retain its original filename.';
      }
      if (!_isSafeRelativeAssetPath(image.assetPath)) {
        return 'Image asset paths must be safe relative paths.';
      }
    }
    return null;
  }

  static String? _invalidAttachmentReason(
    List<Note> notes,
    List<BoardImage> images,
    List<CanvasHeading> headings,
    List<BoardAttachment> attachments,
  ) {
    final objectIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
      for (final heading in headings) heading.id,
    };
    final assetPaths = <String>{};
    for (final attachment in attachments) {
      if (attachment.id.isEmpty || !objectIds.add(attachment.id)) {
        return 'Attachment identifiers must be non-empty and unique across canvas objects.';
      }
      if (!attachment.x.isFinite ||
          !attachment.y.isFinite ||
          !attachment.width.isFinite ||
          !attachment.height.isFinite ||
          attachment.width <= 0 ||
          attachment.height <= 0) {
        return 'Attachment geometry must contain finite coordinates and positive dimensions.';
      }
      if (attachment.originalFileName.isEmpty || attachment.byteSize <= 0) {
        return 'An attachment must retain a filename and positive byte size.';
      }
      if (!_isSafeRelativeAssetPath(attachment.assetPath) ||
          !assetPaths.add(attachment.assetPath.replaceAll('\\', '/'))) {
        return 'Attachment asset paths must be safe and unique.';
      }
      final previewPath = attachment.previewAssetPath;
      if (previewPath != null &&
          (!_isSafeRelativeAssetPath(previewPath) ||
              !RegExp(
                r'^assets/[A-Za-z0-9_-]+\.(png|jpe?g)$',
                caseSensitive: false,
              ).hasMatch(previewPath.replaceAll(r'\', '/')))) {
        return 'An attachment preview must use a managed image asset path.';
      }
      try {
        if (AttachmentKind.fromFileName(attachment.originalFileName) !=
            attachment.kind) {
          return 'Attachment kind must match its original filename.';
        }
      } on FormatException {
        return 'Attachment filename must use a supported extension.';
      }
    }
    return null;
  }

  static String? _invalidYouTubeEmbedReason(
    List<Note> notes,
    List<BoardImage> images,
    List<CanvasHeading> headings,
    List<BoardAttachment> attachments,
    List<YouTubeEmbed> embeds,
  ) {
    final objectIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
      for (final heading in headings) heading.id,
      for (final attachment in attachments) attachment.id,
    };
    final videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');
    for (final embed in embeds) {
      if (embed.id.isEmpty || !objectIds.add(embed.id)) {
        return 'YouTube identifiers must be non-empty and unique across canvas objects.';
      }
      if (!embed.x.isFinite ||
          !embed.y.isFinite ||
          !embed.width.isFinite ||
          !embed.height.isFinite ||
          embed.width <= 0 ||
          embed.height <= 0 ||
          embed.originalUrl.isEmpty ||
          !videoId.hasMatch(embed.videoId)) {
        return 'A YouTube embed must contain safe geometry and a valid video identifier.';
      }
      final thumbnailPath = embed.thumbnailAssetPath;
      if (thumbnailPath != null &&
          (!_isSafeRelativeAssetPath(thumbnailPath) ||
              !RegExp(
                r'^assets/[A-Za-z0-9_-]+\.(png|jpe?g)$',
                caseSensitive: false,
              ).hasMatch(thumbnailPath.replaceAll(r'\', '/')))) {
        return 'A YouTube thumbnail must use a managed image asset path.';
      }
    }
    return null;
  }

  static String? _invalidShapeReason(
    List<Note> notes,
    List<BoardImage> images,
    List<CanvasHeading> headings,
    List<BoardAttachment> attachments,
    List<YouTubeEmbed> embeds,
    List<BoardShape> shapes,
  ) {
    final objectIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
      for (final heading in headings) heading.id,
      for (final attachment in attachments) attachment.id,
      for (final embed in embeds) embed.id,
    };
    for (final shape in shapes) {
      if (shape.id.isEmpty || !objectIds.add(shape.id)) {
        return 'Shape identifiers must be non-empty and unique across canvas objects.';
      }
      if (!shape.x.isFinite ||
          !shape.y.isFinite ||
          !shape.width.isFinite ||
          !shape.height.isFinite ||
          shape.width < 0 ||
          shape.height < 0 ||
          (shape.isOpen
              ? shape.width * shape.width + shape.height * shape.height <
                    BoardShape.minimumLineLength * BoardShape.minimumLineLength
              : shape.width < BoardShape.minimumClosedWidth ||
                    shape.height < BoardShape.minimumClosedHeight)) {
        return 'Shape geometry must contain finite coordinates and useful dimensions.';
      }
      if (shape.fillColorValue < 0 ||
          shape.fillColorValue > 0xFFFFFFFF ||
          shape.outlineColorValue < 0 ||
          shape.outlineColorValue > 0xFFFFFFFF ||
          !shape.fillOpacity.isFinite ||
          shape.fillOpacity < 0 ||
          shape.fillOpacity > 1 ||
          !BoardShape.supportedOutlineWidths.contains(shape.outlineWidth)) {
        return 'Shape appearance values must be supported.';
      }
      if (!shape.spinePosition.isFinite ||
          shape.spinePosition < 0 ||
          shape.spinePosition > 1) {
        return 'An orthogonal shape spine must remain within its endpoints.';
      }
      final shapeHeading = shape.heading;
      if (shapeHeading != null) {
        String? normalized;
        try {
          normalized = ShapeHeading.normalizeText(shapeHeading.text);
        } on FormatException {
          return 'A shape heading must be valid.';
        }
        if (normalized != shapeHeading.text ||
            !ShapeHeading.supportedFontSizes.contains(shapeHeading.fontSize) ||
            shapeHeading.colorValue < 0 ||
            shapeHeading.colorValue > 0xFFFFFFFF) {
          return 'A shape heading must be valid.';
        }
      }
    }
    return null;
  }

  static String? _invalidShapeLayerReason(
    List<BoardShape> shapes,
    List<ShapeLayer> layers,
  ) {
    if (layers.isEmpty) {
      return 'A Board must contain at least one shape layer.';
    }
    final layerIds = <String>{};
    final layerNames = <String>{};
    final knownShapeIds = {for (final shape in shapes) shape.id};
    final assignedShapeIds = <String>{};
    for (final layer in layers) {
      if (layer.id.isEmpty || !layerIds.add(layer.id)) {
        return 'Shape layer identifiers must be non-empty and unique.';
      }
      String normalizedName;
      try {
        normalizedName = ShapeLayer.normalizeName(layer.name);
      } on FormatException {
        return 'Shape layer names must be valid.';
      }
      if (normalizedName != layer.name ||
          !layerNames.add(normalizedName.toLowerCase())) {
        return 'Shape layer names must be valid and unique.';
      }
      if (!layer.opacity.isFinite ||
          !ShapeLayer.supportedOpacities.contains(layer.opacity)) {
        return 'Shape layer opacity must use a supported preset.';
      }
      for (final shapeId in layer.shapeIds) {
        if (!knownShapeIds.contains(shapeId) ||
            !assignedShapeIds.add(shapeId)) {
          return 'Every shape must belong to exactly one valid shape layer.';
        }
      }
    }
    if (assignedShapeIds.length != knownShapeIds.length) {
      return 'Every shape must belong to exactly one valid shape layer.';
    }
    return null;
  }

  static String? _invalidGroupReason(
    List<Note> notes,
    List<BoardImage> images,
    List<CanvasHeading> headings,
    List<BoardAttachment> attachments,
    List<YouTubeEmbed> embeds,
    List<BoardShape> shapes,
    List<BoardGroup> groups, {
    required bool allowShapeGroupMembers,
  }) {
    final eligibleIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
      for (final heading in headings) heading.id,
      for (final attachment in attachments) attachment.id,
      for (final embed in embeds) embed.id,
      if (allowShapeGroupMembers)
        for (final shape in shapes) shape.id,
    };
    final groupIds = <String>{};
    final assignedIds = <String>{};
    for (final group in groups) {
      if (group.id.isEmpty || !groupIds.add(group.id)) {
        return 'Group identifiers must be non-empty and unique.';
      }
      if (group.memberIds.length < 2 ||
          group.memberIds.toSet().length != group.memberIds.length ||
          !eligibleIds.containsAll(group.memberIds)) {
        return 'A group must contain at least two unique eligible canvas objects.';
      }
      final name = group.name;
      if (name != null &&
          (name.isEmpty || name != name.trim() || name.length > 80)) {
        return 'Group names must be trimmed non-empty text of at most 80 characters.';
      }
      for (final memberId in group.memberIds) {
        if (!assignedIds.add(memberId)) {
          return 'A canvas object can belong to only one group.';
        }
      }
    }
    return null;
  }

  static String? _invalidLockedObjectReason(
    List<Note> notes,
    List<BoardImage> images,
    List<CanvasHeading> headings,
    List<BoardAttachment> attachments,
    List<YouTubeEmbed> embeds,
    List<String> lockedObjectIds,
  ) {
    final eligibleIds = {
      for (final note in notes) note.id,
      for (final image in images) image.id,
      for (final heading in headings) heading.id,
      for (final attachment in attachments) attachment.id,
      for (final embed in embeds) embed.id,
    };
    if (lockedObjectIds.toSet().length != lockedObjectIds.length ||
        lockedObjectIds.any((id) => id.isEmpty || !eligibleIds.contains(id))) {
      return 'Locked object identifiers must reference eligible foreground objects.';
    }
    return null;
  }

  static bool _isSafeRelativeAssetPath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.startsWith(r'\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      return false;
    }
    final segments = path.replaceAll(r'\', '/').split('/');
    return segments.every((segment) => segment.isNotEmpty && segment != '..');
  }

  static String? _invalidSceneReason(List<Scene> scenes) {
    final sceneIds = <String>{};
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    for (final scene in scenes) {
      if (!uuidV4.hasMatch(scene.id) || !sceneIds.add(scene.id)) {
        return 'Scene identifiers must be unique UUID-v4 values.';
      }
      if (scene.name.trim().isEmpty) {
        return 'Scene names must be non-empty after trimming.';
      }
      if (!scene.x.isFinite || !scene.y.isFinite) {
        return 'Scene coordinates must be finite.';
      }
      if (!scene.zoom.isFinite ||
          scene.zoom < minimumViewportZoom ||
          scene.zoom > maximumViewportZoom) {
        return 'Scene zoom must be within the supported viewport range.';
      }
    }
    return null;
  }
}
