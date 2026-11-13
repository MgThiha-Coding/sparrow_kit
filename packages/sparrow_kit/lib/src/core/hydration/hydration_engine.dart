import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../reactivity/signals.dart';
import '../../rendering/dom_patcher.dart';
import '../../rendering/dom_stylesheets.dart';
import '../../rendering/markup_dom_fragment.dart';
import '../ssr/markup.dart';

class HydrationState {
  HydrationState(Map<String, Object?> values)
      : _values = Map<String, Object?>.unmodifiable(values);

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

  Signal<T> signal<T>(
    String id, {
    required T fallback,
    T Function(Object?)? decode,
  }) {
    final existing = _signals[id];
    if (existing != null) {
      if (existing is! Signal<T>) {
        throw StateError(
          'Hydration signal "$id" was requested with inconsistent types.',
        );
      }
      return existing;
    }

    final rawValue = _values[id];
    final value = _values.containsKey(id)
        ? decode == null
            ? rawValue
            : decode(rawValue)
        : fallback;
    if (value is! T) {
      throw FormatException(
        'Serialized value for hydration signal "$id" is not a ${T.toString()}.',
      );
    }
    final signal = Signal<T>(value);
    _signals[id] = signal;
    return signal;
  }
}

class HydrationEngine {
  static final Expando<Object> _activeHydrations =
      Expando<Object>('SparrowKit active hydration');

  void Function() hydrate({
    required web.Element container,
    required MarkupNode tree,
  }) {
    if (_activeHydrations[container] != null) {
      throw StateError('This container is already being hydrated.');
    }
    final hydrationToken = Object();
    _activeHydrations[container] = hydrationToken;

    final cleanups = <void Function()>[];
    try {
      cleanups.add(installMarkupStylesheets(tree));
      final nextNode =
          _hydrateNode(container.firstChild, tree, cleanups, 'root');
      if (nextNode != null) {
        throw StateError('Unexpected DOM node after the hydrated root.');
      }
    } catch (error, stackTrace) {
      _activeHydrations[container] = null;
      try {
        _runCleanups(cleanups);
      } catch (cleanupError, cleanupStackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'Hydration failed: $error. Cleanup also failed: $cleanupError.',
          ),
          cleanupStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    var isDisposed = false;
    return () {
      if (isDisposed) return;
      isDisposed = true;
      try {
        _runCleanups(cleanups);
      } finally {
        if (identical(_activeHydrations[container], hydrationToken)) {
          _activeHydrations[container] = null;
        }
      }
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
        final initialValue = ReactiveContext.untracked(() => signal.value);
        if (textNode.data != _textValue(initialValue)) {
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
      case MarkupKeyedChildren():
        return _hydrateKeyedChildren(node, template, cleanups, path);
      case MarkupElement(
          :final tag,
          :final attributes,
          :final children,
          :final events,
        ):
        if (node is! web.Element || node.localName != tag.toLowerCase()) {
          final actual = node is web.Element
              ? '<${node.localName}>'
              : node.nodeType == 3
                  ? 'text node'
                  : node.nodeType == 8
                      ? 'comment'
                      : 'node type ${node.nodeType}';
          throw StateError('Expected <$tag> at $path, found $actual.');
        }

        for (final attribute in attributes.entries) {
          final value = attribute.value;
          final initialValue = value is SignalAttribute
              ? ReactiveContext.untracked(() => value.signal.value)
              : value;
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

  web.Node? _hydrateKeyedChildren(
    web.Node? node,
    MarkupKeyedChildren template,
    List<void Function()> cleanups,
    String path,
  ) {
    if (node is! web.Comment || node.data != 'fw:children:${template.id}') {
      throw StateError('Keyed children marker mismatch at $path.');
    }

    final mountedItems = <String, _HydratedKeyedItem>{};
    cleanups.add(() {
      for (final item in mountedItems.values.toList().reversed) {
        _runCleanups(item.cleanups);
      }
      mountedItems.clear();
    });
    var installedStylesheet = template.stylesheet;
    void Function()? disposeDynamicStylesheet;
    cleanups.add(() => disposeDynamicStylesheet?.call());

    var childNode = node.nextSibling;
    for (final item in template.initialItems) {
      if (childNode is! web.Element ||
          childNode.localName != template.itemTag.toLowerCase() ||
          childNode.getAttribute('data-sparrow-key') != item.key) {
        throw StateError(
          'Keyed child "${item.key}" mismatch at $path.',
        );
      }
      final itemCleanups = <void Function()>[];
      late final web.Node? nextNode;
      try {
        nextNode = _hydrateNode(
          childNode.firstChild,
          item.node,
          itemCleanups,
          '$path/${template.id}[${item.key}]',
        );
      } catch (_) {
        _runCleanups(itemCleanups);
        rethrow;
      }
      if (nextNode != null) {
        _runCleanups(itemCleanups);
        throw StateError(
          'Unexpected child node for keyed child "${item.key}" at $path.',
        );
      }
      mountedItems[item.key] = _HydratedKeyedItem(
        element: childNode,
        node: item.node,
        cleanups: itemCleanups,
      );
      childNode = childNode.nextSibling;
    }

    if (childNode is! web.Comment ||
        childNode.data != 'fw:/children:${template.id}') {
      throw StateError('Keyed children end marker mismatch at $path.');
    }
    final endMarker = childNode;

    cleanups.add(
      effect(() {
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
        _reconcileKeyedChildren(
          template,
          desiredItems,
          mountedItems,
          endMarker,
          path,
        );
      }),
    );
    return endMarker.nextSibling;
  }

  void _reconcileKeyedChildren(
    MarkupKeyedChildren template,
    List<MarkupKeyedItem> desiredItems,
    Map<String, _HydratedKeyedItem> mountedItems,
    web.Comment endMarker,
    String path,
  ) {
    final desiredKeys = {for (final item in desiredItems) item.key};
    final parent = endMarker.parentNode;
    if (parent == null) {
      throw StateError('Keyed children were detached at $path.');
    }

    for (final key in mountedItems.keys.toList()) {
      if (desiredKeys.contains(key)) continue;
      final removed = mountedItems.remove(key)!;
      _runCleanups(removed.cleanups);
      removed.element.remove();
    }

    for (final item in desiredItems) {
      var mounted = mountedItems[item.key];
      if (mounted == null) {
        mounted = _createKeyedItem(template, item, path);
        mountedItems[item.key] = mounted;
      } else if (!markupNodeEquals(mounted.node, item.node)) {
        final replacement = _createKeyedItem(template, item, path);
        _runCleanups(mounted.cleanups);
        while (mounted.element.firstChild != null) {
          mounted.element.removeChild(mounted.element.firstChild!);
        }
        while (replacement.element.firstChild != null) {
          mounted.element.appendChild(replacement.element.firstChild!);
        }
        mounted.node = item.node;
        mounted.cleanups = replacement.cleanups;
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

  _HydratedKeyedItem _createKeyedItem(
    MarkupKeyedChildren template,
    MarkupKeyedItem item,
    String path,
  ) {
    final element = web.document.createElement(template.itemTag);
    element.setAttribute('data-sparrow-key', item.key);
    final itemCleanups = <void Function()>[];
    try {
      itemCleanups.add(installMarkupStylesheets(item.node));
      appendMarkupDomFragment(item.node, element);
      final nextNode = _hydrateNode(
        element.firstChild,
        item.node,
        itemCleanups,
        '$path/${template.id}[${item.key}]',
      );
      if (nextNode != null) {
        throw StateError(
          'Unexpected child node for keyed child "${item.key}" at $path.',
        );
      }
      return _HydratedKeyedItem(
        element: element,
        node: item.node,
        cleanups: itemCleanups,
      );
    } catch (_) {
      _runCleanups(itemCleanups);
      element.remove();
      rethrow;
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

class _HydratedKeyedItem {
  _HydratedKeyedItem({
    required this.element,
    required this.node,
    required this.cleanups,
  });

  final web.Element element;
  MarkupNode node;
  List<void Function()> cleanups;
}

void _runCleanups(List<void Function()> cleanups) {
  Object? firstError;
  StackTrace? firstStackTrace;
  for (final cleanup in cleanups.reversed) {
    try {
      cleanup();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
  }
  cleanups.clear();
  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace!);
  }
}

String _textValue(Object? value) => value?.toString() ?? '';

String? _attributeValue(Object? value) {
  if (value == null || value == false) return null;
  return value == true ? '' : value.toString();
}
