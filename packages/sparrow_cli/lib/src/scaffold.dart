import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

const _repositoryUrl = 'https://github.com/MgThiha-Coding/sparrow_kit.git';

Future<void> scaffoldProject(String targetPath) async {
  final requested = Directory(p.absolute(targetPath));
  await requested.create(recursive: true);
  final project = await _resolveAppDirectory(requested, createIfMissing: true);
  final manifest = File(p.join(project.path, 'pubspec.yaml'));

  if (!await manifest.exists()) {
    final name = _packageName(p.basename(project.path));
    final dependencies = _dependencyReferences(project);
    await manifest.writeAsString('''
name: $name
publish_to: none

environment:
  sdk: '>=3.6.0 <4.0.0'

dependencies:
  sparrow_kit:
${_yamlDependency(dependencies.kit, 4)}

dev_dependencies:
  sparrow_cli:
${_yamlDependency(dependencies.cli, 4)}
''');
  } else {
    await _ensureCliDependencies(project, manifest);
  }

  final name = await _readPackageName(manifest);
  final created = await _writeProjectFiles(project, name);
  stdout
    ..writeln('Initialized Sparrow Kit in ${project.path}.')
    ..writeln(created.isEmpty
        ? 'Existing project files were left unchanged.'
        : 'Created: ${created.join(', ')}')
    ..writeln('Next: dart pub get, then sparrow dev.');
}

Future<void> addWebToProject(String targetPath) async {
  final requested = Directory(p.absolute(targetPath));
  if (!await requested.exists()) {
    throw FileSystemException('App directory does not exist', requested.path);
  }
  final project = await _resolveAppDirectory(requested);
  final manifest = File(p.join(project.path, 'pubspec.yaml'));
  if (!await manifest.exists()) {
    throw FileSystemException(
        'No pubspec.yaml found in app directory', manifest.path);
  }

  await _ensureCliDependencies(project, manifest);
  final name = await _readPackageName(manifest);
  final created = await _writeProjectFiles(project, name);
  stdout
    ..writeln('Added Sparrow Kit web support to ${project.path}.')
    ..writeln(created.isEmpty
        ? 'Existing project files were left unchanged.'
        : 'Created: ${created.join(', ')}')
    ..writeln('Next: dart pub get, then sparrow dev.');
}

Future<List<String>> _writeProjectFiles(
  Directory project,
  String packageName,
) async {
  final files = <String, String>{
    'sparrow.json': '''
{
  "web": {
    "client": "web/main.dart",
    "server": "server/site.dart",
    "output": "build/web",
    "clientOutput": "main.dart.js"
  }
}
''',
    'web/index.html': '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sparrow Kit app</title>
  </head>
  <body>
    <div id="app"></div>
    <script defer src="main.dart.js"></script>
  </body>
</html>
''',
    'lib/home_page.dart': '''
import 'package:sparrow_kit/reactivity.dart';
import 'package:sparrow_kit/ui.dart';

UiNode buildHomePage(Signal<int> count) => Container(
      padding: 24,
      child: Column(
        gap: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Welcome to Sparrow Kit'),
          Text.bind('home_count', count),
          Button(
            label: 'Increment',
            onPressed: (_) => count.value++,
          ),
        ],
      ),
    );
''',
    'web/main.dart': '''
import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:$packageName/home_page.dart';

void main() => hydrateUiApp((state) {
      final count = state.signal<int>('home_count', fallback: 0);
      return buildHomePage(count);
    });
''',
    'server/site.dart': '''
import 'package:sparrow_kit/server.dart';
import 'package:$packageName/home_page.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError(
      'Expected the output directory and client script from sparrow.',
    );
  }

  await StaticSiteGenerator(clientScript: arguments[1]).generate(
    [
      StaticPage(
        path: '/',
        component: UiPage(() => buildHomePage(Signal<int>(0))),
        metadata: HeadMetadata(
          title: 'Sparrow Kit app',
          description: 'A server-rendered Dart web app.',
        ),
      ),
    ],
    outputDirectory: arguments.first,
  );
}
''',
  };
  final created = <String>[];
  for (final entry in files.entries) {
    final file = File(p.join(project.path, entry.key));
    if (await file.exists()) continue;
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value.trimLeft());
    created.add(entry.key);
  }
  return created;
}

Future<void> _ensureCliDependencies(
  Directory project,
  File manifest,
) async {
  final source = await manifest.readAsString();
  final parsed = loadYaml(source);
  if (parsed is! YamlMap) {
    throw FormatException('${manifest.path} must contain a YAML mapping.');
  }

  final references = _dependencyReferences(project);
  var editor = YamlEditor(source);
  editor = _ensureDependency(
    editor,
    parsed,
    'dependencies',
    'sparrow_kit',
    references.kit,
  );
  final updated = loadYaml(editor.toString());
  if (updated is! YamlMap) {
    throw FormatException('${manifest.path} must contain a YAML mapping.');
  }
  editor = _ensureDependency(
    editor,
    updated,
    'dev_dependencies',
    'sparrow_cli',
    references.cli,
  );
  await manifest.writeAsString(editor.toString());
}

YamlEditor _ensureDependency(
  YamlEditor editor,
  YamlMap manifest,
  String section,
  String package,
  Map<String, Object> reference,
) {
  final dependencies = manifest[section];
  if (dependencies == null) {
    editor.update([section], {package: reference});
    return editor;
  }
  if (dependencies is! YamlMap) {
    throw FormatException('pubspec.yaml "$section" must be a mapping.');
  }
  if (dependencies.containsKey(package)) return editor;
  editor.update([section, package], reference);
  return editor;
}

Future<String> _readPackageName(File manifest) async {
  final parsed = loadYaml(await manifest.readAsString());
  if (parsed is! YamlMap || parsed['name'] is! String) {
    throw FormatException(
      '${manifest.path} must define a valid package name.',
    );
  }
  final name = parsed['name'] as String;
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    throw FormatException(
      '${manifest.path} has an invalid Dart package name "$name".',
    );
  }
  return name;
}

Future<Directory> _resolveAppDirectory(
  Directory requested, {
  bool createIfMissing = false,
}) async {
  final manifest = File(p.join(requested.path, 'pubspec.yaml'));
  if (!await manifest.exists()) {
    if (createIfMissing) return requested;
    throw FileSystemException(
      'No pubspec.yaml found. Run the command from an app package.',
      manifest.path,
    );
  }

  final parsed = loadYaml(await manifest.readAsString());
  if (parsed is! YamlMap) {
    throw FormatException('${manifest.path} must contain a YAML mapping.');
  }
  final workspace = parsed['workspace'];
  if (workspace is! YamlList) return requested;

  final candidates = <({Directory directory, int score})>[];
  for (final member in workspace.whereType<String>()) {
    final normalized = p.normalize(member.replaceAll('\\', p.separator));
    if (p.isAbsolute(normalized) || p.isWithin('..', normalized)) continue;
    final candidate = Directory(p.join(requested.path, normalized));
    final candidateManifest = File(p.join(candidate.path, 'pubspec.yaml'));
    if (!await candidateManifest.exists()) continue;
    final candidateYaml = loadYaml(await candidateManifest.readAsString());
    if (candidateYaml is! YamlMap) continue;

    final memberPath = p.split(normalized);
    if (memberPath.isEmpty || memberPath.first != 'apps') continue;
    final packageName =
        candidateYaml['name'] is String ? candidateYaml['name'] as String : '';
    final dependencies = [
      candidateYaml['dependencies'],
      candidateYaml['dev_dependencies'],
    ];
    final hasFlutter = dependencies.any(
      (section) => section is YamlMap && section.containsKey('flutter'),
    );
    final mobileName =
        '${memberPath.last} $packageName'.toLowerCase().contains('android') ||
            '${memberPath.last} $packageName'.toLowerCase().contains('mobile');
    final score = (hasFlutter ? 100 : 0) + (mobileName ? 50 : 0);
    candidates.add((directory: candidate, score: score));
  }

  if (candidates.length == 1) return candidates.single.directory;
  final ranked = candidates.where((candidate) => candidate.score > 0).toList()
    ..sort((left, right) => right.score.compareTo(left.score));
  if (ranked.isNotEmpty &&
      (ranked.length == 1 || ranked[0].score > ranked[1].score)) {
    return ranked.first.directory;
  }
  throw ArgumentError(
    'Workspace root detected at ${requested.path}, but no unique app package '
    'could be selected. Pass an app directory, for example '
    '"sparrow add web apps/mobile".',
  );
}

({Map<String, Object> kit, Map<String, Object> cli}) _dependencyReferences(
  Directory project,
) {
  final workspaceRoot = _findWorkspaceRoot(project);
  if (workspaceRoot != null) {
    Map<String, Object> localReference(String package) => {
          'path': p
              .relative(
                p.join(workspaceRoot.path, 'packages', package),
                from: project.path,
              )
              .replaceAll(p.separator, '/'),
        };
    return (
      kit: localReference('sparrow_kit'),
      cli: localReference('sparrow_cli'),
    );
  }

  Map<String, Object> gitReference(String package) => {
        'git': {
          'url': _repositoryUrl,
          'path': 'packages/$package',
          'ref': 'main',
        },
      };
  return (
    kit: gitReference('sparrow_kit'),
    cli: gitReference('sparrow_cli'),
  );
}

Directory? _findWorkspaceRoot(Directory project) {
  var current = p.absolute(project.path);
  while (true) {
    final root = Directory(current);
    if (File(p.join(current, 'packages', 'sparrow_kit', 'pubspec.yaml'))
            .existsSync() &&
        File(p.join(current, 'packages', 'sparrow_cli', 'pubspec.yaml'))
            .existsSync()) {
      return root;
    }
    final parent = p.dirname(current);
    if (parent == current) return null;
    current = parent;
  }
}

String _packageName(String directoryName) {
  var name = directoryName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  if (name.isEmpty || RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'sparrow_app_$name';
  }
  return name;
}

String _yamlDependency(Map<String, Object> reference, int indentation) {
  final spaces = ' ' * indentation;
  if (reference.containsKey('path')) {
    return '${spaces}path: ${reference['path']}\n';
  }
  final git = reference['git']! as Map<String, Object>;
  final gitSpaces = ' ' * (indentation + 2);
  return '${spaces}git:\n'
      '${gitSpaces}url: ${git['url']}\n'
      '${gitSpaces}path: ${git['path']}\n'
      '${gitSpaces}ref: ${git['ref']}\n';
}
