/// A normalized route pattern with an optional `:name` per path segment.
///
/// Trailing slashes are removed except for the root path. Parameter names must
/// be unique within the pattern.
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

  /// Query values from the resolved URI; repeated keys keep the last value.
  final Map<String, String> queryParameters;
  final String fragment;
  final bool isNotFound;
}

/// A validated, browser-independent collection of route definitions.
///
/// Matching prefers the route with the most static segments. Duplicate
/// patterns and overlapping patterns with equal specificity are rejected.
class RouteTable {
  RouteTable({required Iterable<RouteDefinition> routes})
      : routes = List<RouteDefinition>.unmodifiable(routes) {
    _validateRoutes(this.routes);
  }

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
  final parameterNames = <String>{};
  for (final segment in _splitPath(normalized)) {
    if (segment.startsWith(':') &&
        !RegExp(r'^:[A-Za-z_][A-Za-z0-9_]*$').hasMatch(segment)) {
      throw ArgumentError.value(path, 'path', 'Invalid parameter segment.');
    }
    if (segment.startsWith(':') && !parameterNames.add(segment.substring(1))) {
      throw ArgumentError.value(
        path,
        'path',
        'Route parameter names must be unique.',
      );
    }
  }
  return normalized;
}

void _validateRoutes(List<RouteDefinition> routes) {
  for (var index = 0; index < routes.length; index++) {
    final route = routes[index];
    for (var otherIndex = 0; otherIndex < index; otherIndex++) {
      final other = routes[otherIndex];
      if (_sameRoutePattern(route, other)) {
        throw ArgumentError(
          'Duplicate route definitions: "${other.path}" and "${route.path}".',
        );
      }

      if (route._staticSegmentCount == other._staticSegmentCount &&
          _routesOverlap(route._segments, other._segments)) {
        throw ArgumentError(
          'Ambiguous route definitions: "${other.path}" and '
          '"${route.path}" match the same path with equal specificity.',
        );
      }
    }
  }
}

bool _sameRoutePattern(RouteDefinition first, RouteDefinition second) {
  if (first._segments.length != second._segments.length) return false;
  for (var index = 0; index < first._segments.length; index++) {
    final firstSegment = first._segments[index];
    final secondSegment = second._segments[index];
    final firstIsParameter = firstSegment.startsWith(':');
    final secondIsParameter = secondSegment.startsWith(':');
    if (firstIsParameter != secondIsParameter) return false;
    if (!firstIsParameter && firstSegment != secondSegment) return false;
  }
  return true;
}

bool _routesOverlap(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    final firstSegment = first[index];
    final secondSegment = second[index];
    if (!firstSegment.startsWith(':') &&
        !secondSegment.startsWith(':') &&
        firstSegment != secondSegment) {
      return false;
    }
  }
  return true;
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
