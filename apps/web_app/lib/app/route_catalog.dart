import 'package:sparrow_kit/routing.dart';
import 'package:sparrow_kit/ssr.dart';

import 'pages/landing_page.dart';

RouteCatalog companyRouteCatalog({String? siteBaseUrl}) {
  final canonicalUrl =
      siteBaseUrl == null ? null : '${Uri.parse(siteBaseUrl).origin}/';
  return RouteCatalog(
    routes: [
      for (final path in const ['/', '/index.html'])
        RouteConfig(
          definition: RouteDefinition(path),
          pageBuilder: (_) => CompanyLandingPage(LandingPageState.initial()),
          metadataBuilder: (_) =>
              companyLandingMetadata(canonicalUrl: canonicalUrl),
        ),
    ],
    notFoundBuilder: (match) => _CompanyNotFoundPage(match.path),
    notFoundMetadataBuilder: (_) => HeadMetadata(
      title: 'Page not found | MyCompany',
      description: 'The requested page could not be found.',
      robots: const RobotsDirectives(index: false),
    ),
  );
}

class _CompanyNotFoundPage implements SsrComponent {
  const _CompanyNotFoundPage(this.path);

  final String path;

  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [
          MarkupElement(
            'h1',
            children: [MarkupText('Page not found')],
          ),
          MarkupElement(
            'p',
            children: [MarkupText(path)],
          ),
        ],
      );
}
