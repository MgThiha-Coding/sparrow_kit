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

class Insets {
  const Insets.only({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  const Insets.all(double value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  const Insets.symmetric({double vertical = 0, double horizontal = 0})
      : top = vertical,
        right = horizontal,
        bottom = vertical,
        left = horizontal;

  static const zero = Insets.all(0);

  final double top;
  final double right;
  final double bottom;
  final double left;
}

class ResponsiveValue<T> {
  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final T mobile;
  final T? tablet;
  final T? desktop;
}

class Padding extends UiNode {
  Padding({
    required this.child,
    this.insets = Insets.zero,
    this.responsiveInsets,
    this.tag = 'div',
    this.attributes = const {},
  }) {
    _validateInsets(insets, 'padding', allowNegative: false);
    if (responsiveInsets != null) {
      _validateResponsiveInsets(
        responsiveInsets!,
        'padding',
        allowNegative: false,
      );
    }
  }

  final UiNode child;
  final Insets insets;
  final ResponsiveValue<Insets>? responsiveInsets;
  final String tag;
  final Map<String, Object?> attributes;
}

class Margin extends UiNode {
  Margin({
    required this.child,
    this.insets = Insets.zero,
    this.responsiveInsets,
    this.tag = 'div',
    this.attributes = const {},
  }) {
    _validateInsets(insets, 'margin', allowNegative: true);
    if (responsiveInsets != null) {
      _validateResponsiveInsets(
        responsiveInsets!,
        'margin',
        allowNegative: true,
      );
    }
  }

  final UiNode child;
  final Insets insets;
  final ResponsiveValue<Insets>? responsiveInsets;
  final String tag;
  final Map<String, Object?> attributes;
}

class Expanded extends UiNode {
  Expanded({
    required this.child,
    this.flex = 1,
    this.tag = 'div',
    this.attributes = const {},
  }) {
    _validateFlexFactor(flex);
  }

  final UiNode child;
  final int flex;
  final String tag;
  final Map<String, Object?> attributes;
}

class Flexible extends UiNode {
  Flexible({
    required this.child,
    this.tag = 'div',
    this.attributes = const {},
  });

  final UiNode child;
  final String tag;
  final Map<String, Object?> attributes;
}

class SizedBox extends UiNode {
  SizedBox({
    this.width,
    this.height,
    this.child,
    this.tag = 'div',
    this.attributes = const {},
  }) {
    _validateNonNegative(width, 'width');
    _validateNonNegative(height, 'height');
    if (width == null && height == null && child == null) {
      throw ArgumentError(
        'SizedBox requires a width, height, or child.',
      );
    }
  }

  final double? width;
  final double? height;
  final UiNode? child;
  final String tag;
  final Map<String, Object?> attributes;
}

class Stack extends UiNode {
  Stack({
    required Iterable<UiNode> children,
    this.width,
    this.height,
    this.tag = 'div',
    this.attributes = const {},
  }) : children = List<UiNode>.unmodifiable(children) {
    _validateNonNegative(width, 'width');
    _validateNonNegative(height, 'height');
  }

  final List<UiNode> children;
  final double? width;
  final double? height;
  final String tag;
  final Map<String, Object?> attributes;
}

class Positioned extends UiNode {
  Positioned({
    required this.child,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.width,
    this.height,
    this.tag = 'div',
    this.attributes = const {},
  }) {
    if (top == null && right == null && bottom == null && left == null) {
      throw ArgumentError(
        'Positioned requires at least one of top, right, bottom, or left.',
      );
    }
    for (final entry in {
      'top': top,
      'right': right,
      'bottom': bottom,
      'left': left,
    }.entries) {
      _validateFinite(entry.value, entry.key);
    }
    _validateNonNegative(width, 'width');
    _validateNonNegative(height, 'height');
  }

  final UiNode child;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double? width;
  final double? height;
  final String tag;
  final Map<String, Object?> attributes;
}

class Grid extends UiNode {
  Grid({
    required Iterable<UiNode> children,
    this.columns = 1,
    this.gap = 0,
    this.responsiveColumns,
    this.responsiveGap,
    this.tag = 'div',
    this.attributes = const {},
  }) : children = List<UiNode>.unmodifiable(children) {
    _validateGridColumns(columns, 'columns');
    _validateNonNegative(gap, 'gap');
    if (responsiveColumns != null) {
      _validateResponsiveColumns(responsiveColumns!);
    }
    if (responsiveGap != null) {
      _validateResponsiveNumbers(responsiveGap!, 'gap', allowNegative: false);
    }
  }

  final List<UiNode> children;
  final int columns;
  final double gap;
  final ResponsiveValue<int>? responsiveColumns;
  final ResponsiveValue<double>? responsiveGap;
  final String tag;
  final Map<String, Object?> attributes;
}

enum ResponsiveBreakpoint {
  mobile(null),
  tablet(600),
  desktop(1024);

  const ResponsiveBreakpoint(this.minWidth);

  final int? minWidth;
}

enum ResponsiveDirection {
  row('row'),
  column('column');

  const ResponsiveDirection(this.cssValue);

  final String cssValue;
}

class ResponsiveFlexLayout {
  ResponsiveFlexLayout({
    required this.direction,
    this.gap = 0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  }) {
    _validateNonNegative(gap, 'gap');
  }

  final ResponsiveDirection direction;
  final double gap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
}

class Responsive extends UiNode {
  Responsive({
    required Iterable<UiNode> children,
    required Map<ResponsiveBreakpoint, ResponsiveFlexLayout> layouts,
    this.tag = 'div',
    this.attributes = const {},
  })  : children = List<UiNode>.unmodifiable(children),
        layouts = _orderedResponsiveLayouts(layouts) {
    if (!this.layouts.containsKey(ResponsiveBreakpoint.mobile)) {
      throw ArgumentError(
        'A responsive layout must define its mobile layout.',
      );
    }
    if (attributes.keys.any((name) =>
        name.toLowerCase() == 'style' ||
        name.toLowerCase() == 'data-sparrow-responsive' ||
        name.toLowerCase() == 'data-sparrow-layout')) {
      throw ArgumentError(
        'Responsive layout styles and markers are managed by Sparrow Kit.',
      );
    }
  }

  final List<UiNode> children;
  final Map<ResponsiveBreakpoint, ResponsiveFlexLayout> layouts;
  final String tag;
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
  final converter = _UiNodeConverter();
  final root = converter.convert(node);
  final stylesheet = converter.stylesheet;
  if (stylesheet == null) return root;
  if (root is! MarkupElement) {
    throw StateError('A UI tree must lower to an HTML element.');
  }

  return MarkupElement(
    root.tag,
    attributes: root.attributes,
    children: root.children,
    events: root.events,
    stylesheets: [...root.stylesheets, stylesheet],
  );
}

enum _UiChildContext { root, ordinary, flex, stack }

class _UiNodeConverter {
  final _responsiveRules = <String, String>{};

  String? get stylesheet =>
      _responsiveRules.isEmpty ? null : _responsiveRules.values.join('\n');

  MarkupNode convert(
    UiNode node, {
    _UiChildContext parent = _UiChildContext.root,
  }) {
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
          children: children.map(
            (child) => convert(child, parent: _UiChildContext.flex),
          ),
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
          children: children.map(
            (child) => convert(child, parent: _UiChildContext.flex),
          ),
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
          children: [convert(child, parent: _UiChildContext.ordinary)],
        ),
      Padding(
        :final child,
        :final insets,
        :final responsiveInsets,
        :final tag,
        :final attributes,
      ) =>
        _convertInsets(
          child: child,
          insets: insets,
          responsiveInsets: responsiveInsets,
          property: 'padding',
          tag: tag,
          attributes: attributes,
          allowNegative: false,
        ),
      Margin(
        :final child,
        :final insets,
        :final responsiveInsets,
        :final tag,
        :final attributes,
      ) =>
        _convertInsets(
          child: child,
          insets: insets,
          responsiveInsets: responsiveInsets,
          property: 'margin',
          tag: tag,
          attributes: attributes,
          allowNegative: true,
        ),
      Expanded(
        :final child,
        :final flex,
        :final tag,
        :final attributes,
      ) =>
        _convertFlexItem(
          child: child,
          tag: tag,
          attributes: attributes,
          parent: parent,
          name: 'Expanded',
          style: 'flex-grow:$flex;flex-shrink:1;flex-basis:0%',
        ),
      Flexible(
        :final child,
        :final tag,
        :final attributes,
      ) =>
        _convertFlexItem(
          child: child,
          tag: tag,
          attributes: attributes,
          parent: parent,
          name: 'Flexible',
          style: 'flex-grow:0;flex-shrink:1;flex-basis:auto',
        ),
      SizedBox(
        :final width,
        :final height,
        :final child,
        :final tag,
        :final attributes,
      ) =>
        MarkupElement(
          tag,
          attributes: _withStyle(
            attributes,
            _sizedBoxStyle(width: width, height: height),
          ),
          children: [
            if (child != null) convert(child, parent: _UiChildContext.ordinary),
          ],
        ),
      Stack(
        :final children,
        :final width,
        :final height,
        :final tag,
        :final attributes,
      ) =>
        MarkupElement(
          tag,
          attributes: _withStyle(
            attributes,
            _stackStyle(width: width, height: height),
          ),
          children: children.map((child) {
            if (child is Positioned) {
              return convert(child, parent: _UiChildContext.stack);
            }
            return _withElementStyle(
              convert(child, parent: _UiChildContext.ordinary),
              'grid-area:1/1',
            );
          }),
        ),
      Positioned(
        :final child,
        :final top,
        :final right,
        :final bottom,
        :final left,
        :final width,
        :final height,
        :final tag,
        :final attributes,
      ) =>
        _convertPositioned(
          child: child,
          top: top,
          right: right,
          bottom: bottom,
          left: left,
          width: width,
          height: height,
          tag: tag,
          attributes: attributes,
          parent: parent,
        ),
      Grid(
        :final children,
        :final columns,
        :final gap,
        :final responsiveColumns,
        :final responsiveGap,
        :final tag,
        :final attributes,
      ) =>
        _convertGrid(
          children: children,
          columns: columns,
          gap: gap,
          responsiveColumns: responsiveColumns,
          responsiveGap: responsiveGap,
          tag: tag,
          attributes: attributes,
        ),
      Responsive(
        :final children,
        :final layouts,
        :final tag,
        :final attributes,
      ) =>
        _convertResponsive(children, layouts, tag, attributes),
      Heading(:final level, :final value, :final attributes) => MarkupElement(
          'h$level',
          attributes: attributes,
          children: [MarkupText(value)],
        ),
      Button(:final label, :final onPressed, :final attributes) =>
        MarkupElement(
          'button',
          attributes: {'type': 'button', ...attributes},
          children: [MarkupText(label)],
          events: {'click': onPressed},
        ),
    };
  }

  MarkupElement _convertInsets({
    required UiNode child,
    required Insets insets,
    required ResponsiveValue<Insets>? responsiveInsets,
    required String property,
    required String tag,
    required Map<String, Object?> attributes,
    required bool allowNegative,
  }) {
    _rejectManagedLayoutMarker(attributes, property);
    if (responsiveInsets == null) {
      return MarkupElement(
        tag,
        attributes: _withStyle(
          attributes,
          '$property:${_insetsCss(insets, allowNegative: allowNegative)}',
        ),
        children: [convert(child, parent: _UiChildContext.ordinary)],
      );
    }

    _rejectResponsiveInlineStyle(attributes, property);
    final responsiveValues = _responsiveInsets(responsiveInsets);
    final declarations = {
      for (final entry in responsiveValues.entries)
        entry.key:
            '$property:${_insetsCss(entry.value, allowNegative: allowNegative)}',
    };
    final token = _registerResponsiveDeclarations(
      'insets:$property',
      declarations,
    );
    return MarkupElement(
      tag,
      attributes: {
        ...attributes,
        'data-sparrow-layout': token,
      },
      children: [convert(child, parent: _UiChildContext.ordinary)],
    );
  }

  MarkupElement _convertFlexItem({
    required UiNode child,
    required String tag,
    required Map<String, Object?> attributes,
    required _UiChildContext parent,
    required String name,
    required String style,
  }) {
    if (parent != _UiChildContext.flex) {
      throw StateError(
        '$name must be a direct child of Row, Column, or Responsive.',
      );
    }
    return MarkupElement(
      tag,
      attributes: _withStyle(attributes, style),
      children: [convert(child, parent: _UiChildContext.ordinary)],
    );
  }

  MarkupElement _convertPositioned({
    required UiNode child,
    required double? top,
    required double? right,
    required double? bottom,
    required double? left,
    required double? width,
    required double? height,
    required String tag,
    required Map<String, Object?> attributes,
    required _UiChildContext parent,
  }) {
    if (parent != _UiChildContext.stack) {
      throw StateError('Positioned must be a direct child of Stack.');
    }
    return MarkupElement(
      tag,
      attributes: _withStyle(
        attributes,
        _positionedStyle(
          top: top,
          right: right,
          bottom: bottom,
          left: left,
          width: width,
          height: height,
        ),
      ),
      children: [convert(child, parent: _UiChildContext.ordinary)],
    );
  }

  MarkupElement _convertGrid({
    required List<UiNode> children,
    required int columns,
    required double gap,
    required ResponsiveValue<int>? responsiveColumns,
    required ResponsiveValue<double>? responsiveGap,
    required String tag,
    required Map<String, Object?> attributes,
  }) {
    _rejectManagedLayoutMarker(attributes, 'Grid');
    if (responsiveColumns == null && responsiveGap == null) {
      return MarkupElement(
        tag,
        attributes: _withStyle(
          attributes,
          _gridStyle(columns: columns, gap: gap),
        ),
        children: children.map(
          (child) => convert(child, parent: _UiChildContext.ordinary),
        ),
      );
    }

    _rejectResponsiveInlineStyle(attributes, 'Grid');
    final mobileColumns = responsiveColumns?.mobile ?? columns;
    final mobileGap = responsiveGap?.mobile ?? gap;
    final declarations = <ResponsiveBreakpoint, String>{
      ResponsiveBreakpoint.mobile:
          _gridStyle(columns: mobileColumns, gap: mobileGap),
    };
    for (final breakpoint in [
      ResponsiveBreakpoint.tablet,
      ResponsiveBreakpoint.desktop,
    ]) {
      final responsiveColumnCount = switch (breakpoint) {
        ResponsiveBreakpoint.tablet => responsiveColumns?.tablet,
        ResponsiveBreakpoint.desktop => responsiveColumns?.desktop,
        ResponsiveBreakpoint.mobile => null,
      };
      final responsiveGapValue = switch (breakpoint) {
        ResponsiveBreakpoint.tablet => responsiveGap?.tablet,
        ResponsiveBreakpoint.desktop => responsiveGap?.desktop,
        ResponsiveBreakpoint.mobile => null,
      };
      if (responsiveColumnCount == null && responsiveGapValue == null) continue;
      declarations[breakpoint] = [
        if (responsiveColumnCount != null)
          'grid-template-columns:${_gridColumns(responsiveColumnCount)}',
        if (responsiveGapValue != null) 'gap:${_cssPixels(responsiveGapValue)}',
      ].join(';');
    }

    final token = _registerResponsiveDeclarations('grid', declarations);
    return MarkupElement(
      tag,
      attributes: {
        ...attributes,
        'data-sparrow-layout': token,
      },
      children: children.map(
        (child) => convert(child, parent: _UiChildContext.ordinary),
      ),
    );
  }

  MarkupElement _convertResponsive(
    List<UiNode> children,
    Map<ResponsiveBreakpoint, ResponsiveFlexLayout> layouts,
    String tag,
    Map<String, Object?> attributes,
  ) {
    final token = _responsiveLayoutToken(layouts);
    _responsiveRules.putIfAbsent(
      token,
      () => _responsiveLayoutCss(token, layouts),
    );
    return MarkupElement(
      tag,
      attributes: {
        ...attributes,
        'data-sparrow-responsive': token,
      },
      children: children.map(
        (child) => convert(child, parent: _UiChildContext.flex),
      ),
    );
  }

  String _registerResponsiveDeclarations(
    String namespace,
    Map<ResponsiveBreakpoint, String> declarations,
  ) {
    final signature = [
      namespace,
      for (final breakpoint in ResponsiveBreakpoint.values)
        if (declarations[breakpoint] case final declaration?)
          '${breakpoint.name}:$declaration',
    ].join('|');
    final token = Uri.encodeComponent(signature);
    final selector = '[data-sparrow-layout="$token"]';
    _responsiveRules.putIfAbsent(
      '$namespace:$token',
      () => _responsiveDeclarationsCss(selector, declarations),
    );
    return token;
  }
}

Map<ResponsiveBreakpoint, ResponsiveFlexLayout> _orderedResponsiveLayouts(
  Map<ResponsiveBreakpoint, ResponsiveFlexLayout> layouts,
) =>
    Map<ResponsiveBreakpoint, ResponsiveFlexLayout>.unmodifiable({
      for (final breakpoint in ResponsiveBreakpoint.values)
        if (layouts[breakpoint] case final layout?) breakpoint: layout,
    });

String _responsiveLayoutToken(
  Map<ResponsiveBreakpoint, ResponsiveFlexLayout> layouts,
) {
  final parts = <String>[];
  for (final breakpoint in ResponsiveBreakpoint.values) {
    final layout = layouts[breakpoint];
    if (layout == null) continue;
    parts.add(
      '${breakpoint.name}:${layout.direction.name}:${_cssPixels(layout.gap)}:'
      '${layout.mainAxisAlignment.name}:${layout.crossAxisAlignment.name}',
    );
  }
  return Uri.encodeComponent(parts.join('|'));
}

String _responsiveLayoutCss(
  String token,
  Map<ResponsiveBreakpoint, ResponsiveFlexLayout> layouts,
) {
  final selector = '[data-sparrow-responsive="$token"]';
  return _responsiveDeclarationsCss(
    selector,
    {
      for (final breakpoint in ResponsiveBreakpoint.values)
        if (layouts[breakpoint] case final layout?)
          breakpoint: _flexStyle(
            direction: layout.direction.cssValue,
            gap: layout.gap,
            mainAxisAlignment: layout.mainAxisAlignment,
            crossAxisAlignment: layout.crossAxisAlignment,
          ),
    },
  );
}

String _responsiveDeclarationsCss(
  String selector,
  Map<ResponsiveBreakpoint, String> declarations,
) {
  final css = StringBuffer();
  for (final breakpoint in ResponsiveBreakpoint.values) {
    final declaration = declarations[breakpoint];
    if (declaration == null) continue;
    final rule = '$selector{$declaration;}';
    final minWidth = breakpoint.minWidth;
    if (minWidth == null) {
      css.write(rule);
    } else {
      css.write('@media (min-width: ${minWidth}px){$rule}');
    }
    css.write('\n');
  }
  return css.toString().trimRight();
}

Map<ResponsiveBreakpoint, Insets> _responsiveInsets(
  ResponsiveValue<Insets> responsiveInsets,
) =>
    {
      ResponsiveBreakpoint.mobile: responsiveInsets.mobile,
      if (responsiveInsets.tablet case final tablet?)
        ResponsiveBreakpoint.tablet: tablet,
      if (responsiveInsets.desktop case final desktop?)
        ResponsiveBreakpoint.desktop: desktop,
    };

String _insetsCss(Insets insets, {required bool allowNegative}) =>
    '${_cssLength(insets.top, allowNegative: allowNegative)} '
    '${_cssLength(insets.right, allowNegative: allowNegative)} '
    '${_cssLength(insets.bottom, allowNegative: allowNegative)} '
    '${_cssLength(insets.left, allowNegative: allowNegative)}';

String _sizedBoxStyle({required double? width, required double? height}) {
  final declarations = ['box-sizing:border-box'];
  if (width != null) declarations.add('width:${_cssPixels(width)}');
  if (height != null) declarations.add('height:${_cssPixels(height)}');
  return declarations.join(';');
}

String _stackStyle({required double? width, required double? height}) {
  final declarations = [
    'box-sizing:border-box',
    'display:grid',
    'position:relative',
    'justify-items:start',
    'align-items:start',
  ];
  if (width != null) declarations.add('width:${_cssPixels(width)}');
  if (height != null) declarations.add('height:${_cssPixels(height)}');
  return declarations.join(';');
}

String _positionedStyle({
  required double? top,
  required double? right,
  required double? bottom,
  required double? left,
  required double? width,
  required double? height,
}) {
  final declarations = ['box-sizing:border-box', 'position:absolute'];
  if (top != null) {
    declarations.add('top:${_cssLength(top, allowNegative: true)}');
  }
  if (right != null) {
    declarations.add('right:${_cssLength(right, allowNegative: true)}');
  }
  if (bottom != null) {
    declarations.add('bottom:${_cssLength(bottom, allowNegative: true)}');
  }
  if (left != null) {
    declarations.add('left:${_cssLength(left, allowNegative: true)}');
  }
  if (width != null) declarations.add('width:${_cssPixels(width)}');
  if (height != null) declarations.add('height:${_cssPixels(height)}');
  return declarations.join(';');
}

String _gridStyle({required int columns, required double gap}) =>
    'display:grid;grid-template-columns:${_gridColumns(columns)};'
    'gap:${_cssPixels(gap)}';

String _gridColumns(int columns) => 'repeat($columns,minmax(0,1fr))';

Map<String, Object?> _withStyle(
  Map<String, Object?> attributes,
  String generatedStyle,
) =>
    {
      ...attributes,
      if (generatedStyle.isNotEmpty)
        'style': _mergeStyle(attributes['style'], generatedStyle),
    };

MarkupNode _withElementStyle(MarkupNode node, String style) {
  if (node is! MarkupElement) {
    throw StateError('A layout child must lower to an HTML element.');
  }
  return MarkupElement(
    node.tag,
    attributes: _withStyle(node.attributes, style),
    children: node.children,
    events: node.events,
    stylesheets: node.stylesheets,
  );
}

void _rejectResponsiveInlineStyle(
  Map<String, Object?> attributes,
  String component,
) {
  if (attributes.keys.any((name) => name.toLowerCase() == 'style')) {
    throw ArgumentError(
      '$component responsive values manage their own inline styles.',
    );
  }
}

void _rejectManagedLayoutMarker(
  Map<String, Object?> attributes,
  String component,
) {
  if (attributes.keys
      .any((name) => name.toLowerCase() == 'data-sparrow-layout')) {
    throw ArgumentError(
      '$component uses the reserved data-sparrow-layout attribute.',
    );
  }
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
  return _formatCssPixels(value);
}

String _cssLength(double value, {required bool allowNegative}) {
  _validateFinite(value, 'value');
  if (!allowNegative && value < 0) {
    throw ArgumentError.value(
      value,
      'value',
      'Must be a non-negative CSS length.',
    );
  }
  return _formatCssPixels(value);
}

String _formatCssPixels(double value) {
  if (value == 0) return '0';
  final formatted = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return '${formatted}px';
}

void _validateInsets(
  Insets insets,
  String name, {
  required bool allowNegative,
}) {
  for (final entry in {
    'top': insets.top,
    'right': insets.right,
    'bottom': insets.bottom,
    'left': insets.left,
  }.entries) {
    _validateFinite(entry.value, '$name.${entry.key}');
    if (!allowNegative && entry.value < 0) {
      throw ArgumentError.value(
        entry.value,
        '$name.${entry.key}',
        'Must be a non-negative value.',
      );
    }
  }
}

void _validateResponsiveInsets(
  ResponsiveValue<Insets> responsiveInsets,
  String name, {
  required bool allowNegative,
}) {
  _validateInsets(responsiveInsets.mobile, '$name.mobile',
      allowNegative: allowNegative);
  if (responsiveInsets.tablet case final tablet?) {
    _validateInsets(tablet, '$name.tablet', allowNegative: allowNegative);
  }
  if (responsiveInsets.desktop case final desktop?) {
    _validateInsets(desktop, '$name.desktop', allowNegative: allowNegative);
  }
}

void _validateResponsiveNumbers(
  ResponsiveValue<double> responsiveValues,
  String name, {
  required bool allowNegative,
}) {
  for (final entry in {
    ResponsiveBreakpoint.mobile: responsiveValues.mobile,
    if (responsiveValues.tablet case final tablet?)
      ResponsiveBreakpoint.tablet: tablet,
    if (responsiveValues.desktop case final desktop?)
      ResponsiveBreakpoint.desktop: desktop,
  }.entries) {
    _validateFinite(entry.value, '$name.${entry.key.name}');
    if (!allowNegative && entry.value < 0) {
      throw ArgumentError.value(
        entry.value,
        '$name.${entry.key.name}',
        'Must be a non-negative value.',
      );
    }
  }
}

void _validateResponsiveColumns(ResponsiveValue<int> columns) {
  for (final entry in {
    ResponsiveBreakpoint.mobile: columns.mobile,
    if (columns.tablet case final tablet?) ResponsiveBreakpoint.tablet: tablet,
    if (columns.desktop case final desktop?)
      ResponsiveBreakpoint.desktop: desktop,
  }.entries) {
    _validateGridColumns(entry.value, 'columns.${entry.key.name}');
  }
}

void _validateGridColumns(int columns, String name) {
  if (columns < 1) {
    throw ArgumentError.value(columns, name, 'Must be at least one column.');
  }
}

void _validateFlexFactor(int flex) {
  if (flex < 1) {
    throw ArgumentError.value(flex, 'flex', 'Must be at least 1.');
  }
}

void _validateFinite(double? value, String name) {
  if (value != null && !value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be a finite CSS length.');
  }
}

void _validateNonNegative(double? value, String name) {
  _validateFinite(value, name);
  if (value != null && value < 0) {
    throw ArgumentError.value(
        value, name, 'Must be a finite non-negative value.');
  }
}

String _textValue(Object? value) => value?.toString() ?? '';
