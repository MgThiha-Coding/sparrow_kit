import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../reactivity/signals.dart';
import 'route_table.dart';

export 'route_table.dart';

class Router {
  Router({required Iterable<RouteDefinition> routes})
      : routeTable = RouteTable(routes: routes) {
    final initialMatch = routeTable.resolve(web.window.location.pathname);
    currentRoute = Signal<RouteMatch>(initialMatch);
    params = Signal<Map<String, String>>(initialMatch.params);

    _popStateListener = ((web.Event _) => _syncFromLocation()).toJS;
    web.window.addEventListener('popstate', _popStateListener);
  }

  final RouteTable routeTable;
  List<RouteDefinition> get routes => routeTable.routes;
  late final Signal<RouteMatch> currentRoute;
  late final Signal<Map<String, String>> params;
  final Map<String, Signal<String?>> _parameterSignals = {};
  late final JSFunction _popStateListener;
  bool _isDisposed = false;

  Signal<String?> param(String name) {
    return _parameterSignals.putIfAbsent(
      name,
      () => Signal<String?>(currentRoute.value.params[name]),
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

    final url = path.startsWith('/') ? path : '/$path';
    web.window.history.pushState(null, '', url);
    _syncFromLocation();
  }

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    web.window.removeEventListener('popstate', _popStateListener);
  }

  void _syncFromLocation() {
    if (_isDisposed) return;

    final nextMatch = routeTable.resolve(web.window.location.pathname);
    for (final entry in _parameterSignals.entries) {
      entry.value.value = nextMatch.params[entry.key];
    }
    params.value = nextMatch.params;
    currentRoute.value = nextMatch;
  }
}
