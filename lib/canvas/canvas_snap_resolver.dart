import 'package:flutter/material.dart';

enum CanvasSnapGuideAxis { vertical, horizontal }

enum CanvasSnapGuideSource { grid, peer }

class CanvasSnapGuide {
  const CanvasSnapGuide({
    required this.axis,
    required this.source,
    required this.position,
    required this.start,
    required this.end,
  });

  final CanvasSnapGuideAxis axis;
  final CanvasSnapGuideSource source;
  final double position;
  final double start;
  final double end;

  @override
  bool operator ==(Object other) =>
      other is CanvasSnapGuide &&
      other.axis == axis &&
      other.source == source &&
      other.position == position &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(axis, source, position, start, end);
}

class CanvasSnapResult {
  const CanvasSnapResult({required this.delta, this.guides = const []});

  final Offset delta;
  final List<CanvasSnapGuide> guides;
}

class CanvasSnapResolver {
  const CanvasSnapResolver._();

  static const thresholdScreenPixels = 8.0;
  static const guidePadding = 12.0;

  static CanvasSnapResult resolve({
    required Rect movingBounds,
    required Offset desiredDelta,
    required Iterable<Rect> peerBounds,
    required double viewportScale,
    required Size canvasSize,
    required double gridSpacing,
  }) {
    assert(viewportScale > 0);
    assert(gridSpacing > 0);
    final proposed = movingBounds.shift(desiredDelta);
    final threshold = thresholdScreenPixels / viewportScale;
    _SnapCandidate? horizontal;
    _SnapCandidate? vertical;

    bool horizontalFits(double correction) =>
        proposed.left + correction >= 0 &&
        proposed.right + correction <= canvasSize.width;
    bool verticalFits(double correction) =>
        proposed.top + correction >= 0 &&
        proposed.bottom + correction <= canvasSize.height;

    for (final value in [proposed.left, proposed.center.dx, proposed.right]) {
      final line = (value / gridSpacing).round() * gridSpacing;
      final correction = line - value;
      if (correction.abs() <= threshold && horizontalFits(correction)) {
        horizontal = _better(
          horizontal,
          _SnapCandidate(
            correction: correction,
            position: line,
            source: CanvasSnapGuideSource.grid,
          ),
        );
      }
    }
    for (final value in [proposed.top, proposed.center.dy, proposed.bottom]) {
      final line = (value / gridSpacing).round() * gridSpacing;
      final correction = line - value;
      if (correction.abs() <= threshold && verticalFits(correction)) {
        vertical = _better(
          vertical,
          _SnapCandidate(
            correction: correction,
            position: line,
            source: CanvasSnapGuideSource.grid,
          ),
        );
      }
    }

    for (final peer in peerBounds) {
      for (final movingEdge in [proposed.left, proposed.right]) {
        for (final peerEdge in [peer.left, peer.right]) {
          final correction = peerEdge - movingEdge;
          if (correction.abs() <= threshold && horizontalFits(correction)) {
            horizontal = _better(
              horizontal,
              _SnapCandidate(
                correction: correction,
                position: peerEdge,
                source: CanvasSnapGuideSource.peer,
                peerBounds: peer,
              ),
            );
          }
        }
      }
      final centerXCorrection = peer.center.dx - proposed.center.dx;
      if (centerXCorrection.abs() <= threshold &&
          horizontalFits(centerXCorrection)) {
        horizontal = _better(
          horizontal,
          _SnapCandidate(
            correction: centerXCorrection,
            position: peer.center.dx,
            source: CanvasSnapGuideSource.peer,
            peerBounds: peer,
          ),
        );
      }

      for (final movingEdge in [proposed.top, proposed.bottom]) {
        for (final peerEdge in [peer.top, peer.bottom]) {
          final correction = peerEdge - movingEdge;
          if (correction.abs() <= threshold && verticalFits(correction)) {
            vertical = _better(
              vertical,
              _SnapCandidate(
                correction: correction,
                position: peerEdge,
                source: CanvasSnapGuideSource.peer,
                peerBounds: peer,
              ),
            );
          }
        }
      }
      final centerYCorrection = peer.center.dy - proposed.center.dy;
      if (centerYCorrection.abs() <= threshold &&
          verticalFits(centerYCorrection)) {
        vertical = _better(
          vertical,
          _SnapCandidate(
            correction: centerYCorrection,
            position: peer.center.dy,
            source: CanvasSnapGuideSource.peer,
            peerBounds: peer,
          ),
        );
      }
    }

    final delta =
        desiredDelta +
        Offset(horizontal?.correction ?? 0, vertical?.correction ?? 0);
    final snappedBounds = movingBounds.shift(delta);
    final guides = <CanvasSnapGuide>[
      if (horizontal != null)
        _verticalGuide(horizontal, snappedBounds, canvasSize.height),
      if (vertical != null)
        _horizontalGuide(vertical, snappedBounds, canvasSize.width),
    ];
    return CanvasSnapResult(delta: delta, guides: List.unmodifiable(guides));
  }

  static _SnapCandidate _better(
    _SnapCandidate? current,
    _SnapCandidate candidate,
  ) {
    if (current == null) return candidate;
    final currentDistance = current.correction.abs();
    final candidateDistance = candidate.correction.abs();
    if (candidateDistance < currentDistance) return candidate;
    if (candidateDistance > currentDistance) return current;
    if (candidate.source == CanvasSnapGuideSource.peer &&
        current.source == CanvasSnapGuideSource.grid) {
      return candidate;
    }
    return current;
  }

  static CanvasSnapGuide _verticalGuide(
    _SnapCandidate candidate,
    Rect snappedBounds,
    double canvasHeight,
  ) {
    final peer = candidate.peerBounds;
    final top = peer == null
        ? snappedBounds.top
        : (snappedBounds.top < peer.top ? snappedBounds.top : peer.top);
    final bottom = peer == null
        ? snappedBounds.bottom
        : (snappedBounds.bottom > peer.bottom
              ? snappedBounds.bottom
              : peer.bottom);
    return CanvasSnapGuide(
      axis: CanvasSnapGuideAxis.vertical,
      source: candidate.source,
      position: candidate.position,
      start: (top - guidePadding).clamp(0, canvasHeight).toDouble(),
      end: (bottom + guidePadding).clamp(0, canvasHeight).toDouble(),
    );
  }

  static CanvasSnapGuide _horizontalGuide(
    _SnapCandidate candidate,
    Rect snappedBounds,
    double canvasWidth,
  ) {
    final peer = candidate.peerBounds;
    final left = peer == null
        ? snappedBounds.left
        : (snappedBounds.left < peer.left ? snappedBounds.left : peer.left);
    final right = peer == null
        ? snappedBounds.right
        : (snappedBounds.right > peer.right ? snappedBounds.right : peer.right);
    return CanvasSnapGuide(
      axis: CanvasSnapGuideAxis.horizontal,
      source: candidate.source,
      position: candidate.position,
      start: (left - guidePadding).clamp(0, canvasWidth).toDouble(),
      end: (right + guidePadding).clamp(0, canvasWidth).toDouble(),
    );
  }
}

class _SnapCandidate {
  const _SnapCandidate({
    required this.correction,
    required this.position,
    required this.source,
    this.peerBounds,
  });

  final double correction;
  final double position;
  final CanvasSnapGuideSource source;
  final Rect? peerBounds;
}
