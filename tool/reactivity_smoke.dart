import 'package:sparrow_kit/reactivity.dart';

Future<void> main() async {
  final value = Signal<int>(0);
  var runs = 0;
  var observed = -1;
  final dispose = effect(() {
    runs++;
    observed = value.value;
  });

  batch(() {
    value.value = 1;
    value.value = 2;
    batch(() => value.value = 3);
  });
  _expect(runs == 1, 'batch should defer effects to the microtask');
  await Future<void>.delayed(Duration.zero);
  _expect(runs == 2 && observed == 3, 'batch should coalesce writes');

  value.value = 4;
  value.value = 5;
  await Future<void>.delayed(Duration.zero);
  _expect(runs == 3 && observed == 5, 'writes should coalesce by microtask');

  value.value = 6;
  dispose();
  await Future<void>.delayed(Duration.zero);
  _expect(runs == 3, 'disposed pending effects should not run');

  final chooseLeft = Signal<bool>(true);
  final left = Signal<int>(1);
  final right = Signal<int>(2);
  var selected = -1;
  var selectionRuns = 0;
  final disposeSelection = effect(() {
    selectionRuns++;
    selected = chooseLeft.value ? left.value : right.value;
  });
  left.value = 3;
  chooseLeft.value = false;
  await Future<void>.delayed(Duration.zero);
  _expect(selected == 2 && selectionRuns == 2, 'dependencies should retrack');
  left.value = 4;
  await Future<void>.delayed(Duration.zero);
  _expect(selectionRuns == 2, 'stale dependencies should be detached');
  disposeSelection();

  final selfUpdating = Signal<int>(0);
  var selfRuns = 0;
  final disposeSelf = effect(() {
    selfRuns++;
    if (selfUpdating.value == 0) selfUpdating.value = 1;
  });
  await Future<void>.delayed(Duration.zero);
  _expect(
    selfRuns == 2 && selfUpdating.value == 1,
    'updates during an effect should schedule one rerun',
  );
  disposeSelf();

  final scopeDisposers = <void Function()>[];
  var cleanupRan = false;
  ReactiveContext.runInEffectScope(scopeDisposers, () {
    effect(() {});
    onCleanup(() => cleanupRan = true);
  });
  for (final disposer in scopeDisposers.reversed) {
    disposer();
  }
  _expect(cleanupRan, 'effect-scope cleanup should remain supported');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
