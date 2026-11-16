import 'package:flutter/material.dart';

class NoteMultiWebsiteBody extends StatelessWidget {
  const NoteMultiWebsiteBody({
    required this.linkCount,
    required this.accentColor,
    required this.child,
    super.key,
  });

  static const footerHeight = 28.0;

  final int linkCount;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labelColor = Color.lerp(accentColor, Colors.black, 0.42)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('multi-website-note-body-pattern'),
            painter: MultiWebsiteNotePatternPainter(
              color: accentColor.withValues(alpha: 0.12),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: child),
            Semantics(
              label: '$linkCount website links',
              child: Container(
                key: const ValueKey('multi-website-note-body-footer'),
                height: footerHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 14, right: 36),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.30),
                  border: Border(
                    top: BorderSide(color: accentColor.withValues(alpha: 0.45)),
                  ),
                ),
                child: Text(
                  'WEBSITES · $linkCount LINKS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MultiWebsiteNotePatternPainter extends CustomPainter {
  const MultiWebsiteNotePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (var y = 14.0; y < size.height; y += spacing) {
      final rowOffset = ((y / spacing).floor().isEven) ? 10.0 : 24.0;
      for (var x = rowOffset; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
        if (x + 10 < size.width) {
          canvas.drawLine(Offset(x + 3, y), Offset(x + 10, y), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(MultiWebsiteNotePatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
