import 'dart:convert';
import 'dart:io';
import 'dart:async';

Future<void> main() async {
  final workspace = Directory.current;
  final temporaryRoot = await workspace.createTemp('.sparrow_cli_workflow_');
  try {
    await _runWorkflow(workspace, temporaryRoot);
  } finally {
    await temporaryRoot.delete(recursive: true);
  }
}

Future<void> _runWorkflow(Directory workspace, Directory temporaryRoot) async {
  final project = Directory(_join(temporaryRoot.path, 'generated_app'));
  final cliEntry = _join(
    workspace.path,
    'packages',
    'sparrow_cli',
    'bin',
    'sparrow_cli.dart',
  );
  final init = await _runDart(
    ['run', cliEntry, 'init', project.path],
    workingDirectory: workspace,
  );
  _expectExit(init, 0, 'project creation');

  for (final relative in [
    'pubspec.yaml',
    'sparrow.json',
    'web/main.dart',
    'server/site.dart',
    'lib/home_page.dart',
  ]) {
    if (!await File(_join(project.path, relative)).exists()) {
      throw StateError('Generated project is missing "$relative".');
    }
  }

  final pubGet = await _runDart(
    ['pub', 'get'],
    workingDirectory: project,
  );
  _expectExit(pubGet, 0, 'generated project dependency resolution');

  final configFile = File(_join(project.path, 'sparrow.json'));
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  (config['web'] as Map<String, dynamic>)['output'] = 'build/custom_web';
  await configFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(config),
  );
  await File(_join(project.path, 'web', 'smoke-asset.txt'))
      .writeAsString('static asset');
  await File(_join(project.path, 'web', 'smoke-source.js.map'))
      .writeAsString('{}');

  final output = Directory(_join(project.path, 'build', 'custom_web'));
  final defaultBuild = await _runCli(
    project,
    ['build', 'web'],
  );
  _expectExit(defaultBuild, 0, 'fresh production build');

  final initialHtml =
      await File(_join(output.path, 'index.html')).readAsString();
  if (!initialHtml.contains('<title>Sparrow Kit app</title>') ||
      !initialHtml.contains('id="__FRAMEWORK_STATE__"') ||
      !await File(_join(output.path, 'main.dart.js')).exists() ||
      await File(_join(output.path, 'smoke-asset.txt')).readAsString() !=
          'static asset' ||
      await File(_join(output.path, 'smoke-source.js.map')).exists()) {
    throw StateError(
      'Fresh project build did not produce SSR, JavaScript, and copied assets '
      'without source maps.',
    );
  }

  final pageFile = File(_join(project.path, 'lib', 'home_page.dart'));
  final originalPage = await pageFile.readAsString();
  final configuredPage = originalPage.replaceFirst(
    "Heading(1, 'Welcome to Sparrow Kit'),",
    "Heading(1, const String.fromEnvironment('CLI_SMOKE_TITLE', "
        "defaultValue: 'Welcome to Sparrow Kit')),",
  );
  if (configuredPage == originalPage) {
    throw StateError(
        'Generated page template no longer matches the smoke test.');
  }
  await pageFile.writeAsString(configuredPage);

  final siteFile = File(_join(project.path, 'server', 'site.dart'));
  final originalSite = await siteFile.readAsString();
  final configuredSite = originalSite.replaceFirst(
    "title: 'Sparrow Kit app',",
    "title: const String.fromEnvironment('CLI_SMOKE_TITLE', "
        "defaultValue: 'Sparrow Kit app'),",
  );
  if (configuredSite == originalSite) {
    throw StateError(
        'Generated server template no longer matches the smoke test.');
  }
  final nestedSite = configuredSite.replaceFirst(
    "      ),\n    ],\n    outputDirectory: arguments.first,",
    """      ),
      StaticPage(
        path: '/nested/page',
        component: UiPage(() => buildHomePage(Signal<int>(0))),
        metadata: HeadMetadata(title: 'Nested page'),
      ),
    ],
    outputDirectory: arguments.first,""",
  );
  if (nestedSite == configuredSite) {
    throw StateError(
      'Generated server template no longer matches the smoke test.',
    );
  }
  await siteFile.writeAsString(nestedSite);

  const buildTitle = 'Sparrow "CLI"; \$title = safe';
  final staleFile = File(_join(output.path, 'stale-output.txt'));
  await staleFile.writeAsString('must be removed');
  final configuredBuild = await _runCli(
    project,
    ['build', 'web', '--define', 'CLI_SMOKE_TITLE=$buildTitle'],
  );
  _expectExit(configuredBuild, 0, 'build with compile-time define');

  final configuredHtml =
      await File(_join(output.path, 'index.html')).readAsString();
  final compiledClient =
      await File(_join(output.path, 'main.dart.js')).readAsString();
  if (!configuredHtml.contains('<title>$buildTitle</title>') ||
      !configuredHtml.contains(buildTitle) ||
      !compiledClient.contains('Sparrow') ||
      await File('${_join(output.path, 'main.dart.js')}.map').exists() ||
      await File('${_join(output.path, 'main.dart.js')}.deps').exists() ||
      compiledClient.contains('sourceMappingURL') ||
      await staleFile.exists()) {
    throw StateError(
      'Compile-time define, production artifacts, or stale-output replacement failed.',
    );
  }
  final nestedHtml = await File(
    _join(output.path, 'nested', 'page', 'index.html'),
  ).readAsString();
  if (!nestedHtml.contains('<title>Nested page</title>') ||
      !nestedHtml.contains('src="/main.dart.js"')) {
    throw StateError(
      'Nested SSG output did not retain its page metadata and root asset path.',
    );
  }
  await _verifyStaticOutput(output, buildTitle);
  await _expectNoBuildTemporaryDirectories(output);

  final unknownBuildOption = await _runCli(
    project,
    ['build', 'web', '--unknown'],
  );
  _expectExit(unknownBuildOption, 64, 'invalid build option');
  if (!unknownBuildOption.stderr
      .toString()
      .contains('Unknown build option "--unknown"')) {
    throw StateError('Invalid build option did not produce actionable output.');
  }

  final invalidDevPort = await _runCli(
    project,
    ['dev', '--port', '0'],
  );
  _expectExit(invalidDevPort, 64, 'invalid development server port');
  if (!invalidDevPort.stderr
      .toString()
      .contains('Port must be between 1 and 65535')) {
    throw StateError('Invalid dev port did not produce actionable output.');
  }

  final duplicateDefine = await _runCli(
    project,
    [
      'build',
      'web',
      '--define',
      'DUPLICATE=first',
      '--define',
      'DUPLICATE=second',
    ],
  );
  _expectExit(duplicateDefine, 64, 'duplicate build define');

  final originalConfig = await configFile.readAsString();
  final unsafeConfig = jsonDecode(originalConfig) as Map<String, dynamic>;
  (unsafeConfig['web'] as Map<String, dynamic>)['output'] = '../outside';
  await configFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(unsafeConfig),
  );
  final invalidOutput = await _runCli(project, ['build', 'web']);
  _expectExit(invalidOutput, 1, 'unsafe output directory');
  if (!invalidOutput.stderr.toString().contains('safe project-relative path') ||
      await File(_join(output.path, 'index.html')).readAsString() !=
          configuredHtml) {
    throw StateError(
      'Invalid output configuration lacked a diagnostic or changed prior output.',
    );
  }
  await configFile.writeAsString(originalConfig);

  final missingEntryConfig = jsonDecode(originalConfig) as Map<String, dynamic>;
  (missingEntryConfig['web'] as Map<String, dynamic>)['client'] =
      'web/missing.dart';
  await configFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(missingEntryConfig),
  );
  final missingEntry = await _runCli(project, ['build', 'web']);
  _expectExit(missingEntry, 1, 'missing client entry');
  if (!missingEntry.stderr
          .toString()
          .contains('Client entry point not found') ||
      await File(_join(output.path, 'index.html')).readAsString() !=
          configuredHtml) {
    throw StateError(
      'Missing entry point lacked a diagnostic or changed previous output.',
    );
  }
  await configFile.writeAsString(originalConfig);

  final previousHtml = configuredHtml;
  final previousClient = compiledClient;
  await siteFile.writeAsString('''
import 'dart:io';

void main() {
  stderr.writeln('intentional CLI build failure');
  exit(23);
}
''');
  final failedBuild = await _runCli(project, ['build', 'web']);
  _expectExit(failedBuild, 23, 'failed build');
  if (!failedBuild.stderr
          .toString()
          .contains('intentional CLI build failure') ||
      await File(_join(output.path, 'index.html')).readAsString() !=
          previousHtml ||
      await File(_join(output.path, 'main.dart.js')).readAsString() !=
          previousClient) {
    throw StateError(
      'Failed build hid its diagnostic or damaged the previous successful output.',
    );
  }
  await _expectNoBuildTemporaryDirectories(output);

  await siteFile.writeAsString(nestedSite);
  await _verifyDevServer(project, buildTitle);
  stdout.writeln(
    'Sparrow CLI project, build, define, failure, and dev workflow passed.',
  );
}

Future<void> _verifyDevServer(
  Directory project,
  String expectedTitle,
) async {
  final reservation = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = reservation.port;
  await reservation.close();

  final process = await Process.start(
    Platform.resolvedExecutable,
    [
      'run',
      'sparrow_cli',
      'dev',
      '--host',
      '127.0.0.1',
      '--port',
      '$port',
      '--define',
      'CLI_SMOKE_TITLE=$expectedTitle',
    ],
    workingDirectory: project.path,
  );
  final stdoutText = StringBuffer();
  final stderrText = StringBuffer();
  process.stdout.transform(utf8.decoder).listen(stdoutText.write);
  process.stderr.transform(utf8.decoder).listen(stderrText.write);
  var processFinished = false;
  var processExitCode = -1;
  process.exitCode.then((code) {
    processFinished = true;
    processExitCode = code;
  });

  final client = HttpClient();
  var clientClosed = false;
  var stopped = false;
  try {
    String? body;
    for (var attempt = 0; attempt < 60; attempt++) {
      if (processFinished) {
        throw StateError(
          'Development server exited before readiness '
          '($processExitCode).\n'
          '${stdoutText.toString()}${stderrText.toString()}',
        );
      }
      try {
        final request = await client
            .getUrl(Uri.parse('http://127.0.0.1:$port/'))
            .timeout(const Duration(milliseconds: 300));
        final response =
            await request.close().timeout(const Duration(milliseconds: 500));
        final responseBody = await utf8.decoder.bind(response).join();
        if (response.statusCode == HttpStatus.ok) {
          body = responseBody;
          break;
        }
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    if (body == null ||
        !body.contains('<title>$expectedTitle</title>') ||
        !body.contains('EventSource("/__sparrow/events")')) {
      throw StateError(
        'Development server did not serve its SSR page and live-reload hook.\n'
        '${stdoutText.toString()}${stderrText.toString()}',
      );
    }

    final developmentOutput = _join(project.path, 'build', 'sparrow_dev');
    if (!await File(_join(developmentOutput, 'main.dart.js.map')).exists() ||
        !await File(_join(developmentOutput, 'smoke-source.js.map')).exists()) {
      throw StateError(
        'Development output should retain JavaScript source maps.',
      );
    }

    await File(_join(project.path, 'web', 'smoke-asset.txt'))
        .writeAsString('updated static asset');
    await _waitForText(
      stdoutText,
      'Changes detected. Rebuilding...',
      const Duration(seconds: 15),
    );

    client.close(force: true);
    clientClosed = true;
    final exitCodeFuture = process.exitCode;
    if (Platform.isWindows) {
      // Process.kill ignores its signal argument on Windows; closing the pipe
      // exercises graceful cleanup without pretending to simulate Ctrl+C.
      await process.stdin.close();
    } else if (!process.kill(ProcessSignal.sigint)) {
      throw StateError('Could not deliver SIGINT to the development server.');
    }
    late final int exitCode;
    try {
      exitCode = await exitCodeFuture.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw StateError(
        'Development server did not exit after graceful shutdown.\n'
        '${stdoutText.toString()}${stderrText.toString()}',
      );
    }
    stopped = true;
    if (exitCode != 0) {
      throw StateError(
        'Development server did not shut down cleanly ($exitCode).\n'
        '${stdoutText.toString()}${stderrText.toString()}',
      );
    }
    if (!stdoutText.toString().contains('Sparrow dev server stopped.')) {
      throw StateError(
        'Development server exited without completing graceful cleanup.\n'
        '${stdoutText.toString()}${stderrText.toString()}',
      );
    }
    if (!stdoutText.toString().contains('Rebuilt successfully.')) {
      throw StateError(
        'Shutdown did not wait for the active rebuild to finish.\n'
        '${stdoutText.toString()}${stderrText.toString()}',
      );
    }
    if (!await _waitForServerShutdown(port)) {
      throw StateError('Development server still accepts requests after exit.');
    }
  } finally {
    if (!clientClosed) client.close(force: true);
    if (!stopped) {
      if (!processFinished) process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    }
  }
}

Future<void> _waitForText(
  StringBuffer output,
  String expected,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (output.toString().contains(expected)) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Timed out waiting for "$expected".\n${output.toString()}');
}

Future<void> _verifyStaticOutput(
  Directory output,
  String expectedTitle,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen((request) async {
    final segments =
        request.uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.any((segment) => segment == '.' || segment == '..')) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    var target = Directory(output.path);
    for (final segment in segments) {
      target = Directory(_join(target.path, segment));
    }
    var file = File(target.path);
    if (await target.exists()) {
      file = File(_join(target.path, 'index.html'));
    }
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = switch (file.path.split('.').last) {
        'html' => ContentType.html,
        'js' => ContentType('application', 'javascript'),
        'txt' => ContentType.text,
        _ => ContentType.binary,
      };
    await request.response.addStream(file.openRead());
    await request.response.close();
  });
  final client = HttpClient();
  final baseUri = Uri(
    scheme: 'http',
    host: server.address.address,
    port: server.port,
  );
  try {
    final nestedResponse =
        await client.getUrl(baseUri.resolve('/nested/page/'));
    final nested = await nestedResponse.close();
    final nestedHtml = await utf8.decoder.bind(nested).join();
    final scriptResponse =
        await client.getUrl(baseUri.resolve('/main.dart.js'));
    final script = await scriptResponse.close();
    final scriptText = await utf8.decoder.bind(script).join();
    final assetResponse =
        await client.getUrl(baseUri.resolve('/smoke-asset.txt'));
    final asset = await assetResponse.close();
    final assetText = await utf8.decoder.bind(asset).join();
    if (nested.statusCode != HttpStatus.ok ||
        !nestedHtml.contains('<title>Nested page</title>') ||
        !nestedHtml.contains('src="/main.dart.js"') ||
        script.statusCode != HttpStatus.ok ||
        !scriptText.contains('Sparrow') ||
        asset.statusCode != HttpStatus.ok ||
        assetText != 'static asset') {
      throw StateError(
        'Static serving failed for generated nested HTML, JavaScript, or assets.',
      );
    }
  } finally {
    client.close(force: true);
    await subscription.cancel();
    await server.close(force: true);
  }
}

Future<bool> _waitForServerShutdown(int port) async {
  final client = HttpClient();
  try {
    for (var attempt = 0; attempt < 30; attempt++) {
      try {
        final request = await client
            .getUrl(Uri.parse('http://127.0.0.1:$port/'))
            .timeout(const Duration(milliseconds: 300));
        await request.close().timeout(const Duration(milliseconds: 500));
      } on Object {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<void> _expectNoBuildTemporaryDirectories(Directory output) async {
  final outputName = output.path.split(Platform.pathSeparator).last;
  await for (final entity in output.parent.list(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('$outputName.sparrow-stage-') ||
        name.startsWith('.sparrow-output-swap-')) {
      throw StateError('Build left temporary output at ${entity.path}.');
    }
  }
}

Future<ProcessResult> _runCli(
  Directory project,
  List<String> arguments,
) =>
    _runDart(
      ['run', 'sparrow_cli', ...arguments],
      workingDirectory: project,
    );

Future<ProcessResult> _runDart(
  List<String> arguments, {
  required Directory workingDirectory,
}) =>
    Process.run(
      Platform.resolvedExecutable,
      arguments,
      workingDirectory: workingDirectory.path,
    );

void _expectExit(ProcessResult result, int expected, String description) {
  if (result.exitCode != expected) {
    throw StateError(
      '$description returned ${result.exitCode}, expected $expected.\n'
      'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
  }
}

String _join(
  String first, [
  String? second,
  String? third,
  String? fourth,
  String? fifth,
]) {
  final segments = [
    first,
    if (second != null) second,
    if (third != null) third,
    if (fourth != null) fourth,
    if (fifth != null) fifth,
  ];
  return segments.join(Platform.pathSeparator);
}
