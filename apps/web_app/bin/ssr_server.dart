import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sparrow_kit/server.dart';
import 'package:web_app/app/pages/landing_page.dart';

Future<void> main() async {
  final appDirectory = File.fromUri(Platform.script).parent.parent;
  final outputDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}build'
    '${Platform.pathSeparator}web',
  );
  final webDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}web',
  );
  final renderer = StringRenderer();
  final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler((
    request,
  ) async {
    if (request.method != 'GET') {
      return Response(HttpStatus.methodNotAllowed);
    }

    final path = request.url.path;
    if (path.isEmpty || path == 'index.html') {
      return Response.ok(
        renderer.render(
          CompanyLandingPage(LandingPageState.initial()),
          metadata: companyLandingMetadata(),
          clientScript: '/main.dart.js',
        ),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }

    final file = switch (path) {
      'main.dart.js' => File(
          '${outputDirectory.path}${Platform.pathSeparator}main.dart.js',
        ),
      'og-image.svg' => File(
          '${webDirectory.path}${Platform.pathSeparator}og-image.svg',
        ),
      'landing.css' => File(
          '${webDirectory.path}${Platform.pathSeparator}landing.css',
        ),
      _ => null,
    };
    if (file == null) return Response.notFound('Not found');
    if (!await file.exists()) {
      return Response.notFound(
        'Build the site first with "sparrow build web".',
      );
    }

    return Response.ok(
      await file.readAsBytes(),
      headers: {
        'content-type': switch (path) {
          'main.dart.js' => 'application/javascript; charset=utf-8',
          'landing.css' => 'text/css; charset=utf-8',
          _ => 'image/svg+xml',
        },
      },
    );
  });

  final server = await shelf_io.serve(
    pipeline,
    InternetAddress.loopbackIPv4,
    8080,
  );
  stdout.writeln(
    'SSR landing page listening on http://${server.address.host}:${server.port}',
  );
}
