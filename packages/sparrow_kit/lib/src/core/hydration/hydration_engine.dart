import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../reactivity/signals.dart';
import '../../rendering/dom_patcher.dart';
import '../ssr/markup.dart';

class HydrationState {
  HydrationState(Map<String, Object?> values) : _values = values;

  factory HydrationState.fromDocument() {
    final script = web.document.getElementById('__FRAMEWORK_STATE__');
    if (script is! web.HTMLScriptElement) {
      throw StateError('Serialized framework state was not found.');
    }

    final decoded = jsonDecode(script.textContent ?? '');
    if (decoded is! Map) {
      throw FormatException(
          'Serialized framework state must be a JSON object.');
    }
    return HydrationState(Map<String, Object?>.from(decoded));
  }

  final Map<String, Object?> _values;
  final Map<String, Signal<dynamic>> _signals = {};

  Signal<T> signal<T>(String id, {required T fallback}) {
    final existing = _signals[id];
    if (existing != null) return existing as Signal<T>;

    final value = _values.containsKey(id) ? _values[id] as T : fallback;
    final signal = Signal<T>(value);
    _signals[id] = signal;
    return signal;
  }
}

class HydrationEngine {
  void Function() hydrate({
    required web.Element container,
    required MarkupNode tree,
  }) {
    final cleanups = <void Function()>[];
    try {
      final nextNode =
          _hydrateNode(container.firstChild, tree, cleanups, 'root');
      if (nextNode != null) {
        throw StateError('Unexpected DOM node after the hydrated root.');
      }
    } catch (_) {
      _runCleanups(cleanups);
      rethrow;
    }

    var isDisposed = false;
    return () {
      if (isDisposed) return;
      isDisposed = true;
      _runCleanups(cleanups);
    };
  }

  web.Node? _hydrateNode(
    web.Node? node,
    MarkupNode template,
    List<void Function()> cleanups,
    String path,
  ) {
    if (node == null) {
      throw StateError('Missing server-rendered node at $path.');
    }

    switch (template) {
      case MarkupText(:final value):
        if (node is! web.Text || node.data != value) {
          throw StateError('Text mismatch at $path.');
        }
        return node.nextSibling;
      case SignalText(:final id, :final signal):
        if (node is! web.Comment || node.data != 'fw:text:$id') {
          throw StateError('Signal text marker mismatch at $path.');
        }
        final textNode = node.nextSibling;
        if (textNode is! web.Text) {
          throw StateError('Missing signal text node at $path.');
        }
        if (textNode.data != _textValue(signal.value)) {
          throw StateError('Signal text value mismatch at $path.');
        }
        final endMarker = textNode.nextSibling;
        if (endMarker is! web.Comment || endMarker.data != 'fw:/text:$id') {
          throw StateError('Signal text end marker mismatch at $path.');
        }
        cleanups.add(
          effect(() {
            textNode.data = _textValue(signal.value);
          }),
        );
        return endMarker.nextSibling;
      case MarkupElement(
          :final tag,
          :final attributes,
          :final children,
          :final events,
        ):
        if (node is! web.Element || node.localName != tag.toLowerCase()) {
          throw StateError('Expected <$tag> at $path.');
        }

        for (final attribute in attributes.entries) {
          final value = attribute.value;
          final initialValue =
              value is SignalAttribute ? value.signal.value : value;
          if (node.getAttribute(attribute.key) !=
              _attributeValue(initialValue)) {
            throw StateError(
                'Attribute mismatch for "${attribute.key}" at $path.');
          }
          if (value is SignalAttribute) {
            _bindAttribute(node, attribute.key, value.signal, cleanups);
          }
        }

        var childNode = node.firstChild;
        for (var index = 0; index < children.length; index++) {
          childNode = _hydrateNode(
            childNode,
            children[index],
            cleanups,
            '$path/$tag[$index]',
          );
        }
        if (childNode != null) {
          throw StateError('Unexpected child node at $path.');
        }

        for (final event in events.entries) {
          final listener = ((web.Event value) => event.value(value)).toJS;
          node.addEventListener(event.key, listener);
          cleanups.add(() => node.removeEventListener(event.key, listener));
        }
        return node.nextSibling;
    }
  }

  void _bindAttribute(
    web.Element element,
    String name,
    Signal<dynamic> signal,
    List<void Function()> cleanups,
  ) {
    cleanups.add(bindAttribute(element, name, () => signal.value));
  }
}

void _runCleanups(List<void Function()> cleanups) {
  for (final cleanup in cleanups.reversed) {
    cleanup();
  }
  cleanups.clear();
}

String _textValue(Object? value) => value?.toString() ?? '';

String? _attributeValue(Object? value) {
  if (value == null || value == false) return null;
  return value == true ? '' : value.toString();
}
