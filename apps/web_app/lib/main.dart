import 'package:sparrow_kit/sparrow_kit.dart' as kit;
import 'package:web/web.dart' as web;

final counterApplication = kit.component<void>((state, _) {
  final count = state.use(0);
  final itemCount = state.use(0);
  final nextItemId = state.use(0);
  final items = kit.ul(attributes: const {'id': 'items'});

  void addItem() {
    final id = nextItemId.value + 1;
    nextItemId.value = id;

    late final web.HTMLElement item;
    item = kit.li(
      attributes: {'data-item-id': '$id'},
      classes: const ['counter-item'],
      children: [
        kit.span(children: ['Item $id']),
        kit.button(
          attributes: {'aria-label': 'Remove item $id'},
          children: const ['Remove'],
          onClick: (_) {
            item.remove();
            itemCount.value--;
          },
        ),
      ],
    );

    items.appendChild(item);
    itemCount.value++;
  }

  return kit.main(
    attributes: const {'class': 'integration-app'},
    children: [
      kit.h1(children: const ['Sparrow Kit integration']),
      kit.p(
        attributes: const {'id': 'counter-value'},
        children: ['Count: ', count],
      ),
      kit.div(
        classes: const ['counter-actions'],
        children: [
          kit.button(
            attributes: const {'aria-label': 'Increment counter'},
            children: const ['Increment'],
            onClick: (_) => count.value++,
          ),
          kit.button(
            attributes: const {'aria-label': 'Decrement counter'},
            children: const ['Decrement'],
            onClick: (_) => count.value--,
          ),
        ],
      ),
      kit.p(
        attributes: const {'id': 'item-count'},
        children: ['Items: ', itemCount],
      ),
      items,
      kit.button(
        attributes: const {'aria-label': 'Add item'},
        children: const ['Add item'],
        onClick: (_) => addItem(),
      ),
    ],
  );
});

void main() {
  counterApplication(null).mount('#app');
}
