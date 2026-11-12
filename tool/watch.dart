import 'dart:async';
import 'dart:io';

const _compileArguments = [
  'compile',
  'js',
  'apps/web_app/web/main.dart',
  '-O2',
  '-o',
  'apps/web_app/web/main.dart.js',
];
const _compileCommand =
    'dart compile js apps/web_app/web/main.dart -O2 -o apps/web_app/web/main.dart.js';
const _debounceDuration = Duration(milliseconds: 250);

Future<void> main() async {
  final projectRoot = File.fromUri(Platform.script).parent.parent;
  final watchedDirectories = [
    Directory(
      '${projectRoot.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}web_app${Platform.pathSeparator}web',
    ),
    Directory(
      '${projectRoot.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}web_app${Platform.pathSeparator}lib',
    ),
    Directory(
      '${projectRoot.path}${Platform.pathSeparator}packages'
      '${Platform.pathSeparator}sparrow_kit${Platform.pathSeparator}lib',
    ),
  ];

  for (final directory in watchedDirectories) {
    if (!directory.existsSync()) {
      throw FileSystemException(
        'Required watch directory does not exist.',
        directory.path,
      );
    }
  }

  var isCompiling = false;
  var buildQueued = false;
  Timer? debounceTimer;

  Future<void> compile() async {
    if (isCompiling) {
      buildQueued = true;
      return;
    }

    isCompiling = true;
    try {
      do {
        buildQueued = false;
        final stopwatch = Stopwatch()..start();
        stdout.writeln('[watch] Compiling: $_compileCommand');

        try {
          final result = await Process.run(
            'dart',
            _compileArguments,
            workingDirectory: projectRoot.path,
          );
          stopwatch.stop();

          final output = result.stdout.toString().trim();
          if (output.isNotEmpty) stdout.writeln(output);

          final errorOutput = result.stderr.toString().trim();
          if (errorOutput.isNotEmpty) stderr.writeln(errorOutput);

          if (result.exitCode == 0) {
            stdout.writeln(
              '[watch] Compilation succeeded in ${stopwatch.elapsed}.',
            );
          } else {
            stderr.writeln(
              '[watch] Compilation failed with exit code '
              '${result.exitCode} after ${stopwatch.elapsed}.',
            );
          }
        } on ProcessException catch (error) {
          stopwatch.stop();
          stderr.writeln('[watch] Could not start Dart compilation: $error');
          stderr.writeln('[watch] Elapsed: ${stopwatch.elapsed}.');
        }
      } while (buildQueued);
    } finally {
      isCompiling = false;
    }
  }

  void scheduleCompile() {
    debounceTimer?.cancel();
    debounceTimer = Timer(_debounceDuration, () {
      unawaited(compile());
    });
  }

  final subscriptions = <StreamSubscription<FileSystemEvent>>[];
  for (final directory in watchedDirectories) {
    subscriptions.add(
      directory.watch(recursive: true).listen(
        (event) {
          if (event.isDirectory || _isGeneratedOutput(event.path)) return;

          stdout.writeln('[watch] Change detected: ${event.path}');
          scheduleCompile();
        },
        onError: (Object error) {
          stderr.writeln('[watch] Error watching ${directory.path}: $error');
        },
      ),
    );
  }

  stdout.writeln(
    '[watch] Watching recursively: ${watchedDirectories.map((directory) => directory.path).join(', ')}',
  );
  await compile();
}

bool _isGeneratedOutput(String path) {
  final fileName = path.replaceAll(r'\', '/').split('/').last.toLowerCase();
  return fileName == 'main.dart.js' ||
      fileName.startsWith('main.dart.js.') ||
      fileName == 'ssr_client.dart.js' ||
      fileName.startsWith('ssr_client.dart.js.');
}
