import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/providers/polygon_assets_provider.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

import '../fixtures/polygon_mapping_store.dart';

void main() {
  late PolygonMappingStore store;
  late ProviderContainer container;

  setUp(() async {
    store = PolygonMappingStore();
    final catalog = await store.loadCatalog();
    container = ProviderContainer(
      overrides: [
        mappingCatalogProvider.overrideWithValue(catalog),
        polygonAssetRepositoryProvider.overrideWithValue(
          PolygonAssetRepository(catalog: catalog, fileSystem: store),
        ),
      ],
    );
    store.reads.clear();
  });
  tearDown(() => container.dispose());

  test('polygon keys preserve distinct validated manifest filenames', () {
    final plain = MappingStoreOperationKey.polygonDisplay(
      'Polygons/optional.poly',
    );
    final spaced = MappingStoreOperationKey.polygonDisplay(
      ' Polygons/optional.poly',
    );
    expect(spaced, isNot(plain));
    expect(spaced.parameters['path'], ' Polygons/optional.poly');
  });

  test(
    'provider construction is lazy; display keeps valid independent geometry',
    () async {
      expect(container.read(polygonDisplayStateProvider).polygons, isEmpty);
      expect(store.reads, isEmpty);
      await container.read(polygonAssetsProvider.future);
      final state = container.read(polygonDisplayStateProvider);
      expect(state.polygons, isNotEmpty);
      expect(
        state.failures.keys,
        containsAll([
          PolygonMappingStore.optionalPath,
          PolygonMappingStore.secondPath,
        ]),
      );
      expect(
        container
            .read(mappingStoreOperationCoordinatorProvider)
            .failures
            .map((failure) => failure.key.parameters['path']),
        [PolygonMappingStore.optionalPath, PolygonMappingStore.secondPath],
      );
    },
  );

  test(
    'same path shares pending future, one read, and one failure; other paths queue FIFO',
    () async {
      store.repairOptional();
      store.optionalRead = Completer<String>();
      final notifier = container.read(polygonDisplayStateProvider.notifier);
      final first = notifier.load(PolygonMappingStore.optionalPath);
      final duplicate = notifier.load(PolygonMappingStore.optionalPath);
      expect(duplicate, same(first));
      final firstFailure = expectLater(
        first,
        throwsA(isA<MappingStoreOperationException>()),
      );
      final duplicateFailure = expectLater(
        duplicate,
        throwsA(isA<MappingStoreOperationException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final second = notifier.load(PolygonMappingStore.secondPath);
      await expectLater(second, throwsA(isA<MappingStoreOperationException>()));
      store.optionalRead!.complete('malformed');
      await Future.wait([firstFailure, duplicateFailure]);
      expect(
        store.reads.where((path) => path.endsWith('/optional.poly')),
        hasLength(1),
      );
      final coordinator = container.read(
        mappingStoreOperationCoordinatorProvider,
      );
      expect(
        coordinator.failures.map((failure) => failure.key.parameters['path']),
        [PolygonMappingStore.secondPath, PolygonMappingStore.optionalPath],
      );
    },
  );

  test(
    'dismissal and pending retry preserve unavailable state and prior polygon',
    () async {
      store.repairOptional();
      final notifier = container.read(polygonDisplayStateProvider.notifier);
      final retained = await notifier.load(PolygonMappingStore.optionalPath);
      store.files['${PolygonMappingStore.root}/${PolygonMappingStore.optionalPath}'] =
          'malformed';
      await expectLater(
        notifier.load(PolygonMappingStore.optionalPath),
        throwsA(isA<MappingStoreOperationException>()),
      );
      final coordinator = container.read(
        mappingStoreOperationCoordinatorProvider,
      );
      coordinator.dismissActive();
      expect(coordinator.activeFailure, isNull);
      expect(
        container.read(polygonDisplayStateProvider).unavailableReason,
        contains(PolygonMappingStore.optionalPath),
      );
      expect(
        container.read(polygonDisplayStateProvider).polygons.single,
        same(retained),
      );

      store.optionalRead = Completer<String>();
      final retry = notifier.retryUnavailable();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(polygonDisplayStateProvider).unavailableReason,
        isNotNull,
      );
      expect(container.read(polygonDisplayStateProvider).pending, {
        PolygonMappingStore.optionalPath,
      });
      final joiningRetry = coordinator.retryActive();
      store.optionalRead!.complete(
        polygonText.replaceFirst('none', 'repaired'),
      );
      await Future.wait([retry, joiningRetry]);
      expect(
        container.read(polygonDisplayStateProvider).unavailableReason,
        isNull,
      );
      expect(
        container.read(polygonDisplayStateProvider).polygons.single.name,
        'repaired',
      );
      expect(
        store.reads.where((path) => path.endsWith('/optional.poly')),
        hasLength(3),
      );
    },
  );

  test(
    'dialog retry updates provider state without a second initiating request',
    () async {
      final notifier = container.read(polygonDisplayStateProvider.notifier);
      await expectLater(
        notifier.load(PolygonMappingStore.optionalPath),
        throwsA(isA<MappingStoreOperationException>()),
      );
      store.repairOptional();
      await container
          .read(mappingStoreOperationCoordinatorProvider)
          .retryActive();
      expect(container.read(polygonDisplayStateProvider).failures, isEmpty);
      expect(
        container.read(polygonDisplayStateProvider).polygons.single.assetPath,
        PolygonMappingStore.optionalPath,
      );
    },
  );

  test(
    'retry joins a pending read of the failed path and rejects unsafe key aliases',
    () async {
      final notifier = container.read(polygonDisplayStateProvider.notifier);
      await expectLater(
        notifier.load(PolygonMappingStore.optionalPath),
        throwsA(isA<MappingStoreOperationException>()),
      );
      store.repairOptional();
      store.optionalRead = Completer<String>();
      final reread = notifier.load(PolygonMappingStore.optionalPath);
      expect(
        () => notifier.load(' ${PolygonMappingStore.optionalPath} '),
        throwsA(isA<MappingStoreOperationException>()),
      );
      final retry = container
          .read(mappingStoreOperationCoordinatorProvider)
          .retry(
            MappingStoreOperationKey.polygonDisplay(
              PolygonMappingStore.optionalPath,
            ),
          );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(polygonDisplayStateProvider).unavailableReason,
        isNotNull,
      );
      store.optionalRead!.complete(polygonText);
      await Future.wait([reread, retry]);
      expect(
        store.reads.where((path) => path.endsWith('/optional.poly')),
        hasLength(1),
      );
      expect(container.read(polygonDisplayStateProvider).failures, isEmpty);
    },
  );
}
