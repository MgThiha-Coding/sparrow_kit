<p align="center">
  <a href="https://github.com/MgThiha-Coding/sparrow_kit">
    <img src="assets/logo.png" alt="Sparrow Kit logo" width="112">
  </a>
</p>

<h1 align="center">Sparrow Kit</h1>

<p align="center">
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.6%2B-0175C2?logo=dart&logoColor=white" alt="Dart 3.6 or newer"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://github.com/MgThiha-Coding/sparrow_kit"><img src="https://img.shields.io/badge/Web-DOM--native-2E8B57" alt="DOM-native web framework"></a>
</p>

<p align="center">Build semantic, server-rendered web experiences with Dart.</p>

Sparrow Kit is a lightweight, DOM-native Dart web framework with a UI syntax
that feels familiar to Flutter developers. Describe interfaces with `Column`,
`Row`, `Text`, `Container`, and `Button`; Sparrow Kit renders real HTML and CSS,
not a Flutter canvas.

The framework combines server-side rendering (SSR), browser hydration, and
fine-grained `Signal<T>` reactivity. Search engines and visitors receive
meaningful HTML in the initial response, while interactive updates patch the
DOM directly.

## Why Sparrow Kit?

Flutter Web is designed to deliver a consistent, app-like Flutter experience
in the browser. Sparrow Kit takes a document-first approach: it renders
semantic HTML elements and lets the browser handle layout and painting. It
does not ship Flutter's CanvasKit or Skwasm renderer for its UI.

That makes Sparrow Kit a good fit for content-rich sites and interactive Dart
experiences where accessible markup, initial page content, and browser-native
layout are important. It is not a transpiler for arbitrary Flutter widgets,
and bundle size still depends on the application's code and dependencies.

## Features

- **Flutter-familiar primitives:** Build with `Column`, `Row`, `Text`,
  `Container`, `Heading`, and `Button`.
- **Semantic DOM output:** Layout primitives map to HTML elements and CSS
  flexbox; headings and buttons remain native semantic elements.
- **Fine-grained reactivity:** `Text.bind()` updates its text node without
  rerendering the component or replacing neighboring DOM.
- **SSR and hydration parity:** Use a shared platform-neutral UI description
  to render HTML on the server and attach client-side effects and events
  without replacing the initial page.
- **SEO foundations:** Serve crawlable page content and metadata in the
  initial HTML. Add accurate titles, descriptions, canonical URLs, and
  structured data for each page.
- **Dart-native tooling:** `sparrow_cli build web` validates entry points with
  the Dart analyzer, runs your explicit SSR routes, and compiles the browser
  entry point.
- **Signals and lifecycle cleanup:** `Signal<T>` tracks only the effects that
  read it; bindings and listeners are disposed with their owner.

## Requirements

- Dart SDK `>=3.6.0 <4.0.0`
- A browser for DOM rendering and hydration
- A Dart server runtime for SSR and static generation

## Installation

Add Sparrow Kit to your application's `pubspec.yaml`:

```yaml
dependencies:
  sparrow_kit:
    git:
      url: https://github.com/MgThiha-Coding/sparrow_kit.git
      path: packages/sparrow_kit
      ref: main
```

Then resolve dependencies:

```sh
dart pub get
```

## Quick start

Add a mount point to `web/index.html`:

```html
<div id="app"></div>
<script defer src="main.dart.js"></script>
```

Define the platform-neutral UI tree in `lib/counter_page.dart`:

```dart
import 'package:sparrow_kit/reactivity.dart';
import 'package:sparrow_kit/ui.dart';

UiNode counterPage(Signal<int> count) => Container(
      padding: 24,
      child: Column(
        gap: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Sparrow Kit counter'),
          Text.bind('counter_count', count),
          Button(
            label: 'Increment',
            onPressed: (_) => count.value++,
          ),
        ],
      ),
    );
```

Then create the browser entry point in `web/main.dart`:

```dart
import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:your_app/counter_page.dart';

final counter = component<void>((state, _) {
  final count = state.use<int>(0);
  return renderUi(counterPage(count));
});

void main() => runApp(counter(null));
```

`component()` provides component-scoped state through `state.use()`.
`renderUi()` turns the platform-neutral UI description into DOM nodes and
registers its effects and event listeners with the component's cleanup scope.
`Text.bind()` gives the count its own reactive text binding, so clicking the
button changes only that text node.

For browser-only pages that do not need the `component()` lifecycle, use
`mountUi()` and keep its returned disposer:

```dart
final dispose = mountUi(
  Column(children: [const Text('Hello from Sparrow Kit')]),
);
```

## Server rendering and hydration

The UI description is independent of browser APIs. Build it on the server
inside a `UiPage`, then build the matching description in the browser with
the serialized signal state. Keep `counterPage` in a shared library, such as
`lib/counter_page.dart`, and import it in both entry points:

```dart
// Server entry point
import 'package:sparrow_kit/server.dart';
import 'package:your_app/counter_page.dart';

final html = renderToString(
  UiPage(() => counterPage(Signal<int>(0))),
  clientScript: '/main.dart.js',
);
```

```dart
// Browser entry point
import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:your_app/counter_page.dart';

void main() => hydrateUiApp((state) {
      final count = state.signal<int>('counter_count', fallback: 0);
      return counterPage(count);
    });
```

For static output, use `StaticSiteGenerator` from
`package:sparrow_kit/server.dart`. Hydration checks the server markup and
signal IDs before attaching events and reactive bindings. Keep the server and
client component structure consistent.

## Build with `sparrow_cli`

Add the CLI as a development dependency. In the monorepo layout:

```yaml
dev_dependencies:
  sparrow_cli:
    git:
      url: https://github.com/MgThiha-Coding/sparrow_kit.git
      path: packages/sparrow_cli
      ref: main
```

Create `sparrow.json` at the application root. The server entry point declares
the static routes explicitly; the CLI does not infer routes or execute source
code through analyzer:

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

Run the build from the application root:

```sh
dart run sparrow_cli build web
```

The command analyzes the configured Dart entry points, copies non-Dart assets
from `web/`, runs `bin/site.dart` to generate SSR routes, and compiles the
browser entry point with `dart compile js`.

## Compatibility boundary

Sparrow Kit's UI primitives are its own Dart-native API. They are **not**
Flutter's `Widget` classes, and arbitrary Flutter widgets, render objects,
plugins, and `package:flutter` applications are not automatically compatible.
The initial layout contract uses CSS flexbox rather than Flutter's
constraint-based layout engine. See the [UI contract and web build
guide](docs/ui-contract-and-build.md) for the supported properties and
an end-to-end example.

## Documentation

- [UI contract and web build](docs/ui-contract-and-build.md)
- [Architecture](docs/architecture.md)
- [SSR, hydration, and SEO](docs/ssr-and-seo.md)
- [Routing and state](docs/routing-and-state.md)
- [Getting started](docs/getting-started.md)

Sparrow Kit is open source under the [MIT License](LICENSE). Contributions,
bug reports, and feedback are welcome.
