import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/polygon_assets_provider.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/polygon_mapping_store.dart';
import 'map_route_robot.dart';

void main() {
  testWidgets(
    'lazy display failure retains map selection and geometry after dismissal, then retries the same polygon',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      final store = PolygonMappingStore()..repairOptional();
      store.optionalRead = Completer<String>();
      final catalog = await store.loadCatalog();
      // This journey isolates one failure; parser/provider tests cover FIFO peers.
      store.files['${PolygonMappingStore.root}/${PolygonMappingStore.secondPath}'] =
          polygonText;
      final robot = MapRouteRobot(
        tester,
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
          selectedLocation: const LatLng(-41.4, 146.4),
        ),
        routePlanningOutcomes: const [],
        providerOverrides: [
          polygonAssetRepositoryProvider.overrideWithValue(
            PolygonAssetRepository(catalog: catalog, fileSystem: store),
          ),
        ],
      );
      addTearDown(robot.dispose);
      await robot.pumpApp();
      await robot.openMap();
      expect(
        store.reads,
        isNot(
          contains(
            '${PolygonMappingStore.root}/${PolygonMappingStore.optionalPath}',
          ),
        ),
      );
      await robot.showPolygonBoundaries();
      await robot.selectMapLocation(Offset.zero);
      final selectedLocation = robot
          .container()
          .read(mapProvider)
          .selectedLocation;
      expect(selectedLocation, isNotNull);
      store.optionalRead!.complete('malformed');
      await tester.pumpAndSettle();
      robot.expectPolygonGeometryVisible();
      robot.expectMapSelectionUnavailable(unavailable: true);
      await robot.dismissMappingFailure();
      robot.expectMapSelectionUnavailable(unavailable: true);
      robot.expectPolygonGeometryVisible();
      expect(
        robot.container().read(mapProvider).selectedLocation,
        selectedLocation,
      );

      store.repairOptional();
      store.optionalRead = null;
      await robot.retryMapSelectionMapping();
      robot.expectMapSelectionUnavailable(unavailable: false);
      robot.expectPolygonGeometryVisible();
      expect(
        robot.container().read(polygonDisplayStateProvider).loaded,
        contains(PolygonMappingStore.optionalPath),
      );
      expect(
        store.reads.where((path) => path.endsWith('/optional.poly')),
        hasLength(2),
      );
      expect(
        robot.container().read(mapProvider).selectedLocation,
        selectedLocation,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
