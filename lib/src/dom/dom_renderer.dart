import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../reactivity/signals.dart';
import '../runtime/component.dart';

web.HTMLElement createElement(
  String tagName, {
  Iterable<Object?> children = const [],
  Map<String, String> attributes = const {},
}) {
  final element = web.document.createElement(tagName) as web.HTMLElement;

  for (final attribute in attributes.entries) {
    element.setAttribute(attribute.key, attribute.value);
  }
  for (final child in children) {
    _appendChild(element, child);
  }

  return element;
}

web.HTMLButtonElement createButton({
  required Object? child,
  void Function()? onClick,
}) {
  final button = web.document.createElement('button') as web.HTMLButtonElement;
  button.type = 'button';
  _appendChild(button, child);

  if (onClick != null) {
    button.addEventListener('click', ((web.Event _) => onClick()).toJS);
  }

  return button;
}

void _appendChild(web.Element parent, Object? child) {
  if (child == null) return;

  if (child is Iterable<Object?>) {
    for (final nestedChild in child) {
      _appendChild(parent, nestedChild);
    }
    return;
  }

  if (child is Signal<dynamic>) {
    final textNode = web.document.createTextNode(_textValue(child.value));
    parent.appendChild(textNode);
    effect(() {
      textNode.data = _textValue(child.value);
    });
    return;
  }

  if (child is web.Node) {
    parent.appendChild(child);
    return;
  }

  if (child is Component<dynamic>) {
    child.mountInto(parent);
    return;
  }

  parent.appendChild(web.document.createTextNode(_textValue(child)));
}

String _textValue(Object? value) => value?.toString() ?? '';
