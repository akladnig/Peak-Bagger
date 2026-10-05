import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/polygon_assets_provider.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';
import 'package:peak_bagger/widgets/map_selection_mapping_unavailable.dart';
import 'package:peak_bagger/widgets/mapping_store_failure_dialog.dart';

import '../fixtures/polygon_mapping_store.dart';
import '../harness/test_map_notifier.dart';

void main() {
  testWidgets(
    'dismissed failure retains Retry and its reason throughout a pending reread',
    (tester) async {
      final store = PolygonMappingStore()..repairOptional();
      final catalog = await store.loadCatalog();
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          polygonAssetRepositoryProvider.overrideWithValue(
            PolygonAssetRepository(catalog: catalog, fileSystem: store),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(polygonDisplayStateProvider.notifier);
      final retained = await tester.runAsync(
        () => notifier.load(PolygonMappingStore.optionalPath),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: MappingStoreFailureDialogHost(child: child!),
            ),
            home: const Scaffold(
              body: Center(child: MapSelectionMappingUnavailable()),
            ),
          ),
        ),
      );
      store.files['${PolygonMappingStore.root}/${PolygonMappingStore.optionalPath}'] =
          'malformed';
      final failure = notifier
          .load(PolygonMappingStore.optionalPath)
          .then<void>((_) {}, onError: (Object error) {});
      await tester.pumpAndSettle();
      await failure;
      expect(
        find.byKey(const Key('mapping-store-failure-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mapping-store-failure-dismiss')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mapping-store-failure-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('map-selection-mapping-unavailable')),
        findsOneWidget,
      );
      expect(
        find.textContaining(PolygonMappingStore.optionalPath),
        findsOneWidget,
      );
      expect(
        container.read(polygonDisplayStateProvider).polygons.single,
        same(retained),
      );

      store.optionalRead = Completer<String>();
      await tester.tap(
        find.byKey(const Key('map-selection-mapping-unavailable-retry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('map-selection-mapping-unavailable')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('map-selection-mapping-unavailable-retry')),
            )
            .onPressed,
        isNull,
      );
      expect(
        container.read(polygonDisplayStateProvider).polygons.single,
        same(retained),
      );
      store.optionalRead!.complete(polygonText);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('map-selection-mapping-unavailable')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('mapping-store-failure-dialog')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
