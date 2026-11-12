import '../../reactivity/signals.dart';

typedef MarkupEventHandler = void Function(Object? event);

sealed class MarkupNode {}

class MarkupText extends MarkupNode {
  MarkupText(this.value);

  final String value;
}

class SignalText extends MarkupNode {
  SignalText(this.id, this.signal) {
    _validateSignalId(id);
  }

  final String id;
  final Signal<dynamic> signal;
}

class SignalAttribute {
  SignalAttribute(this.id, this.signal) {
    _validateSignalId(id);
  }

  final String id;
  final Signal<dynamic> signal;
}

class MarkupElement extends MarkupNode {
  MarkupElement(
    this.tag, {
    Map<String, Object?> attributes = const {},
    Iterable<MarkupNode> children = const [],
    Map<String, MarkupEventHandler> events = const {},
    Iterable<String> stylesheets = const [],
  })  : attributes = Map<String, Object?>.unmodifiable(attributes),
        children = _normalizeChildren(children),
        events = Map<String, MarkupEventHandler>.unmodifiable(events),
        stylesheets = List<String>.unmodifiable(stylesheets) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9-]*$').hasMatch(tag)) {
      throw ArgumentError.value(tag, 'tag', 'Invalid HTML tag name.');
    }
  }

  final String tag;
  final Map<String, Object?> attributes;
  final List<MarkupNode> children;
  final Map<String, MarkupEventHandler> events;
  final List<String> stylesheets;
}

class MarkupKeyedItem {
  const MarkupKeyedItem(this.key, this.node);

  final String key;
  final MarkupNode node;
}

class MarkupKeyedChildren extends MarkupNode {
  MarkupKeyedChildren({
    required this.id,
    required this.itemTag,
    required this.source,
    required List<MarkupKeyedItem> Function() buildItems,
    this.stylesheetProvider,
  })  : _buildItems = buildItems,
        initialItems = _validatedKeyedItems(buildItems()) {
    _validateSignalId(id);
    if (!_validTag.hasMatch(itemTag) ||
        _voidElements.contains(itemTag.toLowerCase())) {
      throw ArgumentError.value(
          itemTag, 'itemTag', 'Invalid item element tag.');
    }
  }

  final String id;
  final String itemTag;
  final Signal<dynamic> source;
  final List<MarkupKeyedItem> initialItems;
  final String? Function()? stylesheetProvider;
  final List<MarkupKeyedItem> Function() _buildItems;

  List<MarkupKeyedItem> buildItems() => _validatedKeyedItems(_buildItems());

  String? get stylesheet => stylesheetProvider?.call();
}

abstract interface class SsrComponent {
  MarkupNode render();
}

List<String> collectMarkupStylesheets(MarkupNode root) {
  final stylesheets = <String>{};

  void visit(MarkupNode node) {
    switch (node) {
      case MarkupElement element:
        stylesheets.addAll(
          element.stylesheets.where((stylesheet) => stylesheet.isNotEmpty),
        );
        for (final child in element.children) {
          visit(child);
        }
      case MarkupKeyedChildren(:final initialItems):
        for (final item in initialItems) {
          visit(item.node);
        }
        final stylesheet = node.stylesheet;
        if (stylesheet != null && stylesheet.isNotEmpty) {
          stylesheets.add(stylesheet);
        }
      case MarkupText() || SignalText():
        return;
    }
  }

  visit(root);
  return List<String>.unmodifiable(stylesheets);
}

bool markupNodeEquals(MarkupNode first, MarkupNode second) {
  if (identical(first, second)) return true;
  if (first is MarkupText) {
    return second is MarkupText && first.value == second.value;
  }
  if (first is SignalText) {
    return second is SignalText &&
        first.id == second.id &&
        identical(first.signal, second.signal);
  }
  if (first is MarkupKeyedChildren) {
    return second is MarkupKeyedChildren && _sameKeyedChildren(first, second);
  }
  if (first is MarkupElement) {
    return second is MarkupElement && _sameElement(first, second);
  }
  return false;
}

String markupStylesheetId(String stylesheet) {
  var firstHash = 17;
  var secondHash = 29;
  for (final codeUnit in stylesheet.codeUnits) {
    firstHash = (firstHash * 31 + codeUnit) % 2147483647;
    secondHash = (secondHash * 37 + codeUnit) % 2147483629;
  }
  return 'sparrow-responsive-${firstHash.toRadixString(36)}-'
      '${secondHash.toRadixString(36)}';
}

List<MarkupNode> _normalizeChildren(Iterable<MarkupNode> children) {
  final normalized = <MarkupNode>[];
  for (final child in children) {
    if (child is MarkupText) {
      if (child.value.isEmpty) continue;
      if (normalized.isNotEmpty && normalized.last is MarkupText) {
        final previous = normalized.removeLast() as MarkupText;
        normalized.add(MarkupText('${previous.value}${child.value}'));
      } else {
        normalized.add(child);
      }
    } else {
      normalized.add(child);
    }
  }
  return List<MarkupNode>.unmodifiable(normalized);
}

List<MarkupKeyedItem> _validatedKeyedItems(
  Iterable<MarkupKeyedItem> items,
) {
  final keys = <String>{};
  final result = <MarkupKeyedItem>[];
  for (final item in items) {
    if (item.key.isEmpty) {
      throw ArgumentError.value(item.key, 'key', 'Keys cannot be empty.');
    }
    if (!keys.add(item.key)) {
      throw StateError('Duplicate keyed child key "${item.key}".');
    }
    result.add(item);
  }
  return List<MarkupKeyedItem>.unmodifiable(result);
}

bool _sameKeyedChildren(
  MarkupKeyedChildren first,
  MarkupKeyedChildren second,
) {
  if (first.id != second.id ||
      first.itemTag != second.itemTag ||
      !identical(first.source, second.source) ||
      first.initialItems.length != second.initialItems.length) {
    return false;
  }
  for (var index = 0; index < first.initialItems.length; index++) {
    final left = first.initialItems[index];
    final right = second.initialItems[index];
    if (left.key != right.key || !markupNodeEquals(left.node, right.node)) {
      return false;
    }
  }
  return true;
}

bool _sameElement(MarkupElement first, MarkupElement second) {
  if (first.tag != second.tag ||
      first.attributes.length != second.attributes.length ||
      first.events.length != second.events.length ||
      first.children.length != second.children.length ||
      first.stylesheets.length != second.stylesheets.length) {
    return false;
  }
  for (final entry in first.attributes.entries) {
    if (!second.attributes.containsKey(entry.key) ||
        !_sameAttributeValue(entry.value, second.attributes[entry.key])) {
      return false;
    }
  }
  for (final entry in first.events.entries) {
    if (!identical(entry.value, second.events[entry.key])) return false;
  }
  for (var index = 0; index < first.children.length; index++) {
    if (!markupNodeEquals(first.children[index], second.children[index])) {
      return false;
    }
  }
  for (var index = 0; index < first.stylesheets.length; index++) {
    if (first.stylesheets[index] != second.stylesheets[index]) return false;
  }
  return true;
}

bool _sameAttributeValue(Object? first, Object? second) {
  if (identical(first, second)) return true;
  return first is SignalAttribute &&
      second is SignalAttribute &&
      first.id == second.id &&
      identical(first.signal, second.signal);
}

void _validateSignalId(String id) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid signal identifier.');
  }
}

final _validTag = RegExp(r'^[A-Za-z][A-Za-z0-9-]*$');
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
