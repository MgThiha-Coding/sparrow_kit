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
      if (arguments.length != 2 || arguments[1] != 'web') {
        return _usageError('sparrow build web');
      }
      return buildWeb(Directory.current);
    case 'dev':
      final options = _parseDevOptions(arguments.skip(1).toList());
      return runDevServer(
        Directory.current,
        host: options.host,
        port: options.port,
      );
    default:
      return _usageError('Unknown command "${arguments.first}".');
  }
}

_DevOptions _parseDevOptions(List<String> arguments) {
  var host = '127.0.0.1';
  var port = 8080;
  final seen = <String>{};

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--host' || argument == '--port') {
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
    throw RangeError.range(port, 1, 65535, 'port');
  }
  return _DevOptions(host: host, port: port);
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
    ..writeln('  sparrow dev [--host H] [--port P]')
    ..writeln(
        '                             Run SSR dev server with live reload')
    ..writeln('  sparrow build web           Build a production web site');
}

class _DevOptions {
  const _DevOptions({required this.host, required this.port});

  final String host;
  final int port;
}
