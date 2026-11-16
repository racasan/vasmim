import 'package:characters/characters.dart';

import 'note_emphasis.dart';
import 'note_text_link.dart';

enum NoteColor { yellow, blue, green, pink, purple }

const _unchangedNoteTitle = Object();

class Note {
  Note({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
    required this.createdAt,
    required this.modifiedAt,
    this.color = NoteColor.yellow,
    this.title,
    List<NoteEmphasisRange> emphasis = const [],
    List<NoteTextLinkRange> links = const [],
  }) : emphasis = List.unmodifiable(emphasis),
       links = List.unmodifiable(links);

  static const maximumTitleCharacters = 80;

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;
  final String? title;
  final List<NoteEmphasisRange> emphasis;
  final List<NoteTextLinkRange> links;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final NoteColor color;

  Note copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
    DateTime? modifiedAt,
    NoteColor? color,
    Object? title = _unchangedNoteTitle,
    List<NoteEmphasisRange>? emphasis,
    List<NoteTextLinkRange>? links,
  }) {
    return Note(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      title: identical(title, _unchangedNoteTitle)
          ? this.title
          : title as String?,
      emphasis: emphasis ?? this.emphasis,
      links: links ?? this.links,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      color: color ?? this.color,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'text': text,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
      'color': color.name,
    };
    final title = this.title;
    if (title != null) {
      json['title'] = title;
    }
    if (emphasis.isNotEmpty) {
      json['emphasis'] = emphasis.map((range) => range.toJson()).toList();
    }
    if (links.isNotEmpty) {
      json['links'] = links.map((range) => range.toJson()).toList();
    }
    return json;
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    bool readTitle = true,
    bool readEmphasis = true,
    bool readItalic = true,
    bool readLinks = true,
  }) {
    return Note(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      text: json['text'] as String,
      title: readTitle ? json['title'] as String? : null,
      emphasis: readEmphasis
          ? [
              for (final range in json['emphasis'] as List? ?? const [])
                if (readItalic ||
                    (range as Map)['bold'] == true ||
                    range['underline'] == true)
                  NoteEmphasisRange.fromJson(
                    Map<String, dynamic>.from(range),
                    readItalic: readItalic,
                  ),
            ]
          : const [],
      links: readLinks
          ? [
              for (final range in json['links'] as List? ?? const [])
                NoteTextLinkRange.fromJson(
                  Map<String, dynamic>.from(range as Map),
                ),
            ]
          : const [],
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
      color: NoteColor.values.firstWhere(
        (color) => color.name == json['color'],
        orElse: () => NoteColor.yellow,
      ),
    );
  }

  static String? normalizeTitle(String rawTitle) {
    final title = rawTitle.trim();
    if (title.isEmpty) {
      return null;
    }
    if (RegExp(r'[\r\n\u2028\u2029]').hasMatch(title) ||
        title.characters.length > maximumTitleCharacters) {
      throw const FormatException(
        'A note title must be single-line and at most 80 characters.',
      );
    }
    return title;
  }
}
