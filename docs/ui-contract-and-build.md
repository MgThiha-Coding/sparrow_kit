# Sparrow Kit UI contract and web build

## Compatibility boundary

The UI API in `package:sparrow_kit/ui.dart` is Sparrow Kit's Dart-native component model. It is not a Flutter renderer and does not accept arbitrary `package:flutter` widgets. Its first supported components are `Text`, `Heading`, `Row`, `Column`, `Container`, and `Button`.

`Row` and `Column` lower to CSS flexbox. Their supported main-axis values are start, center, end, space-between, space-around, and space-evenly; cross-axis values are start, center, end, and stretch. `gap` is a non-negative pixel value. `Container` supports non-negative pixel width, height, padding, margin, and border radius, plus a static background color and ordinary attributes. Flutter constraints, render objects, custom painting, implicit Flutter themes, and Flutter package compatibility are out of scope.

## One UI description for SSR, DOM, and hydration

The UI objects are platform-neutral and lower to Sparrow Kit's existing `MarkupNode` model. `UiPage.render()` makes the result available to `StringRenderer`; `mountUi()` creates real browser DOM; `hydrateUiApp()` turns the same description into the template checked against server HTML. Browser-only `package:web` types are confined to `ui_browser.dart`.

```dart
import 'package:sparrow_kit/reactivity.dart';
import 'package:sparrow_kit/ui.dart';

UiNode counterPage(Signal<int> count) => Container(
      padding: 16,
      child: Column(
        gap: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Counter'),
          Row(
            gap: 8,
            children: [
              const Text('Count: '),
              Text.bind('count', count),
            ],
          ),
          Button(
            label: 'Increment',
            onPressed: (_) => count.value++,
          ),
        ],
      ),
    );
```

`Text.bind` requires a stable ID shared by SSR and hydration. IDs use letters, digits, and underscores, beginning with a letter or underscore. The server serializes the signal's initial value and places markers around its text. Hydration verifies those markers and the initial value before attaching the effect and event listeners. It does not replace the hydrated DOM.

`mountUi()` renders a client-only UI tree and returns a disposer. Both direct mounting and hydration dispose bindings and event listeners when their disposer is called. A signal update patches the bound text node, not the component root. Structural changes are intentionally not implicit: this initial contract does not include conditionals, dynamic child lists, or keyed reconciliation.

## Browser and server entry points

Browser code imports `package:sparrow_kit/sparrow_kit.dart` or the focused `ui_browser.dart` entry point. Server code imports `package:sparrow_kit/server.dart`; the UI model itself does not import browser libraries.

```dart
// Browser hydration entry point.
import 'package:sparrow_kit/sparrow_kit.dart';

void main() => hydrateUiApp((state) {
      final count = state.signal<int>('count', fallback: 0);
      return counterPage(count);
    });
```

For client-rendered pages, `uiComponent` adapts the DSL to Sparrow Kit's
existing `Component<P>` lifecycle and `ComponentState` hooks:

```dart
final counter = uiComponent<void>((state, _) {
  final count = state.use(0);
  return Column(
    children: [
      Text.bind('count', count),
      Button(label: 'Increment', onPressed: (_) => count.value++),
    ],
  );
});

void main() => runApp(counter(null));
```

`Text.bind` reads its signal in a leaf effect, not in the component render
effect. The component root stays mounted while the text node changes. Rendering
effects and event listeners are disposed with the owning component.

For static generation, explicitly declare routes in a server entry point and pass them to `StaticSiteGenerator`:

```dart
import 'package:sparrow_kit/server.dart';

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
        component: UiPage(() => counterPage(Signal<int>(0))),
      ),
    ],
    outputDirectory: arguments.first,
  );
}
```

## Build CLI

`packages/sparrow_cli` provides the `sparrow_cli build web` executable. Add the CLI as a development dependency, then create `sparrow.json` at the application root:

For local development in this monorepo, add `sparrow_cli` as a path
`dev_dependency` pointing to `../../packages/sparrow_cli`.

```yaml
dev_dependencies:
  sparrow_cli:
    path: ../../packages/sparrow_cli
```

```json
{
  "web": {
    "client": "web/main.dart",
    "server": "bin/site.dart",
    "output": "build/web",
    "clientOutput": "main.dart.js"
  }
}
```

The build command:

1. Runs `dart analyze` on the configured client and server entry points.
2. Clears the output directory, then copies non-Dart assets from `web/`.
3. Runs the server entry point with the output directory and root-relative client script. That entry point owns the explicit route list and SSR.
4. Compiles the configured browser entry point with `dart compile js`.

The analyzer checks Dart validity and types. It is not used to execute components, infer route tables, or translate Flutter widget trees. The app must use Sparrow Kit's supported UI API. Unsupported widget types are not silently approximated.

In this monorepo, run from `examples/ui_contract`:

```sh
dart run sparrow_cli build web
```

The company landing page is wired to the same workflow in `apps/web_app`:

```sh
cd apps/web_app
dart run sparrow_cli build web
```

The CLI is deliberately an orchestration layer around user-provided entry points. It does not replace or intercept `flutter build web`.

## Proof checks

From the monorepo root:

```sh
dart run tool/ui_contract_smoke.dart
dart compile js tool/ui_contract_browser_smoke.dart -O2 -o tool/ui_contract_browser_smoke.dart.js
```

Open `tool/ui_contract_browser_smoke.html` in a browser after compiling. The
browser smoke checks hydration without root replacement, leaf text updates,
component mounting, and cleanup after disposal. The SSR smoke verifies semantic
tags, flexbox CSS, signal serialization, and event-bearing controls.
