import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class DropMarkerRobot {
  DropMarkerRobot(this.tester);

  final WidgetTester tester;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get dropMarkerFab => find.byKey(const Key('drop-marker-fab'));
  Finder get gotoFavouriteFab => find.byKey(const Key('goto-favourite-fab'));
  Finder get chooser => find.byKey(const Key('map-tap-action-popup'));
  Finder get chooserClose => find.byKey(const Key('map-tap-action-close'));
  Finder get chooserDropFavourite =>
      find.byKey(const Key('map-tap-action-drop-favourite'));
  Finder get favouriteNameInput =>
      find.byKey(const Key('favourite-name-input'));
  Finder get favouriteNameSave => find.byKey(const Key('favourite-name-save'));
  Finder get favouritesPopup => find.byKey(const Key('favourites-popup'));
  Finder favouriteMarkerName(int id) =>
      find.byKey(Key('favourite-marker-name-$id'));

  Future<void> pumpMap({
    required MapState initialState,
    required WaypointsRepository waypointsRepository,
  }) async {
    final tasmapRepository = await TestTasmapRepository.create();
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              initialState,
              waypointsRepository: waypointsRepository,
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          peaksBaggedRepositoryProvider.overrideWithValue(
            PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
          ),
          gpxTrackRepositoryProvider.overrideWithValue(
            GpxTrackRepository.test(InMemoryGpxTrackStorage()),
          ),
          tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(tasmapRepository),
          ),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDropMarkerPopup() async {
    await tester.ensureVisible(dropMarkerFab);
    await tester.pumpAndSettle();
    await tester.tap(dropMarkerFab);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> chooseDropMarker() async {
    await tester.tap(find.byKey(const Key('map-tap-action-drop-marker')));
    await tester.pumpAndSettle();
  }

  Future<void> closeChooser() async {
    await tester.tap(chooserClose);
    await tester.pumpAndSettle();
  }

  Future<void> tapMapCenter() async {
    await tester.tapAt(tester.getCenter(mapInteractionRegion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> chooseDropFavourite(String name) async {
    await tester.tap(chooserDropFavourite);
    await tester.pumpAndSettle();
    await tester.enterText(favouriteNameInput, name);
    await tester.tap(favouriteNameSave);
    await tester.pumpAndSettle();
  }

  Future<void> openFavourites() async {
    await tester.ensureVisible(gotoFavouriteFab);
    await tester.pumpAndSettle();
    await tester.tap(gotoFavouriteFab);
    await tester.pump();
  }

  Future<void> selectFavouriteRow(int id) async {
    await tester.tap(find.byKey(Key('favourites-popup-row-$id')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  ProviderContainer container() {
    return ProviderScope.containerOf(tester.element(mapInteractionRegion));
  }

  void expectSelectedLocation(LatLng location) {
    expect(container().read(mapProvider).selectedLocation, location);
  }
}
