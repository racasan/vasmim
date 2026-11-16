enum BoardPaperTone { defaultTone, warm, blue, green }

extension BoardPaperToneLabel on BoardPaperTone {
  String get label => switch (this) {
    BoardPaperTone.defaultTone => 'Default',
    BoardPaperTone.warm => 'Warm',
    BoardPaperTone.blue => 'Blue',
    BoardPaperTone.green => 'Green',
  };
}
