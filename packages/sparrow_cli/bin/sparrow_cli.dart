import 'dart:io';

import 'package:sparrow_cli/sparrow_cli.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await runSparrowCli(arguments);
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('sparrow: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}
