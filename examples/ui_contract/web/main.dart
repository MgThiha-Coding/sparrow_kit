import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:ui_contract_demo/ui_contract_page.dart';

void main() {
  hydrateUiApp((state) {
    final count = state.signal<int>('ui_count', fallback: 0);
    return buildUiContractPage(count);
  });
}
