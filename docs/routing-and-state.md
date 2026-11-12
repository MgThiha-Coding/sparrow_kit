# Routing and state management

## Browser routing

`Router` matches the current pathname against `RouteDefinition` values and listens for `popstate` and `hashchange`. On construction it resolves the current browser URL, including its query parameters and fragment, so direct deep links initialize the same route state as in-app navigation. Static paths take precedence over parameterized paths with the same segment count. A match with no route has `isNotFound == true`.

```dart
import 'package:sparrow_kit/sparrow_kit.dart';

final router = Router(
  routes: [
    RouteDefinition('/'),
    RouteDefinition('/products/:productId'),
    RouteDefinition('/search'),
  ],
);

final stop = effect(() {
  final match = router.currentRoute.value;
  if (match.isNotFound) {
    print('Not found: ${match.path}');
  } else {
    print(
      'Route: ${match.path}; params: ${match.params}; '
      'query: ${match.queryParameters}; fragment: ${match.fragment}',
    );
  }
});

router.push('/products/42?tab=overview');
router.push('/search?q=sparrow&page=2');
```

`push()` accepts a same-origin path, including query parameters and fragments, and updates the History API and route signals. Query-only and fragment-only values such as `?page=2` and `#details` apply to the current path; other relative paths are resolved from the origin root. Browser back/forward navigation also updates route state. `router.param('productId')` and `router.queryParam('page')` return synchronized `Signal<String?>` values; `router.params` and `router.queryParameters` expose the corresponding full maps as signals. `RouteMatch` contains the normalized path, path parameters, query parameters, and fragment.

Link interception is enabled by default. The router handles unmodified primary clicks on same-origin links with no download, `rel="external"`, non-self target, or fragment destination. Modified clicks, external links, and fragment links remain native browser navigation; this preserves new-tab behavior and in-page anchor scrolling. Pass `interceptLinks: false` to disable delegated document-level interception. Dispose the router when its owning app is torn down so its listeners are removed.

The router resolves paths; the application maps `currentRoute` to page components or a not-found view. It does not impose a page-loading or route-component convention.

Dispose resources when the owning application is torn down:

```dart
stop();
router.dispose();
```

### Direct links on Vercel

The repository-root `vercel.json` rewrites unmatched paths to `/index.html` so the static app shell can boot on a direct route such as `/products/42`. Configure the Vercel project so its deployment output contains the app's `index.html` at its root, plus static assets such as `/data/projects.json`. Verify both `/` and a nested route with a hard refresh after deployment.

## State

Use `Signal<T>` for mutable state and `effect()` for work that should rerun when its signal dependencies change. Keep UI-only state in its component. Put state shared across a feature in a feature-owned store and pass that store or its signals to the components that need them; reserve app-level stores for genuinely app-wide state. Avoid hidden global singletons so ownership and disposal remain explicit.

Prefer passing a signal to a DSL child, attribute, or style for a targeted DOM update. Reading `.value` inside a component render makes the component depend on that signal and rerender when it changes. Use `batch()` when one action changes multiple related signals. Replace collection values rather than mutating and reassigning the same instance, since equal-value assignments do not notify dependents.

Effects created in a component render are scoped to that render. Keep long-lived effects and resources with the component, feature, or app that owns them, and retain and call their disposers when that owner is torn down.

`Component.createState<T>()` creates a signal associated with a component. For SSR, use stable signal IDs with `SignalText` or `SignalAttribute`; the server serializes those values and the client restores them through `HydrationState.signal()`. See [SSR, hydration, and SEO](ssr-and-seo.md).
