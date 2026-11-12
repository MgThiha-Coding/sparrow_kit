import 'package:sparrow_kit/server.dart';

void main() {
  final count = Signal<int>(3);
  final page = UiPage(
    () => Container(
      padding: 16,
      child: Column(
        gap: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Sparrow UI contract'),
          Row(
            gap: 4,
            children: [
              const Text('Count: '),
              Text.bind('count', count),
            ],
          ),
          Button(label: 'Increment', onPressed: (_) => count.value++),
        ],
      ),
    ),
  );

  final html = renderToString(page, clientScript: null);
  for (final expected in [
    '<h1>Sparrow UI contract</h1>',
    'display:flex;flex-direction:column;gap:8px;',
    'display:flex;flex-direction:row;gap:4px;',
    '<!--fw:text:count-->3<!--fw:/text:count-->',
    '<button type="button">Increment</button>',
    '"count":3',
  ]) {
    if (!html.contains(expected)) {
      throw StateError('Expected UI contract SSR to include: $expected');
    }
  }
}
