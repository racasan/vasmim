import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/connector/connector_geometry.dart';
import 'package:vasmim/connector/connector_painter.dart';

void main() {
  test('resolves note-image and image-image segments from object bounds', () {
    final timestamp = DateTime.utc(2026, 8, 19);
    const noteBounds = Rect.fromLTWH(100, 100, 260, 170);
    const imageABounds = Rect.fromLTWH(600, 120, 320, 180);
    const imageBBounds = Rect.fromLTWH(1100, 400, 240, 180);
    final painter = ConnectorPainter(
      objectBounds: const {
        'note-a': noteBounds,
        'image-a': imageABounds,
        'image-b': imageBBounds,
      },
      connectors: [
        Connector(
          id: 'note-image',
          objectAId: 'note-a',
          objectBId: 'image-a',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
        Connector(
          id: 'image-image',
          objectAId: 'image-a',
          objectBId: 'image-b',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
      viewportScale: 1,
    );

    final expected = [
      ConnectorGeometry.betweenRects(noteBounds, imageABounds),
      ConnectorGeometry.betweenRects(imageABounds, imageBBounds),
    ];
    expect(painter.segments, hasLength(expected.length));
    for (var index = 0; index < expected.length; index++) {
      expect(painter.segments[index].start, expected[index].start);
      expect(painter.segments[index].end, expected[index].end);
    }
  });

  test('styles only the exact hovered connector at stable screen width', () {
    final timestamp = DateTime.utc(2026, 8, 29);
    final painter = ConnectorPainter(
      objectBounds: const {
        'note-a': Rect.fromLTWH(100, 100, 260, 170),
        'note-b': Rect.fromLTWH(600, 100, 260, 170),
        'note-c': Rect.fromLTWH(600, 500, 260, 170),
      },
      connectors: [
        Connector(
          id: 'normal',
          objectAId: 'note-a',
          objectBId: 'note-b',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
        Connector(
          id: 'hovered',
          objectAId: 'note-a',
          objectBId: 'note-c',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
      viewportScale: 0.5,
      hoveredConnectorId: 'hovered',
    );

    expect(painter.strokes, hasLength(2));
    expect(painter.strokes.first.connectorId, 'normal');
    expect(painter.strokes.first.color, ConnectorPainter.normalColor);
    expect(
      painter.strokes.first.strokeWidth * 0.5,
      ConnectorPainter.screenStrokeWidth,
    );
    expect(painter.strokes.last.connectorId, 'hovered');
    expect(painter.strokes.last.color, ConnectorPainter.hoveredColor);
    expect(
      painter.strokes.last.strokeWidth * 0.5,
      ConnectorPainter.hoveredScreenStrokeWidth,
    );
  });

  test('repaints when the transient hovered connector changes', () {
    final timestamp = DateTime.utc(2026, 8, 29);
    final connector = Connector(
      id: 'connector',
      objectAId: 'note-a',
      objectBId: 'note-b',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    const objectBounds = {
      'note-a': Rect.fromLTWH(100, 100, 260, 170),
      'note-b': Rect.fromLTWH(600, 100, 260, 170),
    };
    final connectors = [connector];
    ConnectorPainter painter(String? hoveredConnectorId) => ConnectorPainter(
      objectBounds: objectBounds,
      connectors: connectors,
      viewportScale: 1,
      hoveredConnectorId: hoveredConnectorId,
    );

    expect(painter('connector').shouldRepaint(painter(null)), isTrue);
    expect(painter('connector').shouldRepaint(painter('connector')), isFalse);
  });
}
