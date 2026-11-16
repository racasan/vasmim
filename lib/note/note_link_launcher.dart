import 'package:url_launcher/url_launcher.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri url);

Future<bool> launchNoteLink(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
