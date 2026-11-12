import 'dart:async';

/// Signals track only effects that read their value, avoiding stream
/// controllers/subscriptions and virtual-DOM tree traversal. A changed signal
/// queues those effects once for the next microtask, so synchronous writes
/// coalesce into one render/DOM update per effect.
typedef EffectCallback = void Function();

class ReactiveContext {
  static final List<_ReactiveEffect> _subscriberStack = [];
  static final List<List<void Function()>> _effectScopes = [];
  static final Set<_ReactiveEffect> _pendingEffects = {};

  static int _batchDepth = 0;
  static bool _isFlushScheduled = false;
  static bool _isFlushing = false;

  static _ReactiveEffect? get _activeSubscriber =>
      _subscriberStack.isEmpty ? null : _subscriberStack.last;

  static void _pushSubscriber(_ReactiveEffect subscriber) {
    _subscriberStack.add(subscriber);
  }

  static void _popSubscriber(_ReactiveEffect subscriber) {
    final popped = _subscriberStack.removeLast();
    assert(identical(popped, subscriber));
  }

  static void _scheduleEffect(_ReactiveEffect effect) {
    if (effect._isDisposed) return;
    _pendingEffects.add(effect);
    _scheduleFlush();
  }

  static void _removePendingEffect(_ReactiveEffect effect) {
    _pendingEffects.remove(effect);
  }

  static void _scheduleFlush() {
    if (_pendingEffects.isEmpty ||
        _batchDepth > 0 ||
        _isFlushScheduled ||
        _isFlushing) {
      return;
    }

    _isFlushScheduled = true;
    scheduleMicrotask(_flushEffects);
  }

  static void _flushEffects() {
    _isFlushScheduled = false;
    if (_batchDepth > 0 || _isFlushing) {
      _scheduleFlush();
      return;
    }

    _isFlushing = true;
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      while (_pendingEffects.isNotEmpty) {
        final readyEffects = _pendingEffects.toList(growable: false);
        _pendingEffects.clear();

        for (final effect in readyEffects) {
          try {
            effect._run();
          } catch (error, stackTrace) {
            firstError ??= error;
            firstStackTrace ??= stackTrace;
          }
        }
      }
    } finally {
      _isFlushing = false;
      _scheduleFlush();
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
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
    for (final subscriber in _subscribers) {
      subscriber._invalidate();
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
  bool _rerunRequested = false;

  void _dependOn(_Dependency dependency) {
    if (_isDisposed) return;
    if (_dependencies.add(dependency)) {
      dependency._addSubscriber(this);
    }
  }

  void _invalidate() {
    if (_isDisposed) return;
    if (_isRunning) {
      _rerunRequested = true;
    } else {
      ReactiveContext._scheduleEffect(this);
    }
  }

  void _run() {
    if (_isDisposed || _isRunning) return;

    _isRunning = true;
    _rerunRequested = false;
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
      if (_rerunRequested) {
        _rerunRequested = false;
        ReactiveContext._scheduleEffect(this);
      }
    }
  }

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    ReactiveContext._removePendingEffect(this);
    for (final dependency in _dependencies) {
      dependency._removeSubscriber(this);
    }
    _dependencies.clear();
  }
}

void Function() effect(EffectCallback callback) {
  final reactiveEffect = _ReactiveEffect(callback);
  try {
    reactiveEffect._run();
  } catch (_) {
    reactiveEffect.dispose();
    rethrow;
  }
  ReactiveContext._registerEffectDisposer(reactiveEffect.dispose);
  return reactiveEffect.dispose;
}

void batch(void Function() action) {
  ReactiveContext._batchDepth++;
  try {
    action();
  } finally {
    ReactiveContext._batchDepth--;
    if (ReactiveContext._batchDepth == 0) {
      ReactiveContext._scheduleFlush();
    }
  }
}

void onCleanup(void Function() cleanup) {
  ReactiveContext.registerCleanup(cleanup);
}
