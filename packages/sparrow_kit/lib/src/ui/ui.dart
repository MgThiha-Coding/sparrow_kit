import '../core/ssr/markup.dart';
import '../reactivity/signals.dart';

enum MainAxisAlignment {
  start('flex-start'),
  center('center'),
  end('flex-end'),
  spaceBetween('space-between'),
  spaceAround('space-around'),
  spaceEvenly('space-evenly');

  const MainAxisAlignment(this.cssValue);

  final String cssValue;
}

enum CrossAxisAlignment {
  start('flex-start'),
  center('center'),
  end('flex-end'),
  stretch('stretch');

  const CrossAxisAlignment(this.cssValue);

  final String cssValue;
}

sealed class UiNode {
  const UiNode();
}

class Text extends UiNode {
  const Text(
    this.value, {
    this.tag = 'span',
    this.attributes = const {},
  })  : id = null,
        signal = null;

  const Text.bind(
    String id,
    Signal<dynamic> signal, {
    this.tag = 'span',
    this.attributes = const {},
  })  : id = id,
        signal = signal,
        value = null;

  final Object? value;
  final String? id;
  final Signal<dynamic>? signal;
  final String tag;
  final Map<String, Object?> attributes;
}

class Row extends UiNode {
  Row({
    Iterable<UiNode> children = const [],
    this.gap = 0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.attributes = const {},
  }) : children = List<UiNode>.unmodifiable(children);

  final List<UiNode> children;
  final double gap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final Map<String, Object?> attributes;
}

class Column extends UiNode {
  Column({
    Iterable<UiNode> children = const [],
    this.gap = 0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.attributes = const {},
  }) : children = List<UiNode>.unmodifiable(children);

  final List<UiNode> children;
  final double gap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final Map<String, Object?> attributes;
}

class Container extends UiNode {
  Container({
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.attributes = const {},
  }) {
    _validateNonNegative(width, 'width');
    _validateNonNegative(height, 'height');
    _validateNonNegative(padding, 'padding');
    _validateNonNegative(margin, 'margin');
    _validateNonNegative(borderRadius, 'borderRadius');
    if (backgroundColor != null && backgroundColor!.contains(';')) {
      throw ArgumentError.value(
        backgroundColor,
        'backgroundColor',
        'A CSS declaration separator is not allowed.',
      );
    }
  }

  final UiNode child;
  final double? width;
  final double? height;
  final double? padding;
  final double? margin;
  final String? backgroundColor;
  final double? borderRadius;
  final Map<String, Object?> attributes;
}

class Heading extends UiNode {
  Heading(
    this.level,
    this.value, {
    this.attributes = const {},
  }) {
    if (level < 1 || level > 6) {
      throw ArgumentError.value(level, 'level', 'Heading level must be 1-6.');
    }
  }

  final int level;
  final String value;
  final Map<String, Object?> attributes;
}

class Button extends UiNode {
  Button({
    required this.label,
    required this.onPressed,
    this.attributes = const {},
  }) {
    if (attributes.keys.any((name) => name.toLowerCase() == 'type')) {
      throw ArgumentError('Button type is always "button".');
    }
  }

  final String label;
  final MarkupEventHandler onPressed;
  final Map<String, Object?> attributes;
}

/// A Sparrow Kit page description; it is not a Flutter Widget.
class UiPage implements SsrComponent {
  const UiPage(this.build);

  final UiNode Function() build;

  @override
  MarkupNode render() => toMarkupNode(build());
}

MarkupNode toMarkupNode(UiNode node) {
  return switch (node) {
    Text(
      :final value,
      :final id,
      :final signal,
      :final tag,
      :final attributes,
    ) =>
      MarkupElement(
        tag,
        attributes: attributes,
        children: [
          if (signal case final boundSignal?)
            SignalText(id!, boundSignal)
          else
            MarkupText(_textValue(value)),
        ],
      ),
    Row(
      :final children,
      :final gap,
      :final mainAxisAlignment,
      :final crossAxisAlignment,
      :final attributes,
    ) =>
      MarkupElement(
        'div',
        attributes: {
          ...attributes,
          'style': _mergeStyle(
            attributes['style'],
            _flexStyle(
              direction: 'row',
              gap: gap,
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
            ),
          ),
        },
        children: children.map(toMarkupNode),
      ),
    Column(
      :final children,
      :final gap,
      :final mainAxisAlignment,
      :final crossAxisAlignment,
      :final attributes,
    ) =>
      MarkupElement(
        'div',
        attributes: {
          ...attributes,
          'style': _mergeStyle(
            attributes['style'],
            _flexStyle(
              direction: 'column',
              gap: gap,
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
            ),
          ),
        },
        children: children.map(toMarkupNode),
      ),
    Container(
      :final child,
      :final width,
      :final height,
      :final padding,
      :final margin,
      :final backgroundColor,
      :final borderRadius,
      :final attributes,
    ) =>
      MarkupElement(
        'div',
        attributes: {
          ...attributes,
          'style': _mergeStyle(
            attributes['style'],
            _containerStyle(
              width: width,
              height: height,
              padding: padding,
              margin: margin,
              backgroundColor: backgroundColor,
              borderRadius: borderRadius,
            ),
          ),
        },
        children: [toMarkupNode(child)],
      ),
    Heading(:final level, :final value, :final attributes) => MarkupElement(
        'h$level',
        attributes: attributes,
        children: [MarkupText(value)],
      ),
    Button(:final label, :final onPressed, :final attributes) => MarkupElement(
        'button',
        attributes: {'type': 'button', ...attributes},
        children: [MarkupText(label)],
        events: {'click': onPressed},
      ),
  };
}

String _flexStyle({
  required String direction,
  required double gap,
  required MainAxisAlignment mainAxisAlignment,
  required CrossAxisAlignment crossAxisAlignment,
}) {
  _validateNonNegative(gap, 'gap');
  return 'display:flex;flex-direction:$direction;gap:${_cssPixels(gap)};'
      'justify-content:${mainAxisAlignment.cssValue};'
      'align-items:${crossAxisAlignment.cssValue}';
}

String _containerStyle({
  required double? width,
  required double? height,
  required double? padding,
  required double? margin,
  required String? backgroundColor,
  required double? borderRadius,
}) {
  final declarations = <String>['box-sizing:border-box'];
  if (width != null) declarations.add('width:${_cssPixels(width)}');
  if (height != null) declarations.add('height:${_cssPixels(height)}');
  if (padding != null) declarations.add('padding:${_cssPixels(padding)}');
  if (margin != null) declarations.add('margin:${_cssPixels(margin)}');
  if (backgroundColor != null) {
    declarations.add('background-color:$backgroundColor');
  }
  if (borderRadius != null) {
    declarations.add('border-radius:${_cssPixels(borderRadius)}');
  }
  return declarations.join(';');
}

String _mergeStyle(Object? existing, String generated) {
  if (existing != null && existing is! String) {
    throw ArgumentError.value(
      existing,
      'style',
      'Layout styles must be static strings.',
    );
  }
  final custom = (existing as String?)?.trim() ?? '';
  if (custom.isEmpty) return generated;
  return '$custom;$generated';
}

String _cssPixels(double value) {
  _validateNonNegative(value, 'value');
  if (value == 0) return '0';
  final formatted = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return '${formatted}px';
}

void _validateNonNegative(double? value, String name) {
  if (value != null && (!value.isFinite || value < 0)) {
    throw ArgumentError.value(
        value, name, 'Must be a finite non-negative value.');
  }
}

String _textValue(Object? value) => value?.toString() ?? '';
