import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

void main() {
  test('filteredPeaksProvider returns only matching peaks for specific list', () {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Alpha',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 7,
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peaks: [
                Peak(
                  osmId: 6406,
                  name: 'Bonnet Hill',
                  latitude: -43.0,
                  longitude: 147.0,
                ),
                Peak(
                  osmId: 7000,
                  name: 'Other Peak',
                  latitude: -42.9,
                  longitude: 147.1,
                ),
              ],
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListId: 7,
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
      ],
    );
    addTearDown(container.dispose);

    final filteredPeaks = container.read(filteredPeaksProvider);

    expect(filteredPeaks.map((peak) => peak.osmId).toList(), [6406]);
  });

  test(
    'filteredPeaksProvider stays pure and returns all peaks on repository error',
    () {
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => _TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 15,
                basemap: Basemap.tracestrack,
                peaks: [
                  Peak(
                    osmId: 6406,
                    name: 'Bonnet Hill',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                  Peak(
                    osmId: 7000,
                    name: 'Other Peak',
                    latitude: -42.9,
                    longitude: 147.1,
                  ),
                ],
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListId: 7,
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(_ThrowingPeakListStorage()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final filteredPeaks = container.read(filteredPeaksProvider);

      expect(filteredPeaks.map((peak) => peak.osmId).toList(), [6406, 7000]);
      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(peakListsProvider), isEmpty);
    },
  );
}

class _TestMapNotifier extends MapNotifier {
  _TestMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}

class _ThrowingPeakListStorage extends InMemoryPeakListStorage {
  @override
  List<PeakList> getAll() {
    throw StateError('boom');
  }
}
