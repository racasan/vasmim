String portableBoardSuggestedName(String boardName) {
  var safeName = boardName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[ .]+$'), '');
  if (safeName.isEmpty) {
    safeName = 'Board';
  }
  if (RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
    caseSensitive: false,
  ).hasMatch(safeName)) {
    safeName = '_$safeName';
  }
  return '$safeName.vasmim';
}

String portableBoardBackupFileName(String boardName, String boardId) {
  final suggested = portableBoardSuggestedName(boardName);
  final stem = suggested.substring(0, suggested.length - '.vasmim'.length);
  return '$stem--$boardId.vasmim';
}

String libraryBackupFolderName(DateTime timestamp) {
  final utc = timestamp.toUtc();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return 'Vasmim Backup ${utc.year.toString().padLeft(4, '0')}-'
      '${twoDigits(utc.month)}-${twoDigits(utc.day)} '
      '${twoDigits(utc.hour)}${twoDigits(utc.minute)}${twoDigits(utc.second)}Z';
}
