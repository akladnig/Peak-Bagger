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
  test(
    'filteredPeaksProvider returns union of matching peaks for specific lists',
    () {
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
    },
  );

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

  test(
    'summary provider orders chips by rendered label with fallback labels',
    () {
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

      expect(summary.chips.map((chip) => chip.label).toList(), [
        'List #9',
        'Zulu',
      ]);
    },
  );

  test(
    'summary provider keeps malformed selected lists visible with neutral styling',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Broken',
            region: 'tasmania',
            peakList: '{not-json}',
            colour: 0xFF4C8BF5,
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
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
        ],
      );
      addTearDown(container.dispose);

      final summary = container.read(peakListSelectionSummaryProvider);

      expect(summary.chips, hasLength(1));
      expect(summary.chips.single.label, 'Broken');
      expect(summary.chips.single.usesNeutralStyle, isTrue);
      expect(summary.chips.single.colourValue, isNull);
    },
  );

  test(
    'peakMarkerColourAssignmentsProvider uses the lowest selected peakListId winner',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Bravo',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
            ]),
            colour: 0xFFE67E22,
          )..peakListId = 8,
          PeakList(
            name: 'Alpha',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
              const PeakListItem(peakOsmId: 7000, points: 1),
            ]),
            colour: 0xFF4C8BF5,
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
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7, 8},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(peakMarkerColourAssignmentsProvider), {
        6406: 0xFF4C8BF5,
        7000: 0xFF4C8BF5,
      });
    },
  );

  test(
    'peakMarkerColourAssignmentsProvider skips malformed selected lists',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Broken',
            peakList: '{not-json}',
            colour: 0xFFD6336C,
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
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(peakMarkerColourAssignmentsProvider), isEmpty);
    },
  );

  test(
    'renderablePeakListIds keeps Tasmania lists with legacy region values',
    () {
      final peakLists = [
        PeakList(
          name: 'Alpha',
          region: 'tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 7,
        PeakList(
          name: 'Legacy Blank',
          region: '',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6407, points: 1),
          ]),
        )..peakListId = 10,
        PeakList(
          name: 'Legacy Cased',
          region: 'Tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6408, points: 1),
          ]),
        )..peakListId = 11,
        PeakList(
          name: 'Zero',
          region: 'victoria',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 9999, points: 1),
          ]),
        )..peakListId = 8,
        PeakList(name: 'Broken', region: 'tasmania', peakList: '{not-json}')
          ..peakListId = 9,
      ];

      expect(
        renderablePeakListIds(
          peakLists: peakLists,
          selectedPeakListIds: {7, 8, 9, 10, 11},
          currentRegionKey: 'tasmania',
        ),
        {7, 10, 11},
      );
    },
  );

  test(
    'renderablePeakListIdsForVisibleRegions unions matching lists across visible regions',
    () {
      final peakLists = [
        PeakList(name: 'Alpha', region: 'tasmania', peakList: '[]')
          ..peakListId = 7,
        PeakList(name: 'Bravo', region: 'new-south-wales', peakList: '[]')
          ..peakListId = 8,
        PeakList(name: 'Charlie', region: 'victoria', peakList: '[]')
          ..peakListId = 9,
      ];

      expect(
        renderablePeakListIdsForVisibleRegions(
          peakLists: peakLists,
          selectedPeakListIds: {7, 8, 9},
          visibleRegionKeys: {'tasmania', 'new-south-wales'},
        ),
        {7, 8},
      );
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
