# Dart Web Framework

A lightweight, DOM-first Dart web framework built on [`package:web`](https://pub.dev/packages/web). Its reactive core uses signals to track dependencies and update DOM text without a virtual DOM.

This README's overview and counter example focus on the Milestone 1 reactivity, DOM, and component APIs. The project tree below lists the source files currently present in the workspace; files outside that scope are listed for accuracy, not described here.

## Project structure

```text
.
├── .github/
│   └── .github/
│       └── copilot-instructions.md
├── bin/
│   └── ssr_server.dart
├── lib/
│   └── src/
│       ├── dom/
│       │   └── dom_renderer.dart
│       ├── dsl/
│       │   └── html.dart
│       ├── hydration/
│       │   └── hydration_engine.dart
│       ├── reactivity/
│       │   └── signals.dart
│       ├── router/
│       │   ├── route_table.dart
│       │   └── router.dart
│       ├── runtime/
│       │   └── component.dart
│       ├── seo/
│       │   ├── head_manager.dart
│       │   ├── json_ld.dart
│       │   └── metadata.dart
│       └── ssr/
│           ├── counter_page.dart
│           ├── markup.dart
│           ├── static_site_generator.dart
│           └── string_renderer.dart
├── web/
│   ├── index.html
│   ├── main.dart
│   └── ssr_client.dart
├── pubspec.lock
└── pubspec.yaml
```

`.dart_tool/` and compiled JavaScript files are generated locally and are not source files.

## Milestone 1 counter example

This example shows the existing `Signal`, `createElement`, `createButton`, and `Component<P>` APIs working together. It is an API example, not a verbatim copy of the current [`web/main.dart`](web/main.dart), which currently renders a product detail page.

```dart
import 'package:web/web.dart' as web;

import '../lib/src/dom/dom_renderer.dart';
import '../lib/src/reactivity/signals.dart';
import '../lib/src/runtime/component.dart';

class CounterApp extends Component<void> {
  CounterApp() : super(null);

  final Signal<int> count = Signal<int>(0);

  @override
  web.Node render() {
    return createElement(
      'main',
      children: [
        createElement('h1', children: const ['Reactive counter']),
        createElement('p', children: ['Count: ', count]),
        createButton(
          child: 'Increment',
          onClick: () => count.value++,
        ),
      ],
    );
  }
}

void main() {
  CounterApp().mount('#app');
}
```

Passing a `Signal` as a child binds it to a text node. The click handler updates the signal and the bound text follows it.

## Setup

Requirements:

- Dart SDK `>=3.5.0 <4.0.0` (as declared in `pubspec.yaml`)
- A static HTTP server for the `web/` directory

From the project root, fetch the declared dependencies:

```sh
dart pub get
```

The browser code uses `package:web`; `dart pub get` creates the package configuration needed by the Dart analyzer and compiler.

## Build and run

Compile the current browser entry point:

```sh
dart compile js web/main.dart -O2 -o web/main.dart.js
```

Serve the `web/` directory over HTTP (for example, open `web/index.html` with the VS Code Live Server extension), then visit the URL it provides. The HTML loads `main.dart.js`.

## Development

- Keep browser DOM operations on `package:web` and update nodes directly.
- Put signal and effect code in `lib/src/reactivity/`; use `Signal<T>` for reactive values and `effect()` for tracked work.
- Use `createElement()` and `createButton()` from `lib/src/dom/dom_renderer.dart` for the Milestone 1 DOM helpers.
- Run formatting and analysis after changes:

  ```sh
  dart format lib web
  dart analyze .
  ```

- Rebuild the browser entry point after changing Dart code:

  ```sh
  dart compile js web/main.dart -O2 -o web/main.dart.js
  ```
