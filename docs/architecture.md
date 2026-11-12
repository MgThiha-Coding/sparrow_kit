# Core architecture

The framework package is `packages/sparrow_kit`. Browser code should import `package:sparrow_kit/sparrow_kit.dart` for components, DOM APIs, signals, routing, hydration, SEO, and shared SSR types. Focused entry points remain available when only a subset is needed. `package:sparrow_kit/server.dart` adds `dart:io` static-site generation and should only be imported by server-side code. Application code belongs in an application workspace such as `apps/web_app`, not in `lib/src`.

## Direct DOM rendering

Sparrow Kit uses `package:web` and creates real browser nodes. `element()`, `div()`, `button()`, and the other DSL helpers return `HTMLElement` instances that can be appended directly. Attributes, styles, classes, and events are applied to those nodes; the framework does not construct or diff a virtual DOM tree for browser rendering. Signal-bound text, attributes, and styles use targeted patches that compare the requested value to the live DOM value and skip unchanged writes. A signal used as a child updates its text node without rebuilding sibling nodes or lists. A signal read by a component's `render()` still reruns that component, so use leaf bindings for frequently changing values.

The lower-level `createElement()` and `createButton()` functions are available from `core.dart` as well. Prefer the declarative DSL for normal application code:

```dart
final card = element(
  'article',
  classes: const ['card'],
  attributes: {'aria-label': 'Product'},
  children: [
    h2(children: const ['Product']),
    p(children: const ['Available now']),
  ],
);
```

The restricted `package:sparrow_kit/ui.dart` API provides Dart-native `Text`,
`Heading`, `Row`, `Column`, `Container`, and `Button` descriptions. It is not
Flutter widget compatibility. These platform-neutral descriptions lower to the
same `MarkupNode` model used by SSR and hydration; `mountUi()` renders them as
DOM and `hydrateUiApp()` attaches to server HTML. See
[UI contract and web build](ui-contract-and-build.md) for the subset and CLI.

## Fine-grained reactivity

`Signal<T>` stores a value and notifies only effects that read it. Setting an equal value is a no-op, so replace collection values instead of mutating and reassigning the same instance. `effect()` runs once immediately, tracks signal reads during that run, and returns a disposer. Later invalidations are deduplicated and flushed in a microtask, so synchronous writes made before that flush trigger an effect at most once:

```dart
Future<void> main() async {
  final status = Signal<String>('Loading');
  final stop = effect(() {
    print(status.value);
  });

  batch(() {
    status.value = 'Preparing';
    status.value = 'Ready';
  });
  await Future<void>.delayed(Duration.zero);
  stop();
}
```

`batch()` nests safely and delays scheduling until the outer batch completes. Updates outside an explicit batch use the same microtask scheduler. The DSL binds signal children to text nodes and signal-valued attributes/styles to the corresponding DOM property. These bindings update without rebuilding unrelated nodes. Reading a signal directly inside a component's `render()` makes that component's render effect depend on it.

Prefer a leaf binding for frequently changing values. Passing a signal as a child, attribute, or style lets the DSL update that DOM value directly. Reading `.value` while building a component makes the component depend on the signal; an update reruns the component render and replaces its root. This is appropriate when the whole component should change, but avoid it for small, frequent updates such as counters or progress values.

Replace collection values to notify dependents:

```dart
final items = Signal<List<String>>([]);

void addItem(String item) {
  items.value = [...items.value, item];
}
```

Use `batch()` when multiple signal writes form one logical state change. Effects are scheduled once per flush, but batching also makes the update boundary explicit:

```dart
final page = Signal<int>(1);
final loading = Signal<bool>(false);
const nextPage = 2;

batch(() {
  page.value = nextPage;
  loading.value = true;
});
```

This dependency model is intentionally narrower than stream broadcasting: a signal stores subscribers that actually read it, without allocating per-signal stream controllers or delivering values to unrelated listeners. Unlike virtual-DOM rendering, an update invokes affected effects and patches their bound DOM directly instead of diffing a component tree.

Run `dart run tool/reactivity_smoke.dart` from the monorepo root for a dependency-free check of batching, dependency retracking, disposal, and effect-scope cleanup.

## Component lifecycle and cleanup

`Component<P>` owns a rendered root and its child components. `mount()` or `mountInto()` attaches it once. Override `onMount()`, `onUpdate()`, and `onDispose()` for lifecycle work; `createState<T>()` is a component-scoped convenience for a `Signal<T>`.

Event listeners and reactive work created during a component render are registered in that render's cleanup scope. They are released when the render is replaced and when the component is disposed. `dispose()` also removes the component tree. Put resources that should live for the mounted component's lifetime in `onMount()` and explicitly release them in `onDispose()`; app- or feature-level resources should be released by their owning app or feature.

## Functional component API

For new components, `component<P>()` creates a reusable immutable definition from one builder function. Each invocation with props creates an independently mounted component instance:

```dart
class GreetingProps {
  const GreetingProps(this.name);

  final String name;
}

final greeting = component<GreetingProps>((state, props) {
  final visits = state.use(0);

  return div(
    children: [
      p(children: ['Hello ${props.name}']),
      button(
        children: ['Visits: ', visits],
        onClick: (_) => visits.value++,
      ),
    ],
  );
});

final page = main(
  children: [
    greeting(const GreetingProps('Sparrow Kit')),
  ],
);
```

Props are passed through as the original typed object; Sparrow Kit does not convert them to a map or clone them. Prefer immutable, typed props. `state.use(initialValue)` returns the same signal for that hook slot across renders and uses the initial value only when the instance is created. Hooks must be called synchronously in the same order and with the same types on every render. Keep state hooks unconditional so their slot order remains stable.

The public `ComponentDefinition<P>` stores only the builder reference. For this initial implementation, mounted instances adapt the existing `Component<P>` lifecycle so functional components compose with existing DOM child mounting, effect scopes, and disposal. That adapter carries the current runtime's per-instance bookkeeping; a separate lean mount runtime should only replace it after profiling, not by bypassing cleanup semantics.

Use the class-based `Component<P>` directly when lifecycle overrides such as `onMount()`/`onDispose()` are needed. Both APIs are exported by `core.dart`; unused API entry points can be tree-shaken by the Dart compiler.

## Hydration lifecycle

Hydration attaches client effects and event handlers to server-generated HTML without replacing that HTML. `HydrationEngine.hydrate()` checks the existing node, text, and initial attribute values against a `MarkupNode` tree. It throws on a mismatch and removes any bindings installed before the failure. Its returned disposer removes event listeners and reactive effects.

For signals, the SSR renderer emits marker comments and a JSON state script. `hydrateApp()` reads that state, locates `#app`, attaches bindings, and initializes browser head metadata automatically. `runApp()` provides the matching client-rendered bootstrap. The client still supplies the page's markup builder and stable signal IDs; Sparrow Kit cannot infer application UI. See [SSR, hydration, and SEO](ssr-and-seo.md) for the full lifecycle.
