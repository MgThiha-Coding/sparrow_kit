import 'package:sparrow_kit/server.dart';
import 'package:web_app/app/pages/landing_page.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError(
      'Expected the output directory and client script from sparrow_cli.',
    );
  }

  await StaticSiteGenerator(clientScript: arguments[1]).generate(
    [
      StaticPage(
        path: '/',
        component: CompanyLandingPage(LandingPageState.initial()),
        metadata: companyLandingMetadata(),
      ),
    ],
    outputDirectory: arguments.first,
  );
}
