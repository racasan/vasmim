import 'package:file_selector/file_selector.dart';

typedef AttachmentPathPicker = Future<String?> Function();

Future<String?> pickAttachmentPath() async {
  const types = XTypeGroup(
    label: 'Reference files',
    extensions: [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'mp4',
      'm4v',
      'mov',
      'mkv',
      'avi',
      'webm',
      'mp3',
      'wav',
      'm4a',
      'flac',
      'ogg',
    ],
  );
  final file = await openFile(acceptedTypeGroups: [types]);
  return file?.path;
}
