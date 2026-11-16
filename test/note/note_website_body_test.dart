import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_website_body.dart';

void main() {
  testWidgets('shows a bounded patterned footer for a website host', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 78,
              child: NoteWebsiteBody(
                host: 'an-intentionally-very-long-provider-name.example.com',
                accentColor: const Color(0xFFD6B63A),
                child: const Text('Editable note text'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('website-note-body-pattern')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('website-note-body-footer')),
      findsOneWidget,
    );
    expect(
      find.text(
        'WEBSITE · an-intentionally-very-long-provider-name.example.com',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
