import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

void main() {
  test('toggling last specific list off enters none', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListIds: {7},
              previousSpecificPeakListIds: {7},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);

    notifier.togglePeakListSelection(7);

    expect(notifier.state.peakListSelectionMode, PeakListSelectionMode.none);
    expect(notifier.state.selectedPeakListIds, isEmpty);
    expect(notifier.state.previousSpecificPeakListIds, {7});
  });

  test('turning all peaks off restores remembered selection', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.allPeaks,
              previousSpecificPeakListIds: {7, 8},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);

    notifier.setAllPeaksSelected(false);

    expect(
      notifier.state.peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(notifier.state.selectedPeakListIds, {7, 8});
    expect(notifier.state.previousSpecificPeakListIds, {7, 8});
  });

  test('turning all peaks on captures current specific selection', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListIds: {7, 8},
              previousSpecificPeakListIds: {7},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);

    notifier.setAllPeaksSelected(true);

    expect(
      notifier.state.peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(notifier.state.selectedPeakListIds, isEmpty);
    expect(notifier.state.previousSpecificPeakListIds, {7, 8});
  });

  test('toggling a specific list while all peaks active replaces snapshot', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.allPeaks,
              previousSpecificPeakListIds: {7, 8},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);

    notifier.togglePeakListSelection(9);

    expect(
      notifier.state.peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(notifier.state.selectedPeakListIds, {9});
    expect(notifier.state.previousSpecificPeakListIds, {9});
  });

  test(
    'explicit reconcile follows cursor region and falls back to all peaks',
    () {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Alpha',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
            ]),
          )..peakListId = 7,
          PeakList(
            name: 'Zero',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 9999, points: 1),
            ]),
          )..peakListId = 8,
          PeakList(name: 'Broken', peakList: '{not-json}')..peakListId = 9,
        ]),
      );

      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => _InitialStateMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 15,
                basemap: Basemap.tracestrack,
                cursorPoint: const LatLng(-44.0, 148.8867),
                peaks: [
                  Peak(
                    osmId: 6406,
                    name: 'Bonnet Hill',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                ],
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7, 8, 9},
                previousSpecificPeakListIds: {7, 8, 9},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(mapProvider.notifier).reconcileSelectedPeakList();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListIds, {7});
      expect(container.read(mapProvider).previousSpecificPeakListIds, {7});

      container
          .read(mapProvider.notifier)
          .updateVisibleBounds(
            LatLngBounds(const LatLng(-10.0, 10.0), const LatLng(-5.0, 15.0)),
          );

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListIds, {7});
      expect(container.read(mapProvider).previousSpecificPeakListIds, {7});

      container.read(mapProvider.notifier).setCursorMgrs(const LatLng(0, 0));

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListIds, {7});
      expect(container.read(mapProvider).previousSpecificPeakListIds, {7});

      container.read(mapProvider.notifier).reconcileSelectedPeakList();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.allPeaks,
      );
      expect(container.read(mapProvider).selectedPeakListIds, isEmpty);
      expect(container.read(mapProvider).previousSpecificPeakListIds, isEmpty);
    },
  );
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;

  @override
  Future<void> persistPeakListSelection() async {}
}
