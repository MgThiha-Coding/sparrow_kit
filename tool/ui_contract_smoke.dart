import 'package:sparrow_kit/server.dart';

void main() {
  final count = Signal<int>(3);
  final page = UiPage(
    () => Container(
      padding: 16,
      child: Column(
        gap: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(1, 'Sparrow UI contract'),
          Row(
            gap: 4,
            children: [
              const Text('Count: '),
              Text.bind('count', count),
            ],
          ),
          Button(label: 'Increment', onPressed: (_) => count.value++),
        ],
      ),
    ),
  );

  final html = renderToString(page, clientScript: null);
  for (final expected in [
    '<h1>Sparrow UI contract</h1>',
    'display:flex;flex-direction:column;gap:8px;',
    'display:flex;flex-direction:row;gap:4px;',
    '<!--fw:text:count-->3<!--fw:/text:count-->',
    '<button type="button">Increment</button>',
    '"count":3',
  ]) {
    if (!html.contains(expected)) {
      throw StateError('Expected UI contract SSR to include: $expected');
    }
  }

  _expect(
    ResponsiveBreakpoint.mobile.minWidth == null &&
        ResponsiveBreakpoint.tablet.minWidth == 600 &&
        ResponsiveBreakpoint.desktop.minWidth == 1024,
    'responsive breakpoints should use the documented mobile-first widths',
  );

  final responsivePage = UiPage(_responsivePage);
  final responsiveHtml = renderToString(
    responsivePage,
    clientScript: null,
  );
  for (final expected in [
    'data-sparrow-responsive=',
    'flex-direction:column;gap:8px;',
    '@media (min-width: 600px)',
    'flex-direction:row;gap:12px;',
    '@media (min-width: 1024px)',
    'flex-direction:row;gap:24px;',
    '<section',
    '<h1>Responsive layout</h1>',
  ]) {
    if (!responsiveHtml.contains(expected)) {
      throw StateError('Expected responsive SSR to include: $expected');
    }
  }
  _expect(
    responsiveHtml.indexOf('<style id="sparrow-responsive-') >= 0 &&
        responsiveHtml.indexOf('<style id="sparrow-responsive-') <
            responsiveHtml.indexOf('</head>'),
    'responsive CSS should be emitted in the document head',
  );
  _expect(
    responsiveHtml == renderToString(responsivePage, clientScript: null),
    'responsive CSS generation should be deterministic',
  );

  var missingMobileRejected = false;
  try {
    Responsive(
      children: const [],
      layouts: {
        ResponsiveBreakpoint.tablet: ResponsiveFlexLayout(
          direction: ResponsiveDirection.row,
        ),
      },
    );
  } on ArgumentError {
    missingMobileRejected = true;
  }
  _expect(
    missingMobileRejected,
    'responsive layouts should require a mobile base layout',
  );

  final layoutHtml = renderToString(
    UiPage(_layoutPrimitives),
    clientScript: null,
  );
  for (final expected in [
    'style="padding:1px 2px 3px 4px"',
    'margin:-2px -3px -4px -5px',
    'margin:-6px -6px -6px -6px',
    'flex-grow:2;flex-shrink:1;flex-basis:0%',
    'flex-grow:0;flex-shrink:1;flex-basis:auto',
    'style="box-sizing:border-box;width:32px;height:16px"',
    'style="box-sizing:border-box;display:grid;position:relative;',
    'grid-area:1/1',
    'style="box-sizing:border-box;position:absolute;top:6px;right:7px;'
        'bottom:8px;left:4px;width:20px;height:10px"',
    'style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px"',
    'padding:9px 9px 9px 9px',
    'padding:12px 16px 12px 16px',
    'grid-template-columns:repeat(4,minmax(0,1fr))',
  ]) {
    if (!layoutHtml.contains(expected)) {
      throw StateError(
        'Expected layout SSR to include: $expected\n$layoutHtml',
      );
    }
  }
  _expect(
    layoutHtml.indexOf('<style id="sparrow-responsive-') <
        layoutHtml.indexOf('</head>'),
    'responsive padding and grid CSS should be emitted in the document head',
  );
  _expect(
    layoutHtml == renderToString(UiPage(_layoutPrimitives), clientScript: null),
    'responsive layout CSS generation should be deterministic',
  );

  final keyedItems = Signal<List<String>>(['a:Alpha', 'b:Beta']);
  final keyedList = KeyedList<String>(
    id: 'keyed_items',
    items: keyedItems,
    keyOf: (item) => item.split(':').first,
    itemBuilder: (item) => Text(item.split(':').last),
  );
  final keyedHtml = renderToString(UiPage(() => keyedList));
  for (final expected in [
    '<ul><!--fw:children:keyed_items-->',
    '<li data-sparrow-key="a"><span>Alpha</span></li>',
    '<li data-sparrow-key="b"><span>Beta</span></li>',
    '<!--fw:/children:keyed_items-->',
    '"keyed_items":["a:Alpha","b:Beta"]',
  ]) {
    _expect(
      keyedHtml.contains(expected),
      'Keyed-list SSR should contain "$expected".',
    );
  }
  final keyedMarkup = toMarkupNode(keyedList) as MarkupElement;
  final keyedChildren = keyedMarkup.children.single as MarkupKeyedChildren;
  keyedItems.value = ['b:Beta', 'a:Updated', 'c:Gamma'];
  final updatedKeyedItems = keyedChildren.buildItems();
  final updatedItemNode = updatedKeyedItems[1].node;
  final updatedTextNode =
      updatedItemNode is MarkupElement ? updatedItemNode.children.single : null;
  _expect(
    updatedKeyedItems.map((item) => item.key).join(',') == 'b,a,c' &&
        updatedTextNode is MarkupText &&
        updatedTextNode.value == 'Updated',
    'Keyed-list updates should preserve item keys and rebuild updated content.',
  );
  keyedItems.value = ['duplicate:first', 'duplicate:second'];
  _expectThrows(
    keyedChildren.buildItems,
    StateError,
    'duplicate keys should be rejected on subsequent list updates',
  );
  _expectThrows(
    () => renderToString(
      UiPage(
        () => KeyedList<String>(
          id: 'duplicate_items',
          items: Signal<List<String>>(['same:first', 'same:second']),
          keyOf: (item) => item.split(':').first,
          itemBuilder: (item) => Text(item),
        ),
      ),
    ),
    StateError,
    'duplicate keys should be rejected during SSR',
  );

  _expectThrows(
    () => Padding(child: const Text('invalid'), insets: const Insets.all(-1)),
    ArgumentError,
    'negative padding should be rejected',
  );
  _expectThrows(
    () => SizedBox(),
    ArgumentError,
    'an empty SizedBox should be rejected',
  );
  _expectThrows(
    () => Expanded(child: const Text('invalid'), flex: 0),
    ArgumentError,
    'an invalid flex factor should be rejected',
  );
  _expectThrows(
    () => Grid(children: const [], columns: 0),
    ArgumentError,
    'a grid must have at least one column',
  );
  _expectThrows(
    () => Positioned(child: const Text('invalid')),
    ArgumentError,
    'Positioned requires at least one offset',
  );
  _expectThrows(
    () => toMarkupNode(Expanded(child: const Text('invalid'))),
    StateError,
    'Expanded must be a flex container child',
  );
  _expectThrows(
    () => toMarkupNode(Positioned(left: 0, child: const Text('invalid'))),
    StateError,
    'Positioned must be a Stack child',
  );
  _expectThrows(
    () => toMarkupNode(
      Padding(
        attributes: const {'style': 'padding:99px'},
        responsiveInsets: const ResponsiveValue(mobile: Insets.all(1)),
        child: const Text('invalid'),
      ),
    ),
    ArgumentError,
    'responsive Padding must own its generated CSS',
  );
}

UiNode _responsivePage() => Responsive(
      tag: 'section',
      layouts: {
        ResponsiveBreakpoint.mobile: ResponsiveFlexLayout(
          direction: ResponsiveDirection.column,
          gap: 8,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        ResponsiveBreakpoint.tablet: ResponsiveFlexLayout(
          direction: ResponsiveDirection.row,
          gap: 12,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        ResponsiveBreakpoint.desktop: ResponsiveFlexLayout(
          direction: ResponsiveDirection.row,
          gap: 24,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
      },
      children: [Heading(1, 'Responsive layout')],
    );

UiNode _layoutPrimitives() => Column(
      children: [
        Padding(
          insets: const Insets.only(top: 1, right: 2, bottom: 3, left: 4),
          child: const Text('padded'),
        ),
        Margin(
          insets: const Insets.only(
            top: -2,
            right: -3,
            bottom: -4,
            left: -5,
          ),
          responsiveInsets: const ResponsiveValue(
            mobile: Insets.only(
              top: -2,
              right: -3,
              bottom: -4,
              left: -5,
            ),
            tablet: Insets.all(-6),
          ),
          child: const Text('margined'),
        ),
        Padding(
          responsiveInsets: const ResponsiveValue(
            mobile: Insets.all(9),
            tablet: Insets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: const Text('responsive padding'),
        ),
        Row(
          children: [
            Expanded(flex: 2, child: const Text('expanded')),
            Flexible(child: const Text('flexible')),
          ],
        ),
        SizedBox(width: 32, height: 16),
        Stack(
          width: 100,
          height: 40,
          children: [
            const Text('stack base'),
            Positioned(
              top: 6,
              right: 7,
              bottom: 8,
              left: 4,
              width: 20,
              height: 10,
              child: const Text('stack overlay'),
            ),
          ],
        ),
        Grid(
          columns: 2,
          gap: 8,
          children: const [Text('grid item')],
        ),
        Grid(
          responsiveColumns: const ResponsiveValue(
            mobile: 1,
            tablet: 2,
            desktop: 4,
          ),
          children: const [Text('responsive grid item')],
        ),
      ],
    );

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _expectThrows(
  void Function() action,
  Type expectedType,
  String message,
) {
  try {
    action();
  } catch (error) {
    if (error.runtimeType == expectedType) return;
    throw StateError('$message; expected $expectedType, got $error');
  }
  throw StateError('$message; no error was thrown');
}
