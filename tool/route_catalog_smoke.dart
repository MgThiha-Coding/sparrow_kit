import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sparrow_kit/server.dart';
import 'package:web_app/ssr_handler.dart';

class _Page implements SsrComponent {
  const _Page(this.content);

  final String content;

  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [MarkupText(content)],
      );
}

Future<void> main() async {
  final catalog = RouteCatalog(
    routes: [
      RouteConfig(
        definition: RouteDefinition('/about'),
        pageBuilder: (_) => const _Page('About page'),
        indexable: false,
        metadataBuilder: (_) => HeadMetadata(
          title: 'About Sparrow',
          description: 'About page description',
          canonicalUrl: 'https://example.test/about/',
          openGraph: const OpenGraphMetadata(
            title: 'About social title',
            type: 'website',
            description: 'About social description',
            url: 'https://example.test/about/',
            image: 'https://example.test/about.png',
          ),
          twitterCard: const TwitterCardMetadata(
            card: 'summary',
            title: 'About Twitter title',
            description: 'About Twitter description',
          ),
        ),
      ),
      RouteConfig(
        definition: RouteDefinition('/index.html'),
        pageBuilder: (match) =>
            _Page('Index tab ${match.queryParameters['tab'] ?? ''}'),
        metadataBuilder: (_) => HeadMetadata(title: 'Catalog index'),
      ),
      RouteConfig(
        definition: RouteDefinition('/products/:productId'),
        pageBuilder: (match) => _Page(
          'Product ${match.params['productId']} '
          'tab ${match.queryParameters['tab'] ?? ''}',
        ),
        metadataBuilder: (match) {
          final productId = match.params['productId']!;
          return HeadMetadata(
            title: 'Product $productId',
            description: 'Details for product $productId',
            canonicalUrl: 'https://example.test/products/$productId/',
            openGraph: OpenGraphMetadata(
              title: 'Social product $productId',
              type: 'product',
              url: 'https://example.test/products/$productId/',
              image: 'https://example.test/products/$productId.png',
            ),
            twitterCard: TwitterCardMetadata(
              card: 'summary_large_image',
              title: 'Twitter product $productId',
            ),
          );
        },
      ),
    ],
    notFoundBuilder: (match) => _Page('Missing ${match.path}'),
  );

  _testCatalogMatching(catalog);
  _testServerRendering(catalog);

  final temporaryDirectory =
      await Directory.systemTemp.createTemp('sparrow_route_catalog_');
  try {
    await _testHttpResponses(catalog, temporaryDirectory);
    await _testStaticGeneration(catalog, temporaryDirectory);
  } finally {
    await temporaryDirectory.delete(recursive: true);
  }
}

void _testCatalogMatching(RouteCatalog catalog) {
  final match = catalog.resolve('/products/42?tab=specifications');
  _expect(
    match.route?.path == '/products/:productId' &&
        match.params['productId'] == '42' &&
        match.queryParameters['tab'] == 'specifications',
    'The shared catalog should resolve route, path, and query values.',
  );
  _expect(
    catalog.resolve('/not-found').isNotFound,
    'Unknown paths should resolve to a not-found match.',
  );
  _expect(
    catalog.resolve('/index.html?tab=home').route?.path == '/index.html',
    'Direct alias requests should resolve through the catalog route table.',
  );
}

void _testServerRendering(RouteCatalog catalog) {
  final about = catalog.renderRequest('/about', clientScript: null);
  _expect(
    about.statusCode == 200 &&
        about.html.contains('About page') &&
        about.html.contains('<title>About Sparrow</title>') &&
        about.html
            .contains('rel="canonical" href="https://example.test/about/"') &&
        about.html
            .contains('property="og:title" content="About social title"') &&
        about.html.contains(
          'name="twitter:title" content="About Twitter title"',
        ) &&
        about.html.contains('name="robots" content="noindex, follow"'),
    'Static SSR should render its page and route-level SEO metadata.',
  );

  final product = catalog.renderRequest(
    '/products/42?tab=specifications',
    clientScript: null,
  );
  _expect(
    product.statusCode == 200 &&
        product.match.params['productId'] == '42' &&
        product.match.queryParameters['tab'] == 'specifications' &&
        product.html.contains('Product 42 tab specifications') &&
        product.html.contains('<title>Product 42</title>') &&
        product.html.contains(
          'rel="canonical" href="https://example.test/products/42/"',
        ) &&
        product.html.contains(
          'property="og:title" content="Social product 42"',
        ) &&
        product.html.contains(
          'name="twitter:title" content="Twitter product 42"',
        ),
    'Dynamic SSR should pass path and query values to page and metadata builders.',
  );

  final missing = catalog.renderRequest('/missing', clientScript: null);
  _expect(
    missing.statusCode == 404 &&
        missing.html.contains('Missing /missing') &&
        missing.html.contains('name="robots" content="noindex, follow"'),
    'Unmatched SSR paths should render a noindex 404 page.',
  );
}

Future<void> _testHttpResponses(
  RouteCatalog catalog,
  Directory temporaryDirectory,
) async {
  final handler = createSsrHandler(
    catalog: catalog,
    outputDirectory: temporaryDirectory.path,
    webDirectory: temporaryDirectory.path,
  );
  final aboutResponse = await handler(
    Request('GET', Uri.parse('http://localhost/about')),
  );
  final aboutHtml = await aboutResponse.readAsString();
  _expect(
    aboutResponse.statusCode == 200 &&
        aboutHtml.contains('About page') &&
        aboutHtml.contains('<title>About Sparrow</title>') &&
        aboutHtml.contains('name="twitter:title"'),
    'The SSR HTTP handler should serve a static direct request.',
  );

  final indexResponse = await handler(
    Request('GET', Uri.parse('http://localhost/index.html?tab=home')),
  );
  final indexHtml = await indexResponse.readAsString();
  _expect(
    indexResponse.statusCode == 200 &&
        indexHtml.contains('Index tab home') &&
        indexHtml.contains('<title>Catalog index</title>'),
    'The SSR HTTP handler should preserve catalog matching and query values '
    'for /index.html requests.',
  );

  final productResponse = await handler(
    Request(
      'GET',
      Uri.parse('http://localhost/products/17?tab=overview'),
    ),
  );
  final productHtml = await productResponse.readAsString();
  _expect(
    productResponse.statusCode == 200 &&
        productHtml.contains('Product 17 tab overview') &&
        productHtml.contains(
          'name="twitter:title" content="Twitter product 17"',
        ) &&
        productHtml.contains(
          'rel="canonical" href="https://example.test/products/17/"',
        ),
    'The SSR HTTP handler should serve a dynamic direct request.',
  );

  final notFoundResponse = await handler(
    Request('GET', Uri.parse('http://localhost/unknown')),
  );
  final notFoundHtml = await notFoundResponse.readAsString();
  _expect(
    notFoundResponse.statusCode == 404 &&
        notFoundHtml.contains('Missing /unknown'),
    'The SSR HTTP handler should return an actual 404 response.',
  );

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    0,
  );
  final client = HttpClient();
  final baseUri = Uri(
    scheme: 'http',
    host: server.address.address,
    port: server.port,
  );
  try {
    final (staticStatus, staticHtml) = await _getHttpResponse(
      client,
      baseUri.resolve('/about'),
    );
    final (dynamicStatus, dynamicHtml) = await _getHttpResponse(
      client,
      baseUri.resolve('/products/17?tab=overview'),
    );
    final (missingStatus, missingHtml) = await _getHttpResponse(
      client,
      baseUri.resolve('/unknown'),
    );
    _expect(
      staticStatus == 200 &&
          staticHtml.contains('About page') &&
          dynamicStatus == 200 &&
          dynamicHtml.contains('Product 17 tab overview') &&
          missingStatus == 404 &&
          missingHtml.contains('Missing /unknown'),
      'Live HTTP requests should preserve catalog rendering and status codes.',
    );
  } finally {
    client.close(force: true);
    await server.close(force: true);
  }
}

Future<(int, String)> _getHttpResponse(HttpClient client, Uri uri) async {
  final response = await (await client.getUrl(uri)).close();
  return (
    response.statusCode,
    await response.transform(utf8.decoder).join(),
  );
}

Future<void> _testStaticGeneration(
  RouteCatalog catalog,
  Directory temporaryDirectory,
) async {
  final output = Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}static',
  );
  final files = await catalog.generateStaticSite(
    concretePathsByRoute: const {
      '/about': ['/about'],
      '/products/:productId': ['/products/42', '/products/99'],
    },
    outputDirectory: output.path,
    generator: StaticSiteGenerator(
      siteBaseUrl: 'https://example.test',
      clientScript: '/main.dart.js',
    ),
  );
  _expect(
    files.length == 3,
    'SSG should generate only the explicitly configured concrete paths.',
  );

  final aboutHtml = await File(
    '${output.path}${Platform.pathSeparator}about'
    '${Platform.pathSeparator}index.html',
  ).readAsString();
  _expect(
    aboutHtml.contains('<title>About Sparrow</title>') &&
        aboutHtml.contains('name="robots" content="noindex, follow"'),
    'SSG should preserve catalog route metadata and indexability.',
  );

  final productHtml = await File(
    '${output.path}${Platform.pathSeparator}products'
    '${Platform.pathSeparator}42${Platform.pathSeparator}index.html',
  ).readAsString();
  _expect(
    productHtml.contains('Product 42 tab ') &&
        productHtml.contains('<title>Product 42</title>') &&
        productHtml.contains(
          'rel="canonical" href="https://example.test/products/42/"',
        ) &&
        productHtml.contains(
          'property="og:title" content="Social product 42"',
        ) &&
        productHtml.contains('src="/main.dart.js"'),
    'SSG should use the catalog page, route metadata, and root-relative client '
    'asset path.',
  );

  final sitemap = await File(
    '${output.path}${Platform.pathSeparator}sitemap.xml',
  ).readAsString();
  _expect(
    sitemap.contains('https://example.test/products/42/') &&
        sitemap.contains('https://example.test/products/99/') &&
        !sitemap.contains('https://example.test/about/'),
    'SSG should honor route indexability when building the sitemap.',
  );

  final robots = await File(
    '${output.path}${Platform.pathSeparator}robots.txt',
  ).readAsString();
  final handler = createSsrHandler(
    catalog: catalog,
    outputDirectory: output.path,
    webDirectory: temporaryDirectory.path,
  );
  final sitemapResponse = await handler(
    Request('GET', Uri.parse('http://localhost/sitemap.xml')),
  );
  final robotsResponse = await handler(
    Request('GET', Uri.parse('http://localhost/robots.txt')),
  );
  _expect(
    sitemapResponse.statusCode == 200 &&
        sitemapResponse.headers['content-type'] ==
            'application/xml; charset=utf-8' &&
        await sitemapResponse.readAsString() == sitemap &&
        robotsResponse.statusCode == 200 &&
        robotsResponse.headers['content-type'] == 'text/plain; charset=utf-8' &&
        await robotsResponse.readAsString() == robots,
    'The SSR handler should serve generated sitemap and robots files.',
  );

  await _expectArgumentError(
    () => catalog.generateStaticSite(
      concretePathsByRoute: const {
        '/products/:productId': ['/products/:productId'],
      },
      outputDirectory: output.path,
    ),
    'Dynamic route patterns must not be used as concrete SSG paths.',
  );
}

Future<void> _expectArgumentError(
  Future<Object?> Function() action,
  String message,
) async {
  try {
    await action();
  } on ArgumentError {
    return;
  }
  throw StateError(message);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
