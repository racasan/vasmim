import 'package:flutter/material.dart';

import 'note.dart';

extension NoteColorPresentation on NoteColor {
  String get label => switch (this) {
    NoteColor.yellow => 'Yellow',
    NoteColor.blue => 'Blue',
    NoteColor.green => 'Green',
    NoteColor.pink => 'Pink',
    NoteColor.purple => 'Purple',
  };

  Color get backgroundColor => switch (this) {
    NoteColor.yellow => const Color(0xFFFFE88A),
    NoteColor.blue => const Color(0xFFCFE8FF),
    NoteColor.green => const Color(0xFFD7F2D0),
    NoteColor.pink => const Color(0xFFF8D5E5),
    NoteColor.purple => const Color(0xFFE6D9FA),
  };

  Color get borderColor => switch (this) {
    NoteColor.yellow => const Color(0xFFD6B63A),
    NoteColor.blue => const Color(0xFF5B9BD5),
    NoteColor.green => const Color(0xFF67A85B),
    NoteColor.pink => const Color(0xFFC8759A),
    NoteColor.purple => const Color(0xFF9070C5),
  };

  Color get headerColor => switch (this) {
    NoteColor.yellow => const Color(0xFFFFDC5C),
    NoteColor.blue => const Color(0xFFB4D9FA),
    NoteColor.green => const Color(0xFFBFE7B6),
    NoteColor.pink => const Color(0xFFF0BDD4),
    NoteColor.purple => const Color(0xFFD6C3F2),
  };
}
