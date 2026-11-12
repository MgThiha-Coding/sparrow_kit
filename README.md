# SparrowKit

SparrowKit is a DOM-first web framework for Dart. It combines functional components, fine-grained signals, browser routing, server-rendered markup, hydration, and SEO helpers in a small package at `packages/sparrow_kit`.

> **SDK:** Dart 3.6 or newer. The repository is a Pub workspace.

## Why SparrowKit

- **Fine-grained reactivity:** `Signal<T>` tracks effects that read it. Synchronous changes coalesce through microtask scheduling, and `batch()` groups updates.
- **Targeted DOM updates:** Browser rendering uses `package:web` and patches bound text, attributes, and styles directly, skipping equal values instead of diffing a virtual tree.
- **Functional component API:** `component()` builders receive typed props and per-instance `state.use()` slots.
- **Convenient SSR and hydration:** `renderToString()` supplies default head metadata, serialized state, and a conventional client-script path. `hydrateApp()` reads that state and attaches to `#app` with one call.
- **Built-in SEO:** `HeadManager` updates title, description, canonical links, Open Graph/Twitter tags, and JSON-LD. Browser startup supplies safe baseline metadata; page-specific URLs, images, and structured data remain application-owned.
- **One browser import:** `package:sparrow_kit/sparrow_kit.dart` exports the functional API, DOM helpers, reactivity, routing, hydration, SEO, and shared SSR types.
- **Mobile dependency isolation:** `apps/android_app` does not depend on SparrowKit. This keeps the web package out of that app's dependency graph; it is not a claim of a measured binary-size reduction.

SSR uses a separate `SsrComponent`/`MarkupNode` tree from the direct-DOM component API. The application supplies that tree and keeps it consistent with the hydration builder. SparrowKit provides rendering primitives, not an HTTP server or automatic discovery of page-specific SEO data.

## Install from GitHub

Add the package subdirectory to a web application's `pubspec.yaml`:

```yaml
dependencies:
  sparrow_kit:
    git:
      url: https://github.com/MgThiha-Coding/flutter_web_framework.git
      path: packages/sparrow_kit
      ref: main
```

Then resolve it:

```sh
dart pub get
```

Pub caches Git checkouts under `$PUB_CACHE/git/` (on Windows, commonly `%LOCALAPPDATA%\Pub\Cache\git\`). The lockfile records the resolved revision; commit it in applications for repeatable builds. To pin a release, replace `main` with a version tag such as `v1.0.0`:

```yaml
      ref: v1.0.0
```

For development inside this monorepo, use the local workspace dependency already configured in `apps/web_app/pubspec.yaml`.

## Quick start

Create `web/index.html` with a mount element and the compiled script:

```html
<div id="app"></div>
<script defer src="main.dart.js"></script>
```

Then create a functional component in `web/main.dart`:

```dart
import 'package:sparrow_kit/sparrow_kit.dart';

final counter = component<void>((state, _) {
  final count = state.use<int>(0);

  return element(
    'main',
    children: [
      h1(children: const ['Counter']),
      p(children: ['Count: ', count]),
      button(
        children: const ['Increment'],
        onClick: (_) {
          count.value++;
        },
      ),
    ],
  );
});

void main() => runApp(counter(null));
```

Compile and serve the web directory over HTTP:

```sh
dart compile js web/main.dart -O2 -o web/main.dart.js
```

`runApp()` mounts into `#app` by default, sets baseline head metadata from the document (with safe defaults when values are absent), and returns a disposer for unmounting. Use typed props with `component<MyProps>((state, props) { ... })`; hooks must be called in a consistent order on every render.

## SSR, hydration, and SEO

The app must define an `SsrComponent` tree with stable IDs for signal-backed text and attributes. The repository's shared example is [CounterPage](apps/web_app/lib/app/pages/counter_page.dart); it imports the platform-neutral `ssr.dart` API. In a server entry point, use `server.dart` to render that page:

```dart
import 'package:sparrow_kit/server.dart';
import 'package:web_app/app/pages/counter_page.dart';

final html = renderToString(
  CounterPage(initialCount: 3),
  clientScript: '/client.js',
);
```

With no options, `renderToString()` emits default title/description and baseline social tags, serializes signal values, creates the `#app` root, and includes `/main.dart.js`. Compile the matching hydration entry point to that URL or pass its URL through `clientScript:`. Pass `metadata:` for page-specific SEO or `clientScript: null` for a static document.

In the browser hydration entry point, recreate the same tree using the serialized signal state:

```dart
import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:web_app/app/pages/counter_page.dart';

void main() => hydrateApp(
      (state) => CounterPage(
        count: state.signal<int>('count', fallback: 0),
      ).render(),
    );
```

Use `HeadMetadata`, `OpenGraphMetadata`, `TwitterCardMetadata`, and the provided JSON-LD schema classes for accurate page-specific metadata:

```dart
import 'package:sparrow_kit/server.dart';

final metadata = HeadMetadata(
  title: 'Counter | Example',
  description: 'An interactive, server-rendered counter.',
  canonicalUrl: 'https://example.com/counter',
  metaTags: [
    ...OpenGraphMetadata(
      title: 'Counter | Example',
      type: 'website',
      url: 'https://example.com/counter',
      image: 'https://example.com/counter-preview.png',
    ).toMetaTags(),
    ...TwitterCardMetadata(
      card: 'summary_large_image',
      title: 'Counter | Example',
      image: 'https://example.com/counter-preview.png',
    ).toMetaTags(),
  ],
  jsonLd: [
    OrganizationJsonLd(
      name: 'Example',
      url: 'https://example.com',
    ),
  ],
);
```

Generic defaults cannot infer a production domain, share image, organization, or article details. Supply real values and JSON-LD where appropriate. `StaticSiteGenerator` is available only through `package:sparrow_kit/server.dart`; it uses `dart:io`. For request-time SSR, integrate `renderToString()` with your HTTP server of choice.

## Routing and state

`Router` matches static and `:parameter` path segments, updates `currentRoute` and parameter signals on navigation and browser back/forward, and exposes `push()` for same-origin paths. It does not impose a page-loading convention:

```dart
import 'package:sparrow_kit/sparrow_kit.dart';

final router = Router(
  routes: [
    RouteDefinition('/'),
    RouteDefinition('/products/:productId'),
  ],
);

router.push('/products/42');
final match = router.currentRoute.value;
```

Signals are also available directly for application state. Effects track dependencies automatically; use `effect()` for reactive work and call its returned disposer when that work outlives a component.

## Workspace and mobile isolation

```text
apps/android_app/       # Independent package; no sparrow_kit dependency
apps/web_app/           # Landing page, counter, and SSR/hydration example
packages/sparrow_kit/    # Framework package
docs/                   # Guides
```

Run workspace checks from the repository root:

```sh
dart pub get
dart analyze .
dart run tool/reactivity_smoke.dart
dart run tool/ssr_defaults_smoke.dart
```

The Android package has no SparrowKit dependency edge; the web runtime is imported by web code only. Dart's normal reachability/tree-shaking behavior remains compiler- and application-dependent.

## Documentation

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Routing and state](docs/routing-and-state.md)
- [SSR, hydration, and SEO](docs/ssr-and-seo.md)
