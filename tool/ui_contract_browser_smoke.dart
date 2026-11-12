import 'dart:async';

import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:web/web.dart' as web;

var _keyedButtonClicks = 0;
final MarkupEventHandler _keyedButtonHandler = _recordKeyedButtonClick;

void _recordKeyedButtonClick(Object? _) {
  _keyedButtonClicks++;
}

class _LifecycleCounters {
  int parentMounts = 0;
  int parentUpdates = 0;
  int parentDisposals = 0;
  int childMounts = 0;
  int childDisposals = 0;
  int clicks = 0;
}

class _NestedLifecycleComponent extends Component<void> {
  _NestedLifecycleComponent(this.counters) : super(null);

  final _LifecycleCounters counters;

  @override
  web.Node render() => createButton(
        child: 'Nested',
        onClick: () => counters.clicks++,
      );

  @override
  void onMount() {
    counters.childMounts++;
  }

  @override
  void onDispose() {
    counters.childDisposals++;
  }
}

class _LifecycleParentComponent extends Component<int> {
  _LifecycleParentComponent(this.value, this.counters) : super(0);

  final Signal<int> value;
  final _LifecycleCounters counters;

  @override
  web.Node render() {
    final current = value.value;
    return createElement(
      'div',
      children: [
        createButton(child: 'Parent $current'),
        _NestedLifecycleComponent(counters),
      ],
    );
  }

  @override
  void onMount() {
    counters.parentMounts++;
  }

  @override
  void onUpdate() {
    counters.parentUpdates++;
  }

  @override
  void onDispose() {
    counters.parentDisposals++;
  }
}

class _TransactionalComponent extends Component<void> {
  _TransactionalComponent(this.value) : super(null);

  final Signal<int> value;
  int clicks = 0;
  int disposals = 0;

  @override
  web.Node render() {
    final current = value.value;
    if (current < 0) throw StateError('Render rejected.');
    return createButton(
      child: 'State $current',
      onClick: () => clicks++,
    );
  }

  @override
  void onDispose() {
    disposals++;
  }
}

Future<void> main() async {
  try {
    await _runSmoke();
  } catch (error) {
    web.document.body?.setAttribute('data-test-error', error.toString());
    web.document.body?.setAttribute('data-test-result', 'failed');
    rethrow;
  }
}

Future<void> _runSmoke() async {
  final app = web.document.getElementById('app');
  final direct = web.document.getElementById('direct');
  final componentHost = web.document.getElementById('component');
  if (app == null || direct == null || componentHost == null) {
    throw StateError('Browser smoke test roots are missing.');
  }

  final serverHtml = renderToString(
    UiPage(
      () => _responsivePage(
        Signal<int>(3),
        Signal<List<String>>(['a:Alpha', 'b:Beta']),
      ),
    ),
    metadata: HeadMetadata(
      title: 'Responsive hydration test',
      language: 'fr-CA',
    ),
    clientScript: null,
  );
  final serverDocument =
      web.DOMParser().parseFromString(serverHtml, 'text/html');
  final serverDocumentRoot = serverDocument.getElementById('app');
  final serverMarkup = serverDocumentRoot?.firstChild;
  final serverState = serverDocument.getElementById('__FRAMEWORK_STATE__');
  if (serverMarkup == null || serverState == null) {
    throw StateError('Responsive SSR output is incomplete.');
  }
  final serverLanguage = serverDocument.documentElement?.getAttribute('lang');
  if (serverLanguage == null) {
    throw StateError('Responsive SSR output has no document language.');
  }
  web.document.documentElement?.setAttribute('lang', serverLanguage);
  app.appendChild(serverMarkup.cloneNode(true));
  final serverStyles =
      serverDocument.head!.querySelectorAll('style[data-sparrow-stylesheet]');
  for (var index = 0; index < serverStyles.length; index++) {
    final style = serverStyles.item(index);
    if (style == null) {
      throw StateError('Responsive SSR stylesheet is missing.');
    }
    web.document.head!.appendChild(style.cloneNode(true));
  }
  web.document.body!.appendChild(serverState.cloneNode(true));
  _expect(
    web.document.head!.querySelector('style[data-sparrow-stylesheet]') != null,
    'responsive SSR stylesheet was not installed',
  );

  final mismatchHost = web.document.createElement('div');
  mismatchHost.appendChild(serverMarkup.cloneNode(true));
  web.document.body!.appendChild(mismatchHost);
  mismatchHost
      .querySelector('ul [data-sparrow-key]')!
      .setAttribute('data-sparrow-key', 'wrong');
  Object? mismatchError;
  try {
    HydrationEngine().hydrate(
      container: mismatchHost,
      tree: toMarkupNode(
        _responsivePage(
          Signal<int>(3),
          Signal<List<String>>(['a:Alpha', 'b:Beta']),
        ),
      ),
    );
  } on StateError catch (error) {
    mismatchError = error;
  } finally {
    mismatchHost.remove();
  }
  _expect(
    mismatchError.toString().contains('Keyed child "a" mismatch'),
    'keyed hydration mismatch diagnostics were not reported',
  );

  final hydratedRoot = app.firstChild;
  late Signal<int> hydratedCount;
  late Signal<List<String>> hydratedItems;
  final hydrated = hydrateUiApp((state) {
    final count = state.signal<int>('count', fallback: 0);
    final items = state.signal<List<String>>(
      'keyed_items',
      fallback: ['a:Alpha', 'b:Beta'],
      decode: (value) => (value! as List).cast<String>(),
    );
    hydratedCount = count;
    hydratedItems = items;
    return _responsivePage(count, items);
  });
  _expect(
    web.document.documentElement?.getAttribute('lang') == 'fr-CA',
    'hydration did not preserve the server-rendered language',
  );
  _expect(
    identical(hydratedRoot, app.firstChild),
    'hydration replaced its root',
  );
  _expect(app.textContent?.contains('3') ?? false, 'initial text mismatch');

  final keyedList = app.querySelector('ul')!;
  final keyedA = keyedList.querySelector('[data-sparrow-key="a"]')!;
  final keyedB = keyedList.querySelector('[data-sparrow-key="b"]')!;
  final keyedAButton = keyedA.querySelector('button')! as web.HTMLButtonElement;
  final keyedBButton = keyedB.querySelector('button')! as web.HTMLButtonElement;
  _keyedButtonClicks = 0;
  hydratedItems.value = ['b:Beta', 'a:Updated', 'c:Gamma'];
  await Future<void>.delayed(Duration.zero);
  final keyedChildren = keyedList.querySelectorAll('[data-sparrow-key]');
  _expect(
    keyedChildren.length == 3 &&
        (keyedChildren.item(0) as web.Element?)
                ?.getAttribute('data-sparrow-key') ==
            'b' &&
        (keyedChildren.item(1) as web.Element?)
                ?.getAttribute('data-sparrow-key') ==
            'a' &&
        (keyedChildren.item(2) as web.Element?)
                ?.getAttribute('data-sparrow-key') ==
            'c',
    'keyed children did not insert and reorder correctly',
  );
  _expect(
    identical(keyedB, keyedList.querySelector('[data-sparrow-key="b"]')) &&
        identical(
          keyedBButton,
          keyedList.querySelector('[data-sparrow-key="b"] button'),
        ) &&
        identical(keyedA, keyedList.querySelector('[data-sparrow-key="a"]')) &&
        keyedList.querySelector('[data-sparrow-key="a"]')?.textContent ==
            'Updated',
    'keyed reconciliation replaced stable items or missed an update',
  );
  keyedAButton.click();
  _expect(_keyedButtonClicks == 0, 'updated keyed item kept a stale listener');
  keyedBButton.click();
  _expect(_keyedButtonClicks == 1, 'reordered keyed event listener was lost');

  hydratedItems.value = ['c:Gamma'];
  await Future<void>.delayed(Duration.zero);
  keyedAButton.click();
  keyedBButton.click();
  _expect(_keyedButtonClicks == 1, 'removed keyed items kept event listeners');

  (app.querySelector('button')! as web.HTMLButtonElement).click();
  await Future<void>.delayed(Duration.zero);
  _expect(
      app.textContent?.contains('4') ?? false, 'hydrated event/binding failed');
  _expect(identical(hydratedRoot, app.firstChild),
      'signal update replaced its root');
  _expectResponsiveLayoutStyles(app);
  hydrated();
  (app.querySelector('button')! as web.HTMLButtonElement).click();
  await Future<void>.delayed(Duration.zero);
  _expect(hydratedCount.value == 4, 'disposed handler still ran');
  (keyedList.querySelector('button') as web.HTMLButtonElement?)?.click();
  _expect(_keyedButtonClicks == 1, 'disposed keyed list still handled events');

  final count = Signal<int>(1);
  final stylesheetCountBeforeDirect = web.document.head!
      .querySelectorAll('style[data-sparrow-stylesheet]')
      .length;
  final disposeDirect = mountUi(
    Responsive(
      layouts: {
        ResponsiveBreakpoint.mobile: ResponsiveFlexLayout(
          direction: ResponsiveDirection.column,
        ),
      },
      children: [
        Text.bind('direct_count', count),
        Button(label: 'Increment', onPressed: (_) => count.value++),
      ],
    ),
    rootSelector: '#direct',
  );
  _expect(
    web.document.head!
            .querySelectorAll('style[data-sparrow-stylesheet]')
            .length ==
        stylesheetCountBeforeDirect + 1,
    'direct rendering did not install its responsive stylesheet',
  );
  final directButton = direct.querySelector('button')! as web.HTMLButtonElement;
  directButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(direct.textContent == '2Increment', 'direct DOM binding failed');
  disposeDirect();
  _expect(
    web.document.head!
            .querySelectorAll('style[data-sparrow-stylesheet]')
            .length ==
        stylesheetCountBeforeDirect,
    'direct rendering did not remove its responsive stylesheet',
  );
  directButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(count.value == 2, 'disposed DOM handler still ran');

  late Signal<int> componentCount;
  final componentApp = component<void>((state, _) {
    componentCount = state.use(1);
    return renderUi(
      Column(
        children: [
          Text.bind('component_count', componentCount),
          Button(
            label: 'Increment',
            onPressed: (_) => componentCount.value++,
          ),
        ],
      ),
    );
  })(null);
  final disposeComponent = runApp(
    componentApp,
    rootSelector: '#component',
  );
  final componentRoot = componentHost.firstChild;
  final componentButton =
      componentHost.querySelector('button')! as web.HTMLButtonElement;
  componentButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(
    componentHost.textContent == '2Increment',
    'component UI leaf binding failed',
  );
  _expect(
    identical(componentHost.firstChild, componentRoot),
    'component UI signal update replaced its root',
  );
  disposeComponent();
  componentButton.click();
  await Future<void>.delayed(Duration.zero);
  _expect(componentCount.value == 2, 'disposed component handler still ran');

  final lifecycleCounters = _LifecycleCounters();
  final lifecycleSignal = Signal<int>(0);
  final lifecycleParent =
      _LifecycleParentComponent(lifecycleSignal, lifecycleCounters);
  lifecycleParent.mountInto(componentHost);
  final originalNestedButton = componentHost.querySelectorAll('button').item(1)!
      as web.HTMLButtonElement;
  _expect(
    lifecycleCounters.parentMounts == 1 && lifecycleCounters.childMounts == 1,
    'nested component mount lifecycle did not run once',
  );
  lifecycleSignal.value = 1;
  await Future<void>.delayed(Duration.zero);
  final updatedNestedButton = componentHost.querySelectorAll('button').item(1)!
      as web.HTMLButtonElement;
  _expect(
    lifecycleCounters.parentUpdates == 1 &&
        lifecycleCounters.childMounts == 2 &&
        lifecycleCounters.childDisposals == 1,
    'nested component update did not dispose and remount predictably',
  );
  originalNestedButton.click();
  updatedNestedButton.click();
  _expect(
    lifecycleCounters.clicks == 1,
    'nested event listeners were not cleaned up on component update',
  );
  lifecycleParent.dispose();
  updatedNestedButton.click();
  lifecycleSignal.value = 2;
  await Future<void>.delayed(Duration.zero);
  _expect(
    lifecycleCounters.parentDisposals == 1 &&
        lifecycleCounters.childDisposals == 2 &&
        lifecycleCounters.parentUpdates == 1 &&
        lifecycleCounters.clicks == 1,
    'disposed components remained reactive or retained event listeners',
  );

  final transactionalState = Signal<int>(0);
  final transactionalComponent = _TransactionalComponent(transactionalState);
  transactionalComponent.mountInto(componentHost);
  final transactionalRoot = componentHost.firstChild;
  final transactionalButton =
      componentHost.querySelector('button')! as web.HTMLButtonElement;
  Object? renderError;
  runZonedGuarded(
    () => transactionalState.value = -1,
    (error, _) => renderError = error,
  );
  await Future<void>.delayed(Duration.zero);
  _expect(renderError is StateError, 'component render failure was hidden');
  _expect(
    identical(componentHost.firstChild, transactionalRoot),
    'failed component update replaced the committed root',
  );
  transactionalButton.click();
  _expect(
    transactionalComponent.clicks == 1,
    'failed component update disposed the committed event listener',
  );
  transactionalState.value = 1;
  await Future<void>.delayed(Duration.zero);
  _expect(
    componentHost.textContent == 'State 1' &&
        !identical(componentHost.firstChild, transactionalRoot),
    'component did not recover after a failed render',
  );
  transactionalButton.click();
  _expect(
    transactionalComponent.clicks == 1,
    'successful update retained the previous event listener',
  );
  transactionalComponent.dispose();
  _expect(
    transactionalComponent.disposals == 1,
    'component dispose lifecycle did not run exactly once',
  );

  final disposeResponsiveDom = mountUi(
    Padding(
      attributes: const {'data-test-layout': 'client-padding'},
      responsiveInsets: const ResponsiveValue(
        mobile: Insets.all(3),
        tablet: Insets.all(6),
      ),
      child: SizedBox(width: 20, height: 10),
    ),
    rootSelector: '#direct',
  );
  final clientPadding =
      direct.querySelector('[data-test-layout="client-padding"]');
  if (clientPadding == null) {
    throw StateError('Client DOM rendering omitted the new layout primitive.');
  }
  _expectResponsivePadding(
    clientPadding,
    mobile: '3px',
    tablet: '6px',
    desktop: '6px',
  );
  disposeResponsiveDom();

  final directItems = Signal<List<String>>(['x:One', 'y:Two']);
  final disposeKeyedDirect = mountUi(
    KeyedList<String>(
      id: 'direct_items',
      items: directItems,
      keyOf: (item) => item.split(':').first,
      itemBuilder: (item) => Text(item.split(':').last),
    ),
    rootSelector: '#direct',
  );
  final directList = direct.querySelector('ul')!;
  final directX = directList.querySelector('[data-sparrow-key="x"]')!;
  directItems.value = ['y:Two', 'x:Updated', 'z:Three'];
  await Future<void>.delayed(Duration.zero);
  final directKeyedChildren = directList.querySelectorAll('[data-sparrow-key]');
  _expect(
    directKeyedChildren.length == 3 &&
        (directKeyedChildren.item(0) as web.Element?)
                ?.getAttribute('data-sparrow-key') ==
            'y' &&
        identical(
            directX, directList.querySelector('[data-sparrow-key="x"]')) &&
        directList.querySelector('[data-sparrow-key="x"]')?.textContent ==
            'Updated',
    'direct DOM keyed reconciliation failed',
  );
  disposeKeyedDirect();
  directItems.value = ['x:After dispose'];
  await Future<void>.delayed(Duration.zero);
  _expect(
    directList.querySelector('[data-sparrow-key="x"]')?.textContent ==
        'Updated',
    'disposed direct keyed list kept reacting to signals',
  );

  final stylesheetCountBeforeSharedMounts = web.document.head!
      .querySelectorAll('style[data-sparrow-stylesheet]')
      .length;
  final sharedLayout = Padding(
    responsiveInsets: const ResponsiveValue(
      mobile: Insets.all(5),
      tablet: Insets.all(10),
    ),
    child: const Text('shared stylesheet'),
  );
  final disposeSharedFirst = mountUi(sharedLayout, rootSelector: '#direct');
  final disposeSharedSecond = mountUi(sharedLayout, rootSelector: '#direct');
  _expect(
    web.document.head!
            .querySelectorAll('style[data-sparrow-stylesheet]')
            .length ==
        stylesheetCountBeforeSharedMounts + 1,
    'identical layouts should reuse their stylesheet',
  );
  disposeSharedFirst();
  _expect(
    web.document.head!
            .querySelectorAll('style[data-sparrow-stylesheet]')
            .length ==
        stylesheetCountBeforeSharedMounts + 1,
    'disposing one mount removed a stylesheet still used by another',
  );
  disposeSharedSecond();
  _expect(
    web.document.head!
            .querySelectorAll('style[data-sparrow-stylesheet]')
            .length ==
        stylesheetCountBeforeSharedMounts,
    'disposing the final mount did not clean up its stylesheet',
  );

  final originalTitle = web.document.title;
  final originalLanguage = web.document.documentElement?.getAttribute('lang');
  final headManager = HeadManager();
  headManager.apply(
    HeadMetadata(
      title: 'Hydrated SEO title',
      description: 'Hydrated SEO description',
      canonicalUrl: 'https://example.test/seo/',
      language: 'fr-CA',
      locale: 'fr_CA',
      openGraph: const OpenGraphMetadata(
        title: 'Hydrated OG title',
        type: 'website',
        url: 'https://example.test/seo/',
        image: 'https://example.test/seo.png',
      ),
      twitterCard: const TwitterCardMetadata(
        card: 'summary_large_image',
        title: 'Hydrated Twitter title',
      ),
      robots: const RobotsDirectives(index: false),
      jsonLd: const [
        OrganizationJsonLd(name: 'Sparrow', url: 'https://example.test/'),
      ],
    ),
  );
  _expect(
    web.document.documentElement?.getAttribute('lang') == 'fr-CA' &&
        web.document.title == 'Hydrated SEO title' &&
        web.document.head
                ?.querySelector('meta[name="description"]')
                ?.getAttribute('content') ==
            'Hydrated SEO description' &&
        web.document.head
                ?.querySelector('meta[property="og:title"]')
                ?.getAttribute('content') ==
            'Hydrated OG title' &&
        web.document.head
                ?.querySelector('meta[name="twitter:card"]')
                ?.getAttribute('content') ==
            'summary_large_image' &&
        web.document.head
                ?.querySelector('meta[name="robots"]')
                ?.getAttribute('content') ==
            'noindex, follow' &&
        web.document.head?.querySelector(
              'script[type="application/ld+json"]',
            ) !=
            null,
    'HeadManager did not apply typed metadata during hydration',
  );
  headManager.dispose();
  _expect(
    web.document.title == originalTitle &&
        web.document.documentElement?.getAttribute('lang') ==
            originalLanguage &&
        web.document.head?.querySelector('link[rel="canonical"]') == null &&
        web.document.head?.querySelector('meta[name="robots"]') == null &&
        web.document.head?.querySelector(
              'script[type="application/ld+json"]',
            ) ==
            null,
    'HeadManager did not restore document metadata when disposed',
  );

  web.document.body!.setAttribute('data-test-result', 'passed');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

UiNode _responsivePage(
  Signal<int> count,
  Signal<List<String>> items,
) =>
    Responsive(
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
      children: [
        Heading(1, 'Hydration test'),
        Text.bind('count', count),
        Button(label: 'Increment', onPressed: (_) => count.value++),
        Padding(
          attributes: const {'data-test-layout': 'responsive-padding'},
          responsiveInsets: const ResponsiveValue(
            mobile: Insets.all(4),
            tablet: Insets.all(8),
            desktop: Insets.all(12),
          ),
          child: const Text('responsive padding'),
        ),
        Margin(
          attributes: const {'data-test-layout': 'margin'},
          responsiveInsets: const ResponsiveValue(
            mobile: Insets.all(-2),
            tablet: Insets.all(-4),
            desktop: Insets.all(-6),
          ),
          child: const Text('negative margin'),
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              attributes: const {'data-test-layout': 'expanded'},
              child: const Text('expanded'),
            ),
            Flexible(
              attributes: const {'data-test-layout': 'flexible'},
              child: const Text('flexible'),
            ),
          ],
        ),
        SizedBox(
          width: 32,
          height: 16,
          attributes: {'data-test-layout': 'sized-box'},
        ),
        Stack(
          width: 80,
          height: 50,
          attributes: const {'data-test-layout': 'stack'},
          children: [
            const Text('stack background'),
            Positioned(
              top: 6,
              right: 7,
              bottom: 8,
              left: 4,
              width: 20,
              height: 10,
              attributes: const {'data-test-layout': 'positioned'},
              child: const Text('positioned child'),
            ),
          ],
        ),
        Grid(
          attributes: const {'data-test-layout': 'responsive-grid'},
          responsiveColumns: const ResponsiveValue(
            mobile: 1,
            tablet: 2,
            desktop: 4,
          ),
          responsiveGap: const ResponsiveValue(
            mobile: 4,
            tablet: 8,
            desktop: 16,
          ),
          children: const [
            Text('grid one'),
            Text('grid two'),
            Text('grid three'),
            Text('grid four'),
          ],
        ),
        KeyedList<String>(
          id: 'keyed_items',
          items: items,
          keyOf: (item) => item.split(':').first,
          itemBuilder: (item) => Button(
            label: item.split(':').last,
            onPressed: _keyedButtonHandler,
          ),
        ),
      ],
    );

void _expectResponsiveLayoutStyles(web.Element app) {
  final width = web.window.innerWidth;
  final padding = app.querySelector(
    '[data-test-layout="responsive-padding"]',
  );
  if (padding == null) {
    throw StateError('Hydrated responsive padding is missing.');
  }
  _expectResponsivePadding(
    padding,
    mobile: '4px',
    tablet: '8px',
    desktop: '12px',
  );

  final margin = app.querySelector('[data-test-layout="margin"]');
  final expanded = app.querySelector('[data-test-layout="expanded"]');
  final flexible = app.querySelector('[data-test-layout="flexible"]');
  final sizedBox = app.querySelector('[data-test-layout="sized-box"]');
  final stack = app.querySelector('[data-test-layout="stack"]');
  final positioned = app.querySelector('[data-test-layout="positioned"]');
  final grid = app.querySelector('[data-test-layout="responsive-grid"]');
  if (margin == null ||
      expanded == null ||
      flexible == null ||
      sizedBox == null ||
      stack == null ||
      positioned == null ||
      grid == null) {
    throw StateError('Hydrated layout primitive is missing.');
  }

  final expectedMarginTop = width >= 1024
      ? '-6px'
      : width >= 600
          ? '-4px'
          : '-2px';
  _expect(
    web.window.getComputedStyle(margin).marginTop == expectedMarginTop,
    'responsive negative margins were not rendered',
  );
  _expect(
    web.window.getComputedStyle(expanded).flexGrow == '2' &&
        web.window.getComputedStyle(expanded).flexBasis == '0%',
    'Expanded flex sizing was not applied',
  );
  _expect(
    web.window.getComputedStyle(flexible).flexGrow == '0' &&
        web.window.getComputedStyle(flexible).flexBasis == 'auto',
    'Flexible sizing was not applied',
  );
  _expect(
    (sizedBox.getAttribute('style') ?? '').contains('width:32px') &&
        (sizedBox.getAttribute('style') ?? '').contains('height:16px') &&
        _cssLengthIsNear(web.window.getComputedStyle(sizedBox).height, 16),
    'SizedBox dimensions were not applied',
  );
  _expect(
    web.window.getComputedStyle(stack).position == 'relative',
    'Stack did not establish its positioning context',
  );
  _expect(
    web.window.getComputedStyle(positioned).position == 'absolute' &&
        web.window.getComputedStyle(positioned).top == '6px' &&
        web.window.getComputedStyle(positioned).left == '4px' &&
        _cssLengthIsNear(web.window.getComputedStyle(positioned).width, 20) &&
        _cssLengthIsNear(web.window.getComputedStyle(positioned).height, 10) &&
        (positioned.getAttribute('style') ?? '').contains('right:7px') &&
        (positioned.getAttribute('style') ?? '').contains('bottom:8px'),
    'Positioned offsets were not applied',
  );

  final gridStyle = web.window.getComputedStyle(grid);
  final expectedColumns = width >= 1024
      ? 4
      : width >= 600
          ? 2
          : 1;
  final expectedGap = width >= 1024
      ? '16px'
      : width >= 600
          ? '8px'
          : '4px';
  _expect(
    gridStyle.gridTemplateColumns.trim().split(RegExp(r'\s+')).length ==
            expectedColumns &&
        gridStyle.gap == expectedGap,
    'responsive Grid columns or gap mismatch at ${width}px',
  );
}

void _expectResponsivePadding(
  web.Element padding, {
  required String mobile,
  required String tablet,
  required String desktop,
}) {
  final width = web.window.innerWidth;
  final expected = width >= 1024
      ? desktop
      : width >= 600
          ? tablet
          : mobile;
  _expect(
    web.window.getComputedStyle(padding).paddingTop == expected,
    'responsive Padding mismatch at ${width}px',
  );
}

bool _cssLengthIsNear(String value, double expected) {
  final actual = double.tryParse(value.replaceFirst('px', ''));
  return actual != null && (actual - expected).abs() < 0.1;
}
