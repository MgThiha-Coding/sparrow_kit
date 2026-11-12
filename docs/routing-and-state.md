# Routing and state management

## Browser routing

`Router` matches `window.location.pathname` against `RouteDefinition` values and listens for `popstate`. Static paths take precedence over parameterized paths with the same segment count. A match with no route has `isNotFound == true`.

```dart
import 'package:sparrow_kit/sparrow_kit.dart';

final router = Router(
  routes: [
    RouteDefinition('/'),
    RouteDefinition('/products/:productId'),
  ],
);

final stop = effect(() {
  final match = router.currentRoute.value;
  if (match.isNotFound) {
    print('Not found: ${match.path}');
  } else {
    print('Route: ${match.path}; params: ${match.params}');
  }
});

router.push('/products/42');
```

`push()` accepts a same-origin path and updates the History API and route signals. Browser back/forward navigation also updates those signals. `router.param('productId')` returns a `Signal<String?>` that stays synchronized with the current route; `router.params` exposes the full parameter map as a signal.

The router resolves paths; the application maps `currentRoute` to page components or a not-found view. It does not impose a page-loading or route-component convention.

Dispose resources when the owning application is torn down:

```dart
stop();
router.dispose();
```

## State

Use `Signal<T>` for mutable state and `effect()` for work that should rerun when its signal dependencies change. Keep state near the component or feature that owns it, pass signals to children when they need shared state, and retain disposers for effects that outlive a render scope.

`Component.createState<T>()` creates a signal associated with a component. For SSR, use stable signal IDs with `SignalText` or `SignalAttribute`; the server serializes those values and the client restores them through `HydrationState.signal()`. See [SSR, hydration, and SEO](ssr-and-seo.md).
