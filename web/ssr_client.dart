import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../lib/src/hydration/hydration_engine.dart';
import '../lib/src/ssr/counter_page.dart';

void main() {
  final state = HydrationState.fromDocument();
  final page = CounterPage(
    count: state.signal<int>('count', fallback: 0),
  );
  final container = web.document.getElementById('app');
  if (container is! web.Element) {
    throw StateError('The server-rendered app root was not found.');
  }

  final dispose = HydrationEngine().hydrate(
    container: container,
    tree: page.render(),
  );
  web.window.addEventListener('pagehide', ((web.Event _) => dispose()).toJS);
}
