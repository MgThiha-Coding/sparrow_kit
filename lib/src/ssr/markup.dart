import '../reactivity/signals.dart';

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
  })  : attributes = Map<String, Object?>.unmodifiable(attributes),
        children = _normalizeChildren(children),
        events = Map<String, MarkupEventHandler>.unmodifiable(events) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9-]*$').hasMatch(tag)) {
      throw ArgumentError.value(tag, 'tag', 'Invalid HTML tag name.');
    }
  }

  final String tag;
  final Map<String, Object?> attributes;
  final List<MarkupNode> children;
  final Map<String, MarkupEventHandler> events;
}

abstract interface class SsrComponent {
  MarkupNode render();
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

void _validateSignalId(String id) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid signal identifier.');
  }
}
