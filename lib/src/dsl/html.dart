import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dom/dom_renderer.dart' as dom;
import '../reactivity/signals.dart';

typedef EventHandler = void Function(web.Event event);

web.HTMLElement element(
  String tagName, {
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) {
  final element = dom.createElement(tagName, children: children);
  final attributeValues = Map<String, Object?>.of(attributes);
  final classAttribute = attributeValues.remove('class');

  for (final attribute in attributeValues.entries) {
    _bindAttribute(element, attribute.key, attribute.value);
  }

  if (classAttribute is Signal<dynamic>) {
    _bindAttribute(element, 'class', classAttribute, classes: classes);
  } else {
    final classNames = <String>[
      ...classes,
      if (classAttribute != null && classAttribute.toString().isNotEmpty)
        classAttribute.toString(),
    ];
    if (classNames.isNotEmpty) {
      element.setAttribute('class', classNames.join(' '));
    }
  }

  for (final style in styles.entries) {
    _bindStyle(element, style.key, style.value);
  }
  for (final event in events.entries) {
    _listen(element, event.key, event.value);
  }

  return element;
}

web.HTMLElement div({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'div',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement span({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'span',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement h1({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'h1',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement h2({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'h2',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement p({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'p',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement section({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'section',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement main({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'main',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement nav({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'nav',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLButtonElement button({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
  EventHandler? onClick,
}) {
  final buttonAttributes = Map<String, Object?>.of(attributes);
  buttonAttributes.putIfAbsent('type', () => 'button');
  final button = element(
    'button',
    children: children,
    attributes: buttonAttributes,
    classes: classes,
    styles: styles,
    events: _withEvent(events, 'click', onClick),
  ) as web.HTMLButtonElement;
  return button;
}

web.HTMLInputElement input({
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
  EventHandler? onInput,
  EventHandler? onChange,
}) {
  return element(
    'input',
    attributes: attributes,
    classes: classes,
    styles: styles,
    events: _withEvents(events, {'input': onInput, 'change': onChange}),
  ) as web.HTMLInputElement;
}

web.HTMLElement label({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'label',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement a({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'a',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement ul({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'ul',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

web.HTMLElement li({
  Iterable<Object?> children = const [],
  Map<String, Object?> attributes = const {},
  Iterable<String> classes = const [],
  Map<String, Object?> styles = const {},
  Map<String, EventHandler> events = const {},
}) =>
    element(
      'li',
      children: children,
      attributes: attributes,
      classes: classes,
      styles: styles,
      events: events,
    );

void _bindAttribute(
  web.HTMLElement element,
  String name,
  Object? value, {
  Iterable<String> classes = const [],
}) {
  if (value is Signal<dynamic>) {
    void update() {
      final attributeValue = _attributeValue(
        name,
        classes,
        value: value.value,
      );
      if (attributeValue == null) {
        element.removeAttribute(name);
      } else {
        element.setAttribute(name, attributeValue);
      }
    }

    update();
    effect(update);
    return;
  }

  final attributeValue = _attributeValue(name, classes, value: value);
  if (attributeValue == null) {
    element.removeAttribute(name);
  } else {
    element.setAttribute(name, attributeValue);
  }
}

String? _attributeValue(
  String name,
  Iterable<String> classes, {
  required Object? value,
}) {
  if (value == null) return null;

  if (name == 'class') {
    final names = <String>[
      ...classes,
      if (value.toString().isNotEmpty) value.toString(),
    ];
    return names.isEmpty ? null : names.join(' ');
  }

  return value.toString();
}

void _bindStyle(web.HTMLElement element, String name, Object? value) {
  void update(Object? styleValue) {
    if (styleValue == null) {
      element.style.removeProperty(name);
    } else {
      element.style.setProperty(name, styleValue.toString());
    }
  }

  if (value is Signal<dynamic>) {
    update(value.value);
    effect(() => update(value.value));
  } else {
    update(value);
  }
}

void _listen(web.HTMLElement element, String type, EventHandler handler) {
  final listener = ((web.Event event) => handler(event)).toJS;
  element.addEventListener(type, listener);
  onCleanup(() => element.removeEventListener(type, listener));
}

Map<String, EventHandler> _withEvent(
  Map<String, EventHandler> events,
  String name,
  EventHandler? handler,
) {
  if (handler == null) return events;
  return {...events, name: handler};
}

Map<String, EventHandler> _withEvents(
  Map<String, EventHandler> events,
  Map<String, EventHandler?> handlers,
) {
  return {
    ...events,
    for (final handler in handlers.entries)
      if (handler.value != null) handler.key: handler.value!,
  };
}
