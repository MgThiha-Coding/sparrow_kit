import 'dart:io';

import 'build.dart';
import 'scaffold.dart';

Future<int> runSparrowCli(List<String> arguments) async {
  if (arguments.isEmpty ||
      arguments.length == 1 &&
          const {'-h', '--help', 'help'}.contains(arguments.first)) {
    _writeUsage();
    return 0;
  }

  switch (arguments.first) {
    case 'init':
    case 'create':
      if (arguments.length > 2) return _usageError('sparrow init [directory]');
      await scaffoldProject(
        arguments.length == 2 ? arguments[1] : Directory.current.path,
      );
      return 0;
    case 'add':
      if (arguments.length < 2 ||
          arguments[1] != 'web' ||
          arguments.length > 3) {
        return _usageError('sparrow add web [app-directory]');
      }
      await addWebToProject(
        arguments.length == 3 ? arguments[2] : Directory.current.path,
      );
      return 0;
    case 'build':
      if (arguments.length < 2 || arguments[1] != 'web') {
        return _usageError('sparrow build web');
      }
      late final Map<String, String> defines;
      try {
        defines = _parseBuildDefines(arguments.skip(2).toList());
      } on FormatException catch (error) {
        return _usageError(error.message);
      }
      return buildWeb(Directory.current, defines: defines);
    case 'dev':
      late final _DevOptions options;
      try {
        options = _parseDevOptions(arguments.skip(1).toList());
      } on FormatException catch (error) {
        return _usageError(error.message);
      }
      return runDevServer(
        Directory.current,
        host: options.host,
        port: options.port,
        defines: options.defines,
      );
    default:
      return _usageError('Unknown command "${arguments.first}".');
  }
}

_DevOptions _parseDevOptions(List<String> arguments) {
  var host = '127.0.0.1';
  var port = 8080;
  final seen = <String>{};
  final defines = <String, String>{};

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--define') {
      if (index + 1 >= arguments.length) {
        throw const FormatException('Expected a value after --define.');
      }
      _addDefine(defines, arguments[++index]);
    } else if (argument.startsWith('--define=')) {
      _addDefine(defines, argument.substring('--define='.length));
    } else if (argument == '--host' || argument == '--port') {
      if (!seen.add(argument)) {
        throw FormatException('Option $argument may only be specified once.');
      }
      if (index + 1 >= arguments.length) {
        throw FormatException('Expected a value after $argument.');
      }
      final value = arguments[++index];
      if (argument == '--host') {
        if (value.isEmpty) throw const FormatException('Host cannot be empty.');
        host = value;
      } else {
        port = int.tryParse(value) ??
            (throw const FormatException('Port must be an integer.'));
      }
    } else {
      throw FormatException('Unknown dev option "$argument".');
    }
  }

  if (port < 1 || port > 65535) {
    throw const FormatException('Port must be between 1 and 65535.');
  }
  return _DevOptions(host: host, port: port, defines: defines);
}

Map<String, String> _parseBuildDefines(List<String> arguments) {
  final defines = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--define') {
      if (index + 1 >= arguments.length) {
        throw const FormatException('Expected a value after --define.');
      }
      _addDefine(defines, arguments[++index]);
    } else if (argument.startsWith('--define=')) {
      _addDefine(defines, argument.substring('--define='.length));
    } else {
      throw FormatException('Unknown build option "$argument".');
    }
  }
  return defines;
}

void _addDefine(Map<String, String> defines, String assignment) {
  final separator = assignment.indexOf('=');
  if (separator <= 0) {
    throw const FormatException(
      'Expected --define NAME=VALUE with a non-empty name.',
    );
  }
  final name = assignment.substring(0, separator);
  final value = assignment.substring(separator + 1);
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$').hasMatch(name) ||
      name.contains('\u0000') ||
      value.contains('\u0000')) {
    throw const FormatException(
      'Build define names must start with a letter or underscore and contain '
      'only letters, digits, ".", "_" or "-"; values cannot contain NUL.',
    );
  }
  if (defines.containsKey(name)) {
    throw FormatException('Build define "$name" was specified more than once.');
  }
  defines[name] = value;
}

int _usageError(String message) {
  stderr
    ..writeln(message)
    ..writeln();
  _writeUsage();
  return 64;
}

void _writeUsage() {
  stdout
    ..writeln('Sparrow Kit CLI')
    ..writeln('  sparrow init [directory]   Create or initialize a project')
    ..writeln('  sparrow add web [directory] Add web support to an app')
    ..writeln(
      '  sparrow dev [--host H] [--port P] [--define NAME=VALUE]',
    )
    ..writeln(
        '                             Run SSR dev server with live reload')
    ..writeln(
      '  sparrow build web [--define NAME=VALUE]',
    )
    ..writeln('                             Build a production web site');
}

class _DevOptions {
  const _DevOptions({
    required this.host,
    required this.port,
    required this.defines,
  });

  final String host;
  final int port;
  final Map<String, String> defines;
}
