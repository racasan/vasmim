import 'package:flutter/material.dart';

import 'connector.dart';
import 'connector_geometry.dart';

class ConnectorStroke {
  const ConnectorStroke({
    required this.connectorId,
    required this.segment,
    required this.color,
    required this.strokeWidth,
  });

  final String connectorId;
  final ConnectorSegment segment;
  final Color color;
  final double strokeWidth;
}

class ConnectorPainter extends CustomPainter {
  ConnectorPainter({
    required this.objectBounds,
    required this.connectors,
    required this.viewportScale,
    this.hoveredConnectorId,
    this.isDark = false,
  });

  static const screenStrokeWidth = 2.25;
  static const hoveredScreenStrokeWidth = 3.75;
  static const normalColor = Color(0xFF667085);
  static const darkNormalColor = Color(0xFFAAB8CC);
  static const hoveredColor = Color(0xFF2563EB);

  final Map<String, Rect> objectBounds;
  final List<Connector> connectors;
  final double viewportScale;
  final String? hoveredConnectorId;
  final bool isDark;

  List<ConnectorStroke> get strokes {
    return [
      for (final connector in connectors)
        ConnectorStroke(
          connectorId: connector.id,
          segment: ConnectorGeometry.betweenRects(
            objectBounds[connector.objectAId]!,
            objectBounds[connector.objectBId]!,
          ),
          color: connector.id == hoveredConnectorId
              ? hoveredColor
              : (isDark ? darkNormalColor : normalColor),
          strokeWidth:
              (connector.id == hoveredConnectorId
                  ? hoveredScreenStrokeWidth
                  : screenStrokeWidth) /
              viewportScale,
        ),
    ];
  }

  List<ConnectorSegment> get segments {
    return [for (final stroke in strokes) stroke.segment];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final stroke in strokes) {
      paint
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth;
      canvas.drawLine(stroke.segment.start, stroke.segment.end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConnectorPainter oldDelegate) {
    return oldDelegate.objectBounds != objectBounds ||
        oldDelegate.connectors != connectors ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hoveredConnectorId != hoveredConnectorId;
  }
}
