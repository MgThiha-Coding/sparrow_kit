# Getting started

## Requirements

- Dart SDK `>=3.6.0 <4.0.0`
- A static HTTP server for browser output

For the monorepo, run dependency resolution at the root:

```sh
dart pub get
```

The `apps/web_app` package uses `../../packages/sparrow_kit`. External projects can use the Git sub-path dependency in the root [installation guide](../README.md#install-from-git).

## Quickstart

Add Sparrow Kit to a web application's dependencies. For example, an external app can use:

```yaml
dependencies:
  sparrow_kit:
    git:
      url: https://github.com/MgThiha-Coding/flutter_web_framework.git
      path: packages/sparrow_kit
      ref: v1.0.0
```

Create a browser entry point with a mount element in the HTML. The recommended umbrella import provides the functional component API, DOM helpers, signals, hydration, and SEO:

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

```html
<div id="app"></div>
<script defer src="main.dart.js"></script>
```

Compile and serve the output:

```sh
dart compile js web/main.dart -O2 -o web/main.dart.js
```

The `element()` DSL creates browser DOM nodes directly. Passing a signal as a child binds the text node to its current value; the click handler updates it without a virtual DOM diff. `runApp` mounts into `#app` by default and initializes baseline SEO metadata from the existing document, using safe defaults when the document has none. Provide `HeadMetadata` to customize page-specific SEO.

For a complete app in this repository, use `apps/web_app/web/main.dart`. Its build command and the SSR example are in the root [README](../README.md#build-the-example-web-app).
