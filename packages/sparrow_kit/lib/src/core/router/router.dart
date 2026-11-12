import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../reactivity/signals.dart';
import 'route_table.dart';

export 'route_table.dart';

class Router {
  Router({
    required Iterable<RouteDefinition> routes,
    bool interceptLinks = true,
  })  : routeTable = RouteTable(routes: routes),
        _interceptLinks = interceptLinks {
    final initialMatch = routeTable.resolve(_browserLocation);
    currentRoute = Signal<RouteMatch>(initialMatch);
    params = Signal<Map<String, String>>(initialMatch.params);
    queryParameters = Signal<Map<String, String>>(initialMatch.queryParameters);

    _popStateListener = ((web.Event _) => _syncFromLocation()).toJS;
    _hashChangeListener = ((web.Event _) => _syncFromLocation()).toJS;
    _clickListener = ((web.Event event) => _handleLinkClick(event)).toJS;
    web.window.addEventListener('popstate', _popStateListener);
    web.window.addEventListener('hashchange', _hashChangeListener);
    if (_interceptLinks) {
      web.document.addEventListener('click', _clickListener);
    }
  }

  final RouteTable routeTable;
  final bool _interceptLinks;
  List<RouteDefinition> get routes => routeTable.routes;
  late final Signal<RouteMatch> currentRoute;
  late final Signal<Map<String, String>> params;
  late final Signal<Map<String, String>> queryParameters;
  final Map<String, Signal<String?>> _parameterSignals = {};
  final Map<String, Signal<String?>> _queryParameterSignals = {};
  late final JSFunction _popStateListener;
  late final JSFunction _hashChangeListener;
  late final JSFunction _clickListener;
  bool _isDisposed = false;

  Signal<String?> param(String name) {
    return _parameterSignals.putIfAbsent(
      name,
      () => Signal<String?>(currentRoute.value.params[name]),
    );
  }

  Signal<String?> queryParam(String name) {
    return _queryParameterSignals.putIfAbsent(
      name,
      () => Signal<String?>(currentRoute.value.queryParameters[name]),
    );
  }

  void push(String path) {
    if (_isDisposed) {
      throw StateError('A disposed router cannot navigate.');
    }

    final uri = Uri.parse(path);
    if (uri.hasScheme || uri.hasAuthority) {
      throw ArgumentError.value(path, 'path', 'Expected a same-origin path.');
    }

    final currentUri = Uri.parse(web.window.location.href);
    final target =
        path.startsWith('/') || path.startsWith('?') || path.startsWith('#')
            ? path
            : '/$path';
    _navigate(currentUri.resolve(target));
  }

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    web.window.removeEventListener('popstate', _popStateListener);
    web.window.removeEventListener('hashchange', _hashChangeListener);
    if (_interceptLinks) {
      web.document.removeEventListener('click', _clickListener);
    }
  }

  void _syncFromLocation() {
    if (_isDisposed) return;

    final nextMatch = routeTable.resolve(_browserLocation);
    for (final entry in _parameterSignals.entries) {
      entry.value.value = nextMatch.params[entry.key];
    }
    for (final entry in _queryParameterSignals.entries) {
      entry.value.value = nextMatch.queryParameters[entry.key];
    }
    params.value = nextMatch.params;
    queryParameters.value = nextMatch.queryParameters;
    currentRoute.value = nextMatch;
  }

  String get _browserLocation {
    final location = web.window.location;
    return '${location.pathname}${location.search}${location.hash}';
  }

  void _handleLinkClick(web.Event event) {
    if (_isDisposed ||
        event.defaultPrevented ||
        event is! web.MouseEvent ||
        event.button != 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey) {
      return;
    }

    final target = event.target;
    if (target is! web.Element) return;

    final anchor = target.closest('a[href]');
    if (anchor is! web.HTMLAnchorElement ||
        anchor.hasAttribute('download') ||
        anchor.rel.toLowerCase().split(RegExp(r'\s+')).contains('external') ||
        (anchor.target.isNotEmpty && anchor.target.toLowerCase() != '_self')) {
      return;
    }

    final destination = Uri.parse(anchor.href);
    final currentUri = Uri.parse(web.window.location.href);
    if (destination.origin != currentUri.origin) return;

    final samePathAndQuery = destination.path == currentUri.path &&
        destination.query == currentUri.query;
    if (samePathAndQuery) {
      if (destination.fragment != currentUri.fragment) return;
      event.preventDefault();
      return;
    }

    // Let native navigation handle fragment links so browser scrolling works.
    if (destination.hasFragment) return;

    event.preventDefault();
    _navigate(destination);
  }

  void _navigate(Uri destination) {
    final currentUri = Uri.parse(web.window.location.href);
    if (destination.origin != currentUri.origin) {
      throw ArgumentError.value(
        destination,
        'destination',
        'Expected a same-origin URL.',
      );
    }

    web.window.history.pushState(null, '', destination.toString());
    _syncFromLocation();
  }
}
