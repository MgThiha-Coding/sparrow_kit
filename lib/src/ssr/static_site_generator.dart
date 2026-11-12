import 'dart:io';

import '../seo/metadata.dart';
import 'markup.dart';
import 'string_renderer.dart';

class StaticPage {
  const StaticPage({
    required this.path,
    required this.component,
    this.metadata,
  });

  final String path;
  final SsrComponent component;
  final HeadMetadata? metadata;
}

class StaticSiteGenerator {
  StaticSiteGenerator({String? clientScript})
      : _clientScript = clientScript,
        _renderer = StringRenderer();

  final String? _clientScript;
  final StringRenderer _renderer;

  Future<List<File>> generate(
    Iterable<StaticPage> pages, {
    required String outputDirectory,
  }) async {
    if (outputDirectory.isEmpty) {
      throw ArgumentError.value(
        outputDirectory,
        'outputDirectory',
        'An output directory is required.',
      );
    }

    final generatedFiles = <File>[];
    final generatedPaths = <String>{};
    for (final page in pages) {
      final segments = _pathSegments(page.path);
      if (!generatedPaths.add(segments.join('/'))) {
        throw StateError('Duplicate static page path "${page.path}".');
      }

      var directoryPath = outputDirectory;
      for (final segment in segments) {
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
          metadata: page.metadata,
          clientScript: _clientScript,
        ),
      );
      generatedFiles.add(file);
    }

    return List<File>.unmodifiable(generatedFiles);
  }
}

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
