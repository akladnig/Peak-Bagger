import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_save_provider.dart';

import '../harness/test_objectbox_admin_repository.dart';

void main() {
  test(
    'Save locks before preparation; rejects duplicate and releases on failure',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gate = Completer<String?>();
      final notifier = container.read(objectboxAdminSaveProvider.notifier);
      var calls = 0;
      final pending = notifier.run(() {
        expect(container.read(objectboxAdminSaveProvider), isTrue);
        calls++;
        return gate.future;
      });
      expect(
        await notifier.run(() async {
          calls++;
          return null;
        }),
        isNotNull,
      );
      expect(calls, 1);
      gate.completeError(StateError('controlled'));
      await expectLater(pending, throwsStateError);
      expect(container.read(objectboxAdminSaveProvider), isFalse);
      expect(await notifier.run(() async => null), isNull);
    },
  );

  test(
    'pending Save guards stale browser actions and refresh without changing context',
    () async {
      final repository = TestObjectBoxAdminRepository();
      final container = ProviderContainer(
        overrides: [
          objectboxAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final initial = container.read(objectboxAdminProvider);
      notifier.selectRow(initial.rows.first);
      final selected = container.read(objectboxAdminProvider);
      final calls = repository.loadRowsCallCount;
      final gate = Completer<String?>();
      final save = container
          .read(objectboxAdminSaveProvider.notifier)
          .run(() => gate.future);
      await notifier.selectEntity(initial.entities.last);
      notifier.setMode(ObjectBoxAdminViewMode.schema);
      notifier.updateSearchQuery('blocked');
      await notifier.runSearch();
      await notifier.toggleSort();
      notifier.selectRow(initial.rows.last);
      notifier.clearSelection();
      await notifier.refresh();
      expect(container.read(objectboxAdminProvider), same(selected));
      expect(repository.loadRowsCallCount, calls);
      gate.complete('recoverable failure');
      await save;
      notifier.clearSelection();
      expect(container.read(objectboxAdminProvider).selectedRow, isNull);
      notifier.updateSearchQuery('permitted');
      expect(container.read(objectboxAdminProvider).searchQuery, 'permitted');
    },
  );
}
