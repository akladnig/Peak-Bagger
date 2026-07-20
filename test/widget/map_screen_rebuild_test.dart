import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/polygon_assets_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/show_polygons_settings_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('continuous drag does not rebuild route root or action rail', (
    tester,
  ) async {
    MapRebuildDebugCounters.reset();
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final routeRootBuilds = MapRebuildDebugCounters.routeRootBuilds;
    final actionRailBuilds = MapRebuildDebugCounters.actionRailBuilds;
    final region = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.startGesture(tester.getCenter(region));

    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(MapRebuildDebugCounters.routeRootBuilds, routeRootBuilds);
    expect(MapRebuildDebugCounters.actionRailBuilds, actionRailBuilds);

    await gesture.up();
  });

  testWidgets('peak hover does not rebuild route root or action rail', (
    tester,
  ) async {
    MapRebuildDebugCounters.reset();
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(osmId: 1, name: 'Peak A', latitude: -41.5, longitude: 146.5),
        ],
      ),
    );

    final routeRootBuilds = MapRebuildDebugCounters.routeRootBuilds;
    final actionRailBuilds = MapRebuildDebugCounters.actionRailBuilds;
    final region = find.byKey(const Key('map-interaction-region'));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(MapRebuildDebugCounters.routeRootBuilds, routeRootBuilds);
    expect(MapRebuildDebugCounters.actionRailBuilds, actionRailBuilds);
  });

  testWidgets('zoom keeps polygon layer build count flat', (tester) async {
    MapRebuildDebugCounters.reset();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          polygonAssetRepositoryProvider.overrideWithValue(
            PolygonAssetRepository(assetLoader: _polygonAssetLoader),
          ),
          showPolygonsSettingsProvider.overrideWith(
            () => _TestShowPolygonsNotifier(true),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(MapRebuildDebugCounters.polygonAssetLayerBuilds, 1);
    expect(notifier.state.zoom, 12);

    notifier.updatePosition(const LatLng(-41.4, 146.4), 13);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    notifier.updatePosition(const LatLng(-41.3, 146.3), 14);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(MapRebuildDebugCounters.polygonAssetLayerBuilds, 1);
    expect(find.byKey(const Key('asset-polygon-layer')), findsOneWidget);
  });

  testWidgets(
    'continuous drag defers peak-list-derived refresh until motion settles',
    (tester) async {
      MapRebuildDebugCounters.reset();
      final peakA = Peak(
        osmId: 1,
        name: 'Peak A',
        latitude: -41.5,
        longitude: 146.5,
        region: 'tasmania',
      );
      final peakList = PeakList(
        peakListId: 42,
        name: 'Focus List',
        region: 'tasmania',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(
              () => TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 12,
                  basemap: Basemap.tracestrack,
                  peaks: [peakA],
                  visibleBounds: _tasmaniaBounds,
                  peakListSelectionMode: PeakListSelectionMode.specificList,
                  selectedPeakListIds: {42},
                ),
              ),
            ),
            peakListRepositoryProvider.overrideWithValue(
              PeakListRepository.test(
                InMemoryPeakListStorage([peakList]),
                itemStorage: InMemoryPeakListItemEntityStorage([
                  PeakListItemEntity(id: 1, points: 0)
                    ..peakList.target = peakList
                    ..peak.target = peakA,
                ]),
              ),
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      router.go('/map');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final initialRefreshes = MapRebuildDebugCounters.peakListDerivedRefreshes;
      final region = find.byKey(const Key('map-interaction-region'));
      final gesture = await tester.startGesture(tester.getCenter(region));

      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(
        MapRebuildDebugCounters.peakListDerivedRefreshes,
        initialRefreshes,
      );

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        MapRebuildDebugCounters.peakListDerivedRefreshes,
        greaterThan(initialRefreshes),
      );
    },
  );

  testWidgets(
    'continuous drag defers peak projection rebuild until motion settles',
    (tester) async {
      MapRebuildDebugCounters.reset();
      final peakA = Peak(
        osmId: 1,
        name: 'Peak A',
        latitude: -41.5,
        longitude: 146.5,
        region: 'tasmania',
      );
      final peakList = PeakList(
        peakListId: 42,
        name: 'Focus List',
        region: 'tasmania',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(
              () => TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 12,
                  basemap: Basemap.tracestrack,
                  peaks: [peakA],
                  visibleBounds: _tasmaniaBounds,
                  peakListSelectionMode: PeakListSelectionMode.specificList,
                  selectedPeakListIds: {42},
                ),
              ),
            ),
            peakListRepositoryProvider.overrideWithValue(
              PeakListRepository.test(
                InMemoryPeakListStorage([peakList]),
                itemStorage: InMemoryPeakListItemEntityStorage([
                  PeakListItemEntity(id: 1, points: 0)
                    ..peakList.target = peakList
                    ..peak.target = peakA,
                ]),
              ),
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      router.go('/map');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final initialBuilds = MapRebuildDebugCounters.peakProjectionBuilds;
      final region = find.byKey(const Key('map-interaction-region'));
      final gesture = await tester.startGesture(tester.getCenter(region));

      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(MapRebuildDebugCounters.peakProjectionBuilds, initialBuilds);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        MapRebuildDebugCounters.peakProjectionBuilds,
        greaterThan(initialBuilds),
      );
    },
  );

  testWidgets('polygon toggle hides and restores the layer', (tester) async {
    MapRebuildDebugCounters.reset();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );
    final polygonToggle = _TestShowPolygonsNotifier(true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          polygonAssetRepositoryProvider.overrideWithValue(
            PolygonAssetRepository(assetLoader: _polygonAssetLoader),
          ),
          showPolygonsSettingsProvider.overrideWith(() => polygonToggle),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset-polygon-layer')), findsOneWidget);
    expect(MapRebuildDebugCounters.polygonAssetLayerBuilds, 1);

    await polygonToggle.setShowPolygons(false);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset-polygon-layer')), findsNothing);
    expect(MapRebuildDebugCounters.polygonAssetLayerBuilds, 1);

    await polygonToggle.setShowPolygons(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset-polygon-layer')), findsOneWidget);
    expect(MapRebuildDebugCounters.polygonAssetLayerBuilds, 2);
  });

  test('filteredPeaksProvider ignores camera-only updates', () {
    final peakA = Peak(
      osmId: 1,
      name: 'Peak A',
      latitude: -41.5,
      longitude: 146.5,
    );
    final peakB = Peak(
      osmId: 2,
      name: 'Peak B',
      latitude: -41.6,
      longitude: 146.6,
    );
    final peakList = PeakList(peakListId: 42, name: 'Focus List');
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        peaks: [peakA, peakB],
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {42},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(
            InMemoryPeakListStorage([peakList]),
            itemStorage: InMemoryPeakListItemEntityStorage([
              PeakListItemEntity(id: 1, points: 0)
                ..peakList.target = peakList
                ..peak.target = peakA,
            ]),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    var notifications = 0;
    final sub = container.listen<List<Peak>>(
      filteredPeaksProvider,
      (previous, next) => notifications += 1,
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(container.read(filteredPeaksProvider).map((peak) => peak.osmId), [
      1,
    ]);

    notifier.updatePosition(const LatLng(-41.4, 146.4), 13);

    expect(container.read(filteredPeaksProvider).map((peak) => peak.osmId), [
      1,
    ]);
    expect(notifications, 1);
  });
}

final _tasmaniaBounds = LatLngBounds(
  const LatLng(-43.5, 145.5),
  const LatLng(-40.5, 148.5),
);

Future<void> _pumpMapApp(WidgetTester tester, MapState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<String> _polygonAssetLoader(String assetPath) async {
  return switch (assetPath) {
    'assets/polygons/manifest.json' => '["assets/polygons/test.poly"]',
    'assets/polygons/test.poly' => 'none\n1\n0 0\n1 0\n1 1\n0 0\nEND\nEND\n',
    _ => throw StateError('Unexpected polygon asset: $assetPath'),
  };
}

class _TestShowPolygonsNotifier extends ShowPolygonsSettingsNotifier {
  _TestShowPolygonsNotifier(this._value);

  final bool _value;

  @override
  bool build() => _value;

  @override
  Future<void> setShowPolygons(bool value) async {
    state = value;
  }
}
