import '../connector/connector.dart';

class ConnectorSearchResult {
  const ConnectorSearchResult({required this.connector});

  final Connector connector;

  String get label => connector.label!;
}

class ConnectorSearch {
  const ConnectorSearch._();

  static List<ConnectorSearchResult> find(
    List<Connector> connectors,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final connector in connectors)
        if (connector.label != null &&
            connector.label!.toLowerCase().contains(query))
          ConnectorSearchResult(connector: connector),
    ];
  }
}
