import '../api/bootstrap.dart' show hydrateApp;
import '../core/hydration/hydration_engine.dart' show HydrationState;
import 'ui.dart' show UiNode, toMarkupNode;

export 'dom_renderer.dart' show mountUi, renderMarkup, renderUi, uiComponent;

void Function() hydrateUiApp(
  UiNode Function(HydrationState state) build, {
  String rootId = 'app',
}) =>
    hydrateApp(
      (state) => toMarkupNode(build(state)),
      rootId: rootId,
    );
