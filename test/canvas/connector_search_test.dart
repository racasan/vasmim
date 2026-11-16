import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/connector_search.dart';
import 'package:vasmim/connector/connector.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 26, 16);
  Connector connector(String id, {String? label}) => Connector(
    id: id,
    objectAId: 'a-$id',
    objectBId: 'b-$id',
    label: label,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  test(
    'matches trimmed literal labels case-insensitively in connector order',
    () {
      final results = ConnectorSearch.find([
        connector('first', label: 'Alpha Shared Link'),
        connector('unlabeled'),
        connector('second', label: 'shared link follow-up'),
        connector('other', label: 'Unrelated'),
      ], '  SHARED Link  ');

      expect(results.map((result) => result.connector.id), ['first', 'second']);
      expect(
        ConnectorSearch.find([
          connector('literal', label: 'depends [on]'),
        ], '[on]'),
        hasLength(1),
      );
      expect(
        ConnectorSearch.find([
          connector('empty', label: 'relationship'),
        ], '   '),
        isEmpty,
      );
    },
  );

  test('excludes unlabeled connectors from every query', () {
    expect(ConnectorSearch.find([connector('unlabeled')], 'anything'), isEmpty);
  });
}
