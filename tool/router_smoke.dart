import '../packages/sparrow_kit/lib/src/core/router/route_table.dart';

void main() {
  final routes = RouteTable(
    routes: [
      RouteDefinition('/products/:productId'),
      RouteDefinition('/products/new'),
    ],
  );

  final staticMatch =
      routes.resolve('/products/new?sort=recent&page=2#results');
  _expect(
    staticMatch.route?.path == '/products/new',
    'static routes should take precedence over parameterized routes',
  );
  _expect(
    staticMatch.queryParameters['sort'] == 'recent' &&
        staticMatch.queryParameters['page'] == '2',
    'query parameters should be resolved from the URL',
  );
  _expect(
    staticMatch.fragment == 'results',
    'the URL fragment should be preserved',
  );

  final parameterMatch = routes.resolve('/products/42?page=3');
  _expect(
    parameterMatch.params['productId'] == '42' &&
        parameterMatch.queryParameters['page'] == '3',
    'path and query parameters should resolve together',
  );

  final notFound = routes.resolve('/missing?source=direct');
  _expect(notFound.isNotFound, 'unmatched paths should remain not found');
  _expect(
    notFound.queryParameters['source'] == 'direct',
    'query parameters should be available on not-found matches',
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
