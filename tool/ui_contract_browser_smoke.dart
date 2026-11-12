import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  final app = web.document.getElementById('app');
  final direct = web.document.getElementById('direct');
  final componentHost = web.document.getElementById('component');
  if (app == null || direct == null || componentHost == null) {
    throw StateError('Browser smoke test roots are missing.');
  }

  app.innerHTML = '<div style="display:flex;flex-direction:column;gap:0;'
      'justify-content:flex-start;align-items:stretch"><h1>Hydration test</h1>'
      '<span><!--fw:text:count-->3<!--fw:/text:count--></span>'
      '<button type="button">Increment</button></div>';
  final hydrationState =
      web.document.createElement('script') as web.HTMLScriptElement
        ..id = '__FRAMEWORK_STATE__'
        ..type = 'application/json'
        ..textContent = '{"count":3}';
  web.document.body!.appendChild(hydrationState);

  final serverRoot = app.firstChild;
  late Signal<int> hydratedCount;
  final hydrated = hydrateUiApp((state) {
    final count = state.signal<int>('count', fallback: 0);
    hydratedCount = count;
    return Column(
      children: [
        Heading(1, 'Hydration test'),
        Text.bind('count', count),
        Button(label: 'Increment', onPressed: (_) => count.value++),
      ],
    );
  });
  _expect(identical(serverRoot, app.firstChild), 'hydration replaced its root');
  _expect(app.textContent?.contains('3') ?? false, 'initial text mismatch');

  (app.querySelector('button')! as web.HTMLButtonElement).click();
  await Future<void>.delayed(Duration.zero);
  _expect(
      app.textContent?.contains('4') ?? false, 'hydrated event/binding failed');
  _expect(
      identical(serverRoot, app.firstChild), 'signal update replaced its root');
  hydrated();
  (app.querySelector('button')! as web.HTMLButtonElement).click();
  await Future<void>.delayed(Duration.zero);
  _expect(hydratedCount.value == 4, 'disposed handler still ran');

  final count = Signal<int>(1);
  final disposeDirect = mountUi(
    Column(
      children: [
        Text.bind('direct_count', count),
        Button(label: 'Increment', onPressed: (_) => count.value++),
      ],
    ),
    rootSelector: '#direct',
  );
  final directButton = direct.querySelector('button')! as web.HTMLButtonElement;
  directButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(direct.textContent == '2Increment', 'direct DOM binding failed');
  disposeDirect();
  directButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(count.value == 2, 'disposed DOM handler still ran');

  late Signal<int> componentCount;
  final componentApp = component<void>((state, _) {
    componentCount = state.use(1);
    return renderUi(
      Column(
        children: [
          Text.bind('component_count', componentCount),
          Button(
            label: 'Increment',
            onPressed: (_) => componentCount.value++,
          ),
        ],
      ),
    );
  })(null);
  final disposeComponent = runApp(
    componentApp,
    rootSelector: '#component',
  );
  final componentRoot = componentHost.firstChild;
  final componentButton =
      componentHost.querySelector('button')! as web.HTMLButtonElement;
  componentButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(
    componentHost.textContent == '2Increment',
    'component UI leaf binding failed',
  );
  _expect(
    identical(componentHost.firstChild, componentRoot),
    'component UI signal update replaced its root',
  );
  disposeComponent();
  componentButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(componentCount.value == 2, 'disposed component handler still ran');

  web.document.body!.setAttribute('data-test-result', 'passed');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
