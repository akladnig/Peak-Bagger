import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

import '../harness/test_objectbox_admin_repository.dart';

void main() {
  const peak = ObjectBoxAdminEntityDescriptor(
    name: 'Peak',
    displayName: 'Peak',
    primaryKeyField: 'id',
    primaryNameField: 'name',
    fields: [],
  );
  const route = ObjectBoxAdminEntityDescriptor(
    name: 'Route',
    displayName: 'Route',
    primaryKeyField: 'id',
    primaryNameField: 'name',
    fields: [],
  );
  ProviderContainer containerFor(TestObjectBoxAdminRepository repository) {
    final container = ProviderContainer(
      overrides: [
        objectboxAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'live raw Search and Enter keep committed selection outside results and after Save',
    () async {
      final rows = <String, List<ObjectBoxAdminRow>>{
        'Peak': [
          const ObjectBoxAdminRow(
            primaryKeyValue: 1,
            values: {'name': 'Committed Ossa'},
          ),
          const ObjectBoxAdminRow(primaryKeyValue: 2, values: {'name': 'Anne'}),
        ],
      };
      final container = containerFor(
        TestObjectBoxAdminRepository(entities: [peak], rowsByEntity: rows),
      );
      final notifier = container.read(objectboxAdminProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      notifier.selectRow(container.read(objectboxAdminProvider).rows.first);
      for (final query in ['  ANNE ', 'draft only', '', '   ', 'Committed']) {
        notifier.updateSearchQuery(query);
        await Future<void>.delayed(Duration.zero);
        final state = container.read(objectboxAdminProvider);
        expect(state.searchQuery, query);
        expect(state.selectedRow?.primaryKeyValue, 1);
        expect(state.selectedRow?.values['name'], 'Committed Ossa');
        expect(
          state.rows.length,
          query.trim().isEmpty
              ? 2
              : query == 'draft only'
              ? 0
              : 1,
        );
        await notifier.runSearch();
        expect(
          container.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
          1,
        );
      }
      rows['Peak'] = [
        const ObjectBoxAdminRow(
          primaryKeyValue: 1,
          values: {'name': 'Saved outside query'},
        ),
      ];
      await notifier.refreshAfterSave(keepSelectedRowPrimaryKey: 1);
      expect(container.read(objectboxAdminProvider).rows, isEmpty);
      expect(
        container.read(objectboxAdminProvider).selectedRow?.values['name'],
        'Saved outside query',
      );
    },
  );

  test(
    'stale query successes/errors and selection snapshots cannot replace newer context',
    () async {
      final repository = TestObjectBoxAdminRepository(entities: [peak]);
      final container = containerFor(repository);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final initial = container.read(objectboxAdminProvider).rows;
      notifier.selectRow(initial.first);
      final reads = <Completer<List<ObjectBoxAdminRow>>>[];
      repository.rowLoader = (_) {
        final read = Completer<List<ObjectBoxAdminRow>>();
        reads.add(read);
        return read.future;
      };
      notifier.updateSearchQuery('old');
      notifier.updateSearchQuery('Ossa');
      reads[1].complete(initial);
      await Future<void>.delayed(Duration.zero);
      reads[0].completeError(StateError('obsolete'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(objectboxAdminProvider).error, isNull);
      notifier.updateSearchQuery('missing');
      notifier.clearSelection();
      reads[2].complete(initial);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(objectboxAdminProvider).selectedRow, isNull);
      notifier.updateSearchQuery('newer');
      notifier.updateSearchQuery('Ossa');
      reads[4].complete(initial);
      await Future<void>.delayed(Duration.zero);
      reads[3].complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(objectboxAdminProvider).rows, hasLength(2));
    },
  );

  test(
    'read errors and Retry keep selection; confirmed removal invalidates only its own identity',
    () async {
      final repository = TestObjectBoxAdminRepository(entities: [peak]);
      final container = containerFor(repository);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final rows = container.read(objectboxAdminProvider).rows;
      notifier.selectRow(rows.first);
      repository.rowLoader = (_) async => throw StateError('read failed');
      await notifier.runSearch();
      expect(
        container.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
        1,
      );
      repository.rowLoader = null;
      await notifier.refresh();
      expect(
        container.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
        1,
      );
      notifier.didDeleteRecord(2);
      expect(
        container.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
        1,
      );
      notifier.didDeleteRecord(1);
      expect(container.read(objectboxAdminProvider).selectedRow, isNull);
    },
  );

  test(
    'captured Search actions cannot run in Schema or with unavailable metadata',
    () async {
      final repository = TestObjectBoxAdminRepository(entities: [peak]);
      final container = containerFor(repository);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      notifier.setMode(ObjectBoxAdminViewMode.schema);
      final calls = repository.loadRowsCallCount;
      notifier.updateSearchQuery('blocked');
      await notifier.runSearch();
      expect(container.read(objectboxAdminProvider).searchQuery, isEmpty);
      expect(repository.loadRowsCallCount, calls);
      notifier.setMode(ObjectBoxAdminViewMode.data);
      repository.discoveryError = StateError('unavailable');
      await notifier.refresh();
      notifier.updateSearchQuery('blocked');
      await notifier.runSearch();
      expect(container.read(objectboxAdminProvider).searchQuery, isEmpty);
      expect(container.read(objectboxAdminProvider).isLoading, isFalse);
    },
  );

  test(
    'initial discovery failure and repeated Retry are schema errors, not Data errors',
    () async {
      final repository = TestObjectBoxAdminRepository()
        ..discoveryError = StateError('discovery');
      final container = containerFor(repository);
      final initial = container.read(objectboxAdminProvider);
      expect(initial.schemaError, contains('schema'));
      expect(initial.error, isNull);
      expect(initial.selectedEntity, isNull);
      expect(initial.isLoading, isFalse);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await notifier.refresh();
      expect(container.read(objectboxAdminProvider).schemaError, isNotNull);
      expect(repository.loadRowsCallCount, 0);
      repository.discoveryError = null;
      await notifier.refresh();
      expect(container.read(objectboxAdminProvider).schemaError, isNull);
      expect(
        container.read(objectboxAdminProvider).selectedEntity!.name,
        'Peak',
      );
      expect(repository.getEntitiesCallCount, 3);
    },
  );

  test(
    'failed refresh hides stale metadata and recovers normalized canonical selection',
    () async {
      final repository = TestObjectBoxAdminRepository(entities: [peak, route]);
      final container = containerFor(repository);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await notifier.selectEntity(route);
      notifier.setMode(ObjectBoxAdminViewMode.schema);
      repository.discoveryError = StateError('refresh');
      await notifier.refresh();
      expect(container.read(objectboxAdminProvider).entities, isEmpty);
      expect(container.read(objectboxAdminProvider).selectedEntity, isNull);
      expect(container.read(objectboxAdminProvider).schemaError, isNotNull);
      await notifier.refresh();
      const fresh = ObjectBoxAdminEntityDescriptor(
        name: 'Route',
        displayName: 'Fresh Route',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [],
      );
      repository
        ..discoveryError = null
        ..replaceEntities([peak, fresh, route]);
      await notifier.refresh();
      final recovered = container.read(objectboxAdminProvider);
      expect(recovered.schemaError, isNull);
      expect(recovered.selectedEntity, same(fresh));
      expect(recovered.entities, [peak, fresh]);
      expect(recovered.mode, ObjectBoxAdminViewMode.schema);
    },
  );

  for (final empty in [false, true]) {
    test(
      'discovery recovery falls back to ${empty ? 'no selection' : 'first entity'}',
      () async {
        final repository = TestObjectBoxAdminRepository(
          entities: [peak, route],
        );
        final container = containerFor(repository);
        final notifier = container.read(objectboxAdminProvider.notifier);
        await notifier.selectEntity(route);
        repository.discoveryError = StateError('refresh');
        await notifier.refresh();
        repository
          ..discoveryError = null
          ..replaceEntities(empty ? [] : [peak]);
        await notifier.refresh();
        final state = container.read(objectboxAdminProvider);
        expect(state.selectedEntity, empty ? isNull : same(peak));
        expect(state.entities, empty ? isEmpty : [peak]);
        expect(state.schemaError, isNull);
        expect(state.isLoading, isFalse);
      },
    );
  }

  test(
    'Schema metadata survives pending and failed Data; obsolete reads cannot win',
    () async {
      final first = Completer<List<ObjectBoxAdminRow>>();
      final second = Completer<List<ObjectBoxAdminRow>>();
      final repository = TestObjectBoxAdminRepository(entities: [peak, route])
        ..rowLoader = (entity) =>
            entity.name == 'Peak' ? first.future : second.future;
      final container = containerFor(repository);
      final notifier = container.read(objectboxAdminProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      notifier.setMode(ObjectBoxAdminViewMode.schema);
      expect(container.read(objectboxAdminProvider).selectedEntity, same(peak));
      expect(container.read(objectboxAdminProvider).isLoading, isTrue);
      final selection = notifier.selectEntity(route);
      second.completeError(StateError('Data only'));
      await selection;
      expect(
        container.read(objectboxAdminProvider).error,
        contains('Data only'),
      );
      expect(container.read(objectboxAdminProvider).schemaError, isNull);
      expect(
        container.read(objectboxAdminProvider).selectedEntity,
        same(route),
      );
      first.complete(const [
        ObjectBoxAdminRow(primaryKeyValue: 99, values: {'name': 'stale'}),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(objectboxAdminProvider).rows, isEmpty);
      expect(
        container.read(objectboxAdminProvider).error,
        contains('Data only'),
      );
      repository.rowLoader = (_) async => [];
      await notifier.refresh();
      expect(container.read(objectboxAdminProvider).error, isNull);
    },
  );

  test(
    'refresh failure invalidates a pending row result and disposal ignores completion',
    () async {
      final pending = Completer<List<ObjectBoxAdminRow>>();
      final repository = TestObjectBoxAdminRepository(entities: [peak])
        ..rowLoader = (_) => pending.future;
      final container = containerFor(repository);
      container.read(objectboxAdminProvider);
      await Future<void>.delayed(Duration.zero);
      repository.discoveryError = StateError('metadata');
      await container.read(objectboxAdminProvider.notifier).refresh();
      pending.complete(const [
        ObjectBoxAdminRow(primaryKeyValue: 1, values: {}),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(objectboxAdminProvider).rows, isEmpty);
      expect(container.read(objectboxAdminProvider).schemaError, isNotNull);

      final disposedRead = Completer<List<ObjectBoxAdminRow>>();
      final disposed = ProviderContainer(
        overrides: [
          objectboxAdminRepositoryProvider.overrideWithValue(
            TestObjectBoxAdminRepository()
              ..rowLoader = (_) => disposedRead.future,
          ),
        ],
      );
      disposed.read(objectboxAdminProvider);
      await Future<void>.delayed(Duration.zero);
      disposed.dispose();
      disposedRead.completeError(StateError('after disposal'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('normalizes duplicate entity descriptors by name', () {
    const peak = ObjectBoxAdminEntityDescriptor(
      name: 'Peak',
      displayName: 'Peak',
      primaryKeyField: 'id',
      primaryNameField: 'name',
      fields: [],
    );
    const peakDuplicate = ObjectBoxAdminEntityDescriptor(
      name: 'Peak',
      displayName: 'Duplicate Peak',
      primaryKeyField: 'id',
      primaryNameField: 'name',
      fields: [],
    );
    const route = ObjectBoxAdminEntityDescriptor(
      name: 'Route',
      displayName: 'Route',
      primaryKeyField: 'id',
      primaryNameField: 'name',
      fields: [],
    );
    final repository = TestObjectBoxAdminRepository(
      entities: [peak, peakDuplicate, route],
    );
    final container = ProviderContainer(
      overrides: [
        objectboxAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(objectboxAdminProvider);

    expect(state.entities, [peak, route]);
    expect(state.selectedEntity, same(peak));
  });

  test(
    'refresh restores the selection with the canonical descriptor',
    () async {
      const peak = ObjectBoxAdminEntityDescriptor(
        name: 'Peak',
        displayName: 'Peak',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [],
      );
      const route = ObjectBoxAdminEntityDescriptor(
        name: 'Route',
        displayName: 'Route',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [],
      );
      final repository = TestObjectBoxAdminRepository(entities: [peak, route]);
      final container = ProviderContainer(
        overrides: [
          objectboxAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(objectboxAdminProvider.notifier).selectEntity(route);

      const refreshedRoute = ObjectBoxAdminEntityDescriptor(
        name: 'Route',
        displayName: 'Refreshed Route',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [],
      );
      repository.replaceEntities([peak, refreshedRoute, refreshedRoute]);

      await container.read(objectboxAdminProvider.notifier).refresh();

      final state = container.read(objectboxAdminProvider);
      expect(state.entities, [peak, refreshedRoute]);
      expect(state.selectedEntity, same(refreshedRoute));
    },
  );

  test(
    'refresh falls back to the first entity when the selection is absent',
    () async {
      const peak = ObjectBoxAdminEntityDescriptor(
        name: 'Peak',
        displayName: 'Peak',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [],
      );
      const route = ObjectBoxAdminEntityDescriptor(
        name: 'Route',
        displayName: 'Route',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [],
      );
      final repository = TestObjectBoxAdminRepository(entities: [peak, route]);
      final container = ProviderContainer(
        overrides: [
          objectboxAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(objectboxAdminProvider.notifier).selectEntity(route);
      repository.replaceEntities([peak]);

      await container.read(objectboxAdminProvider.notifier).refresh();

      expect(container.read(objectboxAdminProvider).selectedEntity, same(peak));
    },
  );
}
