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

<p align="center">Build DOM-native, server-rendered web experiences with Dart.</p>

Sparrow Kit is a web framework and build CLI for Dart developers who want
semantic HTML, browser-native layout, and server-rendered content without
shipping a Flutter rendering engine for their UI. Describe pages with familiar
primitives like `Column`, `Row`, `Text`, and `Button`; Sparrow Kit renders real
DOM rather than painting the interface to a canvas.

The framework brings server-side rendering (SSR), browser hydration, SEO
metadata, and fine-grained `Signal<T>` reactivity into one workflow. The
`sparrow_cli` scaffold creates the project wiring, and its build command
orchestrates your configured server and browser entry points.

## Why Sparrow Kit?

Flutter Web is a strong choice for app-like experiences that need Flutter's
consistent rendering model. For content-rich websites, however, a
canvas-oriented renderer can be a poor fit for document semantics, browser
accessibility, initial HTML content, and search or social crawlers.

Sparrow Kit takes a document-first approach:

- **DOM-native UI:** components map to HTML elements and CSS layout, not
  Flutter's CanvasKit or Skwasm renderer.
- **Useful content before JavaScript:** SSR emits HTML for the browser to
  display and crawlers to inspect.
- **Interactive without replacing the page:** hydration attaches event
  handlers and reactive bindings to the existing server-rendered DOM.
- **Targeted updates:** `Text.bind()` patches its text node; it does not
  rebuild neighboring nodes for a value change.
- **CLI-driven builds:** a single build command checks the configured
  entrypoints, generates SSR pages, copies web assets, and compiles the browser
  bundle.

Sparrow Kit is not a Flutter widget transpiler. Its UI contract is a focused
Dart API, not compatibility with arbitrary `package:flutter` widgets. It does
not include Flutter's canvas renderer, but total JavaScript size and runtime
performance still depend on your application, dependencies, and deployment.

## Get started

### 1. Install the CLI

The CLI is currently distributed from this Git repository:

```sh
dart pub global activate --source git https://github.com/MgThiha-Coding/sparrow_kit.git --git-path packages/sparrow_cli
```

Ensure Dart's global executable directory is on your `PATH`. On Windows, this
is typically `%LOCALAPPDATA%\Pub\Cache\bin`.

### 2. Scaffold an app

```sh
sparrow init my_site
cd my_site
dart pub get
```

The scaffold creates the package dependencies, `sparrow.json`, a shared page
under `lib/`, a hydration entrypoint under `web/`, and an SSR entrypoint under
`server/`. It gives the CLI a working starting point rather than requiring you
to wire package dependencies and build commands by hand.

For an existing Dart package, run `sparrow add web` from that package to add
the Sparrow Kit web dependencies and starter files. Existing files are left
unchanged.

### 3. Build your page in `lib/`

The scaffolded `lib/home_page.dart` uses the same UI description for both SSR
and hydration:

```dart
import 'package:sparrow_kit/reactivity.dart';
import 'package:sparrow_kit/ui.dart';

UiNode buildHomePage(Signal<int> count) => Container(
      padding: 24,
      child: Column(
        gap: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Welcome to Sparrow Kit'),
          Row(
            gap: 8,
            children: [
              const Text('Visits: '),
              Text.bind('home_count', count),
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

`Text.bind` takes a stable ID so the server can serialize the initial signal
value and the browser can restore it during hydration. A signal update patches
the bound text node directly. The initial UI contract includes common layout
and content primitives; it does not implicitly provide Flutter's full widget
catalogue or dynamic, keyed child-list reconciliation.

### 4. Run and build with the CLI

From the app directory:

```sh
sparrow dev
sparrow build web
```

`sparrow dev` builds the configured app and serves it with live reload.
`sparrow build web` creates the production site in `build/web`, compiling the
browser entrypoint with Dart's optimized JavaScript compiler.

## What the CLI automates

The generated `sparrow.json` connects the browser and server entrypoints:

```json
{
  "web": {
    "client": "web/main.dart",
    "server": "server/site.dart",
    "output": "build/web",
    "clientOutput": "main.dart.js"
  }
}
```

The scaffolded browser entrypoint calls `hydrateUiApp`; the server entrypoint
uses `StaticSiteGenerator` to render the initial route from the shared page in
`lib/`. When you run `sparrow build web`, the CLI:

1. Analyzes the configured client and server entrypoints.
2. Copies non-Dart assets from `web/` into the output directory.
3. Runs the server entrypoint to generate the declared SSR routes and HTML.
4. Compiles the client entrypoint with `dart compile js -O2`.

This is build orchestration around your app code, not source-code discovery:
the server entrypoint owns the route list, and you decide which pages and
metadata to render. Add routes there as your site grows. The CLI does not
translate Flutter widgets, infer routes from `lib/`, or replace `flutter build
web`.

## SSR, hydration, and SEO

The server renders page markup and serialized signal state into the initial
HTML. In the browser, `hydrateUiApp` rebuilds the matching UI description from
that state, checks it against the existing DOM, and attaches bindings and
events without replacing the server markup. Keep the server and client UI
structure and `Text.bind` IDs consistent.

For page-specific SEO, pass `HeadMetadata` from the server route. Sparrow Kit
can render titles, descriptions, canonical links, Open Graph and Twitter meta
tags, and JSON-LD schemas into the initial response. The framework supplies
the mechanisms; your app must provide accurate, page-specific values and
public URLs. No framework can guarantee indexing, rankings, or rich-result
eligibility across search engines.

See the [SSR, hydration, and SEO guide](docs/ssr-and-seo.md) for metadata,
structured-data, and request-time rendering examples.

## Compatibility and requirements

- Dart SDK `>=3.6.0 <4.0.0`
- A modern browser for DOM rendering and hydration
- A Dart runtime for SSR and static generation

Sparrow Kit's `Text`, `Row`, `Column`, `Container`, `Heading`, and `Button` are
Sparrow Kit APIs, not Flutter widgets. The initial layout contract uses CSS
flexbox; Flutter render objects, custom painting, implicit Flutter themes, and
Flutter package compatibility are outside its scope.

## Documentation

- [UI contract and web build](docs/ui-contract-and-build.md)
- [Architecture](docs/architecture.md)
- [SSR, hydration, and SEO](docs/ssr-and-seo.md)
- [Routing and state](docs/routing-and-state.md)
- [Getting started](docs/getting-started.md)

Sparrow Kit is open source under the [MIT License](LICENSE). Contributions,
bug reports, and feedback are welcome.
