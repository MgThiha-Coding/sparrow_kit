import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../api/component.dart' show ComponentState, component;
import '../core/hydration/hydration_engine.dart';
import '../core/ssr/markup.dart';
import '../reactivity/signals.dart' show Signal, effect, onCleanup;
import '../rendering/component.dart' as runtime;
import '../rendering/dom_patcher.dart';
import '../rendering/dom_stylesheets.dart';
import '../rendering/markup_dom_fragment.dart';
import 'ui.dart';

class DomUiRenderer {
  DomUiRenderer();

  final List<void Function()> _cleanups = [];
  web.Node? _root;
  bool _isDisposed = false;

  web.Node render(UiNode description) {
    return renderMarkupTree(toMarkupNode(description));
  }

  web.Node renderMarkupTree(MarkupNode tree) {
    if (_root != null) {
      throw StateError('A UI renderer can only render once.');
    }

    try {
      _cleanups.add(installMarkupStylesheets(tree));
      final root = _renderNode(tree);
      _root = root;
      return root;
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  void mount(UiNode description, web.Element host) {
    final root = render(description);
    host.appendChild(root);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final cleanup in _cleanups.reversed) {
      cleanup();
    }
    _cleanups.clear();
    _root?.parentNode?.removeChild(_root!);
    _root = null;
  }

  web.Node _renderNode(MarkupNode node) {
    return switch (node) {
      MarkupText(:final value) => web.document.createTextNode(value),
      SignalText(:final signal) => _renderSignalText(signal),
      MarkupKeyedChildren keyedChildren => _renderKeyedChildren(keyedChildren),
      MarkupElement(
        :final tag,
        :final attributes,
        :final children,
        :final events,
      ) =>
        _renderElement(tag, attributes, children, events),
    };
  }

  web.Node _renderKeyedChildren(MarkupKeyedChildren template) {
    final fragment = web.document.createDocumentFragment();
    final startMarker =
        web.document.createComment('fw:children:${template.id}');
    final endMarker = web.document.createComment('fw:/children:${template.id}');
    fragment
      ..appendChild(startMarker)
      ..appendChild(endMarker);
    final mountedItems = <String, _RenderedKeyedItem>{};
    var installedStylesheet = template.stylesheet;
    void Function()? disposeDynamicStylesheet;

    void reconcile() {
      final desiredItems = template.buildItems();
      final stylesheet = template.stylesheet;
      if (stylesheet != installedStylesheet) {
        disposeDynamicStylesheet?.call();
        disposeDynamicStylesheet = stylesheet == null || stylesheet.isEmpty
            ? null
            : installMarkupStylesheets(
                MarkupElement('div', stylesheets: [stylesheet]),
              );
        installedStylesheet = stylesheet;
      }
      final desiredKeys = {for (final item in desiredItems) item.key};
      final parent = endMarker.parentNode;
      if (parent == null) {
        throw StateError('Keyed children were detached before rendering.');
      }

      for (final key in mountedItems.keys.toList()) {
        if (desiredKeys.contains(key)) continue;
        final removed = mountedItems.remove(key)!;
        removed.dispose();
        removed.element.remove();
      }

      for (final item in desiredItems) {
        var mounted = mountedItems[item.key];
        if (mounted == null) {
          mounted = _createKeyedItem(template, item);
          mountedItems[item.key] = mounted;
        } else if (!markupNodeEquals(mounted.node, item.node)) {
          final replacement = _createKeyedItem(template, item);
          mounted.dispose();
          while (mounted.element.firstChild != null) {
            mounted.element.removeChild(mounted.element.firstChild!);
          }
          while (replacement.element.firstChild != null) {
            mounted.element.appendChild(replacement.element.firstChild!);
          }
          mounted
            ..node = item.node
            ..dispose = replacement.dispose;
        }
      }

      web.Node nextNode = endMarker;
      for (final item in desiredItems.reversed) {
        final element = mountedItems[item.key]!.element;
        if (!identical(element.nextSibling, nextNode)) {
          parent.insertBefore(element, nextNode);
        }
        nextNode = element;
      }
    }

    void disposeItems() {
      for (final item in mountedItems.values.toList().reversed) {
        item.dispose();
      }
      mountedItems.clear();
    }

    late final void Function() disposeEffect;
    try {
      disposeEffect = effect(reconcile);
    } catch (_) {
      disposeItems();
      rethrow;
    }
    _cleanups.add(() {
      disposeEffect();
      disposeDynamicStylesheet?.call();
      disposeItems();
    });
    return fragment;
  }

  _RenderedKeyedItem _createKeyedItem(
    MarkupKeyedChildren template,
    MarkupKeyedItem item,
  ) {
    final element = web.document.createElement(template.itemTag);
    element.setAttribute('data-sparrow-key', item.key);
    appendMarkupDomFragment(item.node, element);
    final dispose = HydrationEngine().hydrate(
      container: element,
      tree: item.node,
    );
    return _RenderedKeyedItem(
      element: element,
      node: item.node,
      dispose: dispose,
    );
  }

  web.Node _renderSignalText(Signal<dynamic> signal) {
    final text = web.document.createTextNode('');
    _cleanups.add(bindText(text, () => signal.value));
    return text;
  }

  web.Node _renderElement(
    String tag,
    Map<String, Object?> attributes,
    List<MarkupNode> children,
    Map<String, MarkupEventHandler> events,
  ) {
    final element = web.document.createElement(tag);
    final isVoid = _voidElements.contains(tag.toLowerCase());
    if (isVoid && children.isNotEmpty) {
      throw ArgumentError('Void element <$tag> cannot have children.');
    }

    for (final attribute in attributes.entries) {
      _validateAttributeName(attribute.key);
      if (attribute.key.toLowerCase().startsWith('on')) {
        throw ArgumentError.value(
          attribute.key,
          'attribute',
          'Inline event attributes are not supported.',
        );
      }

      final value = attribute.value;
      if (value is SignalAttribute) {
        _cleanups.add(
          bindAttribute(element, attribute.key, () => value.signal.value),
        );
      } else {
        patchAttribute(element, attribute.key, value);
      }
    }

    for (final child in children) {
      element.appendChild(_renderNode(child));
    }

    for (final event in events.entries) {
      final listener = ((web.Event value) => event.value(value)).toJS;
      element.addEventListener(event.key, listener);
      _cleanups.add(() => element.removeEventListener(event.key, listener));
    }

    return element;
  }
}

class _RenderedKeyedItem {
  _RenderedKeyedItem({
    required this.element,
    required this.node,
    required this.dispose,
  });

  final web.Element element;
  MarkupNode node;
  void Function() dispose;
}

typedef UiComponentBuilder<P> = UiNode Function(
  ComponentState state,
  P props,
);

class UiComponentDefinition<P> {
  const UiComponentDefinition(this._build);

  final UiComponentBuilder<P> _build;

  runtime.Component<P> call(P props) => component<P>(
        (state, props) => renderUi(_build(state, props)),
      )(props);
}

UiComponentDefinition<P> uiComponent<P>(UiComponentBuilder<P> build) =>
    UiComponentDefinition<P>(build);

web.Node renderUi(UiNode description) {
  final renderer = DomUiRenderer();
  final root = renderer.render(description);
  onCleanup(renderer.dispose);
  return root;
}

web.Node renderMarkup(MarkupNode description) {
  final renderer = DomUiRenderer();
  final root = renderer.renderMarkupTree(description);
  onCleanup(renderer.dispose);
  return root;
}

void Function() mountUi(
  UiNode description, {
  String rootSelector = '#app',
}) {
  final host = web.document.querySelector(rootSelector);
  if (host == null) {
    throw StateError('No element found for selector "$rootSelector".');
  }

  final renderer = DomUiRenderer();
  try {
    renderer.mount(description, host);
  } catch (_) {
    renderer.dispose();
    rethrow;
  }
  return renderer.dispose;
}

void _validateAttributeName(String name) {
  if (!RegExp(r'^[A-Za-z_:][A-Za-z0-9:._-]*$').hasMatch(name)) {
    throw ArgumentError.value(
        name, 'attribute', 'Invalid HTML attribute name.');
  }
}

const _voidElements = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};
