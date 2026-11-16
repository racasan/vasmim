import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_multi_website_body.dart';

void main() {
  testWidgets('shows a passive colour-derived linked-dot footer treatment', (
    tester,
  ) async {
    const accent = Color(0xFF356A93);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 180,
          child: NoteMultiWebsiteBody(
            linkCount: 4,
            accentColor: accent,
            child: Text('Editable source notes'),
          ),
        ),
      ),
    );

    expect(find.text('Editable source notes'), findsOneWidget);
    expect(find.text('WEBSITES · 4 LINKS'), findsOneWidget);
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('multi-website-note-body-pattern')),
    );
    final painter = paint.painter! as MultiWebsiteNotePatternPainter;
    expect(painter.color, accent.withValues(alpha: 0.12));
  });
}
