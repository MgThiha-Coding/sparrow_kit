# SparrowKit

SparrowKit is a DOM-first Dart web framework with fine-grained signals, browser routing, SSR, hydration, and SEO helpers.

## Requirements

- Dart SDK `>=3.6.0 <4.0.0`
- A browser application for the DOM APIs
- A Dart server runtime for `StaticSiteGenerator` (`dart:io`)

## Install

Add the Git package to your web application's `pubspec.yaml`:

```yaml
dependencies:
  sparrow_kit:
    git:
      url: https://github.com/MgThiha-Coding/flutter_web_framework.git
      path: packages/sparrow_kit
      ref: main
```

Run `dart pub get`. To use a fixed release, replace `main` with a tag such as `v1.0.0` and commit the consuming application's `pubspec.lock`. Pub caches Git checkouts under `$PUB_CACHE/git/` (commonly `%LOCALAPPDATA%\Pub\Cache\git\` on Windows).

## Browser quick start

Create a `<div id="app"></div>` in the page, then use the single browser-facing import:

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

`runApp` mounts into `#app` by default, initializes baseline page metadata, and returns a disposer. `Signal` children update their text nodes directly; signal-bound attributes and styles use targeted DOM patches. The functional component API uses typed props and `state.use()` slots; keep hooks in the same order on each render.

## SSR, hydration, and SEO

Define the SSR page with the platform-neutral `package:sparrow_kit/ssr.dart` API:

```dart
import 'package:sparrow_kit/ssr.dart';

class CounterPage implements SsrComponent {
  CounterPage(this.count);

  final Signal<int> count;

  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [
          MarkupElement(
            'p',
            children: [SignalText('count', count)],
          ),
        ],
      );
}
```

In a server entry point, import `package:sparrow_kit/server.dart` and call `renderToString(CounterPage(Signal<int>(0)))`. It supplies generic SEO defaults, serializes signal values, creates the `#app` root, and includes `/main.dart.js` by default. Compile the matching hydration client to that URL, or pass `clientScript:` explicitly.

In the browser, import `package:sparrow_kit/sparrow_kit.dart` and hydrate the same markup and stable signal IDs. Replace `your_app` below with the consuming application's package name:

```dart
import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:your_app/counter_page.dart';

void main() => hydrateApp(
      (state) => CounterPage(
        state.signal<int>('count', fallback: 0),
      ).render(),
    );
```

For production metadata, pass `HeadMetadata` with a real title, description, canonical URL, Open Graph/Twitter tags, and JSON-LD as appropriate. SparrowKit cannot infer site-specific URLs, preview images, or structured business data. `StaticSiteGenerator` is exported by `server.dart` only because it uses `dart:io`.

The SSR markup model is separate from the direct-DOM component API. The application defines the SSR tree and ensures the hydration builder produces the matching shape; the framework does not provide an HTTP server adapter.

## Reactivity and routing

`Signal<T>`, `effect()`, and `batch()` provide dependency-tracked updates with a microtask scheduler. `Router` supports static and `:parameter` path segments, same-origin `push()` navigation, and browser back/forward synchronization. Applications map route matches to their own page components.

## Platform isolation

The monorepo's `apps/android_app` intentionally has no dependency on SparrowKit. Browser rendering and SEO APIs are only linked by applications that import them. AOT output size depends on the consuming app and compiler reachability analysis; no fixed binary-size reduction is promised.

## Further reading

- [Root installation, examples, and workspace guide](../../README.md)
- [Getting started](../../docs/getting-started.md)
- [Architecture](../../docs/architecture.md)
- [Routing and state](../../docs/routing-and-state.md)
- [SSR, hydration, and SEO](../../docs/ssr-and-seo.md)
