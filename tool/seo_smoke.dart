import 'dart:io';

import 'package:sparrow_kit/server.dart';

class _Page implements SsrComponent {
  const _Page(this.label);

  final String label;

  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [MarkupText(label)],
      );
}

Future<void> main() async {
  _testTypedMetadataRendering();
  _testInvalidSiteBaseUrl();

  final temporaryDirectory =
      await Directory.systemTemp.createTemp('sparrow_seo_smoke_');
  try {
    await _testStaticSeoOutput(temporaryDirectory);
    await _testLegacyGeneration(temporaryDirectory);
    await _testMissingSiteBaseUrl(temporaryDirectory);
  } finally {
    await temporaryDirectory.delete(recursive: true);
  }
}

void _testTypedMetadataRendering() {
  final html = renderToString(
    const _Page('Home'),
    metadata: HeadMetadata(
      title: 'Sparrow & Co',
      description: 'A <thoughtful> company',
      canonicalUrl: 'https://example.test/',
      language: 'en-GB',
      locale: 'en_GB',
      openGraph: const OpenGraphMetadata(
        title: 'Open graph title',
        type: 'website',
        url: 'https://example.test/',
        image: 'https://example.test/preview.png',
        description: 'Open graph description',
      ),
      twitterCard: const TwitterCardMetadata(
        card: 'summary_large_image',
        title: 'Social title',
        image: 'https://example.test/preview.png',
      ),
      robots: const RobotsDirectives(
        index: false,
        follow: false,
        archive: false,
        snippets: false,
        imageIndex: false,
      ),
      jsonLd: const [
        OrganizationJsonLd(
          name: 'Sparrow & Co',
          url: 'https://example.test/',
        ),
      ],
    ),
    clientScript: null,
  );

  for (final expected in [
    '<html lang="en-GB">',
    '<title>Sparrow &amp; Co</title>',
    'name="description" content="A &lt;thoughtful&gt; company"',
    'href="https://example.test/">',
    'property="og:title" content="Open graph title"',
    'name="twitter:card" content="summary_large_image"',
    'property="og:locale" content="en_GB"',
    'name="robots" content="noindex, nofollow, noarchive, nosnippet, noimageindex"',
    '"@type":"Organization"',
  ]) {
    _expect(html.contains(expected), 'SSR output should contain "$expected".');
  }
}

void _testInvalidSiteBaseUrl() {
  for (final value in [
    'example.test',
    'ftp://example.test',
    'https://user@example.test',
    'https://example.test/path',
    'https://example.test/?query=1',
  ]) {
    _expectArgumentError(
      () => StaticSiteGenerator(siteBaseUrl: value),
      'Invalid site base URL "$value" should be rejected.',
    );
  }
}

Future<void> _testStaticSeoOutput(Directory temporaryDirectory) async {
  final output = Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}seo',
  );
  final pages = [
    StaticPage(
      path: '/',
      component: const _Page('Home'),
      metadata: HeadMetadata(
        title: 'Home title',
        description: 'Home description',
        openGraph: const OpenGraphMetadata(
          title: 'Home title',
          type: 'website',
          url: 'https://example.test/',
          image: 'https://example.test/image.png?size=small&theme=light',
        ),
      ),
    ),
    StaticPage(
      path: '/articles/one',
      component: const _Page('Article'),
      metadata: HeadMetadata(
        title: 'Article title',
        description: 'Article description',
        canonicalUrl: 'https://example.test/articles/one/',
        robots: const RobotsDirectives(index: false),
      ),
    ),
    StaticPage(
      path: '/private',
      component: const _Page('Private'),
      indexable: false,
    ),
    StaticPage(
      path: '/external',
      component: const _Page('External'),
      metadata: HeadMetadata(
        title: 'External',
        canonicalUrl: 'https://other.test/canonical/',
      ),
    ),
    StaticPage(
      path: '/escaped',
      component: const _Page('Escaped'),
      metadata: HeadMetadata(
        title: 'Escaped',
        canonicalUrl: 'https://example.test/a&b/',
      ),
    ),
  ];

  final files = await StaticSiteGenerator(
    siteBaseUrl: 'https://example.test',
  ).generate(pages, outputDirectory: output.path);
  _expect(files.length == pages.length, 'Every page should be generated.');

  final homeHtml = await File(
    '${output.path}${Platform.pathSeparator}index.html',
  ).readAsString();
  final articleHtml = await File(
    '${output.path}${Platform.pathSeparator}articles'
    '${Platform.pathSeparator}one${Platform.pathSeparator}index.html',
  ).readAsString();
  final privateHtml = await File(
    '${output.path}${Platform.pathSeparator}private'
    '${Platform.pathSeparator}index.html',
  ).readAsString();
  for (final expected in [
    '<title>Home title</title>',
    'name="description" content="Home description"',
    'rel="canonical" href="https://example.test/">',
    'property="og:url" content="https://example.test/"',
  ]) {
    _expect(
        homeHtml.contains(expected), 'Home HTML should contain "$expected".');
  }
  _expect(
    articleHtml.contains('<title>Article title</title>') &&
        articleHtml.contains('content="noindex, follow"'),
    'The article should retain its route-specific metadata and noindex rule.',
  );
  _expect(
    privateHtml.contains('content="noindex, follow"'),
    'Non-indexable pages should include a noindex directive.',
  );

  final sitemap = await File(
    '${output.path}${Platform.pathSeparator}sitemap.xml',
  ).readAsString();
  final expectedHomeUrl = 'https://example.test/';
  final expectedExternalUrl = 'https://other.test/canonical/';
  _expect(
    sitemap.contains('<loc>$expectedHomeUrl</loc>') &&
        !sitemap.contains('/articles/one/') &&
        !sitemap.contains('/private/') &&
        !sitemap.contains(expectedExternalUrl) &&
        sitemap.contains('<loc>https://example.test/a&amp;b/</loc>'),
    'The sitemap should include only same-origin indexable canonicals.',
  );
  _expect(
    sitemap.split('<loc>$expectedHomeUrl</loc>').length == 2,
    'Sitemap canonical locations should not be duplicated.',
  );
  _expect(
    sitemap.indexOf('<loc>$expectedHomeUrl</loc>') <
        sitemap.indexOf('<loc>https://example.test/a&amp;b/</loc>'),
    'Sitemap locations should be sorted deterministically.',
  );

  final robots = await File(
    '${output.path}${Platform.pathSeparator}robots.txt',
  ).readAsString();
  _expect(
    robots ==
        'User-agent: *\n'
            'Allow: /\n'
            'Sitemap: https://example.test/sitemap.xml\n',
    'robots.txt should include the configured sitemap URL.',
  );

  await _expectArgumentErrorAsync(
    () async {
      await StaticSiteGenerator(siteBaseUrl: 'https://example.test').generate(
        [
          StaticPage(
            path: '/bad',
            component: const _Page('Bad'),
            metadata: HeadMetadata(
              title: 'Bad',
              canonicalUrl: '/relative/',
            ),
          ),
        ],
        outputDirectory: output.path,
      );
    },
    'Relative canonicals should be rejected when a site origin is configured.',
  );

  await _expectStateError(
    () async {
      await StaticSiteGenerator(siteBaseUrl: 'https://example.test').generate(
        [
          StaticPage(path: '/', component: const _Page('One')),
          StaticPage(path: '/', component: const _Page('Two')),
        ],
        outputDirectory: output.path,
      );
    },
    'Duplicate static paths should remain rejected.',
  );

  await _expectStateError(
    () async {
      await StaticSiteGenerator(siteBaseUrl: 'https://example.test').generate(
        [
          StaticPage(
            path: '/first',
            component: const _Page('First'),
            metadata: HeadMetadata(
              title: 'First',
              canonicalUrl: 'https://example.test/shared/',
            ),
          ),
          StaticPage(
            path: '/second',
            component: const _Page('Second'),
            metadata: HeadMetadata(
              title: 'Second',
              canonicalUrl: 'https://example.test/shared/',
            ),
          ),
        ],
        outputDirectory: output.path,
      );
    },
    'Duplicate canonical URLs should be rejected.',
  );

  await _expectArgumentErrorAsync(
    () async {
      await StaticSiteGenerator(siteBaseUrl: 'https://example.test').generate(
        const [
          StaticPage(
            path: '/robots.txt/child',
            component: _Page('Reserved'),
          ),
        ],
        outputDirectory: output.path,
      );
    },
    'Routes cannot collide with generated SEO output paths.',
  );
}

Future<void> _testLegacyGeneration(Directory temporaryDirectory) async {
  final output = Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}legacy',
  );
  await StaticSiteGenerator().generate(
    const [StaticPage(path: '/', component: _Page('Legacy'))],
    outputDirectory: output.path,
  );
  _expect(
    !await File('${output.path}${Platform.pathSeparator}sitemap.xml')
            .exists() &&
        !await File('${output.path}${Platform.pathSeparator}robots.txt')
            .exists(),
    'Legacy generation without a site origin should not emit SEO files.',
  );
}

Future<void> _testMissingSiteBaseUrl(Directory temporaryDirectory) async {
  final output = Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}missing-origin',
  );
  await _expectArgumentErrorAsync(
    () async {
      await StaticSiteGenerator(generateSeoFiles: true).generate(
        const [StaticPage(path: '/', component: _Page('Missing origin'))],
        outputDirectory: output.path,
      );
    },
    'SEO file generation should require a site base URL.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _expectArgumentError(void Function() action, String message) {
  try {
    action();
  } on ArgumentError {
    return;
  }
  throw StateError(message);
}

Future<void> _expectArgumentErrorAsync(
  Future<void> Function() action,
  String message,
) async {
  try {
    await action();
  } on ArgumentError {
    return;
  }
  throw StateError(message);
}

Future<void> _expectStateError(
  Future<void> Function() action,
  String message,
) async {
  try {
    await action();
  } on StateError {
    return;
  }
  throw StateError(message);
}
