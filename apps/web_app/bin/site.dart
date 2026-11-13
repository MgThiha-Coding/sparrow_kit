import 'dart:io';

import 'package:sparrow_kit/server.dart';
import 'package:web_app/app/route_catalog.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError(
      'Expected the output directory and client script from sparrow_cli.',
    );
  }

  final siteBaseUrl = Platform.environment['SPARROW_SITE_URL'];
  await companyRouteCatalog(siteBaseUrl: siteBaseUrl).generateStaticSite(
    concretePathsByRoute: const {
      '/': ['/']
    },
    outputDirectory: arguments.first,
    generator: StaticSiteGenerator(
      clientScript: arguments[1],
      siteBaseUrl: siteBaseUrl,
    ),
  );
}
