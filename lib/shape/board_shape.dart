import 'package:characters/characters.dart';

enum BoardShapeType {
  rectangle,
  roundedRectangle,
  ellipse,
  line,
  arrow,
  triangle,
  rightTriangle,
  diamond,
  parallelogram,
  trapezoid,
  hexagon,
  elbowLine,
  elbowArrow,
  doubleArrow,
  doubleElbowArrow,
  blockArrowRight,
  blockArrowLeft,
  blockArrowUp,
  blockArrowDown,
  terminator,
  document,
  database,
  predefinedProcess,
  pentagon,
  octagon,
  heart,
  lightning,
  leftBracket,
  rightBracket,
  smiley,
  moon,
  cloud,
  turnBlockArrow,
  uTurnBlockArrow,
  splitBlockArrow,
  mergeBlockArrow,
  circularBlockArrow,
  star,
  banner,
  callout,
  curvedLine,
  multiBendLine,
}

extension BoardShapeTypeValue on BoardShapeType {
  String get label => switch (this) {
    BoardShapeType.rectangle => 'Rectangle',
    BoardShapeType.roundedRectangle => 'Rounded rectangle',
    BoardShapeType.ellipse => 'Ellipse',
    BoardShapeType.line => 'Straight line',
    BoardShapeType.arrow => 'Arrow',
    BoardShapeType.triangle => 'Triangle',
    BoardShapeType.rightTriangle => 'Right triangle',
    BoardShapeType.diamond => 'Diamond',
    BoardShapeType.parallelogram => 'Parallelogram',
    BoardShapeType.trapezoid => 'Trapezoid',
    BoardShapeType.hexagon => 'Hexagon',
    BoardShapeType.elbowLine => 'Elbow line',
    BoardShapeType.elbowArrow => 'Elbow arrow',
    BoardShapeType.doubleArrow => 'Double-ended arrow',
    BoardShapeType.doubleElbowArrow => 'Double-ended elbow arrow',
    BoardShapeType.blockArrowRight => 'Right block arrow',
    BoardShapeType.blockArrowLeft => 'Left block arrow',
    BoardShapeType.blockArrowUp => 'Up block arrow',
    BoardShapeType.blockArrowDown => 'Down block arrow',
    BoardShapeType.terminator => 'Terminator',
    BoardShapeType.document => 'Document',
    BoardShapeType.database => 'Database',
    BoardShapeType.predefinedProcess => 'Predefined process',
    BoardShapeType.pentagon => 'Pentagon',
    BoardShapeType.octagon => 'Octagon',
    BoardShapeType.heart => 'Heart',
    BoardShapeType.lightning => 'Lightning',
    BoardShapeType.leftBracket => 'Left bracket',
    BoardShapeType.rightBracket => 'Right bracket',
    BoardShapeType.smiley => 'Smiley',
    BoardShapeType.moon => 'Moon',
    BoardShapeType.cloud => 'Cloud',
    BoardShapeType.turnBlockArrow => 'Turn block arrow',
    BoardShapeType.uTurnBlockArrow => 'U-turn block arrow',
    BoardShapeType.splitBlockArrow => 'Split block arrow',
    BoardShapeType.mergeBlockArrow => 'Merge block arrow',
    BoardShapeType.circularBlockArrow => 'Circular block arrow',
    BoardShapeType.star => 'Star',
    BoardShapeType.banner => 'Banner',
    BoardShapeType.callout => 'Callout',
    BoardShapeType.curvedLine => 'Curved line',
    BoardShapeType.multiBendLine => 'Multi-bend line',
  };

  bool get supportsFill => switch (this) {
    BoardShapeType.line ||
    BoardShapeType.arrow ||
    BoardShapeType.elbowLine ||
    BoardShapeType.elbowArrow ||
    BoardShapeType.doubleArrow ||
    BoardShapeType.doubleElbowArrow => false,
    BoardShapeType.curvedLine || BoardShapeType.multiBendLine => false,
    _ => true,
  };
}

enum OrthogonalRouteAxis { horizontalFirst, verticalFirst }

enum ShapeHeadingAlignment { left, center, right }

enum ShapeHeadingPlacement { insideTop, above }

class ShapeHeading {
  const ShapeHeading({
    required this.text,
    this.fontSize = 20,
    this.colorValue = 0xFF263238,
    this.alignment = ShapeHeadingAlignment.center,
    this.placement = ShapeHeadingPlacement.insideTop,
  });

  static const maximumCharacters = 160;
  static const supportedFontSizes = <double>[16, 20, 28, 40];

  final String text;
  final double fontSize;
  final int colorValue;
  final ShapeHeadingAlignment alignment;
  final ShapeHeadingPlacement placement;

  ShapeHeading copyWith({
    String? text,
    double? fontSize,
    int? colorValue,
    ShapeHeadingAlignment? alignment,
    ShapeHeadingPlacement? placement,
  }) => ShapeHeading(
    text: text ?? this.text,
    fontSize: fontSize ?? this.fontSize,
    colorValue: colorValue ?? this.colorValue,
    alignment: alignment ?? this.alignment,
    placement: placement ?? this.placement,
  );

  Map<String, Object> toJson() => {
    'text': text,
    'fontSize': fontSize,
    'colorValue': colorValue,
    'alignment': alignment.name,
    'placement': placement.name,
  };

  factory ShapeHeading.fromJson(Map<String, dynamic> json) => ShapeHeading(
    text: json['text'] as String,
    fontSize: (json['fontSize'] as num).toDouble(),
    colorValue: json['colorValue'] as int,
    alignment: ShapeHeadingAlignment.values.byName(json['alignment'] as String),
    placement: ShapeHeadingPlacement.values.byName(json['placement'] as String),
  );

  static String? normalizeText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;
    if (RegExp(r'[\r\n\u2028\u2029]').hasMatch(text) ||
        text.characters.length > maximumCharacters) {
      throw const FormatException(
        'A shape heading must be single-line and at most 160 characters.',
      );
    }
    return text;
  }
}

class BoardShape {
  const BoardShape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.lineStartsAtTopLeft = true,
    this.lineReversed = false,
    this.routeAxis = OrthogonalRouteAxis.horizontalFirst,
    this.spinePosition = 0.5,
    this.fillColorValue = 0xFFFFFFFF,
    this.fillOpacity = 0,
    this.outlineColorValue = 0xFF263238,
    this.outlineWidth = 2,
    required this.createdAt,
    required this.modifiedAt,
    this.heading,
  });

  static const minimumClosedWidth = 40.0;
  static const minimumClosedHeight = 30.0;
  static const minimumLineLength = 12.0;
  static const supportedOutlineWidths = <double>[1, 2, 4, 8];

  final String id;
  final BoardShapeType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool lineStartsAtTopLeft;
  final bool lineReversed;
  final OrthogonalRouteAxis routeAxis;
  final double spinePosition;
  final int fillColorValue;
  final double fillOpacity;
  final int outlineColorValue;
  final double outlineWidth;
  final ShapeHeading? heading;
  final DateTime createdAt;
  final DateTime modifiedAt;

  bool get isOpen => !type.supportsFill;
  bool get isOrthogonal =>
      type == BoardShapeType.elbowLine ||
      type == BoardShapeType.elbowArrow ||
      type == BoardShapeType.doubleElbowArrow;

  BoardShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? lineStartsAtTopLeft,
    bool? lineReversed,
    OrthogonalRouteAxis? routeAxis,
    double? spinePosition,
    int? fillColorValue,
    double? fillOpacity,
    int? outlineColorValue,
    double? outlineWidth,
    ShapeHeading? heading,
    bool removeHeading = false,
    DateTime? modifiedAt,
  }) => BoardShape(
    id: id,
    type: type,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    lineStartsAtTopLeft: lineStartsAtTopLeft ?? this.lineStartsAtTopLeft,
    lineReversed: lineReversed ?? this.lineReversed,
    routeAxis: routeAxis ?? this.routeAxis,
    spinePosition: spinePosition ?? this.spinePosition,
    fillColorValue: fillColorValue ?? this.fillColorValue,
    fillOpacity: fillOpacity ?? this.fillOpacity,
    outlineColorValue: outlineColorValue ?? this.outlineColorValue,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    heading: removeHeading ? null : heading ?? this.heading,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'lineStartsAtTopLeft': lineStartsAtTopLeft,
    'lineReversed': lineReversed,
    'routeAxis': routeAxis.name,
    'spinePosition': spinePosition,
    'fillColorValue': fillColorValue,
    'fillOpacity': fillOpacity,
    'outlineColorValue': outlineColorValue,
    'outlineWidth': outlineWidth,
    'heading': heading?.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
  };

  factory BoardShape.fromJson(
    Map<String, dynamic> json, {
    bool readExpandedTypes = true,
    bool readOrthogonalTypes = true,
    bool readDoubleEndedTypes = true,
    bool readBlockArrowTypes = true,
    bool readFlowchartTypes = true,
    bool readCatalogueTypes = true,
  }) {
    final type = BoardShapeType.values.byName(json['type'] as String);
    if (!readExpandedTypes && !type.isStageOne) {
      throw const FormatException(
        'Expanded shape types require Board format 16.',
      );
    }
    if (!readOrthogonalTypes && type.isOrthogonal) {
      throw const FormatException(
        'Orthogonal shape types require Board format 17.',
      );
    }
    if (!readDoubleEndedTypes && type.isDoubleEnded) {
      throw const FormatException(
        'Double-ended arrow types require Board format 18.',
      );
    }
    if (!readBlockArrowTypes && type.isBlockArrow) {
      throw const FormatException('Block arrow types require Board format 19.');
    }
    if (!readFlowchartTypes && type.isFlowchart) {
      throw const FormatException(
        'Flowchart shape types require Board format 27.',
      );
    }
    if (!readCatalogueTypes && type.isCatalogue30) {
      throw const FormatException(
        'Expanded catalogue types require Board format 30.',
      );
    }
    return BoardShape(
      id: json['id'] as String,
      type: type,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      lineStartsAtTopLeft: json['lineStartsAtTopLeft'] as bool,
      lineReversed: json['lineReversed'] as bool,
      routeAxis: readOrthogonalTypes && json['routeAxis'] != null
          ? OrthogonalRouteAxis.values.byName(json['routeAxis'] as String)
          : OrthogonalRouteAxis.horizontalFirst,
      spinePosition: readOrthogonalTypes && json['spinePosition'] != null
          ? (json['spinePosition'] as num).toDouble()
          : 0.5,
      fillColorValue: json['fillColorValue'] as int,
      fillOpacity: (json['fillOpacity'] as num).toDouble(),
      outlineColorValue: json['outlineColorValue'] as int,
      outlineWidth: (json['outlineWidth'] as num).toDouble(),
      heading: json['heading'] == null
          ? null
          : ShapeHeading.fromJson(
              Map<String, dynamic>.from(json['heading'] as Map),
            ),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }
}

extension BoardShapeTypeVersion on BoardShapeType {
  bool get isStageOne => index <= BoardShapeType.arrow.index;
  bool get isOrthogonal =>
      this == BoardShapeType.elbowLine ||
      this == BoardShapeType.elbowArrow ||
      this == BoardShapeType.doubleElbowArrow;
  bool get isDoubleEnded =>
      this == BoardShapeType.doubleArrow ||
      this == BoardShapeType.doubleElbowArrow;
  bool get isBlockArrow =>
      this == BoardShapeType.blockArrowRight ||
      this == BoardShapeType.blockArrowLeft ||
      this == BoardShapeType.blockArrowUp ||
      this == BoardShapeType.blockArrowDown;
  bool get isFlowchart =>
      this == BoardShapeType.terminator ||
      this == BoardShapeType.document ||
      this == BoardShapeType.database ||
      this == BoardShapeType.predefinedProcess;
  bool get isCatalogue30 =>
      this == BoardShapeType.pentagon ||
      this == BoardShapeType.octagon ||
      this == BoardShapeType.heart ||
      this == BoardShapeType.lightning ||
      this == BoardShapeType.leftBracket ||
      this == BoardShapeType.rightBracket ||
      this == BoardShapeType.smiley ||
      this == BoardShapeType.moon ||
      this == BoardShapeType.cloud ||
      this == BoardShapeType.turnBlockArrow ||
      this == BoardShapeType.uTurnBlockArrow ||
      this == BoardShapeType.splitBlockArrow ||
      this == BoardShapeType.mergeBlockArrow ||
      this == BoardShapeType.circularBlockArrow ||
      this == BoardShapeType.star ||
      this == BoardShapeType.banner ||
      this == BoardShapeType.callout ||
      this == BoardShapeType.curvedLine ||
      this == BoardShapeType.multiBendLine;
}
