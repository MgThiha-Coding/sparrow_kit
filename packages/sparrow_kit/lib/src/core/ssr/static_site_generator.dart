import 'dart:io';

import '../seo/metadata.dart';
import 'markup.dart';
import 'string_renderer.dart';

class StaticPage {
  const StaticPage({
    required this.path,
    required this.component,
    this.metadata,
    this.indexable = true,
  });

  final String path;
  final SsrComponent component;
  final HeadMetadata? metadata;
  final bool indexable;
}

class StaticSiteGenerator {
  StaticSiteGenerator({
    String? clientScript = '/main.dart.js',
    String? siteBaseUrl,
    bool? generateSeoFiles,
  })  : _clientScript = clientScript,
        _siteBaseUrl =
            siteBaseUrl == null ? null : _parseSiteBaseUrl(siteBaseUrl),
        _generateSeoFiles = generateSeoFiles ?? (siteBaseUrl != null),
        _renderer = StringRenderer();

  final String? _clientScript;
  final Uri? _siteBaseUrl;
  final bool _generateSeoFiles;
  final StringRenderer _renderer;

  Future<List<File>> generate(
    Iterable<StaticPage> pages, {
    required String outputDirectory,
  }) async {
    final siteBaseUrl = _siteBaseUrl;
    if (outputDirectory.isEmpty) {
      throw ArgumentError.value(
        outputDirectory,
        'outputDirectory',
        'An output directory is required.',
      );
    }

    if (_generateSeoFiles && siteBaseUrl == null) {
      throw ArgumentError(
        'A siteBaseUrl is required to generate sitemap.xml and robots.txt.',
      );
    }

    final preparedPages = <_PreparedStaticPage>[];
    final generatedPaths = <String>{};
    final sitemapUrls = <String>{};
    for (final page in pages) {
      final segments = _pathSegments(page.path);
      if (!generatedPaths.add(segments.join('/'))) {
        throw StateError('Duplicate static page path "${page.path}".');
      }
      if (_generateSeoFiles && _reservedSeoOutputPath(segments)) {
        throw ArgumentError.value(
          page.path,
          'path',
          'Static pages cannot use the reserved /sitemap.xml or /robots.txt path.',
        );
      }

      final sourceMetadata = page.metadata ?? HeadMetadata.defaults();
      final canonicalUrl = sourceMetadata.canonicalUrl ??
          (siteBaseUrl == null ? null : _canonicalUrl(segments, siteBaseUrl));
      final canonicalUri = canonicalUrl == null || siteBaseUrl == null
          ? null
          : _validateCanonicalUrl(canonicalUrl, page.path);
      final isIndexable =
          page.indexable && sourceMetadata.robots?.index != false;
      final robots = page.indexable
          ? sourceMetadata.robots
          : (sourceMetadata.robots ?? const RobotsDirectives())
              .copyWith(index: false);
      final metadata = HeadMetadata(
        title: sourceMetadata.title,
        description: sourceMetadata.description,
        canonicalUrl: canonicalUrl,
        metaTags: sourceMetadata.metaTags,
        jsonLd: sourceMetadata.jsonLd,
        openGraph: sourceMetadata.openGraph,
        twitterCard: sourceMetadata.twitterCard,
        robots: robots,
        language: sourceMetadata.language,
        locale: sourceMetadata.locale,
      );

      if (_generateSeoFiles &&
          isIndexable &&
          canonicalUri != null &&
          siteBaseUrl != null) {
        final sameOrigin = _hasSameOrigin(canonicalUri, siteBaseUrl);
        if (sameOrigin && !sitemapUrls.add(canonicalUri.toString())) {
          throw StateError(
            'Duplicate canonical URL "${canonicalUri.toString()}" in sitemap.',
          );
        }
      }

      preparedPages.add(
        _PreparedStaticPage(page, segments, metadata),
      );
    }

    final generatedFiles = <File>[];
    for (final prepared in preparedPages) {
      final page = prepared.page;
      var directoryPath = outputDirectory;
      for (final segment in prepared.segments) {
        directoryPath = '$directoryPath${Platform.pathSeparator}$segment';
      }

      final directory = Directory(directoryPath);
      await directory.create(recursive: true);
      final file = File(
        '$directoryPath${Platform.pathSeparator}index.html',
      );
      await file.writeAsString(
        _renderer.render(
          page.component,
          metadata: prepared.metadata,
          clientScript: _clientScript,
        ),
      );
      generatedFiles.add(file);
    }

    if (_generateSeoFiles) {
      final output = Directory(outputDirectory);
      await output.create(recursive: true);
      final sortedSitemapUrls = sitemapUrls.toList()..sort();
      await File(
        '${output.path}${Platform.pathSeparator}sitemap.xml',
      ).writeAsString(_sitemapXml(sortedSitemapUrls));
      await File(
        '${output.path}${Platform.pathSeparator}robots.txt',
      ).writeAsString(_robotsTxt());
    }

    return List<File>.unmodifiable(generatedFiles);
  }

  Uri _validateCanonicalUrl(String canonicalUrl, String pagePath) {
    final uri = Uri.tryParse(canonicalUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        canonicalUrl,
        'canonicalUrl',
        'Canonical URL for "$pagePath" must be absolute HTTP or HTTPS without query or fragment.',
      );
    }
    return uri;
  }

  String _sitemapUrl() =>
      _siteBaseUrl!.replace(pathSegments: const ['sitemap.xml']).toString();

  String _robotsTxt() => 'User-agent: *\n'
      'Allow: /\n'
      'Sitemap: ${_sitemapUrl()}\n';

  bool _reservedSeoOutputPath(List<String> segments) =>
      segments.isNotEmpty &&
      const {'sitemap.xml', 'robots.txt'}
          .contains(segments.first.toLowerCase());
}

class _PreparedStaticPage {
  const _PreparedStaticPage(this.page, this.segments, this.metadata);

  final StaticPage page;
  final List<String> segments;
  final HeadMetadata metadata;
}

Uri _parseSiteBaseUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError.value(
      value,
      'siteBaseUrl',
      'Expected an absolute HTTP or HTTPS site origin without credentials, path, query, or fragment.',
    );
  }
  return uri.replace(path: '');
}

String _canonicalUrl(List<String> segments, Uri siteBaseUrl) {
  final uri = siteBaseUrl.replace(pathSegments: [...segments, '']);
  return (segments.isEmpty ? uri.replace(path: '/') : uri).toString();
}

bool _hasSameOrigin(Uri first, Uri second) =>
    first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
    first.host.toLowerCase() == second.host.toLowerCase() &&
    first.port == second.port;

String _sitemapXml(List<String> urls) {
  final xml = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    );
  for (final url in urls) {
    xml
      ..writeln('  <url>')
      ..writeln('    <loc>${_escapeXml(url)}</loc>')
      ..writeln('  </url>');
  }
  xml.write('</urlset>\n');
  return xml.toString();
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

List<String> _pathSegments(String path) {
  if (!path.startsWith('/') || path.startsWith('//')) {
    throw ArgumentError.value(path, 'path', 'Static paths must start with /.');
  }

  final uri = Uri.parse(path);
  if (uri.hasQuery || uri.hasFragment) {
    throw ArgumentError.value(
      path,
      'path',
      'Static paths cannot include a query or fragment.',
    );
  }

  final segments = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.decodeComponent)
      .toList(growable: false);
  if (segments.any(
    (segment) =>
        segment == '.' ||
        segment == '..' ||
        segment.contains('/') ||
        segment.contains(r'\') ||
        segment.contains(':') ||
        segment.contains('\u0000'),
  )) {
    throw ArgumentError.value(
        path, 'path', 'Static paths cannot traverse directories.');
  }
  return segments;
}
