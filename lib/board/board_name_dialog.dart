import 'package:flutter/material.dart';

enum BoardNameDialogPurpose { create, rename, duplicate, importCopy }

class BoardNameDialog extends StatefulWidget {
  const BoardNameDialog({this.initialName, this.purpose, super.key});

  final String? initialName;
  final BoardNameDialogPurpose? purpose;

  @override
  State<BoardNameDialog> createState() => _BoardNameDialogState();
}

class _BoardNameDialogState extends State<BoardNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  BoardNameDialogPurpose get _purpose =>
      widget.purpose ??
      (widget.initialName == null
          ? BoardNameDialogPurpose.create
          : BoardNameDialogPurpose.rename);

  String get _title => switch (_purpose) {
    BoardNameDialogPurpose.create => 'Create board',
    BoardNameDialogPurpose.rename => 'Rename board',
    BoardNameDialogPurpose.duplicate => 'Duplicate board',
    BoardNameDialogPurpose.importCopy => 'Import board as copy',
  };

  String get _actionLabel => switch (_purpose) {
    BoardNameDialogPurpose.create => 'Create board',
    BoardNameDialogPurpose.rename => 'Rename',
    BoardNameDialogPurpose.duplicate => 'Duplicate',
    BoardNameDialogPurpose.importCopy => 'Import as copy',
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a board name');
    } else {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: TextField(
        key: const ValueKey('board-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Board name',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-board-name-button'),
          onPressed: _submit,
          child: Text(_actionLabel),
        ),
      ],
    );
  }
}
