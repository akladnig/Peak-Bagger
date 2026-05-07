import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';

import '../../harness/test_map_notifier.dart';

void main() {
  testWidgets('trackpad zoom keeps readouts live without rebuilding route chrome', (
    tester,
  ) async {
    MapRebuildDebugCounters.reset();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
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

    final routeRootBuilds = MapRebuildDebugCounters.routeRootBuilds;
    final actionRailBuilds = MapRebuildDebugCounters.actionRailBuilds;
    final region = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(0, 120),
    );
    await tester.pump();

    expect(find.byKey(const Key('map-mgrs-readout')), findsOneWidget);
    expect(find.byKey(const Key('map-zoom-readout')), findsOneWidget);
    expect(MapRebuildDebugCounters.routeRootBuilds, routeRootBuilds);
    expect(MapRebuildDebugCounters.actionRailBuilds, actionRailBuilds);

    await gesture.up();
  });
}
