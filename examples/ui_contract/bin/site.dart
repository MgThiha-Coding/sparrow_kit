import 'package:sparrow_kit/server.dart';
import 'package:ui_contract_demo/ui_contract_page.dart';

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
        component: UiPage(() => buildUiContractPage(Signal<int>(0))),
        metadata: HeadMetadata(
          title: 'Sparrow Kit UI contract',
          description: 'A DOM-native Dart component rendered on the server.',
        ),
      ),
    ],
    outputDirectory: arguments.first,
  );
}
