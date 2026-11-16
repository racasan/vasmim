import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/connector/connector_graph.dart';

void main() {
  final timestamp = DateTime.utc(2026, 9, 2);

  Connector connector(String id, String a, String b) => Connector(
    id: id,
    objectAId: a,
    objectBId: b,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  test('walks an undirected branch and cycle exactly once', () {
    final result = connectedObjectIds(
      seedObjectId: 'b',
      objectIds: const ['a', 'b', 'c', 'd', 'image', 'unrelated'],
      connectors: [
        connector('a-b', 'a', 'b'),
        connector('b-c', 'b', 'c'),
        connector('b-d', 'b', 'd'),
        connector('c-image', 'c', 'image'),
        connector('image-a', 'image', 'a'),
      ],
    );

    expect(result, {'a', 'b', 'c', 'd', 'image'});
  });

  test('isolates missing, disconnected, and dangling endpoints', () {
    final connectors = [
      connector('a-missing', 'a', 'missing'),
      connector('a-b', 'a', 'b'),
    ];

    expect(
      connectedObjectIds(
        seedObjectId: 'a',
        objectIds: const ['a'],
        connectors: connectors,
      ),
      {'a'},
    );
    expect(
      connectedObjectIds(
        seedObjectId: 'missing',
        objectIds: const ['a'],
        connectors: connectors,
      ),
      isEmpty,
    );
  });
}
