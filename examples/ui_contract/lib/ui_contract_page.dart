import 'package:sparrow_kit/reactivity.dart';
import 'package:sparrow_kit/ui.dart';

UiNode buildUiContractPage(Signal<int> count) => Container(
      padding: 16,
      child: Column(
        gap: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Sparrow Kit UI contract'),
          Row(
            gap: 8,
            children: [
              const Text('Count: '),
              Text.bind('ui_count', count),
            ],
          ),
          Button(
            label: 'Increment',
            onPressed: (_) => count.value++,
          ),
        ],
      ),
    );
