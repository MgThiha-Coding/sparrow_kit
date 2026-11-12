import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:sparrow_kit/server.dart';
import 'package:web_app/app/pages/counter_page.dart';

Future<void> main() async {
  final renderer = StringRenderer();
  final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler((
    request,
  ) async {
    if (request.method == 'GET' && request.url.path == 'client.js') {
      final clientScript = File('apps/web_app/web/ssr_client.dart.js');
      if (!await clientScript.exists()) {
        return Response.notFound(
          'Compile the client with: dart compile js apps/web_app/web/ssr_client.dart -O2 -o apps/web_app/web/ssr_client.dart.js',
        );
      }

      return Response.ok(
        await clientScript.readAsBytes(),
        headers: {'content-type': 'application/javascript; charset=utf-8'},
      );
    }

    if (request.method != 'GET' ||
        (request.url.path.isNotEmpty && request.url.path != 'index.html')) {
      return Response.notFound('Not found');
    }

    final metadata = HeadMetadata(
      title: 'SSR Counter',
      description: 'A counter rendered on the server and hydrated in place.',
      canonicalUrl: 'http://localhost:8080/',
      metaTags: [
        MetaTag.property('og:title', 'SSR Counter'),
        MetaTag.property('og:type', 'website'),
        MetaTag.property('og:url', 'http://localhost:8080/'),
      ],
    );
    final html = renderer.render(
      CounterPage(initialCount: 3),
      metadata: metadata,
      clientScript: '/client.js',
    );

    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  });

  final server = await shelf_io.serve(
    pipeline,
    InternetAddress.loopbackIPv4,
    8080,
  );
  stdout.writeln(
      'SSR example listening on http://${server.address.host}:${server.port}');
}
