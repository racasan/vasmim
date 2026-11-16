import 'package:file_selector/file_selector.dart';

typedef ImagePathPicker = Future<String?> Function();

Future<String?> pickImagePath() async {
  const imageTypes = XTypeGroup(
    label: 'PNG, JPEG, and GIF images',
    extensions: ['png', 'jpg', 'jpeg', 'gif'],
  );
  final file = await openFile(acceptedTypeGroups: [imageTypes]);
  return file?.path;
}
