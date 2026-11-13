import 'dart:io';

import '../ssr/static_site_generator.dart';
import 'route_catalog.dart';

extension RouteCatalogStaticSiteGeneration on RouteCatalog {
  /// Generates only the concrete paths explicitly assigned to catalog routes.
  ///
  /// Dynamic routes are never expanded automatically. Supply every desired
  /// concrete path under its normalized route definition path.
  Future<List<File>> generateStaticSite({
    required Map<String, Iterable<String>> concretePathsByRoute,
    required String outputDirectory,
    StaticSiteGenerator? generator,
  }) {
    final routesByPath = {
      for (final route in routes) route.definition.path: route,
    };
    final pages = <StaticPage>[];

    for (final entry in concretePathsByRoute.entries) {
      final route = routesByPath[entry.key];
      if (route == null) {
        throw ArgumentError.value(
          entry.key,
          'concretePathsByRoute',
          'No route is defined for this path.',
        );
      }

      for (final path in entry.value) {
        final uri = Uri.parse(path);
        if (!path.startsWith('/') ||
            path.startsWith('//') ||
            uri.hasScheme ||
            uri.hasAuthority ||
            uri.hasQuery ||
            uri.hasFragment) {
          throw ArgumentError.value(
            path,
            'path',
            'Static route paths must be rooted paths without query or fragment.',
          );
        }

        final match = resolve(path);
        if (match.route?.path != route.definition.path ||
            match.params.values.any((value) => value.startsWith(':'))) {
          throw ArgumentError.value(
            path,
            'path',
            'A concrete path matching "${route.definition.path}" is required.',
          );
        }

        pages.add(
          StaticPage(
            path: match.path,
            component: pageFor(match),
            metadata: metadataFor(match),
            indexable: route.indexable,
          ),
        );
      }
    }

    return (generator ?? StaticSiteGenerator()).generate(
      pages,
      outputDirectory: outputDirectory,
    );
  }
}
