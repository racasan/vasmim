import 'package:flutter/material.dart';

import '../canvas/foreground_item_style.dart';
import 'canvas_heading.dart';
import 'canvas_heading_geometry.dart';
import 'canvas_heading_palette.dart';

class InteractiveCanvasHeading extends StatefulWidget {
  const InteractiveCanvasHeading({
    required this.heading,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onSecondaryTapDown,
    required this.onBeginMoving,
    required this.onMove,
    required this.onEndMoving,
    this.showInteractionChrome = true,
    super.key,
  });

  final CanvasHeading heading;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final GestureTapDownCallback onSecondaryTapDown;
  final ValueChanged<Offset> onBeginMoving;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEndMoving;
  final bool showInteractionChrome;

  @override
  State<InteractiveCanvasHeading> createState() =>
      _InteractiveCanvasHeadingState();
}

class _InteractiveCanvasHeadingState extends State<InteractiveCanvasHeading> {
  bool _isHovered = false;
  Offset? _pointerDownPosition;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = CanvasHeadingGeometry.sizeFor(widget.heading);
    final showOutline =
        widget.showInteractionChrome && (widget.isSelected || _isHovered);
    return Semantics(
      label:
          'Canvas heading ${widget.heading.text}, '
          '${widget.heading.size.label}, '
          '${widget.heading.background.label} background'
          '${widget.isSelected ? ', selected' : ''}',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Listener(
          onPointerDown: (event) => _pointerDownPosition = event.position,
          onPointerCancel: (_) => widget.onEndMoving(),
          child: GestureDetector(
            key: ValueKey('heading-surface-${widget.heading.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect,
            onDoubleTap: widget.onEdit,
            onSecondaryTapDown: widget.onSecondaryTapDown,
            onPanStart: (details) => widget.onBeginMoving(
              _pointerDownPosition ?? details.globalPosition,
            ),
            onPanUpdate: (details) => widget.onMove(details.globalPosition),
            onPanEnd: (_) => widget.onEndMoving(),
            onPanCancel: widget.onEndMoving,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: size.width,
              height: size.height,
              padding: const EdgeInsets.symmetric(
                horizontal: CanvasHeadingGeometry.horizontalPadding,
                vertical: CanvasHeadingGeometry.verticalPadding,
              ),
              decoration: BoxDecoration(
                color: widget.heading.background.color,
                boxShadow:
                    widget.heading.background ==
                        CanvasHeadingBackground.transparent
                    ? null
                    : ForegroundItemStyle.shadows,
                border: Border.all(
                  color: showOutline ? colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.heading.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      widget.heading.background ==
                          CanvasHeadingBackground.transparent
                      ? colorScheme.onSurface
                      : const Color(0xFF242424),
                  fontSize: widget.heading.fontSize,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
