import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<int> buildWeb(
  Directory project, {
  String? outputOverride,
  bool development = false,
  Map<String, String> defines = const {},
}) async {
  final configFile = File(p.join(project.path, 'sparrow.json'));
  if (!await configFile.exists()) {
    throw FileSystemException(
      'Missing project configuration. Run "sparrow init" first.',
      configFile.path,
    );
  }

  final config = _readWebConfig(await configFile.readAsString());
  final client = _projectFile(project, config.client);
  final server = _projectFile(project, config.server);
  if (!await client.exists()) {
    throw FileSystemException('Client entry point not found', client.path);
  }
  if (!await server.exists()) {
    throw FileSystemException('Server entry point not found', server.path);
  }
  final defineArguments = _defineArguments(defines);

  final analysis = await _runDart(
    ['analyze', client.path, server.path],
    project,
  );
  if (analysis != 0) return analysis;

  final output = _projectDirectory(
    project,
    _safeRelativePath(outputOverride ?? config.output),
  );
  final webAssets = Directory(p.join(project.path, 'web'));
  await _validateOutputDirectory(project, output, webAssets);
  final staging = Directory(
    '${output.path}.sparrow-stage-$pid-${DateTime.now().microsecondsSinceEpoch}',
  );
  await _validateOutputDirectory(project, staging, webAssets);
  await staging.parent.create(recursive: true);
  await staging.create();
  var published = false;
  final clientOutput = _safeRelativePath(config.clientOutput);
  final clientScript = '/${clientOutput.replaceAll('\\', '/')}';
  try {
    await _copyWebAssets(
      webAssets,
      staging,
      development: development,
    );

    final serverBuild = await _runDart(
      [...defineArguments, 'run', server.path, staging.path, clientScript],
      project,
    );
    if (serverBuild != 0) return serverBuild;

    final compiledClient =
        File(p.joinAll([staging.path, ...p.split(clientOutput)]));
    await compiledClient.parent.create(recursive: true);
    final clientBuild = await _runDart(
      [
        'compile',
        'js',
        ...defineArguments,
        client.path,
        development ? '-O0' : '-O2',
        if (!development) '--no-source-maps',
        '-o',
        compiledClient.path,
      ],
      project,
    );
    if (clientBuild != 0) return clientBuild;
    if (!development) {
      final compilerDependencies = File('${compiledClient.path}.deps');
      if (await compilerDependencies.exists()) {
        await compilerDependencies.delete();
      }
    }

    await _publishOutput(staging, output);
    published = true;
    if (!development) {
      stdout.writeln('Built Sparrow Kit web app to ${output.path}');
    }
    return 0;
  } finally {
    if (!published && await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }
}

Future<int> runDevServer(
  Directory project, {
  required String host,
  required int port,
  Map<String, String> defines = const {},
}) async {
  final outputPath = 'build/sparrow_dev';
  final initialBuild = await buildWeb(
    project,
    outputOverride: outputPath,
    development: true,
    defines: defines,
  );
  if (initialBuild != 0) return initialBuild;

  final output = _projectDirectory(project, outputPath);
  final server = await HttpServer.bind(host, port);
  final clients = <HttpResponse>{};
  final serverSubscription = server.listen(
    (request) => unawaited(_serveRequest(request, output, clients)),
    onError: (Object error, StackTrace stackTrace) {
      stderr
        ..writeln('Dev server error: $error')
        ..writeln(stackTrace);
    },
  );

  final config = _readWebConfig(
    await File(p.join(project.path, 'sparrow.json')).readAsString(),
  );
  final watchedDirectories = <String>{
    'lib',
    'web',
    'server',
    'bin',
    p.dirname(config.client),
    p.dirname(config.server),
  };
  Timer? debounce;
  var building = false;
  var rebuildQueued = false;
  var shuttingDown = false;
  final stopped = Completer<void>();
  Future<void>? activeRebuild;

  void requestShutdown() {
    if (shuttingDown) return;
    shuttingDown = true;
    rebuildQueued = false;
    stopped.complete();
  }

  Future<void> rebuild() async {
    if (building) {
      rebuildQueued = true;
      return;
    }
    building = true;
    try {
      do {
        rebuildQueued = false;
        stdout.writeln('Changes detected. Rebuilding...');
        try {
          final result = await buildWeb(
            project,
            outputOverride: outputPath,
            development: true,
            defines: defines,
          );
          if (result == 0) {
            if (!shuttingDown) await _notifyReloadClients(clients);
            stdout.writeln('Rebuilt successfully.');
          } else {
            stderr.writeln('Rebuild failed with exit code $result.');
          }
        } on Object catch (error, stackTrace) {
          stderr
            ..writeln('Rebuild failed: $error')
            ..writeln(stackTrace);
        }
      } while (rebuildQueued && !shuttingDown);
    } finally {
      building = false;
    }
  }

  void startRebuild() {
    if (shuttingDown) return;
    if (building) {
      rebuildQueued = true;
      return;
    }
    activeRebuild = rebuild().catchError((Object error, StackTrace stackTrace) {
      stderr
        ..writeln('Rebuild failed: $error')
        ..writeln(stackTrace);
    });
  }

  void scheduleBuild() {
    if (shuttingDown) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      startRebuild();
    });
  }

  final subscriptions = <StreamSubscription<Object?>>[];
  for (final relative in watchedDirectories) {
    if (relative == '.' || relative.isEmpty) continue;
    final directory = _projectDirectory(project, relative);
    if (!await directory.exists()) continue;
    subscriptions.add(
      directory.watch(recursive: true).listen((_) => scheduleBuild(),
          onError: (Object error) {
        stderr.writeln('Unable to watch ${directory.path}: $error');
      }),
    );
  }
  final configFile = File(p.join(project.path, 'sparrow.json'));
  subscriptions.add(
    configFile.watch().listen((_) => scheduleBuild(), onError: (Object error) {
      stderr.writeln('Unable to watch ${configFile.path}: $error');
    }),
  );

  stdout.writeln('Sparrow dev server running at http://$host:$port');
  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen((_) => requestShutdown()),
    if (!Platform.isWindows)
      ProcessSignal.sigterm.watch().listen((_) => requestShutdown()),
  ];
  final stdinSubscription = stdin.hasTerminal
      ? null
      : stdin.listen(
          (_) {},
          onDone: requestShutdown,
          onError: (Object error, StackTrace stackTrace) {
            stderr
              ..writeln('Dev server stdin error: $error')
              ..writeln(stackTrace);
            requestShutdown();
          },
        );

  try {
    await stopped.future;
  } finally {
    debounce?.cancel();
    try {
      if (stdinSubscription != null) await stdinSubscription.cancel();
    } finally {
      try {
        await server.close(force: true);
      } finally {
        try {
          await serverSubscription.cancel();
        } finally {
          try {
            for (final subscription in subscriptions) {
              await subscription.cancel();
            }
          } finally {
            try {
              final rebuild = activeRebuild;
              if (rebuild != null) await rebuild;
            } finally {
              for (final subscription in signalSubscriptions) {
                await subscription.cancel();
              }
            }
          }
        }
      }
    }
  }
  stdout.writeln('Sparrow dev server stopped.');
  return 0;
}

_WebConfig _readWebConfig(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('sparrow.json must contain a JSON object.');
  }
  final web = decoded['web'];
  if (web is! Map<String, dynamic>) {
    throw const FormatException('sparrow.json must define a "web" object.');
  }

  String requiredString(String key, {String? defaultValue}) {
    final value = web[key] ?? defaultValue;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'sparrow.json web.$key must be a non-empty string.',
      );
    }
    return value;
  }

  return _WebConfig(
    client: _safeRelativePath(requiredString('client')),
    server: _safeRelativePath(requiredString('server')),
    output:
        _safeRelativePath(requiredString('output', defaultValue: 'build/web')),
    clientOutput: _safeRelativePath(
      requiredString('clientOutput', defaultValue: 'main.dart.js'),
    ),
  );
}

String _safeRelativePath(String value) {
  final normalized = value.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized.split('/').any(
          (segment) => segment == '.' || segment == '..' || segment.isEmpty)) {
    throw FormatException('Expected a safe project-relative path: "$value".');
  }
  return normalized;
}

Future<void> _validateOutputDirectory(
  Directory project,
  Directory output,
  Directory webAssets,
) async {
  final outputPath = p.normalize(p.absolute(output.path));
  final projectPath = p.normalize(p.absolute(project.path));
  final protectedDirectories = [
    webAssets,
    for (final name in const ['lib', 'bin', 'server'])
      Directory(p.join(project.path, name)),
  ];

  for (final protectedDirectory in protectedDirectories) {
    final protectedPath = p.normalize(p.absolute(protectedDirectory.path));
    if (outputPath == protectedPath ||
        p.isWithin(protectedPath, outputPath) ||
        p.isWithin(outputPath, protectedPath)) {
      throw ArgumentError.value(
        output.path,
        'output',
        'Build output cannot overlap project source directories.',
      );
    }
  }

  var currentPath = projectPath;
  for (final segment in p.split(p.relative(outputPath, from: projectPath))) {
    currentPath = p.join(currentPath, segment);
    if (await FileSystemEntity.type(
          currentPath,
          followLinks: false,
        ) ==
        FileSystemEntityType.link) {
      throw ArgumentError.value(
        output.path,
        'output',
        'Build output cannot traverse a symbolic link.',
      );
    }
  }

  if (outputPath == projectPath) {
    throw ArgumentError.value(
      output.path,
      'output',
      'Build output cannot be the project directory.',
    );
  }
}

File _projectFile(Directory project, String relativePath) =>
    File(p.joinAll([project.path, ...p.split(relativePath)]));

Directory _projectDirectory(Directory project, String relativePath) =>
    Directory(p.joinAll([project.path, ...p.split(relativePath)]));

Future<void> _copyWebAssets(
  Directory source,
  Directory output, {
  required bool development,
}) async {
  if (!await source.exists()) return;
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final path = entity.path.toLowerCase();
    if (entity is! File ||
        path.endsWith('.dart') ||
        (!development && path.endsWith('.map'))) {
      continue;
    }
    final relativePath = p.relative(entity.path, from: source.path);
    final target = File(p.join(output.path, relativePath));
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
  }
}

Future<int> _runDart(List<String> arguments, Directory project) async {
  final result = await Process.run(
    'dart',
    arguments,
    workingDirectory: project.path,
  );
  final stdoutText = result.stdout.toString();
  final stderrText = result.stderr.toString();
  if (stdoutText.isNotEmpty) stdout.write(stdoutText);
  if (stderrText.isNotEmpty) stderr.write(stderrText);
  return result.exitCode;
}

List<String> _defineArguments(Map<String, String> defines) {
  final entries = defines.entries.toList()
    ..sort((first, second) => first.key.compareTo(second.key));
  for (final entry in entries) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$').hasMatch(entry.key) ||
        entry.key.contains('\u0000') ||
        entry.value.contains('\u0000')) {
      throw ArgumentError(
        'Invalid build define "${entry.key}": names must start with a letter '
        'or underscore and contain only letters, digits, ".", "_" or "-"; '
        'values cannot contain NUL.',
      );
    }
  }
  return [
    for (final entry in entries) '--define=${entry.key}=${entry.value}',
  ];
}

Future<void> _publishOutput(Directory staging, Directory output) async {
  await output.parent.create(recursive: true);
  final existingType = await FileSystemEntity.type(
    output.path,
    followLinks: false,
  );
  if (existingType == FileSystemEntityType.file ||
      existingType == FileSystemEntityType.link) {
    throw ArgumentError.value(
      output.path,
      'output',
      'Build output path is occupied by a file or symbolic link.',
    );
  }
  if (existingType != FileSystemEntityType.directory) {
    await staging.rename(output.path);
    return;
  }

  final swapDirectory = await output.parent.createTemp('.sparrow-output-swap-');
  final previousOutput = Directory(p.join(swapDirectory.path, 'previous'));
  var preserveBackup = false;
  try {
    await output.rename(previousOutput.path);
    try {
      await staging.rename(output.path);
    } catch (error, stackTrace) {
      try {
        await previousOutput.rename(output.path);
      } catch (restoreError) {
        preserveBackup = true;
        throw StateError(
          'Publishing the new build failed: $error. The previous output could '
          'not be restored: $restoreError. It remains at ${previousOutput.path}.',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  } finally {
    if (!preserveBackup && await swapDirectory.exists()) {
      await swapDirectory.delete(recursive: true);
    }
  }
}

Future<void> _serveRequest(
  HttpRequest request,
  Directory output,
  Set<HttpResponse> reloadClients,
) async {
  if (request.uri.path == '/__sparrow/events') {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, 'text/event-stream')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.response.write('retry: 1000\n\n');
    await request.response.flush();
    reloadClients.add(request.response);
    unawaited(request.response.done.whenComplete(() {
      reloadClients.remove(request.response);
    }));
    return;
  }

  if (request.method != 'GET' && request.method != 'HEAD') {
    request.response
      ..statusCode = HttpStatus.methodNotAllowed
      ..headers.set(HttpHeaders.allowHeader, 'GET, HEAD')
      ..close();
    return;
  }

  final segments =
      request.uri.pathSegments.where((segment) => segment.isNotEmpty);
  if (segments.any(
    (segment) =>
        segment == '.' ||
        segment == '..' ||
        segment.contains(r'\') ||
        segment.contains(':'),
  )) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..close();
    return;
  }
  final relative = p.joinAll(segments);
  final candidate = p.normalize(p.join(output.path, relative));
  if (candidate != output.path && !p.isWithin(output.path, candidate)) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..close();
    return;
  }

  var file = File(candidate);
  if (!await file.exists()) {
    file = File(p.join(candidate, 'index.html'));
  }
  if (!await file.exists()) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
    return;
  }

  try {
    final html = p.extension(file.path).toLowerCase() == '.html';
    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentType = _contentType(file.path);
    if (request.method == 'HEAD') {
      request.response.contentLength = await file.length();
      await request.response.close();
      return;
    }
    if (html) {
      var source = await file.readAsString();
      const liveReload =
          '<script>new EventSource("/__sparrow/events").onmessage=()=>location.reload();</script>';
      final bodyEnd = source.toLowerCase().lastIndexOf('</body>');
      source = bodyEnd < 0
          ? '$source$liveReload'
          : '${source.substring(0, bodyEnd)}$liveReload${source.substring(bodyEnd)}';
      request.response.write(source);
    } else {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  } on FileSystemException catch (error) {
    stderr.writeln('Unable to serve ${file.path}: $error');
    await request.response.close();
  }
}

ContentType _contentType(String filePath) {
  switch (p.extension(filePath).toLowerCase()) {
    case '.html':
      return ContentType.html;
    case '.js':
      return ContentType('application', 'javascript');
    case '.css':
      return ContentType('text', 'css', charset: 'utf-8');
    case '.json':
      return ContentType.json;
    case '.svg':
      return ContentType('image', 'svg+xml');
    case '.png':
      return ContentType('image', 'png');
    case '.jpg':
    case '.jpeg':
      return ContentType('image', 'jpeg');
    case '.ico':
      return ContentType('image', 'x-icon');
    default:
      return ContentType.binary;
  }
}

Future<void> _notifyReloadClients(Set<HttpResponse> clients) async {
  for (final client in clients.toList()) {
    try {
      client.write('data: reload\n\n');
      await client.flush();
    } on IOException {
      clients.remove(client);
    }
  }
}

class _WebConfig {
  const _WebConfig({
    required this.client,
    required this.server,
    required this.output,
    required this.clientOutput,
  });

  final String client;
  final String server;
  final String output;
  final String clientOutput;
}
