import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/router.dart';
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
    final peakList = PeakList(
      peakListId: 42,
      name: 'Focus List',
      peakList: '[{"peakOsmId":1,"points":0}]',
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        peaks: [peakA, peakB],
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListId: 42,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage([peakList])),
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

    expect(container.read(filteredPeaksProvider).map((peak) => peak.osmId), [1]);

    notifier.updatePosition(const LatLng(-41.4, 146.4), 13);

    expect(container.read(filteredPeaksProvider).map((peak) => peak.osmId), [1]);
    expect(notifications, 1);
  });
}

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
