import 'package:flutter/material.dart';

Future<void> showVasmimHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const VasmimHelpDialog(),
);

class VasmimHelpDialog extends StatelessWidget {
  const VasmimHelpDialog({super.key});

  static const _sections =
      <({String label, List<({String title, String body})> topics})>[
        (
          label: 'Start',
          topics: [
            (
              title: 'Create a Board',
              body:
                  'New board opens a blank Board. Starter board offers Kanban, '
                  'Eisenhower, SWOT, and Campaign brief layouts. Name the Board '
                  'to create it; Cancel leaves the Library unchanged.',
            ),
            (
              title: 'Light, Dark, and paper colour',
              body:
                  'Light/Dark changes the whole app. Paper tone changes only '
                  'the current Board and is saved with it. The faint Board grid '
                  'stays aligned with content as you zoom.',
            ),
          ],
        ),
        (
          label: 'Board',
          topics: [
            (
              title: 'Navigate and add Notes',
              body:
                  'Use the mouse wheel to zoom and right-drag to pan. New note '
                  'and the blank-canvas right-click menu add a Note where you '
                  'are working.',
            ),
            (
              title: 'Edit text and Headings',
              body:
                  'Edit a Note directly. Double-click its title to rename it. '
                  'Double-click a Canvas Heading to change its text, size, and '
                  'background together.',
            ),
            (
              title: 'Find content',
              body:
                  'Find on board searches the open Board. Library search helps '
                  'locate Boards and supported content across your Library.',
            ),
            (
              title: 'Open a YouTube video',
              body:
                  'Click a YouTube card image to open the video on YouTube. '
                  'Use the bottom strip to select or drag the card; Ctrl+click '
                  'also selects it. Right-click offers Open in YouTube.',
            ),
          ],
        ),
        (
          label: 'Organize',
          topics: [
            (
              title: 'Shapes and Groups',
              body:
                  'Shapes mode draws and edits background Shapes on layers. '
                  'Group selected related items to reselect them together. '
                  'To include a Shape, select it in Shapes mode and choose Add to group. '
                  'Drag the central group handle to move the whole group; '
                  'dragging a member moves that item.',
            ),
            (
              title: 'Scenes',
              body:
                  'Save a Scene to return to a Board view. Walkthrough visits '
                  'saved Scenes in order and returns to your working view when '
                  'you exit.',
            ),
          ],
        ),
        (
          label: 'Keep safe',
          topics: [
            (
              title: 'Save and transfer',
              body:
                  'Boards autosave. Save now writes immediately. Export a '
                  'portable .vasmim Board to move it to another Library; '
                  'import never overwrites an existing Board.',
            ),
            (
              title: 'Back up the Library',
              body:
                  'Export all boards writes a backup folder with a manifest. '
                  'Verify backup folder checks it without importing or '
                  'changing your Library.',
            ),
            (
              title: 'Share an image',
              body:
                  'Share Board image saves or copies the current view or the '
                  'whole Board as an image without editor controls.',
            ),
          ],
        ),
        (
          label: 'Keys',
          topics: [
            (
              title: 'Common shortcuts',
              body:
                  'Ctrl+S saves. Ctrl+F finds on the open Board. Ctrl+Z undoes; '
                  'Ctrl+Y or Ctrl+Shift+Z redoes. Ctrl+C and Ctrl+V copy and '
                  'paste selected Board items. Delete removes a selection.',
            ),
            (
              title: 'While editing text',
              body:
                  'When a Note text editor has focus, its text-editing '
                  'shortcuts take priority over Board commands.',
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _sections.length,
    child: AlertDialog(
      key: const ValueKey('vasmim-help-dialog'),
      title: const Text('Vasmim Help'),
      content: SizedBox(
        width: 600,
        height: 350,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final section in _sections) Tab(text: section.label)],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final section in _sections)
                    ListView(
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                        for (final topic in section.topics)
                          ListTile(
                            title: Text(topic.title),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(topic.body),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('close-help-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
