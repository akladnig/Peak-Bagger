import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/time_chart_preference_storage.dart';

void main() {
  ProviderContainer containerFor(
    TestTimeChartPreferenceStorage storage, {
    TimeChartPreferenceDiagnostics? diagnostics,
  }) {
    final container = ProviderContainer(
      overrides: [
        timeChartPreferenceStorageProvider.overrideWithValue(storage),
        if (diagnostics != null)
          timeChartPreferenceDiagnosticsProvider.overrideWithValue(diagnostics),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final value in [
    null,
    'unsupported',
    'Stacked column view',
    '0',
    ...TimeChartType.values.map((t) => t.storageId),
  ]) {
    test('restores $value in independent lifecycles', () async {
      final storage = TestTimeChartPreferenceStorage(value);
      for (var lifecycle = 0; lifecycle < 2; lifecycle++) {
        final container = containerFor(storage);
        expect(container.read(timeChartTypeProvider).isHydrating, isTrue);
        await container.read(timeChartTypeProvider.notifier).load();
        final state = container.read(timeChartTypeProvider);
        expect(state.selected, TimeChartType.restore(value));
        expect(state.readOutcome.hasValue, isTrue);
        expect(state.isHydrating, isFalse);
        expect(state.warning, isNull);
      }
      expect(storage.writes, isEmpty);
    });
  }

  test(
    'shared-preferences adapter uses its own stable key and identifiers',
    () async {
      SharedPreferences.setMockInitialValues({
        dashboardCardOrderStorageKey: ['distance'],
        timeChartTypeStorageKey: 'clustered-column',
        'unrelated': 'preserved',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      expect(
        container.read(timeChartTypeProvider).selected,
        TimeChartType.clusteredColumn,
      );
      await controller.select(TimeChartType.line);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(timeChartTypeStorageKey), 'line');
      expect(prefs.getString('unrelated'), 'preserved');
      expect(prefs.getStringList(dashboardCardOrderStorageKey), ['distance']);
    },
  );

  test(
    'delayed initial read cannot overwrite a newer explicit selection',
    () async {
      final gate = Completer<String?>();
      final storage = TestTimeChartPreferenceStorage()
        ..readSteps.add(() => gate.future);
      final container = containerFor(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      expect(
        container.read(timeChartTypeProvider).readOutcome.isLoading,
        isTrue,
      );
      await controller.select(TimeChartType.line);
      expect(container.read(timeChartTypeProvider).isHydrating, isFalse);
      gate.complete('clustered-column');
      await controller.load();
      expect(
        container.read(timeChartTypeProvider).selected,
        TimeChartType.line,
      );
      expect(storage.stored, 'line');
    },
  );

  test(
    'read failure is diagnosed, fallback usable, retries deduplicated',
    () async {
      final errors = <(String, Object, StackTrace)>[];
      final gate = Completer<String?>();
      final storage = TestTimeChartPreferenceStorage()
        ..readSteps.addAll([
          () async => throw StateError('read fault'),
          () => gate.future,
        ]);
      final container = containerFor(
        storage,
        diagnostics: (op, e, st) => errors.add((op, e, st)),
      );
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      var state = container.read(timeChartTypeProvider);
      expect(state.selected, TimeChartType.stackedColumn);
      expect(state.isHydrating, isFalse);
      expect(state.readOutcome.hasError, isTrue);
      expect(state.warning!.message, 'Couldn’t load Time chart preference.');
      expect(errors.single.$1, 'read');
      expect('${errors.single.$2}', contains('read fault'));
      expect(errors.single.$3.toString(), isNotEmpty);
      final id = state.warning!.id;
      controller.markWarningPresented(id);
      expect(container.read(timeChartTypeProvider).warning!.presented, isTrue);
      final retry = controller.retryVisibleWarning();
      final duplicate = controller.retryWarning(id);
      expect(identical(retry, duplicate), isTrue);
      expect(storage.reads, 2);
      gate.complete('clustered-column');
      await retry;
      state = container.read(timeChartTypeProvider);
      expect(state.selected, TimeChartType.clusteredColumn);
      expect(state.readOutcome.hasValue, isTrue);
      expect(state.warning, isNull);
      await controller.retryWarning(id);
      expect(storage.reads, 2);
    },
  );

  test(
    'late retry reads and failures cannot supersede user selection/save warning',
    () async {
      for (final failRead in [false, true]) {
        final gate = Completer<String?>();
        final storage = TestTimeChartPreferenceStorage()
          ..readSteps.addAll([
            () async => throw StateError('initial'),
            () => gate.future,
          ])
          ..writeSteps.add(() async => false);
        final container = containerFor(storage);
        final controller = container.read(timeChartTypeProvider.notifier);
        await controller.load();
        final retry = controller.retryWarning(
          container.read(timeChartTypeProvider).warning!.id,
        );
        await controller.select(TimeChartType.line);
        final saveWarning = container.read(timeChartTypeProvider).warning;
        if (failRead) {
          gate.completeError(StateError('late read'));
        } else {
          gate.complete('clustered-column');
        }
        await retry;
        expect(
          container.read(timeChartTypeProvider).selected,
          TimeChartType.line,
        );
        expect(
          container.read(timeChartTypeProvider).warning,
          same(saveWarning),
        );
      }
    },
  );

  for (final throws in [false, true]) {
    test(
      'failed save ($throws) retains selection and prior restart default; retry succeeds',
      () async {
        final diagnostics = <String>[];
        final storage = TestTimeChartPreferenceStorage('clustered-column')
          ..writeSteps.add(() async {
            if (throws) throw StateError('write fault');
            return false;
          });
        final container = containerFor(
          storage,
          diagnostics: (op, e, st) => diagnostics.add('$op: $e'),
        );
        final controller = container.read(timeChartTypeProvider.notifier);
        await controller.load();
        final saving = controller.select(TimeChartType.line);
        expect(
          container.read(timeChartTypeProvider).selected,
          TimeChartType.line,
        );
        expect(
          container.read(timeChartTypeProvider).saveOutcome!.isLoading,
          isTrue,
        );
        await saving;
        final state = container.read(timeChartTypeProvider);
        expect(state.saveOutcome!.hasError, isTrue);
        expect(state.selected, TimeChartType.line);
        expect(state.warning!.message, 'Couldn’t save Time chart preference.');
        expect(diagnostics.single, contains('save line revision 1'));
        final restart = containerFor(storage);
        await restart.read(timeChartTypeProvider.notifier).load();
        expect(
          restart.read(timeChartTypeProvider).selected,
          TimeChartType.clusteredColumn,
        );
        await controller.retryWarning(state.warning!.id);
        expect(
          container.read(timeChartTypeProvider).saveOutcome!.hasValue,
          isTrue,
        );
        expect(container.read(timeChartTypeProvider).warning, isNull);
        final nextRestart = containerFor(storage);
        await nextRestart.read(timeChartTypeProvider.notifier).load();
        expect(
          nextRestart.read(timeChartTypeProvider).selected,
          TimeChartType.line,
        );
      },
    );
  }

  test(
    'serializes/coalesces overlapping choices, suppresses obsolete failures',
    () async {
      final first = Completer<bool>();
      final last = Completer<bool>();
      final storage = TestTimeChartPreferenceStorage()
        ..writeSteps.addAll([() => first.future, () => last.future]);
      final container = containerFor(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      final saving = controller.select(TimeChartType.line);
      controller.select(TimeChartType.clusteredColumn);
      controller.select(TimeChartType.stackedColumn);
      expect(storage.writes, ['line']);
      first.completeError(StateError('obsolete save'));
      await Future<void>.delayed(Duration.zero);
      expect(storage.writes, ['line', 'stacked-column']);
      expect(container.read(timeChartTypeProvider).warning, isNull);
      expect(
        container.read(timeChartTypeProvider).saveOutcome!.isLoading,
        isTrue,
      );
      last.complete(true);
      await saving;
      expect(storage.maxActiveWrites, 1);
      expect(storage.stored, 'stacked-column');
      expect(
        container.read(timeChartTypeProvider).saveOutcome!.hasValue,
        isTrue,
      );
    },
  );

  test(
    'pending retry writes latest choice, rejects stale identity and deduplicates',
    () async {
      final gate = Completer<bool>();
      final storage = TestTimeChartPreferenceStorage()
        ..writeSteps.addAll([() async => false, () => gate.future]);
      final container = containerFor(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      await controller.select(TimeChartType.line);
      final id = container.read(timeChartTypeProvider).warning!.id;
      controller.markWarningPresented(id);
      final retry = controller.retryVisibleWarning();
      expect(identical(retry, controller.retryVisibleWarning()), isTrue);
      controller.select(TimeChartType.clusteredColumn);
      await controller.retryWarning(id);
      expect(storage.writes, ['line', 'line']);
      gate.complete(true);
      await retry;
      expect(storage.writes, ['line', 'line', 'clustered-column']);
      expect(storage.stored, 'clustered-column');
      expect(container.read(timeChartTypeProvider).warning, isNull);
      await controller.retryVisibleWarning();
      expect(storage.writes, hasLength(3));
    },
  );

  test(
    'resolving queued warning clears it; same selection does not write',
    () async {
      final storage = TestTimeChartPreferenceStorage()
        ..writeSteps.add(() async => false);
      final container = containerFor(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      await controller.select(TimeChartType.stackedColumn);
      expect(storage.writes, isEmpty);
      await controller.select(TimeChartType.line);
      final id = container.read(timeChartTypeProvider).warning!.id;
      await controller.select(TimeChartType.clusteredColumn);
      expect(container.read(timeChartTypeProvider).warning, isNull);
      controller.markWarningPresented(id);
      expect(container.read(timeChartTypeProvider).visibleWarningId, isNull);
    },
  );

  test(
    'app disposal during read/write does not publish late state or dispatch queued writes',
    () async {
      final readGate = Completer<String?>();
      final writeGate = Completer<bool>();
      final storage = TestTimeChartPreferenceStorage()
        ..readSteps.add(() => readGate.future)
        ..writeSteps.add(() => writeGate.future);
      final container = ProviderContainer(
        overrides: [
          timeChartPreferenceStorageProvider.overrideWithValue(storage),
        ],
      );
      final controller = container.read(timeChartTypeProvider.notifier);
      final reading = controller.load();
      final writing = controller.select(TimeChartType.line);
      controller.select(TimeChartType.clusteredColumn);
      await Future<void>.delayed(Duration.zero);
      expect(storage.reads, 1);
      container.dispose();
      readGate.completeError(StateError('disposed read'));
      writeGate.complete(true);
      await Future.wait([reading, writing]);
      controller.dismissWarning(1);
      expect(storage.writes, ['line']);
    },
  );

  test(
    'synchronous storage throws are outcomes, including at initial build',
    () async {
      final storage = _SynchronousFailures();
      final container = containerFor(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      expect(
        container.read(timeChartTypeProvider).readOutcome.hasError,
        isTrue,
      );
      expect(
        container.read(timeChartTypeProvider).warning!.message,
        'Couldn’t load Time chart preference.',
      );
      await controller.select(TimeChartType.line);
      expect(
        container.read(timeChartTypeProvider).selected,
        TimeChartType.line,
      );
      expect(
        container.read(timeChartTypeProvider).saveOutcome!.hasError,
        isTrue,
      );
    },
  );

  test(
    'an older successful write cannot claim the latest failed choice persisted',
    () async {
      final gate = Completer<bool>();
      final storage = TestTimeChartPreferenceStorage('stacked-column')
        ..writeSteps.addAll([() => gate.future, () async => false]);
      final container = containerFor(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      final saving = controller.select(TimeChartType.line);
      controller.select(TimeChartType.clusteredColumn);
      gate.complete(true);
      await saving;
      expect(storage.stored, 'line');
      expect(
        container.read(timeChartTypeProvider).selected,
        TimeChartType.clusteredColumn,
      );
      expect(
        container.read(timeChartTypeProvider).saveOutcome!.hasError,
        isTrue,
      );
      final id = container.read(timeChartTypeProvider).warning!.id;
      await controller.retryWarning(id);
      expect(storage.writes.last, 'clustered-column');
      expect(storage.stored, 'clustered-column');
    },
  );

  test('read retry success clears its unpresented warning', () async {
    final storage = TestTimeChartPreferenceStorage('line')
      ..readSteps.add(() async => throw StateError('queued read'));
    final container = containerFor(storage);
    final controller = container.read(timeChartTypeProvider.notifier);
    await controller.load();
    final warning = container.read(timeChartTypeProvider).warning!;
    expect(warning.presented, isFalse);
    await controller.retryWarning(warning.id);
    expect(container.read(timeChartTypeProvider).warning, isNull);
    expect(container.read(timeChartTypeProvider).selected, TimeChartType.line);
  });
}

class _SynchronousFailures extends TestTimeChartPreferenceStorage {
  @override
  Future<String?> read() => throw StateError('synchronous read');

  @override
  Future<bool> write(String value) => throw StateError('synchronous write');
}
