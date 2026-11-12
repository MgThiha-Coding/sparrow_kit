class RouteDefinition {
  factory RouteDefinition(String path) {
    return RouteDefinition._(_normalizeRoutePath(path));
  }

  RouteDefinition._(this.path)
      : _segments = _splitPath(path)
            .map(
              (segment) => segment.startsWith(':')
                  ? segment
                  : Uri.decodeComponent(segment),
            )
            .toList(growable: false);

  final String path;
  final List<String> _segments;

  int get _staticSegmentCount =>
      _segments.where((segment) => !segment.startsWith(':')).length;

  Map<String, String>? match(String path) {
    final pathSegments = _splitPath(_normalizePath(path));
    if (pathSegments.length != _segments.length) return null;

    final parameters = <String, String>{};
    for (var index = 0; index < _segments.length; index++) {
      final routeSegment = _segments[index];
      final pathSegment = Uri.decodeComponent(pathSegments[index]);

      if (routeSegment.startsWith(':')) {
        parameters[routeSegment.substring(1)] = pathSegment;
      } else if (routeSegment != pathSegment) {
        return null;
      }
    }

    return Map<String, String>.unmodifiable(parameters);
  }
}

class RouteMatch {
  RouteMatch({
    required this.path,
    required this.params,
    this.route,
    Map<String, String> queryParameters = const {},
    this.fragment = '',
  })  : queryParameters = Map<String, String>.unmodifiable(queryParameters),
        isNotFound = route == null;

  final String path;
  final RouteDefinition? route;
  final Map<String, String> params;
  final Map<String, String> queryParameters;
  final String fragment;
  final bool isNotFound;
}

class RouteTable {
  RouteTable({required Iterable<RouteDefinition> routes})
      : routes = List<RouteDefinition>.unmodifiable(routes);

  final List<RouteDefinition> routes;

  RouteMatch resolve(String path) {
    final uri = Uri.parse(path);
    final normalizedPath = _normalizePath(uri.path);
    RouteDefinition? bestRoute;
    Map<String, String>? bestParams;
    var bestSpecificity = -1;

    for (final route in routes) {
      final routeParams = route.match(normalizedPath);
      if (routeParams == null) continue;

      final specificity = route._staticSegmentCount;
      if (specificity > bestSpecificity) {
        bestRoute = route;
        bestParams = routeParams;
        bestSpecificity = specificity;
      }
    }

    return RouteMatch(
      path: normalizedPath,
      route: bestRoute,
      params: bestParams ?? const {},
      queryParameters: uri.queryParameters,
      fragment: uri.fragment,
    );
  }
}

String _normalizeRoutePath(String path) {
  if (!path.startsWith('/') || path.startsWith('//')) {
    throw ArgumentError.value(path, 'path', 'Route paths must start with /.');
  }

  final uri = Uri.parse(path);
  if (uri.hasQuery || uri.hasFragment) {
    throw ArgumentError.value(
      path,
      'path',
      'Route definitions cannot include a query or fragment.',
    );
  }

  final normalized = _normalizePath(uri.path);
  for (final segment in _splitPath(normalized)) {
    if (segment.startsWith(':') &&
        !RegExp(r'^:[A-Za-z_][A-Za-z0-9_]*$').hasMatch(segment)) {
      throw ArgumentError.value(path, 'path', 'Invalid parameter segment.');
    }
  }
  return normalized;
}

String _normalizePath(String path) {
  var normalized = path.isEmpty ? '/' : path;
  if (!normalized.startsWith('/')) normalized = '/$normalized';
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

List<String> _splitPath(String path) {
  final normalized = _normalizePath(path);
  if (normalized == '/') return const [];
  return normalized.substring(1).split('/');
}
