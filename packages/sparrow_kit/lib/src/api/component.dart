import 'package:web/web.dart' as web;

import '../reactivity/signals.dart';
import '../rendering/component.dart' as runtime;

class ComponentState {
  ComponentState._();

  final List<Signal<dynamic>> _slots = [];
  int _nextSlot = 0;
  int? _expectedHookCount;
  bool _isRendering = false;

  Signal<T> use<T>(T initialValue) {
    if (!_isRendering) {
      throw StateError('Component state can only be used while rendering.');
    }

    final slotIndex = _nextSlot++;
    if (slotIndex == _slots.length) {
      if (_expectedHookCount != null) {
        throw StateError(
          'Component state hook count changed at slot $slotIndex.',
        );
      }
      final signal = Signal<T>(initialValue);
      _slots.add(signal);
      return signal;
    }

    final signal = _slots[slotIndex];
    if (signal is! Signal<T>) {
      throw StateError(
        'Component state hook order or type changed at slot $slotIndex.',
      );
    }
    return signal;
  }

  void _beginRender() {
    if (_isRendering) {
      throw StateError('A component state scope cannot render recursively.');
    }
    _isRendering = true;
    _nextSlot = 0;
  }

  void _endRender({required bool validateHookCount}) {
    _isRendering = false;
    if (!validateHookCount) return;

    final expectedHookCount = _expectedHookCount;
    if (expectedHookCount == null) {
      _expectedHookCount = _nextSlot;
    } else if (_nextSlot != expectedHookCount) {
      throw StateError(
        'Component state hook count changed from '
        '$expectedHookCount to $_nextSlot.',
      );
    }
  }
}

typedef ComponentBuilder<P> = web.Node Function(
  ComponentState state,
  P props,
);

ComponentDefinition<P> component<P>(ComponentBuilder<P> build) {
  return ComponentDefinition<P>(build);
}

class ComponentDefinition<P> {
  const ComponentDefinition(this._build);

  final ComponentBuilder<P> _build;

  runtime.Component<P> call(P props) {
    return _FunctionalComponent<P>(_build, props);
  }
}

class _FunctionalComponent<P> extends runtime.Component<P> {
  _FunctionalComponent(this._build, P props)
      : _state = ComponentState._(),
        super(props);

  final ComponentBuilder<P> _build;
  final ComponentState _state;

  @override
  web.Node render() {
    _state._beginRender();

    late final web.Node node;
    try {
      node = _build(_state, props);
    } catch (_) {
      _state._endRender(validateHookCount: false);
      rethrow;
    }

    _state._endRender(validateHookCount: true);
    return node;
  }
}
