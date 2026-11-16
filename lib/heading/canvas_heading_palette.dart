import 'package:flutter/material.dart';

import '../note/note.dart';
import '../note/note_color_palette.dart';
import 'canvas_heading.dart';

extension CanvasHeadingBackgroundPresentation on CanvasHeadingBackground {
  String get label => switch (this) {
    CanvasHeadingBackground.transparent => 'Transparent',
    CanvasHeadingBackground.white => 'White',
    CanvasHeadingBackground.yellow => 'Yellow',
    CanvasHeadingBackground.blue => 'Blue',
    CanvasHeadingBackground.green => 'Green',
    CanvasHeadingBackground.pink => 'Pink',
    CanvasHeadingBackground.purple => 'Purple',
  };

  Color get color => switch (this) {
    CanvasHeadingBackground.transparent => Colors.transparent,
    CanvasHeadingBackground.white => Colors.white.withValues(alpha: 0.92),
    CanvasHeadingBackground.yellow => NoteColor.yellow.backgroundColor,
    CanvasHeadingBackground.blue => NoteColor.blue.backgroundColor,
    CanvasHeadingBackground.green => NoteColor.green.backgroundColor,
    CanvasHeadingBackground.pink => NoteColor.pink.backgroundColor,
    CanvasHeadingBackground.purple => NoteColor.purple.backgroundColor,
  };
}

extension CanvasHeadingSizePresentation on CanvasHeadingSize {
  String get label => switch (this) {
    CanvasHeadingSize.small => 'Small · 20',
    CanvasHeadingSize.medium => 'Medium · 28',
    CanvasHeadingSize.large => 'Large · 40',
    CanvasHeadingSize.extraLarge => 'Extra large · 56',
  };
}
