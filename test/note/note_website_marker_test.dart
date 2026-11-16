import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_website_marker.dart';

void main() {
  testWidgets('shows the generic globe when a website icon cannot load', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteWebsiteMarker(
            websiteUrl: Uri.parse('https://example.com/reference'),
            imageProvider: MemoryImage(Uint8List.fromList(const [0, 1, 2])),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-website-marker-fallback')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(find.byTooltip('Website: example.com'), findsOneWidget);
  });
}
