# Sparrow Kit UI contract and web build

## Compatibility boundary

The UI API in `package:sparrow_kit/ui.dart` is Sparrow Kit's Dart-native component model. It is not a Flutter renderer and does not accept arbitrary `package:flutter` widgets. Its primitives include `Text`, `Heading`, `Row`, `Column`, `Container`, `Button`, `Padding`, `Margin`, `Expanded`, `Flexible`, `SizedBox`, `Stack`, `Positioned`, `Grid`, `Responsive`, and `KeyedList`.

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

`mountUi()` renders a client-only UI tree and returns a disposer. Both direct mounting and hydration dispose bindings and event listeners when their disposer is called. A signal update patches the bound text node, not the component root. Conditional UI is explicit; `KeyedList<T>` provides the supported reactive collection primitive for adding, removing, updating, and reordering children.

## Keyed child lists

`KeyedList<T>` takes a `Signal<List<T>>`, a stable `keyOf` function, and an
`itemBuilder`. Assign a new list to the signal to update the collection; mutating
the current list in place does not notify subscribers. Keys must be unique and
non-empty. Inserted items are rendered and hydrated, removed items have their
bindings and event listeners disposed, and unchanged items retain their DOM
nodes across reordering.

The initial list value is serialized to JSON during SSR. Restore it with the
same signal ID during hydration. For typed collections, provide `decode` to
`HydrationState.signal<T>()` so JSON-decoded values are converted to the Dart
type expected by the component:

```dart
final items = state.signal<List<String>>(
  'products',
  fallback: const [],
  decode: (value) => (value! as List).cast<String>(),
);
```

## Responsive layouts

`Responsive` describes a flex container with a required mobile base layout and optional tablet and desktop overrides. `ResponsiveBreakpoint.mobile` is the base rule, tablet starts at `600px`, and desktop starts at `1024px`. Omitted larger breakpoints inherit the preceding CSS rule. Each breakpoint can set direction, gap, and the same main- and cross-axis alignments used by `Row` and `Column`.

```dart
Responsive(
  tag: 'section',
  layouts: {
    ResponsiveBreakpoint.mobile: ResponsiveFlexLayout(
      direction: ResponsiveDirection.column,
      gap: 8,
    ),
    ResponsiveBreakpoint.tablet: ResponsiveFlexLayout(
      direction: ResponsiveDirection.row,
      gap: 12,
    ),
    ResponsiveBreakpoint.desktop: ResponsiveFlexLayout(
      direction: ResponsiveDirection.row,
      gap: 24,
    ),
  },
  children: [
    Heading(1, 'Responsive content'),
    Text('The semantic element stays the same at every width.'),
  ],
)
```

The UI converter emits deterministic, mobile-first CSS media queries and a generated `data-sparrow-responsive` marker. SSR places the stylesheet in the document head; browser rendering installs the same stylesheet, and hydration reuses SSR markup and styles without changing the body tree. Breakpoint values are CSS viewport minimum widths, not Flutter device classes. The responsive flex container controls direction, gap, and alignment; responsive spacing and grid values are described below. This remains a focused CSS layout API, not a general layout engine or adaptive widget system.

## Layout primitives

The layout primitives below lower to ordinary HTML elements and CSS in the
same UI/markup pipeline:

```dart
Row(
  children: [
    Expanded(
      flex: 2,
      child: Padding(
        insets: const Insets.symmetric(vertical: 8, horizontal: 12),
        child: const Text('Flexible content'),
      ),
    ),
    Flexible(
      child: const SizedBox(width: 24, height: 24),
    ),
  ],
)
```

- `Insets.all`, `Insets.symmetric`, and `Insets.only` define four-sided
  spacing. `Padding` rejects negative values; `Margin` accepts finite negative
  values. Their `responsiveInsets` parameter accepts a
  `ResponsiveValue<Insets>` with a required mobile value and optional tablet
  and desktop overrides.
- `Expanded(flex: n)` emits a flex item with `flex-grow: n`, shrink enabled,
  and a zero-percent basis. `Flexible` emits `flex-grow: 0`,
  `flex-shrink: 1`, and an `auto` basis, so it can shrink when needed without
  growing to consume free space. Both must be direct children of `Row`,
  `Column`, or `Responsive`.
- `SizedBox` applies optional width and height in pixels. Without a child it
  can serve as a spacer, but at least one dimension is required.
- `Stack` establishes a relative positioning context and layers ordinary
  children in one CSS Grid cell. A `Positioned` child is absolutely positioned
  from any provided top/right/bottom/left offsets and optional dimensions.
  `Positioned` must be a direct child of `Stack` and requires at least one
  offset. Set Stack dimensions explicitly when its children are all positioned.
- `Grid` uses equal-width `repeat(n, minmax(0, 1fr))` columns and a pixel gap.
  `responsiveColumns` and `responsiveGap` accept `ResponsiveValue` and reuse
  the existing mobile/tablet/desktop breakpoints.

```dart
Padding(
  responsiveInsets: const ResponsiveValue(
    mobile: Insets.symmetric(vertical: 8, horizontal: 12),
    tablet: Insets.symmetric(vertical: 16, horizontal: 24),
  ),
  child: Grid(
    responsiveColumns: const ResponsiveValue(
      mobile: 1,
      tablet: 2,
      desktop: 4,
    ),
    responsiveGap: const ResponsiveValue(
      mobile: 12,
      tablet: 16,
      desktop: 24,
    ),
    children: const [Text('One'), Text('Two'), Text('Three')],
  ),
)
```

Responsive padding, margin, and grid values are emitted as deterministic
mobile-first CSS in the server document head. They use the existing shared
stylesheet installation and cleanup path in browser rendering and hydration.
When using responsive values, do not provide a custom inline `style` on that
same primitive; Sparrow Kit owns the declarations and selector marker so
server and client output stay consistent.

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
browser smoke checks hydration without root replacement, responsive stylesheet
reuse, the new layout primitives, leaf text updates, component mounting, and
cleanup after disposal. The `Responsive browser smoke` GitHub Actions workflow
uses the CI harness to run it at 375px, 768px, and 1440px, checking computed
direction, gap, alignment, padding, margin, and grid values. The SSR smoke
verifies semantic tags, layout CSS, signal serialization, and event-bearing
controls.
