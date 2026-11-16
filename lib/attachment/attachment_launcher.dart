import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

abstract interface class AttachmentLauncher {
  Future<bool> open(File file);
}

class SystemAttachmentLauncher implements AttachmentLauncher {
  const SystemAttachmentLauncher();

  @override
  Future<bool> open(File file) => launchUrl(Uri.file(file.absolute.path));
}
