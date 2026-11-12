import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../api/component.dart' show ComponentState, component;
import '../core/ssr/markup.dart';
import '../reactivity/signals.dart' show Signal, onCleanup;
import '../rendering/component.dart' as runtime;
import '../rendering/dom_patcher.dart';
import 'ui.dart';

class DomUiRenderer {
  DomUiRenderer();

  final List<void Function()> _cleanups = [];
  web.Node? _root;
  bool _isDisposed = false;

  web.Node render(UiNode description) {
    if (_root != null) {
      throw StateError('A UI renderer can only render once.');
    }

    try {
      final root = _renderNode(toMarkupNode(description));
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
      MarkupElement(
        :final tag,
        :final attributes,
        :final children,
        :final events,
      ) =>
        _renderElement(tag, attributes, children, events),
    };
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
