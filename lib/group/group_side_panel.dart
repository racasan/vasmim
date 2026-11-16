import 'package:flutter/material.dart';

import 'board_group.dart';

class GroupSidePanel extends StatelessWidget {
  const GroupSidePanel({
    super.key,
    required this.groups,
    required this.selectedMemberIds,
    this.movementBlockedGroupIds = const {},
    required this.onSelect,
    required this.onToggleVisibility,
    required this.onUngroup,
    required this.onRename,
    required this.onClose,
  });

  final List<BoardGroup> groups;
  final Set<String> selectedMemberIds;
  final Set<String> movementBlockedGroupIds;
  final ValueChanged<BoardGroup> onSelect;
  final ValueChanged<BoardGroup> onToggleVisibility;
  final ValueChanged<BoardGroup> onUngroup;
  final ValueChanged<BoardGroup> onRename;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('groups-side-panel'),
      width: 300,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Groups'),
              subtitle: const Text('Persistent selection sets'),
              trailing: IconButton(
                key: const ValueKey('close-groups-panel-button'),
                tooltip: 'Close Groups',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Select two or more items, right-click, and choose Group.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final selected = group.memberIds.every(
                          selectedMemberIds.contains,
                        );
                        final movementBlocked = movementBlockedGroupIds
                            .contains(group.id);
                        return Card(
                          key: ValueKey('group-row-${group.id}'),
                          color: selected
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : null,
                          child: ListTile(
                            onTap: () => onSelect(group),
                            leading: IconButton(
                              key: ValueKey('group-visibility-${group.id}'),
                              tooltip: group.isVisible
                                  ? 'Hide selection set'
                                  : 'Show selection set',
                              onPressed: () => onToggleVisibility(group),
                              icon: Icon(
                                group.isVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            title: Text(group.name ?? 'Group ${index + 1}'),
                            subtitle: Text(
                              '${group.memberIds.length} items'
                              '${group.isVisible ? '' : ' · Hidden'}'
                              '${movementBlocked ? ' · Movement blocked: hidden Shape member' : ''}',
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Group actions',
                              onSelected: (value) {
                                if (value == 'select') onSelect(group);
                                if (value == 'rename') onRename(group);
                                if (value == 'ungroup') onUngroup(group);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'select',
                                  child: Text('Select group'),
                                ),
                                PopupMenuItem(
                                  value: 'ungroup',
                                  child: Text('Ungroup'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
