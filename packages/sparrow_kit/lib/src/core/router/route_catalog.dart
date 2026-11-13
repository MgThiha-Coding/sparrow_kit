import '../seo/metadata.dart';
import '../ssr/markup.dart';
import '../ssr/string_renderer.dart';
import 'route_table.dart';

typedef RouteCatalogPageBuilder = SsrComponent Function(RouteMatch match);
typedef RouteMetadataBuilder = HeadMetadata Function(RouteMatch match);

class RouteConfig {
  const RouteConfig({
    required this.definition,
    required this.pageBuilder,
    required this.metadataBuilder,
    this.indexable = true,
  });

  final RouteDefinition definition;
  final RouteCatalogPageBuilder pageBuilder;
  final RouteMetadataBuilder metadataBuilder;
  final bool indexable;
}

class RouteRenderResult {
  const RouteRenderResult({
    required this.statusCode,
    required this.match,
    required this.metadata,
    required this.html,
  });

  final int statusCode;
  final RouteMatch match;
  final HeadMetadata metadata;
  final String html;
}

/// Shared route definitions and page metadata for browser, SSR, and SSG use.
///
/// The catalog itself has no browser or server-I/O dependencies.
class RouteCatalog {
  factory RouteCatalog({
    required Iterable<RouteConfig> routes,
    required RouteCatalogPageBuilder notFoundBuilder,
    RouteMetadataBuilder? notFoundMetadataBuilder,
  }) {
    final routeList = List<RouteConfig>.unmodifiable(routes);
    final routeTable = RouteTable(
      routes: routeList.map((route) => route.definition),
    );
    return RouteCatalog._(
      routes: routeList,
      routeTable: routeTable,
      notFoundBuilder: notFoundBuilder,
      notFoundMetadataBuilder:
          notFoundMetadataBuilder ?? _defaultNotFoundMetadata,
    );
  }

  RouteCatalog._({
    required this.routes,
    required this.routeTable,
    required this.notFoundBuilder,
    required RouteMetadataBuilder notFoundMetadataBuilder,
  })  : _notFoundMetadataBuilder = notFoundMetadataBuilder,
        _routesByPath = Map<String, RouteConfig>.unmodifiable({
          for (final route in routes) route.definition.path: route,
        });

  final List<RouteConfig> routes;
  final RouteTable routeTable;
  final RouteCatalogPageBuilder notFoundBuilder;
  final RouteMetadataBuilder _notFoundMetadataBuilder;
  final Map<String, RouteConfig> _routesByPath;
  final StringRenderer _renderer = StringRenderer();

  RouteMatch resolve(String location) => routeTable.resolve(location);

  RouteConfig? routeFor(RouteMatch match) {
    final definition = match.route;
    return definition == null ? null : _routesByPath[definition.path];
  }

  SsrComponent pageFor(RouteMatch match) {
    final route = routeFor(match);
    return route == null ? notFoundBuilder(match) : route.pageBuilder(match);
  }

  HeadMetadata metadataFor(RouteMatch match) {
    final route = routeFor(match);
    if (route == null) return _notFoundMetadataBuilder(match);

    final metadata = route.metadataBuilder(match);
    if (route.indexable || metadata.robots?.index == false) return metadata;

    return HeadMetadata(
      title: metadata.title,
      description: metadata.description,
      canonicalUrl: metadata.canonicalUrl,
      metaTags: metadata.metaTags,
      jsonLd: metadata.jsonLd,
      openGraph: metadata.openGraph,
      twitterCard: metadata.twitterCard,
      robots: (metadata.robots ?? const RobotsDirectives()).copyWith(
        index: false,
      ),
      language: metadata.language,
      locale: metadata.locale,
    );
  }

  RouteRenderResult renderRequest(
    String location, {
    String rootId = 'app',
    String? clientScript = '/main.dart.js',
  }) {
    final match = resolve(location);
    final metadata = metadataFor(match);
    return RouteRenderResult(
      statusCode: match.isNotFound ? 404 : 200,
      match: match,
      metadata: metadata,
      html: _renderer.render(
        pageFor(match),
        metadata: metadata,
        rootId: rootId,
        clientScript: clientScript,
      ),
    );
  }
}

HeadMetadata _defaultNotFoundMetadata(RouteMatch _) => HeadMetadata(
      title: 'Not Found',
      description: 'The requested page was not found.',
      robots: const RobotsDirectives(index: false),
    );
