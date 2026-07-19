import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import '../../harness/test_tasmap_notifier.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';

class PeakListPinsRobot {
  PeakListPinsRobot(this.tester);

  final WidgetTester tester;
  late final TestMapNotifier notifier;

  Finder get showPeaksFab => find.byKey(const Key('show-peaks-fab'));
  Finder get summaryRoot =>
      find.byKey(const Key('peak-list-selection-summary'));

  Future<void> pumpApp() async {
    final tasmapRepository = await TestTasmapRepository.create();
    notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: tasmaniaBounds,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(
            _peakListRepositoryWithItems([
              PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
              PeakList(
                name: 'Bravo',
                region: 'new-south-wales',
              )..peakListId = 2,
            ]),
          ),
          tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(tasmapRepository),
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

  Future<void> openDrawer() async {
    await tester.ensureVisible(showPeaksFab);
    await tester.pumpAndSettle();
    await tester.tap(showPeaksFab, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> selectDrawerList(String name) async {
    await openDrawer();
    await tester.tap(find.byKey(Key('peak-list-item-$name')));
    await tester.pumpAndSettle();
  }

  Future<void> pinDrawerList(int peakListId) async {
    await openDrawer();
    await tester.tap(find.byKey(Key('peak-list-pin-$peakListId')));
    await tester.pumpAndSettle();
  }

  Future<void> tapAppBarToggle(int peakListId) async {
    await tester.tap(find.byKey(Key('peak-list-selection-chip-$peakListId')));
    await tester.pumpAndSettle();
  }

  Future<void> tapAppBarUnpin(int peakListId) async {
    await tester.tap(find.byKey(Key('peak-list-app-bar-unpin-$peakListId')));
    await tester.pumpAndSettle();
  }

  Future<void> setVisibleBounds(LatLngBounds bounds) async {
    notifier.updateVisibleBounds(bounds);
    await tester.pumpAndSettle();
  }

  Finder appBarItem(int peakListId) =>
      find.byKey(Key('peak-list-app-bar-item-$peakListId'));
}

final tasmaniaBounds = LatLngBounds(
  const LatLng(-43.5, 145.5),
  const LatLng(-40.5, 148.5),
);

final nswBounds = LatLngBounds(
  const LatLng(-34.5, 147.0),
  const LatLng(-33.0, 150.5),
);

final multiRegionBounds = LatLngBounds(
  const LatLng(-44.0, 145.0),
  const LatLng(-33.0, 150.5),
);

final zeroRegionBounds = LatLngBounds(
  const LatLng(-10.0, 10.0),
  const LatLng(-5.0, 15.0),
);

PeakListRepository _peakListRepositoryWithItems(List<PeakList> peakLists) {
  final peaks = [
    for (final peakList in peakLists)
      switch (peakList.region) {
        'new-south-wales' => Peak(
          osmId: peakList.peakListId * 1000,
          name: '${peakList.name} Peak',
          latitude: -33.8,
          longitude: 149.2,
          region: peakList.region,
        ),
        _ => Peak(
          osmId: peakList.peakListId * 1000,
          name: '${peakList.name} Peak',
          latitude: -42.0,
          longitude: 146.0,
          region: peakList.region,
        ),
      },
  ];
  final peaksById = {for (final peak in peaks) peak.osmId: peak};
  final items = <PeakListItemEntity>[];
  var itemId = 1;
  for (final peakList in peakLists) {
    items.add(
      PeakListItemEntity(id: itemId++, points: 0)
        ..peakList.target = peakList
        ..peak.target = peaksById[peakList.peakListId * 1000]!,
    );
  }

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    peakRepository: PeakRepository.test(InMemoryPeakStorage(peaks)),
    itemStorage: InMemoryPeakListItemEntityStorage(items),
  );
}
