import 'package:sparrow_kit/sparrow_kit.dart' show RouteView, Router;
import 'package:web/web.dart' as web;
import 'package:web_app/app/route_catalog.dart';

void main() {
  final canonical =
      web.document.querySelector('link[rel="canonical"]')?.getAttribute('href');
  final canonicalUri = canonical == null ? null : Uri.tryParse(canonical);
  final canonicalOrigin = canonicalUri != null &&
          canonicalUri.hasAuthority &&
          (canonicalUri.scheme == 'http' || canonicalUri.scheme == 'https')
      ? canonicalUri.origin
      : null;
  final catalog = companyRouteCatalog(siteBaseUrl: canonicalOrigin);
  final router = Router.fromCatalog(catalog: catalog);
  RouteView.fromCatalog(
    router: router,
    catalog: catalog,
    hydrateExisting: true,
  ).mount('#app');
}
