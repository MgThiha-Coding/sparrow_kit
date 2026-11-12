import 'package:web/web.dart' as web;

import '../reactivity/signals.dart' show ReactiveContext, Signal, effect;

abstract class Component<P> {
  Component(
    this.props, {
    List<Object> children = const [],
  }) : children = List<Object>.unmodifiable(children);

  static final List<Component<dynamic>> _renderStack = [];

  final P props;
  final List<Object> children;

  web.Node? _rootNode;
  web.Element? _host;
  List<void Function()> _renderDisposers = [];
  List<Component<dynamic>> _childrenBeingRendered = [];
  List<Component<dynamic>> _renderedChildren = [];
  void Function()? _renderEffectDisposer;
  bool _isDisposed = false;
  bool _isActive = false;
  bool _hasRendered = false;

  web.Node render();

  void onMount() {}

  void onUpdate() {}

  void onDispose() {}

  Signal<T> createState<T>(T initialValue) => Signal<T>(initialValue);

  void mount(String selector) {
    final target = web.document.querySelector(selector);
    if (target == null) {
      throw StateError('No element found for selector "$selector".');
    }

    mountInto(target);
  }

  void mountInto(web.Element host) {
    if (_isDisposed) {
      throw StateError('A disposed component cannot be mounted.');
    }
    if (_renderEffectDisposer != null) {
      throw StateError('A component can only be mounted once.');
    }

    _host = host;
    final parentIsRendering = _renderStack.isNotEmpty;
    if (parentIsRendering) {
      _renderStack.last._childrenBeingRendered.add(this);
    }

    _renderEffectDisposer = effect(_renderAndCommit);
    if (!parentIsRendering) {
      _activateTree();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _renderEffectDisposer?.call();
    _renderEffectDisposer = null;
    _disposeRenderedContent();
    final rootNode = _rootNode;
    if (rootNode != null) {
      rootNode.parentNode?.removeChild(rootNode);
    }
    _rootNode = null;

    if (_isActive) {
      _isActive = false;
      ReactiveContext.untracked(onDispose);
    }
  }

  void _renderAndCommit() {
    _disposeRenderedContent();
    _renderDisposers = [];
    _childrenBeingRendered = [];

    late final web.Node nextRoot;
    try {
      nextRoot = ReactiveContext.runInEffectScope(
        _renderDisposers,
        () {
          _renderStack.add(this);
          try {
            return render();
          } finally {
            final popped = _renderStack.removeLast();
            assert(identical(popped, this));
          }
        },
      );
    } catch (_) {
      for (final child in _childrenBeingRendered.reversed) {
        child.dispose();
      }
      _childrenBeingRendered = [];
      for (final disposer in _renderDisposers.reversed) {
        disposer();
      }
      _renderDisposers = [];
      rethrow;
    }

    final previousRoot = _rootNode;
    if (previousRoot == null) {
      _host!.appendChild(nextRoot);
    } else {
      final parent = previousRoot.parentNode;
      if (parent == null) {
        _host!.appendChild(nextRoot);
      } else {
        parent.replaceChild(nextRoot, previousRoot);
      }
    }
    _rootNode = nextRoot;
    _renderedChildren = List<Component<dynamic>>.of(
      _childrenBeingRendered,
    );

    if (_isActive) {
      ReactiveContext.untracked(onUpdate);
    }
    _hasRendered = true;

    if (_host!.isConnected || _isActive) {
      _activateTree();
    }
  }

  void _activateTree() {
    if (!_hasRendered || _isDisposed) return;

    if (!_isActive) {
      _isActive = true;
      ReactiveContext.untracked(onMount);
    }
    for (final child in _renderedChildren) {
      child._activateTree();
    }
  }

  void _disposeRenderedContent() {
    for (final child in _renderedChildren.reversed) {
      child.dispose();
    }
    _renderedChildren = [];

    for (final disposer in _renderDisposers.reversed) {
      disposer();
    }
    _renderDisposers = [];
  }
}
