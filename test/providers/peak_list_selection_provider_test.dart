import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

void main() {
  test('filteredPeaksProvider returns union of matching peaks for specific lists', () {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Alpha',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 7,
        PeakList(
          name: 'Bravo',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 7000, points: 1),
          ]),
        )..peakListId = 8,
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
              selectedPeakListIds: {7, 8},
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
      ],
    );
    addTearDown(container.dispose);

    final filteredPeaks = container.read(filteredPeaksProvider);

    expect(filteredPeaks.map((peak) => peak.osmId).toList(), [6406, 7000]);
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
                selectedPeakListIds: {7},
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

  test('summary provider orders chips by rendered label with fallback labels', () {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Zulu', peakList: '[]')..peakListId = 2,
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
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListIds: {2, 9},
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
      ],
    );
    addTearDown(container.dispose);

    final summary = container.read(peakListSelectionSummaryProvider);

    expect(summary.chips.map((chip) => chip.label).toList(), ['List #9', 'Zulu']);
  });

  test('renderablePeakListIds keeps only lists that match current peaks', () {
    final peaks = [
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
    ];
    final peakLists = [
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
    ];

    expect(
      renderablePeakListIds(
        peaks: peaks,
        peakLists: peakLists,
        selectedPeakListIds: {7, 8, 9},
      ),
      {7},
    );
  });
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
