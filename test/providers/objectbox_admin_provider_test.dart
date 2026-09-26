import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

import '../harness/test_objectbox_admin_repository.dart';

void main() {
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
