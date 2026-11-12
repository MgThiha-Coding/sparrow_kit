# Server-side rendering, hydration, and SEO

Browser applications can import `package:sparrow_kit/sparrow_kit.dart` for functional components, rendering, reactivity, SEO, SSR markup, and hydration. `package:sparrow_kit/server.dart` additionally exports `StaticSiteGenerator`, which uses `dart:io` and must remain in server-side code.

## Define an SSR tree

SSR uses a separate `SsrComponent`/`MarkupNode` description. A signal needs a stable identifier so its initial value can be serialized and restored:

```dart
import 'package:sparrow_kit/ssr.dart';

class CounterPage implements SsrComponent {
  CounterPage({int initialCount = 0, Signal<int>? count})
      : count = count ?? Signal<int>(initialCount);

  final Signal<int> count;

  @override
  MarkupNode render() => MarkupElement(
        'main',
        children: [
          MarkupElement('h1', children: [MarkupText('Counter')]),
          MarkupElement(
            'p',
            children: [SignalText('count', count)],
          ),
          MarkupElement(
            'button',
            attributes: const {'type': 'button'},
            children: [MarkupText('Increment')],
            events: {'click': (_) => count.value++},
          ),
        ],
      );
}
```

`StringRenderer.render()` produces the HTML document and serializes signal values. Its output includes the root element with the requested ID (default `app`) and a `__FRAMEWORK_STATE__` JSON script. It escapes text, attributes, and JSON-LD content; invalid attribute names and inline `on*` attributes are rejected.

## Render HTML with metadata

`HeadMetadata` represents a page title, description, canonical URL, arbitrary meta tags, and JSON-LD schemas. Use `OpenGraphMetadata` and `TwitterCardMetadata` to generate their property/name tags:

```dart
final pageUrl = Uri.parse('https://example.com/counter');
final pageTitle = 'Counter | Example';
final pageDescription = 'A server-rendered interactive counter.';
final previewImage = 'https://example.com/images/counter.png';

final metadata = HeadMetadata(
  title: pageTitle,
  description: pageDescription,
  canonicalUrl: pageUrl.toString(),
  metaTags: [
    ...OpenGraphMetadata(
      title: pageTitle,
      type: 'website',
      url: pageUrl.toString(),
      image: previewImage,
      description: pageDescription,
      siteName: 'Example',
    ).toMetaTags(),
    ...TwitterCardMetadata(
      card: 'summary_large_image',
      title: pageTitle,
      description: pageDescription,
      image: previewImage,
    ).toMetaTags(),
  ],
  jsonLd: [
    OrganizationJsonLd(
      name: 'Example',
      url: 'https://example.com',
      description: 'Example publisher.',
    ),
  ],
);
```

Pass the metadata to `renderToString()` to render the title, description, canonical link, Open Graph/Twitter tags, and JSON-LD `<script type="application/ld+json">` into the initial response:

```dart
final html = renderToString(
  CounterPage(initialCount: 3),
  metadata: metadata,
  clientScript: '/client.js',
);
```

When metadata and the client script are omitted, `renderToString()` supplies a generic title and description, baseline Open Graph and Twitter tags, serialized state, and a deferred `/main.dart.js` script. Compile the browser entry point to that path to enable hydration without extra renderer configuration. Pass `clientScript: null` for a static page with no client bundle.

Built-in schema classes include `OrganizationJsonLd`, `ProductJsonLd`, and `ArticleJsonLd`. Implement `JsonLdSchema` to provide another schema type. Use accurate, page-specific values and absolute public URLs in production; generic defaults cannot infer the site's identity, canonical host, preview image, or structured business data.

## Dynamic browser metadata

`runApp()` mounts a component into `#app` by default and initializes `HeadManager` from the document's current title and description, filling missing values with safe defaults. It also generates a canonical URL from the current browser URL and baseline Open Graph/Twitter tags. Pass `metadata:` to override these defaults. `hydrateApp()` performs the same head setup while reading serialized state and attaching to the existing server markup.

For route-specific or reactive head updates, use `HeadManager` directly. `apply()` updates document title, description, canonical URL, meta tags, and JSON-LD scripts. `watch()` applies the result of a builder inside a reactive effect, so reading signals in that builder updates metadata when they change. Dispose the manager with its page/component:

```dart
final title = Signal<String>('Products | Example');
late final HeadManager headManager;

void onMount() {
  headManager = HeadManager();
  headManager.watch(
    () => HeadMetadata(
      title: title.value,
      description: 'Browse current products.',
      metaTags: [
        MetaTag.property('og:title', title.value),
        MetaTag.name('twitter:title', title.value),
      ],
    ),
  );
}

void onDispose() {
  headManager.dispose();
}
```

The manager restores pre-existing title/meta/canonical values and removes the tags it created when disposed. It supports one `watch()` binding per manager. Client-side metadata is useful for navigation, but crawlers and social preview bots may not execute JavaScript; render metadata into the initial HTML for reliable indexing and sharing.

## Hydrate the server-rendered page

The client must construct the same markup tree and use the same signal IDs as the server. `hydrateApp()` handles state loading, root lookup, head metadata, mismatch cleanup, and binding setup:

```dart
import 'package:sparrow_kit/sparrow_kit.dart';

void main() {
  hydrateApp(
    (state) => CounterPage(
      count: state.signal<int>('count', fallback: 0),
    ).render(),
  );
}
```

The renderer emits the initial markup and signal values; `hydrateApp()` reads the state script, finds `#app`, verifies the markup, attaches reactive updates and event handlers, and returns a disposer. Keep server and client trees and initial attributes consistent. Pass `rootId: 'content'` to hydrate into a custom root.

## Static generation and HTTP integration

For file-based output, `StaticSiteGenerator` accepts `StaticPage` entries and writes an `index.html` under each page path:

```dart
import 'package:sparrow_kit/server.dart';

await StaticSiteGenerator(clientScript: '/client.js').generate(
  [
    StaticPage(
      path: '/',
      component: CounterPage(initialCount: 3),
      metadata: metadata,
    ),
  ],
  outputDirectory: 'build',
);
```

For request-time SSR, call `renderToString()` from an HTTP handler and return the HTML with a `text/html; charset=utf-8` content type. The Shelf handler in `apps/web_app/bin/ssr_server.dart` renders the same company landing page used by the static build. `apps/web_app/bin/site.dart` is the configured static-generation entry point used by `sparrow_cli`. Sparrow Kit provides rendering primitives, not a framework-specific HTTP server adapter. Put production TLS, caching, compression, error handling, and request timeouts at the server or reverse-proxy layer.
