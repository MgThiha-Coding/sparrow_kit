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

abstract interface class SsrComponent {
  MarkupNode render();
}

List<String> collectMarkupStylesheets(MarkupNode root) {
  final stylesheets = <String>{};

  void visit(MarkupNode node) {
    if (node is! MarkupElement) return;
    stylesheets
        .addAll(node.stylesheets.where((stylesheet) => stylesheet.isNotEmpty));
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(root);
  return List<String>.unmodifiable(stylesheets);
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

void _validateSignalId(String id) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid signal identifier.');
  }
}
