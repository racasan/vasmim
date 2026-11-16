import 'package:flutter/material.dart';

import '../canvas/foreground_item_style.dart';
import 'board_image.dart';

class InteractiveBoardImage extends StatefulWidget {
  const InteractiveBoardImage({
    required this.image,
    required this.isSelected,
    required this.canResize,
    required this.onSelect,
    required this.onSecondaryTapDown,
    required this.onBeginMoving,
    required this.onMove,
    required this.onEndMoving,
    required this.onBeginResizing,
    required this.child,
    super.key,
  });

  final BoardImage image;
  final bool isSelected;
  final bool canResize;
  final VoidCallback onSelect;
  final GestureTapDownCallback onSecondaryTapDown;
  final ValueChanged<Offset> onBeginMoving;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEndMoving;
  final ValueChanged<Offset> onBeginResizing;
  final Widget child;

  @override
  State<InteractiveBoardImage> createState() => _InteractiveBoardImageState();
}

class _InteractiveBoardImageState extends State<InteractiveBoardImage> {
  Offset? _movePointerDownPosition;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Canvas image ${widget.image.originalFileName}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Listener(
              onPointerDown: (event) =>
                  _movePointerDownPosition = event.position,
              onPointerCancel: (_) => widget.onEndMoving(),
              child: GestureDetector(
                key: ValueKey('image-drag-surface-${widget.image.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelect,
                onSecondaryTapDown: widget.onSecondaryTapDown,
                onPanStart: (details) => widget.onBeginMoving(
                  _movePointerDownPosition ?? details.globalPosition,
                ),
                onPanUpdate: (details) => widget.onMove(details.globalPosition),
                onPanEnd: (_) => widget.onEndMoving(),
                onPanCancel: widget.onEndMoving,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: ForegroundItemStyle.shadows,
                    border: Border.all(
                      color: widget.isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: widget.isSelected ? 4 : 0,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (widget.isSelected)
            Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    child: Text(
                      'DRAG TO MOVE',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.isSelected && widget.canResize)
            Positioned(
              right: 4,
              bottom: 4,
              child: Tooltip(
                message: 'Resize image proportionally',
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Listener(
                    onPointerDown: (event) =>
                        widget.onBeginResizing(event.position),
                    child: Container(
                      key: ValueKey('image-resize-handle-${widget.image.id}'),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        border: Border.all(
                          color: colorScheme.onPrimary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.open_in_full,
                        size: 15,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
