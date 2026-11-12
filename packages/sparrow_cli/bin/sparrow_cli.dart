import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await runSparrowCli(arguments);
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('sparrow_cli: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}

Future<int> runSparrowCli(List<String> arguments) async {
  if (arguments.length != 2 ||
      arguments[0] != 'build' ||
      arguments[1] != 'web') {
    stderr.writeln('Usage: sparrow_cli build web');
    return 64;
  }

  final projectDirectory = Directory.current;
  final configFile = File(
    '${projectDirectory.path}${Platform.pathSeparator}sparrow.json',
  );
  if (!await configFile.exists()) {
    stderr.writeln('Missing project configuration: ${configFile.path}');
    return 2;
  }

  final decoded = jsonDecode(await configFile.readAsString());
  final config = _readWebConfig(decoded);
  final client = _projectFile(projectDirectory, config.client);
  final server = _projectFile(projectDirectory, config.server);
  if (!await client.exists()) {
    throw FileSystemException('Client entry point not found', client.path);
  }
  if (!await server.exists()) {
    throw FileSystemException('Server entry point not found', server.path);
  }

  final analysis = await Process.run(
    'dart',
    ['analyze', client.path, server.path],
    workingDirectory: projectDirectory.path,
    runInShell: true,
  );
  _writeProcessOutput(analysis);
  if (analysis.exitCode != 0) return analysis.exitCode;

  final output = _projectDirectory(projectDirectory, config.output);
  final webAssets = Directory(
    '${projectDirectory.path}${Platform.pathSeparator}web',
  );
  _validateOutputDirectory(output, webAssets);
  await _copyWebAssets(
    webAssets,
    output,
  );

  final clientOutput = _safeRelativePath(config.clientOutput);
  final clientScript = '/${clientOutput.replaceAll('\\', '/')}';
  final serverBuild = await Process.run(
    'dart',
    ['run', server.path, output.path, clientScript],
    workingDirectory: projectDirectory.path,
    runInShell: true,
  );
  _writeProcessOutput(serverBuild);
  if (serverBuild.exitCode != 0) return serverBuild.exitCode;

  final compiledClient = File(
    '${output.path}${Platform.pathSeparator}'
    '${clientOutput.replaceAll('/', Platform.pathSeparator)}',
  );
  await compiledClient.parent.create(recursive: true);
  final clientBuild = await Process.run(
    'dart',
    ['compile', 'js', client.path, '-O2', '-o', compiledClient.path],
    workingDirectory: projectDirectory.path,
    runInShell: true,
  );
  _writeProcessOutput(clientBuild);
  if (clientBuild.exitCode != 0) return clientBuild.exitCode;

  stdout.writeln('Built Sparrow Kit web app to ${output.path}');
  return 0;
}

_WebConfig _readWebConfig(Object? decoded) {
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
          'sparrow.json web.$key must be a non-empty string.');
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

void _validateOutputDirectory(Directory output, Directory webAssets) {
  final outputPath = output.absolute.path.toLowerCase();
  final webPath = webAssets.absolute.path.toLowerCase();
  if (outputPath == webPath ||
      outputPath.startsWith('$webPath${Platform.pathSeparator}')) {
    throw ArgumentError.value(
      output.path,
      'output',
      'Build output cannot be inside the web asset source directory.',
    );
  }
}

File _projectFile(Directory projectDirectory, String relativePath) => File(
      '${projectDirectory.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );

Directory _projectDirectory(Directory projectDirectory, String relativePath) =>
    Directory(
      '${projectDirectory.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );

Future<void> _copyWebAssets(Directory source, Directory output) async {
  if (!await source.exists()) return;
  await output.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is! File || entity.path.toLowerCase().endsWith('.dart'))
      continue;
    final relativePath = entity.path.substring(source.path.length + 1);
    final target = File(
      '${output.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
  }
}

void _writeProcessOutput(ProcessResult result) {
  final stdoutText = result.stdout.toString();
  final stderrText = result.stderr.toString();
  if (stdoutText.isNotEmpty) stdout.write(stdoutText);
  if (stderrText.isNotEmpty) stderr.write(stderrText);
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
