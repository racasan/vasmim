import 'package:flutter/material.dart';

class NoteWebsiteBody extends StatelessWidget {
  const NoteWebsiteBody({
    required this.host,
    required this.accentColor,
    required this.child,
    super.key,
  });

  static const footerHeight = 28.0;

  final String host;
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
            key: const ValueKey('website-note-body-pattern'),
            painter: WebsiteNotePatternPainter(
              color: accentColor.withValues(alpha: 0.10),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: child),
            Semantics(
              label: 'Website: $host',
              child: Container(
                key: const ValueKey('website-note-body-footer'),
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
                  'WEBSITE · $host',
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

class WebsiteNotePatternPainter extends CustomPainter {
  const WebsiteNotePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 24.0;
    for (var start = -size.height; start < size.width; start += spacing) {
      canvas.drawLine(
        Offset(start, size.height),
        Offset(start + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WebsiteNotePatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
