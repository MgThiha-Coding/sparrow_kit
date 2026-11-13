import 'package:web/web.dart' as web;

import '../../core/hydration/hydration_engine.dart' show HydrationEngine;
import '../seo/head_manager.dart' show HeadManager;
import '../../reactivity/signals.dart' show ReactiveContext, onCleanup;
import '../../rendering/component.dart' as runtime;
import '../../ui/dom_renderer.dart' show renderMarkup, renderUi;
import '../../ui/ui.dart' show UiNode;
import 'route_catalog.dart';
import 'router.dart' show Router;
import 'route_table.dart' show RouteMatch;

typedef RoutePageBuilder = UiNode Function(RouteMatch match);

/// A mounted route boundary that renders the current match as a UI description.
///
/// The page builder handles matched routes; [notFoundBuilder] handles
/// unmatched paths. Place this component inside an existing component tree to
/// keep the surrounding application shell mounted during navigation.
class RouteView extends runtime.Component<void> {
  RouteView({
    required this.router,
    required RoutePageBuilder pageBuilder,
    required RoutePageBuilder notFoundBuilder,
  })  : _pageBuilder = pageBuilder,
        _notFoundBuilder = notFoundBuilder,
        _catalog = null,
        _hydrateExisting = false,
        super(null);

  RouteView.fromCatalog({
    required this.router,
    required RouteCatalog catalog,
    bool hydrateExisting = false,
  })  : _pageBuilder = null,
        _notFoundBuilder = null,
        _catalog = catalog,
        _hydrateExisting = hydrateExisting,
        super(null) {
    if (!identical(router.routeTable, catalog.routeTable)) {
      throw ArgumentError(
        'Create the router with Router.fromCatalog(catalog) to share routes.',
      );
    }
  }

  final Router router;
  final RoutePageBuilder? _pageBuilder;
  final RoutePageBuilder? _notFoundBuilder;
  final RouteCatalog? _catalog;
  final bool _hydrateExisting;
  web.Element? _initialHydrationHost;
  HeadManager? _headManager;
  void Function()? _stopMetadata;

  @override
  void mountInto(web.Element host) {
    if (_hydrateExisting && host.firstChild != null) {
      _initialHydrationHost = host;
    }
    super.mountInto(host);
  }

  @override
  web.Node render() {
    final match = router.currentRoute.value;
    return ReactiveContext.untracked(() {
      final catalog = _catalog;
      if (catalog != null) {
        final tree = catalog.pageFor(match).render();
        final hydrationHost = _initialHydrationHost;
        if (hydrationHost != null) {
          final root = hydrationHost.firstChild;
          if (root == null) {
            throw StateError('Server-rendered route markup was not found.');
          }
          final disposeHydration = HydrationEngine().hydrate(
            container: hydrationHost,
            tree: tree,
          );
          _initialHydrationHost = null;
          onCleanup(disposeHydration);
          return root;
        }
        return renderMarkup(tree);
      }

      final pageBuilder = _pageBuilder!;
      final notFoundBuilder = _notFoundBuilder!;
      final page =
          match.isNotFound ? notFoundBuilder(match) : pageBuilder(match);
      return renderUi(page);
    });
  }

  @override
  void onMount() {
    final catalog = _catalog;
    if (catalog == null) return;

    final headManager = HeadManager();
    _headManager = headManager;
    _stopMetadata = headManager.watch(
      () => catalog.metadataFor(router.currentRoute.value),
    );
  }

  @override
  void onDispose() {
    _stopMetadata?.call();
    _stopMetadata = null;
    _headManager?.dispose();
    _headManager = null;
  }
}
