import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:web_app/app/pages/counter_page.dart';

void main() {
  hydrateApp(
    (state) => CounterPage(
      count: state.signal<int>('count', fallback: 0),
    ).render(),
  );
}
