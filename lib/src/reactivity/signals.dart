typedef EffectCallback = void Function();

class ReactiveContext {
  static final List<_ReactiveEffect> _subscriberStack = [];
  static final List<List<void Function()>> _effectScopes = [];

  static _ReactiveEffect? get _activeSubscriber =>
      _subscriberStack.isEmpty ? null : _subscriberStack.last;

  static void _pushSubscriber(_ReactiveEffect subscriber) {
    _subscriberStack.add(subscriber);
  }

  static void _popSubscriber(_ReactiveEffect subscriber) {
    final popped = _subscriberStack.removeLast();
    assert(identical(popped, subscriber));
  }

  static T runInEffectScope<T>(
    List<void Function()> disposers,
    T Function() action,
  ) {
    _effectScopes.add(disposers);
    try {
      return action();
    } finally {
      final popped = _effectScopes.removeLast();
      assert(identical(popped, disposers));
    }
  }

  static T untracked<T>(T Function() action) {
    final subscriber =
        _subscriberStack.isEmpty ? null : _subscriberStack.removeLast();
    try {
      return action();
    } finally {
      if (subscriber != null) {
        _subscriberStack.add(subscriber);
      }
    }
  }

  static void _registerEffectDisposer(void Function() disposer) {
    if (_effectScopes.isNotEmpty) {
      _effectScopes.last.add(disposer);
    }
  }

  static void registerCleanup(void Function() cleanup) {
    _registerEffectDisposer(cleanup);
  }
}

abstract interface class _Dependency {
  void _addSubscriber(_ReactiveEffect subscriber);
  void _removeSubscriber(_ReactiveEffect subscriber);
}

class Signal<T> implements _Dependency {
  Signal(this._value);

  T _value;
  final Set<_ReactiveEffect> _subscribers = {};

  T get value {
    ReactiveContext._activeSubscriber?._dependOn(this);
    return _value;
  }

  set value(T value) {
    if (_value == value) return;

    _value = value;
    for (final subscriber in List<_ReactiveEffect>.of(_subscribers)) {
      subscriber.run();
    }
  }

  @override
  void _addSubscriber(_ReactiveEffect subscriber) {
    _subscribers.add(subscriber);
  }

  @override
  void _removeSubscriber(_ReactiveEffect subscriber) {
    _subscribers.remove(subscriber);
  }
}

class _ReactiveEffect {
  _ReactiveEffect(this.callback);

  final EffectCallback callback;
  final Set<_Dependency> _dependencies = {};
  bool _isRunning = false;
  bool _isDisposed = false;

  void _dependOn(_Dependency dependency) {
    if (_dependencies.add(dependency)) {
      dependency._addSubscriber(this);
    }
  }

  void run() {
    if (_isDisposed || _isRunning) return;

    _isRunning = true;
    for (final dependency in _dependencies) {
      dependency._removeSubscriber(this);
    }
    _dependencies.clear();

    ReactiveContext._pushSubscriber(this);
    try {
      callback();
    } finally {
      ReactiveContext._popSubscriber(this);
      _isRunning = false;
    }
  }

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    for (final dependency in _dependencies) {
      dependency._removeSubscriber(this);
    }
    _dependencies.clear();
  }
}

void Function() effect(EffectCallback callback) {
  final reactiveEffect = _ReactiveEffect(callback)..run();
  ReactiveContext._registerEffectDisposer(reactiveEffect.dispose);
  return reactiveEffect.dispose;
}

void onCleanup(void Function() cleanup) {
  ReactiveContext.registerCleanup(cleanup);
}
