import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:sparrow_kit/server.dart';

Handler createSsrHandler({
  required RouteCatalog catalog,
  required String outputDirectory,
  required String webDirectory,
  String clientScript = '/main.dart.js',
}) {
  return const Pipeline().addMiddleware(logRequests()).addHandler(
    (request) async {
      if (request.method != 'GET') {
        return Response(HttpStatus.methodNotAllowed);
      }

      final path = request.url.path;
      final assetPath = path.startsWith('/') ? path.substring(1) : path;
      final file = switch (assetPath) {
        'main.dart.js' => File(
            '$outputDirectory${Platform.pathSeparator}main.dart.js',
          ),
        'robots.txt' => File(
            '$outputDirectory${Platform.pathSeparator}robots.txt',
          ),
        'sitemap.xml' => File(
            '$outputDirectory${Platform.pathSeparator}sitemap.xml',
          ),
        'og-image.svg' => File(
            '$webDirectory${Platform.pathSeparator}og-image.svg',
          ),
        'landing.css' => File(
            '$webDirectory${Platform.pathSeparator}landing.css',
          ),
        _ => null,
      };
      if (file != null) {
        if (!await file.exists()) {
          return Response.notFound(
            'Build the site first with "sparrow build web".',
          );
        }

        return Response.ok(
          await file.readAsBytes(),
          headers: {
            'content-type': switch (assetPath) {
              'main.dart.js' => 'application/javascript; charset=utf-8',
              'landing.css' => 'text/css; charset=utf-8',
              'robots.txt' => 'text/plain; charset=utf-8',
              'sitemap.xml' => 'application/xml; charset=utf-8',
              _ => 'image/svg+xml',
            },
          },
        );
      }

      final location = request.url.toString();
      final result = catalog.renderRequest(
        location,
        clientScript: clientScript,
      );
      return Response(
        result.statusCode,
        body: result.html,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    },
  );
}
