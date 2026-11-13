import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:sparrow_kit/sparrow_kit.dart';
import 'package:web/web.dart' as web;

var _keyedButtonClicks = 0;
final MarkupEventHandler _keyedButtonHandler = _recordKeyedButtonClick;

void _recordKeyedButtonClick(Object? _) {
  _keyedButtonClicks++;
}

class _MarkupSsrFixture implements SsrComponent {
  _MarkupSsrFixture(this.node);

  final MarkupNode node;

  @override
  MarkupNode render() => node;
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

  _testHydrationFailureRecoveryAndStateSafety();

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

  await _testBrowserRouter();
  await _testRouteView();
  await _testCatalogRouteView();
  web.document.body!.setAttribute('data-test-result', 'passed');
}

Future<void> _testCatalogRouteView() async {
  const initialLocation = '/catalog-view/users/17?tab=initial';
  web.window.history.replaceState(null, '', initialLocation);
  final clickCount = Signal(0);
  final wasClicked = Signal(false);
  final catalogItems = Signal<List<String>>(['first']);
  final catalog = RouteCatalog(
    routes: [
      RouteConfig(
        definition: RouteDefinition('/catalog-view/users/:userId'),
        pageBuilder: (match) {
          final userId = match.params['userId']!;
          return UiPage(
            () => Column(
              attributes: const {'data-route-page': 'user'},
              children: [
                Heading(1, 'catalog user:$userId'),
                Text('catalog tab:${match.queryParameters['tab'] ?? ''}'),
                const Text('catalog click count:'),
                Text.bind('catalog_user_click_count_$userId', clickCount),
                Button(
                  label: 'increment user clicks',
                  onPressed: (_) {
                    clickCount.value++;
                    wasClicked.value = true;
                    catalogItems.value = [
                      ...catalogItems.value,
                      'next',
                    ];
                  },
                  attributes: {
                    'data-clicked': SignalAttribute(
                      'catalog_user_clicked_$userId',
                      wasClicked,
                    ),
                  },
                ),
                KeyedList<String>(
                  id: 'catalog_user_items_$userId',
                  items: catalogItems,
                  keyOf: (item) => item,
                  itemBuilder: (item) => Text(item),
                  attributes: const {'data-catalog-list': 'true'},
                ),
              ],
            ),
          );
        },
        metadataBuilder: (match) {
          final userId = match.params['userId']!;
          final canonicalUrl =
              'https://example.test/catalog-view/users/$userId/';
          return HeadMetadata(
            title: 'Catalog user $userId',
            description: 'Profile for catalog user $userId',
            canonicalUrl: canonicalUrl,
            openGraph: OpenGraphMetadata(
              title: 'Catalog OG user $userId',
              type: 'profile',
              url: canonicalUrl,
              image: 'https://example.test/user.png',
              description: 'OG profile for user $userId',
            ),
            twitterCard: TwitterCardMetadata(
              card: 'summary_large_image',
              title: 'Catalog Twitter user $userId',
              description: 'Twitter profile for user $userId',
            ),
            robots: const RobotsDirectives(),
            jsonLd: const [
              OrganizationJsonLd(
                name: 'Sparrow Catalog',
                url: 'https://example.test/catalog/',
              ),
            ],
          );
        },
      ),
      RouteConfig(
        definition: RouteDefinition('/catalog-view/about'),
        indexable: false,
        pageBuilder: (_) => UiPage(
          () => Heading(
            1,
            'catalog about',
            attributes: const {'data-route-page': 'about'},
          ),
        ),
        metadataBuilder: (_) => HeadMetadata(
          title: 'Catalog about',
          canonicalUrl: 'https://example.test/catalog-view/about/',
        ),
      ),
    ],
    notFoundBuilder: (match) => UiPage(
      () => Heading(
        1,
        'catalog missing:${match.path}',
        attributes: const {'data-route-page': 'not-found'},
      ),
    ),
    notFoundMetadataBuilder: (_) => HeadMetadata(
      title: 'Catalog Not Found',
      description: 'This catalog route does not exist.',
      robots: const RobotsDirectives(index: false),
    ),
  );

  await _testCatalogDynamicHydrationAndNavigation(catalog, initialLocation);
  await _testCatalogStaticDirectHydration(catalog);
  _testCatalogHydrationMismatch(catalog);
}

void _testHydrationFailureRecoveryAndStateSafety() {
  const payload =
      '</script><img id="hydration-injected" src=x onerror="alert(1)">';
  final serializedHtml = renderToString(
    _MarkupSsrFixture(SignalText('state_payload', Signal<String>(payload))),
    clientScript: null,
  );
  final serializedDocument =
      web.DOMParser().parseFromString(serializedHtml, 'text/html');
  final stateScript = serializedDocument.getElementById('__FRAMEWORK_STATE__');
  if (stateScript == null) {
    throw StateError('Serialized hydration state was not rendered.');
  }
  final decodedState =
      jsonDecode(stateScript.textContent!) as Map<String, dynamic>;
  _expect(
    decodedState['state_payload'] == payload &&
        !stateScript.textContent!.contains('</script>') &&
        serializedDocument.getElementById('hydration-injected') == null,
    'Serialized hydration state was not safely escaped.',
  );

  Object? invalidStateError;
  try {
    HydrationState({'count': 'not an integer'})
        .signal<int>('count', fallback: 0);
  } on FormatException catch (error) {
    invalidStateError = error;
  }
  _expect(
    invalidStateError.toString().contains('hydration signal "count"'),
    'Invalid serialized signal state lacked a useful diagnostic.',
  );

  final repeatedState = HydrationState({'shared': 1});
  repeatedState.signal<int>('shared', fallback: 0);
  Object? inconsistentTypeError;
  try {
    repeatedState.signal<String>('shared', fallback: '');
  } on StateError catch (error) {
    inconsistentTypeError = error;
  }
  _expect(
    inconsistentTypeError.toString().contains(
        'Hydration signal "shared" was requested with inconsistent types'),
    'A reused hydration signal accepted an inconsistent type.',
  );

  var clicks = 0;
  const stylesheet = '.hydration-rollback-fixture { color: red; }';
  final tree = MarkupElement(
    'div',
    stylesheets: [stylesheet],
    children: [
      MarkupElement(
        'button',
        events: {'click': (_) => clicks++},
        children: [MarkupText('early listener')],
      ),
      MarkupElement('span', children: [MarkupText('expected text')]),
    ],
  );
  final serverHtml =
      renderToString(_MarkupSsrFixture(tree), clientScript: null);
  final serverDocument =
      web.DOMParser().parseFromString(serverHtml, 'text/html');
  final serverRoot = serverDocument.getElementById('app')?.firstChild;
  if (serverRoot == null) {
    throw StateError('Hydration rollback fixture has no server-rendered root.');
  }

  final host = web.document.createElement('div');
  host.appendChild(serverRoot.cloneNode(true));
  web.document.body!.appendChild(host);
  final spanText = host.querySelector('span')?.firstChild;
  if (spanText is! web.Text) {
    host.remove();
    throw StateError('Hydration rollback fixture text node is missing.');
  }
  spanText.data = 'mismatched text';
  final markupBeforeFailure = host.innerHTML;
  final stylesheetId = markupStylesheetId(stylesheet);
  final styleExistedBefore = web.document.getElementById(stylesheetId) != null;
  final engine = HydrationEngine();
  void Function()? disposeHydration;

  try {
    Object? mismatch;
    try {
      engine.hydrate(container: host, tree: tree);
    } on StateError catch (error) {
      mismatch = error;
    }
    _expect(
      mismatch.toString().contains('Text mismatch at root/div[1]/span[0]') &&
          host.innerHTML == markupBeforeFailure &&
          (web.document.getElementById(stylesheetId) != null) ==
              styleExistedBefore,
      'Failed hydration changed server markup or retained its stylesheet.',
    );
    (host.querySelector('button')! as web.HTMLButtonElement).click();
    _expect(clicks == 0, 'Failed hydration left an event listener attached.');

    spanText.data = 'expected text';
    final serverRootAfterRepair = host.firstChild;
    disposeHydration = engine.hydrate(container: host, tree: tree);
    _expect(
      identical(host.firstChild, serverRootAfterRepair) &&
          web.document.getElementById(stylesheetId) != null,
      'Recovered hydration did not reuse the repaired SSR root.',
    );
    final activeDisposer = disposeHydration;

    Object? repeatedHydrationError;
    try {
      HydrationEngine().hydrate(container: host, tree: tree);
    } on StateError catch (error) {
      repeatedHydrationError = error;
    }
    _expect(
      repeatedHydrationError
          .toString()
          .contains('This container is already being hydrated'),
      'Repeated hydration was not rejected while bindings were active.',
    );
    (host.querySelector('button')! as web.HTMLButtonElement).click();
    _expect(clicks == 1, 'Repeated hydration attached a duplicate listener.');

    activeDisposer();
    activeDisposer();
    (host.querySelector('button')! as web.HTMLButtonElement).click();
    _expect(
      clicks == 1 && web.document.getElementById(stylesheetId) == null,
      'Hydration disposal left listeners or stylesheets active.',
    );

    disposeHydration = engine.hydrate(container: host, tree: tree);
    (host.querySelector('button')! as web.HTMLButtonElement).click();
    _expect(
      clicks == 2,
      'A disposed container could not be hydrated cleanly again.',
    );
  } finally {
    disposeHydration?.call();
    host.remove();
  }
}

Future<void> _testCatalogDynamicHydrationAndNavigation(
  RouteCatalog catalog,
  String initialLocation,
) async {
  final originalHead = web.document.head!.innerHTML;
  final originalTitle = web.document.title;
  final originalLanguage = web.document.documentElement?.getAttribute('lang');
  final initialHtml =
      catalog.renderRequest(initialLocation, clientScript: null).html;
  final parsedDocument =
      web.DOMParser().parseFromString(initialHtml, 'text/html');
  final serverRoot = parsedDocument.getElementById('app');
  if (serverRoot?.firstChild == null || parsedDocument.head == null) {
    throw StateError('The route catalog did not render initial server markup.');
  }

  final host = web.document.createElement('div');
  host.appendChild(serverRoot!.firstChild!.cloneNode(true));
  final serverPageRoot = host.firstChild;
  web.document.body!.appendChild(host);
  web.document.head!.innerHTML = parsedDocument.head!.innerHTML;
  web.document.documentElement!.setAttribute(
    'lang',
    parsedDocument.documentElement!.getAttribute('lang')!,
  );
  final serverCanonical =
      web.document.head!.querySelector('link[rel="canonical"]');
  final serverDescription =
      web.document.head!.querySelector('meta[name="description"]');
  final serverOpenGraph =
      web.document.head!.querySelector('meta[property="og:title"]');
  final serverTwitter =
      web.document.head!.querySelector('meta[name="twitter:card"]');
  final serverJsonLd =
      web.document.head!.querySelector('script[type="application/ld+json"]');
  final router = Router.fromCatalog(catalog: catalog);
  final routeView = RouteView.fromCatalog(
    router: router,
    catalog: catalog,
    hydrateExisting: true,
  );
  var pageLifecycleEvents = 0;
  final pageLifecycleListener = ((web.Event _) => pageLifecycleEvents++).toJS;
  web.window.addEventListener('beforeunload', pageLifecycleListener);
  web.window.addEventListener('pagehide', pageLifecycleListener);

  try {
    routeView.mountInto(host);
    _expect(
      identical(router.routeTable, catalog.routeTable) &&
          identical(host.firstChild, serverPageRoot) &&
          host.textContent!.contains('catalog user:17') &&
          host.textContent!.contains('catalog tab:initial') &&
          router.currentRoute.value.params['userId'] == '17' &&
          router.currentRoute.value.queryParameters['tab'] == 'initial' &&
          host.querySelectorAll('h1').length == 1 &&
          web.document.title == 'Catalog user 17' &&
          identical(
            web.document.head!.querySelector('link[rel="canonical"]'),
            serverCanonical,
          ) &&
          identical(
            web.document.head!.querySelector('meta[name="description"]'),
            serverDescription,
          ) &&
          identical(
            web.document.head!.querySelector('meta[property="og:title"]'),
            serverOpenGraph,
          ) &&
          identical(
            web.document.head!.querySelector('meta[name="twitter:card"]'),
            serverTwitter,
          ) &&
          web.document.head!
                  .querySelectorAll('script[type="application/ld+json"]')
                  .length ==
              1 &&
          identical(
            web.document.head!
                .querySelector('script[type="application/ld+json"]'),
            serverJsonLd,
          ),
      'Direct dynamic-route hydration replaced DOM or duplicated SSR metadata.',
    );

    final serverButton = host.querySelector('button') as web.HTMLButtonElement;
    final hydratedRoot = host.firstChild;
    final serverList = host.querySelector('ul');
    final serverFirstItem = host.querySelector('li');
    if (serverList == null || serverFirstItem == null) {
      throw StateError('The direct route did not render keyed child markup.');
    }
    serverButton.click();
    await _waitForRouteViewText(host, 'catalog click count:1');
    await _waitForRouteViewText(host, 'next');
    final didPreserveRoot = identical(host.firstChild, hydratedRoot);
    final didPreserveButton =
        identical(host.querySelector('button'), serverButton);
    final didPreserveKeyedNodes =
        identical(host.querySelector('ul'), serverList) &&
            identical(host.querySelector('li'), serverFirstItem);
    final hasReactiveText = host.textContent!.contains('catalog click count:1');
    final hasReactiveAttribute = serverButton.hasAttribute('data-clicked');
    _expect(
      didPreserveRoot &&
          didPreserveButton &&
          didPreserveKeyedNodes &&
          hasReactiveText &&
          hasReactiveAttribute &&
          host.textContent!.contains('catalog user:17') &&
          pageLifecycleEvents == 0,
      'Hydrated event/reactive behavior failed: root=$didPreserveRoot, '
      'button=$didPreserveButton, keyed=$didPreserveKeyedNodes, '
      'text=$hasReactiveText, '
      'attribute=$hasReactiveAttribute, '
      'lifecycle=$pageLifecycleEvents.',
    );

    router.push('/catalog-view/users/42?tab=details');
    await _waitForCatalogRoute(host, 'catalog user:42', 'Catalog user 42');
    _expect(
      host.textContent!.contains('catalog tab:details') &&
          web.document.head
                  ?.querySelector('link[rel="canonical"]')
                  ?.getAttribute('href') ==
              'https://example.test/catalog-view/users/42/' &&
          web.document.head
                  ?.querySelector('meta[property="og:title"]')
                  ?.getAttribute('content') ==
              'Catalog OG user 42' &&
          web.document.head
                  ?.querySelector('meta[name="twitter:title"]')
                  ?.getAttribute('content') ==
              'Catalog Twitter user 42' &&
          web.document.head
                  ?.querySelector('meta[name="robots"]')
                  ?.getAttribute('content') ==
              'index, follow' &&
          web.document.head!
                  .querySelectorAll('script[type="application/ld+json"]')
                  .length ==
              1 &&
          router.currentRoute.value.queryParameters['tab'] == 'details',
      'Dynamic route navigation did not synchronize URL, content, and metadata.',
    );

    router.push('/catalog-view/about?tab=legal');
    await _waitForCatalogRoute(host, 'catalog about', 'Catalog about');
    _expect(
      router.currentRoute.value.route?.path == '/catalog-view/about' &&
          router.currentRoute.value.queryParameters['tab'] == 'legal' &&
          web.document.head!.querySelector('meta[name="description"]') ==
              null &&
          web.document.head!.querySelector('meta[property^="og:"]') == null &&
          web.document.head!.querySelector('meta[name^="twitter:"]') == null &&
          web.document.head!
                  .querySelector('link[rel="canonical"]')
                  ?.getAttribute('href') ==
              'https://example.test/catalog-view/about/' &&
          web.document.head
                  ?.querySelector('meta[name="robots"]')
                  ?.getAttribute('content') ==
              'noindex, follow' &&
          web.document.head!
                  .querySelectorAll('script[type="application/ld+json"]')
                  .length ==
              0,
      'Optional metadata from the previous route remained active.',
    );

    _expect(
      web.window.location.pathname == '/catalog-view/about' &&
          pageLifecycleEvents == 0,
      'Internal route navigation caused a full document reload.',
    );

    router.push('/catalog-view/unknown?source=direct');
    await _waitForCatalogRoute(
      host,
      'catalog missing:/catalog-view/unknown',
      'Catalog Not Found',
    );
    _expectCatalogHead(
      title: 'Catalog Not Found',
      description: 'This catalog route does not exist.',
      robots: 'noindex, follow',
    );

    await _waitForWindowEvent('popstate', () => web.window.history.back());
    await _waitForCatalogRoute(host, 'catalog about', 'Catalog about');
    _expectCatalogHead(
      title: 'Catalog about',
      canonical: 'https://example.test/catalog-view/about/',
      robots: 'noindex, follow',
    );
    await _waitForWindowEvent('popstate', () => web.window.history.forward());
    await _waitForCatalogRoute(
      host,
      'catalog missing:/catalog-view/unknown',
      'Catalog Not Found',
    );
    _expectCatalogHead(
      title: 'Catalog Not Found',
      description: 'This catalog route does not exist.',
      robots: 'noindex, follow',
    );

    routeView.dispose();
    _expect(
      web.document.title == 'Catalog user 17' &&
          identical(
            web.document.head!.querySelector('meta[property="og:title"]'),
            serverOpenGraph,
          ) &&
          web.document.head!
                  .querySelectorAll('script[type="application/ld+json"]')
                  .length ==
              1,
      'Disposing RouteView did not restore the original SSR head.',
    );
  } finally {
    routeView.dispose();
    router.dispose();
    web.window.removeEventListener('beforeunload', pageLifecycleListener);
    web.window.removeEventListener('pagehide', pageLifecycleListener);
    host.remove();
    web.document.head!.innerHTML = originalHead;
    web.document.title = originalTitle;
    if (originalLanguage == null) {
      web.document.documentElement?.removeAttribute('lang');
    } else {
      web.document.documentElement?.setAttribute('lang', originalLanguage);
    }
  }
}

Future<void> _testCatalogStaticDirectHydration(RouteCatalog catalog) async {
  const location = '/catalog-view/about?tab=legal';
  web.window.history.replaceState(null, '', location);
  final initialHtml = catalog.renderRequest(location, clientScript: null).html;
  final parsedDocument =
      web.DOMParser().parseFromString(initialHtml, 'text/html');
  final serverRoot = parsedDocument.getElementById('app');
  if (serverRoot?.firstChild == null || parsedDocument.head == null) {
    throw StateError('The static route did not render server markup.');
  }

  final originalHead = web.document.head!.innerHTML;
  final originalTitle = web.document.title;
  final host = web.document.createElement('div');
  host.appendChild(serverRoot!.firstChild!.cloneNode(true));
  final serverPageRoot = host.firstChild;
  web.document.body!.appendChild(host);
  web.document.head!.innerHTML = parsedDocument.head!.innerHTML;
  final router = Router.fromCatalog(catalog: catalog);
  final routeView = RouteView.fromCatalog(
    router: router,
    catalog: catalog,
    hydrateExisting: true,
  );

  try {
    routeView.mountInto(host);
    _expect(
      identical(host.firstChild, serverPageRoot) &&
          host.childNodes.length == 1 &&
          host.textContent!.contains('catalog about') &&
          router.currentRoute.value.route?.path == '/catalog-view/about' &&
          router.currentRoute.value.queryParameters['tab'] == 'legal' &&
          web.document.title == 'Catalog about',
      'Direct static-route hydration did not preserve the SSR page.',
    );
  } finally {
    routeView.dispose();
    router.dispose();
    host.remove();
    web.document.head!.innerHTML = originalHead;
    web.document.title = originalTitle;
  }
}

void _testCatalogHydrationMismatch(RouteCatalog catalog) {
  const location = '/catalog-view/about';
  web.window.history.replaceState(null, '', location);
  final initialHtml = catalog.renderRequest(location, clientScript: null).html;
  final parsedDocument =
      web.DOMParser().parseFromString(initialHtml, 'text/html');
  final serverRoot = parsedDocument.getElementById('app');
  if (serverRoot?.firstChild == null) {
    throw StateError('The mismatch fixture did not render server markup.');
  }

  final host = web.document.createElement('div');
  host.appendChild(serverRoot!.firstChild!.cloneNode(true));
  final originalRoot = host.firstChild;
  final text = host.querySelector('h1')?.firstChild;
  if (text is! web.Text) {
    throw StateError('The mismatch fixture heading was not rendered as text.');
  }
  text.data = 'intentionally mismatched';
  web.document.body!.appendChild(host);
  final router = Router.fromCatalog(catalog: catalog);
  final routeView = RouteView.fromCatalog(
    router: router,
    catalog: catalog,
    hydrateExisting: true,
  );
  Object? mismatch;
  var serverRootPreserved = false;

  try {
    routeView.mountInto(host);
  } catch (error) {
    mismatch = error;
    serverRootPreserved = identical(host.firstChild, originalRoot);
  } finally {
    routeView.dispose();
    router.dispose();
    host.remove();
  }

  _expect(
    mismatch.toString().contains('Text mismatch at root/h1[0]') &&
        serverRootPreserved,
    'Direct-route hydration did not report a useful mismatch diagnostic.',
  );
}

Future<void> _waitForCatalogRoute(
  web.Element host,
  String expectedText,
  String expectedTitle,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if ((host.textContent?.contains(expectedText) ?? false) &&
        web.document.title == expectedTitle) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError(
    'Timed out waiting for route "$expectedText" and title "$expectedTitle".',
  );
}

void _expectCatalogHead({
  required String title,
  String? description,
  String? canonical,
  String? robots,
}) {
  final head = web.document.head!;
  _expect(
    web.document.title == title &&
        head.querySelector('meta[name="description"]')?.getAttribute(
                  'content',
                ) ==
            description &&
        head.querySelector('link[rel="canonical"]')?.getAttribute('href') ==
            canonical &&
        head.querySelector('meta[property^="og:"]') == null &&
        head.querySelector('meta[name^="twitter:"]') == null &&
        head.querySelector('meta[name="robots"]')?.getAttribute('content') ==
            robots,
    'Route head metadata was not cleared or restored for "$title".',
  );
}

Future<void> _testRouteView() async {
  web.window.history.replaceState(
    null,
    '',
    '/route-view/users/17?tab=initial',
  );
  final router = Router(
    routes: [
      RouteDefinition('/route-view/users/:userId'),
      RouteDefinition('/route-view/about'),
    ],
  );
  final host = web.document.createElement('div');
  web.document.body!.appendChild(host);
  var userPageClicks = 0;
  var pageBuilderCalls = 0;
  var pageLifecycleEvents = 0;
  final pageLifecycleListener = ((web.Event _) => pageLifecycleEvents++).toJS;
  web.window.addEventListener('beforeunload', pageLifecycleListener);
  web.window.addEventListener('pagehide', pageLifecycleListener);

  final routeView = RouteView(
    router: router,
    pageBuilder: (match) {
      pageBuilderCalls++;
      if (match.route?.path == '/route-view/users/:userId') {
        return Column(
          attributes: const {'data-route-page': 'user'},
          children: [
            Heading(1, 'user:${match.params['userId']}'),
            Text('tab:${match.queryParameters['tab'] ?? ''}', tag: 'p'),
            Button(
              label: 'user action',
              onPressed: (_) => userPageClicks++,
            ),
          ],
        );
      }
      return Heading(
        1,
        'about page',
        attributes: const {'data-route-page': 'about'},
      );
    },
    notFoundBuilder: (match) => Heading(
      1,
      'not found:${match.path}',
      attributes: const {'data-route-page': 'not-found'},
    ),
  );
  final shell = component<void>(
    (_, __) => createElement(
      'main',
      children: [
        createElement('header', children: const ['persistent shell']),
        routeView,
      ],
    ),
  )(null);

  try {
    shell.mountInto(host);
    final shellRoot = host.firstChild;
    final shellHeader = host.querySelector('header');
    final initialUserButton =
        host.querySelector('[data-route-page="user"] button')
            as web.HTMLButtonElement;
    _expect(
      host.textContent!.contains('user:17') &&
          host.textContent!.contains('tab:initial'),
      'RouteView did not render the initial matched route',
    );

    router.push('/route-view/users/42?tab=profile');
    await _waitForRouteViewText(host, 'user:42');
    _expect(
      host.textContent!.contains('tab:profile'),
      'RouteView did not render updated route parameters and query values',
    );
    initialUserButton.click();
    _expect(
      userPageClicks == 0,
      'The previous route view retained its event listener after replacement',
    );

    final profileUserButton =
        host.querySelector('[data-route-page="user"] button')
            as web.HTMLButtonElement;
    router.push('?tab=settings');
    await _waitForRouteViewText(host, 'tab:settings');
    router.push('/route-view/about');
    await _waitForRouteViewText(host, 'about page');
    _expect(
      identical(host.firstChild, shellRoot) &&
          identical(host.querySelector('header'), shellHeader),
      'Route navigation replaced the mounted application shell',
    );
    profileUserButton.click();
    _expect(
      userPageClicks == 0,
      'A departed route view retained its event listener',
    );

    router.push('/route-view/missing');
    await _waitForRouteViewText(host, 'not found:/route-view/missing');
    router.push('/route-view/users/99?tab=history');
    await _waitForRouteViewText(host, 'user:99');
    await _waitForWindowEvent('popstate', () => web.window.history.back());
    await _waitForRouteViewText(host, 'not found:/route-view/missing');
    await _waitForWindowEvent('popstate', () => web.window.history.forward());
    await _waitForRouteViewText(host, 'user:99');
    _expect(
      host.textContent!.contains('tab:history'),
      'Browser back and forward did not update the rendered route view',
    );
    (host.querySelector('[data-route-page="user"] button')
            as web.HTMLButtonElement)
        .click();
    _expect(
      userPageClicks == 1,
      'The active route view did not retain its event handler',
    );
    _expect(
      pageLifecycleEvents == 0,
      'Client-side navigation triggered a full-page lifecycle event',
    );

    final currentUserButton =
        host.querySelector('[data-route-page="user"] button')
            as web.HTMLButtonElement;
    final callsBeforeDispose = pageBuilderCalls;
    shell.dispose();
    currentUserButton.click();
    router.push('/route-view/about');
    await Future<void>.delayed(Duration.zero);
    _expect(
      userPageClicks == 1 &&
          pageBuilderCalls == callsBeforeDispose &&
          host.firstChild == null,
      'Disposing the route shell did not clean up the route view',
    );
  } finally {
    shell.dispose();
    router.dispose();
    web.window.removeEventListener('beforeunload', pageLifecycleListener);
    web.window.removeEventListener('pagehide', pageLifecycleListener);
    host.remove();
  }
}

Future<void> _testBrowserRouter() async {
  web.window.history.replaceState(
    null,
    '',
    '/router-test/users/7?q=initial#section',
  );
  final router = Router(
    routes: [
      RouteDefinition('/router-test/users/:userId'),
      RouteDefinition('/router-test/search'),
    ],
  );
  var isDisposed = false;

  try {
    _expect(
      router.currentRoute.value.path == '/router-test/users/7' &&
          router.param('userId').value == '7' &&
          router.queryParam('q').value == 'initial' &&
          router.currentRoute.value.fragment == 'section',
      'Router did not initialize from the current browser URL',
    );

    router.push('/router-test/users/42?tab=profile#details');
    _expect(
      web.window.location.pathname == '/router-test/users/42' &&
          web.window.location.search == '?tab=profile' &&
          web.window.location.hash == '#details' &&
          router.currentRoute.value.params['userId'] == '42' &&
          router.param('userId').value == '42' &&
          router.queryParameters.value['tab'] == 'profile' &&
          router.queryParam('tab').value == 'profile' &&
          router.currentRoute.value.fragment == 'details',
      'Router.push did not update the URL and route signals',
    );

    router.push('?tab=settings');
    _expect(
      web.window.location.pathname == '/router-test/users/42' &&
          web.window.location.search == '?tab=settings' &&
          web.window.location.hash.isEmpty &&
          router.currentRoute.value.queryParameters['tab'] == 'settings' &&
          router.currentRoute.value.fragment.isEmpty,
      'Query-only navigation did not preserve the path or replace query state',
    );

    router.push('#top');
    _expect(
      web.window.location.hash == '#top' &&
          router.currentRoute.value.fragment == 'top',
      'Fragment-only navigation did not update the route fragment',
    );

    router.push('/router-test/search?stage=one');
    router.push('/router-test/search?stage=two');
    await _waitForWindowEvent('popstate', () => web.window.history.back());
    _expect(
      web.window.location.search == '?stage=one' &&
          router.currentRoute.value.path == '/router-test/search' &&
          router.queryParam('stage').value == 'one',
      'Browser back did not synchronize the URL and route state',
    );
    await _waitForWindowEvent('popstate', () => web.window.history.forward());
    _expect(
      web.window.location.search == '?stage=two' &&
          router.queryParam('stage').value == 'two',
      'Browser forward did not synchronize the URL and route state',
    );

    router.push('/router-test/not-found');
    _expect(
      router.currentRoute.value.isNotFound &&
          router.currentRoute.value.path == '/router-test/not-found',
      'Router did not transition to a not-found match',
    );
    await _waitForWindowEvent('popstate', () => web.window.history.back());
    _expect(
      !router.currentRoute.value.isNotFound &&
          web.window.location.search == '?stage=two',
      'Browser back did not leave the not-found match',
    );
    await _waitForWindowEvent('popstate', () => web.window.history.forward());
    _expect(
      router.currentRoute.value.isNotFound &&
          web.window.location.pathname == '/router-test/not-found',
      'Browser forward did not restore the not-found match',
    );

    final intercepted = _dispatchRouterAnchorClick(
      '/router-test/search?q=anchor',
    );
    _expect(
      intercepted &&
          web.window.location.pathname == '/router-test/search' &&
          web.window.location.search == '?q=anchor' &&
          router.currentRoute.value.route?.path == '/router-test/search' &&
          router.queryParam('q').value == 'anchor',
      'Same-origin anchor navigation was not intercepted by the router',
    );

    _expect(
      !_dispatchRouterAnchorClick('https://outside.example/path'),
      'The router intercepted an external link',
    );
    _expect(
      !_dispatchRouterAnchorClick(
            '/router-test/users/1',
            ctrlKey: true,
          ) &&
          !_dispatchRouterAnchorClick(
            '/router-test/users/1',
            metaKey: true,
          ) &&
          !_dispatchRouterAnchorClick(
            '/router-test/users/1',
            shiftKey: true,
          ) &&
          !_dispatchRouterAnchorClick(
            '/router-test/users/1',
            altKey: true,
          ),
      'The router intercepted a modified click',
    );
    _expect(
      !_dispatchRouterAnchorClick(
        '/router-test/users/1',
        download: true,
      ),
      'The router intercepted a download link',
    );
    _expect(
      !_dispatchRouterAnchorClick(
        '/router-test/users/1',
        target: '_blank',
      ),
      'The router intercepted a non-self target',
    );
    _expect(
      !_dispatchRouterAnchorClick(
        '/router-test/users/1',
        rel: 'external',
      ),
      'The router intercepted a rel=external link',
    );

    final target = web.document.createElement('div')
      ..setAttribute('id', 'router-fragment-target');
    web.document.body!.appendChild(target);
    final fragmentChange = _waitForWindowEvent(
      'hashchange',
      () => _dispatchRouterAnchorClick(
        '#router-fragment-target',
        suppressNativeBehavior: false,
      ),
    );
    await fragmentChange;
    _expect(
      web.window.location.hash == '#router-fragment-target' &&
          router.currentRoute.value.fragment == 'router-fragment-target',
      'Native fragment navigation did not update the router on hashchange',
    );
    target.remove();

    router.push('/router-test/search?q=before-dispose');
    final disposedMatch = router.currentRoute.value;
    router.dispose();
    isDisposed = true;

    var pushAfterDisposeFailed = false;
    try {
      router.push('/router-test/users/99');
    } on StateError {
      pushAfterDisposeFailed = true;
    }
    _expect(
      pushAfterDisposeFailed,
      'Router.push succeeded after Router.dispose',
    );

    web.window.history.pushState(null, '', '/router-test/users/99');
    await _waitForWindowEvent('popstate', () => web.window.history.back());
    _expect(
      web.window.location.pathname == '/router-test/search' &&
          web.window.location.search == '?q=before-dispose' &&
          identical(router.currentRoute.value, disposedMatch),
      'A disposed router continued updating after browser history navigation',
    );
    _expect(
      !_dispatchRouterAnchorClick('/router-test/users/99'),
      'A disposed router continued intercepting document clicks',
    );
  } finally {
    if (!isDisposed) router.dispose();
  }
}

Future<void> _waitForRouteViewText(web.Element host, String expected) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (host.textContent?.contains(expected) ?? false) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Timed out waiting for route view text "$expected".');
}

Future<void> _waitForWindowEvent(
  String type,
  void Function() action,
) async {
  final completed = Completer<void>();
  late final JSFunction listener;
  listener = ((web.Event _) {
    if (completed.isCompleted) return;
    web.window.removeEventListener(type, listener);
    completed.complete();
  }).toJS;
  web.window.addEventListener(type, listener);
  try {
    action();
    await completed.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('Timed out waiting for $type.'),
    );
  } finally {
    web.window.removeEventListener(type, listener);
  }
}

bool _dispatchRouterAnchorClick(
  String href, {
  bool ctrlKey = false,
  bool metaKey = false,
  bool shiftKey = false,
  bool altKey = false,
  bool download = false,
  String? target,
  String? rel,
  bool suppressNativeBehavior = true,
}) {
  final host = web.document.createElement('div');
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = href;
  if (download) anchor.setAttribute('download', '');
  if (target != null) anchor.target = target;
  if (rel != null) anchor.rel = rel;
  host.appendChild(anchor);
  web.document.body!.appendChild(host);

  bool? routerPreventedDefault;
  final observer = ((web.Event event) {
    routerPreventedDefault = event.defaultPrevented;
    if (suppressNativeBehavior) event.preventDefault();
  }).toJS;
  web.document.addEventListener('click', observer);
  try {
    final init = web.MouseEventInit(button: 0)
      ..bubbles = true
      ..cancelable = true
      ..ctrlKey = ctrlKey
      ..metaKey = metaKey
      ..shiftKey = shiftKey
      ..altKey = altKey;
    anchor.dispatchEvent(web.MouseEvent('click', init));
    final prevented = routerPreventedDefault;
    if (prevented == null) {
      throw StateError('The test click did not reach the document.');
    }
    return prevented;
  } finally {
    web.document.removeEventListener('click', observer);
    host.remove();
  }
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
