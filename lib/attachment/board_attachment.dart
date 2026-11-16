enum AttachmentKind {
  pdf('PDF', ['pdf']),
  word('WORD', ['doc', 'docx']),
  spreadsheet('EXCEL', ['xls', 'xlsx']),
  video('MOVIE', ['mp4', 'm4v', 'mov', 'mkv', 'avi', 'webm']),
  audio('AUDIO', ['mp3', 'wav', 'm4a', 'flac', 'ogg']);

  const AttachmentKind(this.label, this.extensions);

  final String label;
  final List<String> extensions;

  static AttachmentKind fromName(String name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => throw const FormatException('Unknown attachment kind.'),
  );

  static AttachmentKind fromFileName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return values.firstWhere(
      (value) => value.extensions.contains(extension),
      orElse: () =>
          throw const FormatException('Unsupported attachment file type.'),
    );
  }
}

class BoardAttachment {
  const BoardAttachment({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.assetPath,
    required this.originalFileName,
    required this.kind,
    required this.byteSize,
    required this.createdAt,
    required this.modifiedAt,
    this.previewAssetPath,
  });

  static const defaultWidth = 300.0;
  static const defaultHeight = 112.0;

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String assetPath;
  final String originalFileName;
  final AttachmentKind kind;
  final int byteSize;
  final String? previewAssetPath;
  final DateTime createdAt;
  final DateTime modifiedAt;

  BoardAttachment copyWith({
    String? id,
    double? x,
    double? y,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? previewAssetPath,
  }) => BoardAttachment(
    id: id ?? this.id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width,
    height: height,
    assetPath: assetPath,
    originalFileName: originalFileName,
    kind: kind,
    byteSize: byteSize,
    previewAssetPath: previewAssetPath ?? this.previewAssetPath,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'assetPath': assetPath,
      'originalFileName': originalFileName,
      'kind': kind.name,
      'byteSize': byteSize,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    };
    if (previewAssetPath case final path?) json['previewAssetPath'] = path;
    return json;
  }

  factory BoardAttachment.fromJson(
    Map<String, dynamic> json, {
    bool readPreview = true,
    bool readAudio = true,
  }) {
    final kind = AttachmentKind.fromName(json['kind'] as String);
    if (!readAudio && kind == AttachmentKind.audio) {
      throw const FormatException('Audio attachments require Board format 31.');
    }
    return BoardAttachment(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      assetPath: json['assetPath'] as String,
      originalFileName: json['originalFileName'] as String,
      kind: kind,
      byteSize: json['byteSize'] as int,
      previewAssetPath: readPreview
          ? json['previewAssetPath'] as String?
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String).toUtc(),
    );
  }
}
