import '../reactivity/signals.dart';
import 'markup.dart';

class CounterPage implements SsrComponent {
  CounterPage({int initialCount = 0, Signal<int>? count})
      : count = count ?? Signal<int>(initialCount);

  final Signal<int> count;

  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [
          MarkupElement('h1',
              children: [MarkupText('Server-rendered counter')]),
          MarkupElement(
            'p',
            attributes: {'data-count': SignalAttribute('count', count)},
            children: [SignalText('count', count)],
          ),
          MarkupElement(
            'button',
            attributes: const {'type': 'button'},
            children: [MarkupText('Increment')],
            events: {
              'click': (_) => count.value++,
            },
          ),
        ],
      );
}
