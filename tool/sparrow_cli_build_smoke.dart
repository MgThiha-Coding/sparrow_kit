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
    if (!await stylesheet.exists() || await stylesheet.length() == 0) {
      throw StateError('The CLI did not copy the landing page stylesheet.');
    }

    final client = File(
      '${output.path}${Platform.pathSeparator}main.dart.js',
    );
    if (!await client.exists() || await client.length() == 0) {
      throw StateError('The CLI did not emit the browser JavaScript bundle.');
    }
    stdout.writeln('Sparrow CLI app build and stale-output smoke passed.');
  } finally {
    if (await staleFile.exists()) await staleFile.delete();
  }
}
