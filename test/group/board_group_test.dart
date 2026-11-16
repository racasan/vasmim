import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/group/board_group.dart';

void main() {
  test(
    'round-trips identity, name, ordered members, visibility, and timestamps',
    () {
      final createdAt = DateTime.utc(2026, 9, 14, 8);
      final modifiedAt = createdAt.add(const Duration(minutes: 3));
      final group = BoardGroup(
        id: 'group-1',
        memberIds: const ['note-a', 'image-b'],
        isVisible: false,
        name: 'Quest outline',
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

      final restored = BoardGroup.fromJson(group.toJson());

      expect(restored.id, group.id);
      expect(restored.memberIds, group.memberIds);
      expect(restored.isVisible, isFalse);
      expect(restored.name, 'Quest outline');
      expect(restored.createdAt, createdAt);
      expect(restored.modifiedAt, modifiedAt);
    },
  );
}
