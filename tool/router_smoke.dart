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

  final moreSpecificRoutes = RouteTable(
    routes: [
      RouteDefinition('/catalog/:category/:itemId'),
      RouteDefinition('/catalog/special/:itemId'),
    ],
  );
  _expect(
    moreSpecificRoutes.resolve('/catalog/special/42').route?.path ==
        '/catalog/special/:itemId',
    'the route with more static segments should win',
  );

  final parameterMatch = routes.resolve('/products/42?page=3');
  _expect(
    parameterMatch.params['productId'] == '42' &&
        parameterMatch.queryParameters['page'] == '3',
    'path and query parameters should resolve together',
  );

  _expect(
    RouteDefinition('/about///').path == '/about' &&
        routes.resolve('/products/42///').path == '/products/42',
    'trailing slashes should be normalized consistently',
  );

  final repeatedQuery = routes.resolve(
    '/products/42?tag=first&tag=last&empty=&empty=second',
  );
  _expect(
    repeatedQuery.queryParameters['tag'] == 'last' &&
        repeatedQuery.queryParameters['empty'] == 'second',
    'repeated query keys should use the last value',
  );

  final notFound = routes.resolve('/missing?source=direct');
  _expect(notFound.isNotFound, 'unmatched paths should remain not found');
  _expect(
    notFound.queryParameters['source'] == 'direct',
    'query parameters should be available on not-found matches',
  );

  _expectArgumentError(
    () => RouteDefinition('/users/:userId/orders/:userId'),
    'duplicate parameter names should be rejected',
  );
  _expectArgumentError(
    () => RouteTable(
      routes: [
        RouteDefinition('/about'),
        RouteDefinition('/about/'),
      ],
    ),
    'duplicate routes after normalization should be rejected',
  );
  _expectArgumentError(
    () => RouteTable(
      routes: [
        RouteDefinition('/users/:id'),
        RouteDefinition('/users/:userId'),
      ],
    ),
    'duplicate route patterns with different parameter names should be rejected',
  );
  _expectArgumentError(
    () => RouteTable(
      routes: [
        RouteDefinition('/users/:userId'),
        RouteDefinition('/:resourceId/settings'),
      ],
    ),
    'overlapping routes with equal specificity should be rejected',
  );

  final nonOverlappingRoutes = RouteTable(
    routes: [
      RouteDefinition('/users/:userId'),
      RouteDefinition('/posts/:postId'),
    ],
  );
  _expect(
    nonOverlappingRoutes.resolve('/posts/42').route?.path == '/posts/:postId',
    'non-overlapping routes with equal specificity should remain valid',
  );
}

void _expectArgumentError(void Function() action, String message) {
  try {
    action();
  } on ArgumentError {
    return;
  }
  throw StateError(message);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
