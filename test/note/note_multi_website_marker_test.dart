import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_multi_website_marker.dart';

void main() {
  testWidgets('shows an exact compact count and caps larger counts', (
    tester,
  ) async {
    Future<void> pump(int count) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoteMultiWebsiteMarker(linkCount: count)),
      ),
    );

    await pump(3);
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('3 website links'), findsOneWidget);

    await pump(12);
    expect(find.text('9+'), findsOneWidget);
    expect(find.byTooltip('12 website links'), findsOneWidget);
  });
}
