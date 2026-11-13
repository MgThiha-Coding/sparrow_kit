import 'dart:io';

Future<void> main() async {
  final root = Directory.current;
  final app = Directory(
    '${root.path}${Platform.pathSeparator}apps'
    '${Platform.pathSeparator}web_app',
  );
  final output = Directory(
    '${app.path}${Platform.pathSeparator}build'
    '${Platform.pathSeparator}web',
  );
  final staleFile = File(
    '${output.path}${Platform.pathSeparator}stale-${pid}.txt',
  );
  await output.create(recursive: true);
  await staleFile.writeAsString('must be removed by the next build');

  try {
    final result = await Process.run(
      'dart',
      ['run', 'sparrow_cli', 'build', 'web'],
      workingDirectory: app.path,
      environment: {
        ...Platform.environment,
        'SPARROW_SITE_URL': 'https://example.test',
      },
      runInShell: true,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw ProcessException(
        'dart',
        ['run', 'sparrow_cli', 'build', 'web'],
        'The web app CLI build failed.',
        result.exitCode,
      );
    }

    if (await staleFile.exists()) {
      throw StateError('The CLI left stale files in its output directory.');
    }

    final html = await File(
      '${output.path}${Platform.pathSeparator}index.html',
    ).readAsString();
    for (final expected in const [
      '<title>MyCompany | Independent Creative Company</title>',
      'rel="canonical" href="https://example.test/"',
      'id="main-content"',
      'id="portfolio"',
      'landing_category_0',
      'id="__FRAMEWORK_STATE__"',
      'src="/main.dart.js"',
      'href="/landing.css"',
    ]) {
      if (!html.contains(expected)) {
        throw StateError('Generated HTML is missing "$expected".');
      }
    }

    final stylesheet = File(
      '${output.path}${Platform.pathSeparator}landing.css',
    );
    final sourceStylesheet = File(
      '${app.path}${Platform.pathSeparator}web'
      '${Platform.pathSeparator}landing.css',
    );
    if (!await stylesheet.exists() ||
        await stylesheet.length() == 0 ||
        await stylesheet.readAsString() !=
            await sourceStylesheet.readAsString()) {
      throw StateError('The CLI did not copy the landing page stylesheet.');
    }

    final client = File(
      '${output.path}${Platform.pathSeparator}main.dart.js',
    );
    if (!await client.exists() || await client.length() == 0) {
      throw StateError('The CLI did not emit the browser JavaScript bundle.');
    }
    final sourceMap = File('${client.path}.map');
    final compilerDependencies = File('${client.path}.deps');
    if (await sourceMap.exists() ||
        await compilerDependencies.exists() ||
        (await client.readAsString()).contains('sourceMappingURL')) {
      throw StateError(
        'The production build must omit source maps and compiler manifests.',
      );
    }

    for (final relativePath in const [
      'integration.html',
      'main.dart',
      'ssr_client.dart',
    ]) {
      final copiedFile = File(
        '${output.path}${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (await copiedFile.exists()) {
        throw StateError('The production build copied "$relativePath".');
      }
    }

    final sitemap = File(
      '${output.path}${Platform.pathSeparator}sitemap.xml',
    );
    final robots = File(
      '${output.path}${Platform.pathSeparator}robots.txt',
    );
    if (!await sitemap.exists() ||
        !(await sitemap.readAsString()).contains('https://example.test/') ||
        !await robots.exists() ||
        !(await robots.readAsString())
            .contains('https://example.test/sitemap.xml')) {
      throw StateError(
        'The production build did not generate configured sitemap and robots files.',
      );
    }

    var totalBytes = 0;
    await for (final entity in output.list(recursive: true)) {
      if (entity is File) totalBytes += await entity.length();
    }
    stdout.writeln(
      'Production artifacts: ${await client.length()} B JavaScript, '
      '${await stylesheet.length()} B CSS, $totalBytes B total; '
      'source maps and compiler manifests excluded.',
    );
    stdout.writeln('Sparrow CLI app build and stale-output smoke passed.');
  } finally {
    if (await staleFile.exists()) await staleFile.delete();
  }
}
