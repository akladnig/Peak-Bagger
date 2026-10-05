import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/providers/natural_feature_provider.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/natural_feature_refresh_service.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  test(
    'a valid empty Natural Features source becomes available only after successful commit',
    () async {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage(),
      );
      final coordinator = MappingStoreOperationCoordinator();
      final container = _container(repository, coordinator);
      addTearDown(container.dispose);
      addTearDown(coordinator.dispose);
      expect(
        container.read(naturalFeatureAvailabilityProvider).isAvailable,
        isFalse,
      );
      await coordinator.run<void>(
        key: const MappingStoreOperationKey.naturalFeaturesBootstrap(),
        action: () async => repository.reconcileAtomically(
          upserts: const [],
          deletedIds: const [],
        ),
      );
      expect(
        container.read(naturalFeatureAvailabilityProvider).isAvailable,
        isTrue,
      );
    },
  );
  test(
    'populated bootstrap skips its source and conditional schedule runs once',
    () async {
      final tasmap = await TestTasmapRepository.create();
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([_feature()..id = 1]),
      );
      var reads = 0;
      final service = NaturalFeatureRefreshService(
        repository,
        fileReader: (_) async {
          reads++;
          return '{"elements":[{"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Loaded","natural":"tree"}}]}';
        },
        mgrsConverter: (_) => const PeakMgrsComponents(
          gridZoneDesignator: '55G',
          mgrs100kId: 'AA',
          easting: '12345',
          northing: '67890',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          naturalFeatureBootstrapEnabledProvider.overrideWithValue(true),
          naturalFeatureRepositoryProvider.overrideWithValue(repository),
          naturalFeatureRefreshServiceProvider.overrideWithValue(service),
          tasmapRepositoryProvider.overrideWithValue(tasmap),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(tasmap)),
        ],
      );
      addTearDown(container.dispose);
      final scheduler = container.read(
        mappingStoreBootstrapCoordinatorProvider,
      );
      await scheduler.schedule();
      await scheduler.schedule();
      expect(reads, 0);
    },
  );

  test(
    'successful bootstrap publishes availability after its row commits',
    () async {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage(),
      );
      final coordinator = MappingStoreOperationCoordinator();
      final container = _container(repository, coordinator);
      addTearDown(container.dispose);
      addTearDown(coordinator.dispose);
      final subscription = container.listen(
        naturalFeatureAvailabilityProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        container.read(naturalFeatureAvailabilityProvider).isAvailable,
        isFalse,
      );
      await coordinator.run<void>(
        key: const MappingStoreOperationKey.naturalFeaturesBootstrap(),
        action: () async => repository.save(_feature()),
      );
      expect(
        container.read(naturalFeatureAvailabilityProvider).isAvailable,
        isTrue,
      );
    },
  );

  test(
    'dismissed manual failure retains the refresh identity and recovers',
    () async {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([_feature()]),
      );
      final coordinator = MappingStoreOperationCoordinator();
      final container = _container(repository, coordinator);
      addTearDown(container.dispose);
      addTearDown(coordinator.dispose);
      var readable = false;
      const key = MappingStoreOperationKey.naturalFeaturesRefresh();
      await expectLater(
        coordinator.run<void>(
          key: key,
          action: () async {
            if (!readable) {
              throw MappingStoreOperationException(
                paths: ['Features/features.json'],
              );
            }
          },
        ),
        throwsA(isA<MappingStoreOperationException>()),
      );
      coordinator.dismissActive();
      expect(
        container.read(naturalFeatureAvailabilityProvider).isAvailable,
        isFalse,
      );
      readable = true;
      await coordinator.retry(key);
      expect(
        container.read(naturalFeatureAvailabilityProvider).isAvailable,
        isTrue,
      );
      expect(repository.getAllNaturalFeatures(), hasLength(1));
    },
  );
}

ProviderContainer _container(
  NaturalFeatureRepository repository,
  MappingStoreOperationCoordinator coordinator,
) => ProviderContainer(
  overrides: [
    naturalFeatureBootstrapEnabledProvider.overrideWithValue(true),
    naturalFeatureRepositoryProvider.overrideWithValue(repository),
    mappingStoreOperationCoordinatorProvider.overrideWithValue(coordinator),
  ],
);

NaturalFeature _feature() => NaturalFeature(
  name: 'Stored',
  tag: 'tree',
  latitude: -42,
  longitude: 146,
  osmId: 1,
  osmType: 'node',
);
