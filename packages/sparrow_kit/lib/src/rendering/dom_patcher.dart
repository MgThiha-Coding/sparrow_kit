import 'package:web/web.dart' as web;

import '../reactivity/signals.dart' show effect;

/// Reactive bindings already identify the affected DOM leaf, so patching it
/// directly avoids VDOM allocation and tree-diff work for low-memory updates.
void patchText(web.Text node, Object? value) {
  final nextValue = _textValue(value);
  if (node.data != nextValue) {
    node.data = nextValue;
  }
}

void Function() bindText(web.Text node, Object? Function() read) {
  return effect(() => patchText(node, read()));
}

void patchAttribute(web.Element element, String name, Object? value) {
  final nextValue = _attributeValue(value);
  if (element.getAttribute(name) == nextValue) return;

  if (nextValue == null) {
    element.removeAttribute(name);
  } else {
    element.setAttribute(name, nextValue);
  }
}

void Function() bindAttribute(
  web.Element element,
  String name,
  Object? Function() read,
) {
  return effect(() => patchAttribute(element, name, read()));
}

void patchStyle(web.HTMLElement element, String name, Object? value) {
  final nextValue = value?.toString();
  final currentValue = element.style.getPropertyValue(name);
  if (nextValue == null) {
    if (currentValue.isNotEmpty) {
      element.style.removeProperty(name);
    }
  } else if (currentValue != nextValue) {
    element.style.setProperty(name, nextValue);
  }
}

void Function() bindStyle(
  web.HTMLElement element,
  String name,
  Object? Function() read,
) {
  return effect(() => patchStyle(element, name, read()));
}

String? _attributeValue(Object? value) {
  if (value == null || value == false) return null;
  return value == true ? '' : value.toString();
}

String _textValue(Object? value) => value?.toString() ?? '';
