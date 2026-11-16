import 'connector.dart';

Set<String> connectedObjectIds({
  required String seedObjectId,
  required Iterable<String> objectIds,
  required Iterable<Connector> connectors,
}) {
  final existingObjectIds = objectIds.toSet();
  if (!existingObjectIds.contains(seedObjectId)) {
    return const {};
  }

  final neighbours = <String, Set<String>>{};
  for (final connector in connectors) {
    if (!existingObjectIds.contains(connector.objectAId) ||
        !existingObjectIds.contains(connector.objectBId)) {
      continue;
    }
    neighbours
        .putIfAbsent(connector.objectAId, () => <String>{})
        .add(connector.objectBId);
    neighbours
        .putIfAbsent(connector.objectBId, () => <String>{})
        .add(connector.objectAId);
  }

  final visited = <String>{seedObjectId};
  final pending = <String>[seedObjectId];
  for (var index = 0; index < pending.length; index++) {
    for (final neighbour in neighbours[pending[index]] ?? const <String>{}) {
      if (visited.add(neighbour)) {
        pending.add(neighbour);
      }
    }
  }
  return Set.unmodifiable(visited);
}
