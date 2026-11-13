import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:web_app/app/route_catalog.dart';
import 'package:web_app/ssr_handler.dart';

Future<void> main() async {
  final appDirectory = File.fromUri(Platform.script).parent.parent;
  final outputDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}build'
    '${Platform.pathSeparator}web',
  );
  final webDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}web',
  );
  final server = await shelf_io.serve(
    createSsrHandler(
      catalog: companyRouteCatalog(
        siteBaseUrl: Platform.environment['SPARROW_SITE_URL'],
      ),
      outputDirectory: outputDirectory.path,
      webDirectory: webDirectory.path,
    ),
    InternetAddress.loopbackIPv4,
    8080,
  );
  stdout.writeln(
    'SSR landing page listening on http://${server.address.host}:${server.port}',
  );
}
