import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';

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

    expect(notifier.state.peakListSelectionMode, PeakListSelectionMode.allPeaks);
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
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;

  @override
  Future<void> persistPeakListSelection() async {}
}
