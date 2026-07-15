import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
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
    'filteredPeaksProvider applies map metadata filters with blank-last semantics',
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
                    osmId: 1,
                    name: 'Tas Easy',
                    latitude: -42.0,
                    longitude: 146.0,
                    rating: 4.4,
                    difficulty: 'Easy',
                    durationMinutes: 255,
                    region: 'tasmania',
                  ),
                  Peak(
                    osmId: 2,
                    name: 'FVG T',
                    latitude: 46.2,
                    longitude: 13.2,
                    rating: 4.8,
                    difficulty: 'T',
                    durationMinutes: 180,
                    region: 'fvg',
                  ),
                  Peak(
                    osmId: 3,
                    name: 'Blank Peak',
                    latitude: -41.9,
                    longitude: 146.1,
                    region: 'tasmania',
                  ),
                ],
                peakRatingFilter: PeakRatingFilterOption.atLeast4_5,
                peakDifficultyFilter: const PeakDifficultyFilterOption(
                  region: 'fvg',
                  difficulty: 'T',
                ),
                peakDurationFilter: PeakDurationFilterOption.upTo4Hours,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final filteredPeaks = container.read(filteredPeaksProvider);

      expect(filteredPeaks.map((peak) => peak.osmId).toList(), [2]);
    },
  );

  test(
    'mapDifficultyFilterOptionsProvider builds grouped exact region+difficulty pairs from scope peaks',
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
                    osmId: 1,
                    name: 'Tas Hard',
                    latitude: -42.0,
                    longitude: 146.0,
                    difficulty: 'Hard',
                    region: 'tasmania',
                  ),
                  Peak(
                    osmId: 2,
                    name: 'FVG T',
                    latitude: 46.2,
                    longitude: 13.2,
                    difficulty: 'T',
                    region: 'fvg',
                  ),
                  Peak(
                    osmId: 3,
                    name: 'FVG EE',
                    latitude: 46.3,
                    longitude: 13.3,
                    difficulty: 'EE',
                    region: 'fvg',
                  ),
                  Peak(
                    osmId: 4,
                    name: 'Blank Peak',
                    latitude: -41.9,
                    longitude: 146.1,
                    region: 'tasmania',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final options = container.read(mapDifficultyFilterOptionsProvider);

      expect(options, [
        const PeakDifficultyFilterOption(region: 'fvg', difficulty: 'T'),
        const PeakDifficultyFilterOption(region: 'fvg', difficulty: 'EE'),
        const PeakDifficultyFilterOption(
          region: 'tasmania',
          difficulty: 'Hard',
        ),
      ]);
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
    'peakMarkerColourAssignmentsProvider uses Tasmania ownership precedence',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Poimenas',
            region: 'tasmania',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
            ]),
            colour: 0xFF6347EA,
          )..peakListId = 1,
          PeakList(
            name: 'Abels',
            region: 'tasmania',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
            ]),
            colour: 0xFF4C8BF5,
          )..peakListId = 9,
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
                    region: 'tasmania',
                  ),
                ],
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {1, 9},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(peakMarkerColourAssignmentsProvider), {
        6406: 0xFF4C8BF5,
      });
    },
  );

  test(
    'peakOwnershipRingSegmentsProvider skips zero and single-list ownership and orders Tasmania segments from 12 o clock clockwise',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'HWC Peak Baggers',
            region: 'tasmania',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
            ]),
            colour: 0xFF12B886,
          )..peakListId = 5,
          PeakList(
            name: 'Abels',
            region: 'tasmania',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
              const PeakListItem(peakOsmId: 6407, points: 1),
            ]),
            colour: 0xFF4C8BF5,
          )..peakListId = 9,
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
                    region: 'tasmania',
                  ),
                  Peak(
                    osmId: 6407,
                    name: 'Single Owner',
                    latitude: -43.1,
                    longitude: 147.1,
                    region: 'tasmania',
                  ),
                  Peak(
                    osmId: 6408,
                    name: 'No Owner',
                    latitude: -43.2,
                    longitude: 147.2,
                    region: 'tasmania',
                  ),
                ],
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {5, 9},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
          peakOwnershipRingSettingsProvider.overrideWith(
            _StaticPeakOwnershipRingSettingsNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final segmentsByPeakId = container.read(
        peakOwnershipRingSegmentsProvider,
      );

      expect(segmentsByPeakId.keys, [6406]);
      expect(
        segmentsByPeakId[6406]!.map((segment) => segment.peakListId).toList(),
        [9, 5],
      );
    },
  );

  test(
    'peakOwnershipRingSegmentsProvider orders non-Tasmania segments by lowest peakListId',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Bravo',
            region: 'victoria',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 7000, points: 1),
            ]),
            colour: 0xFFE67E22,
          )..peakListId = 8,
          PeakList(
            name: 'Alpha',
            region: 'victoria',
            peakList: encodePeakListItems([
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
                center: const LatLng(-37.8, 145.0),
                zoom: 15,
                basemap: Basemap.tracestrack,
                peaks: [
                  Peak(
                    osmId: 7000,
                    name: 'Other Peak',
                    latitude: -37.8,
                    longitude: 145.0,
                    region: 'victoria',
                  ),
                ],
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7, 8},
              ),
            ),
          ),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
          peakOwnershipRingSettingsProvider.overrideWith(
            _StaticPeakOwnershipRingSettingsNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(peakOwnershipRingSegmentsProvider)[7000]!
            .map((segment) => segment.peakListId)
            .toList(),
        [7, 8],
      );
    },
  );

  test(
    'peakMarkerColourAssignmentsProvider skips malformed selected lists',
    () {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Broken', peakList: '{not-json}', colour: 0xFFD6336C)
            ..peakListId = 7,
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

class _StaticPeakOwnershipRingSettingsNotifier
    extends PeakOwnershipRingSettingsNotifier {
  @override
  bool build() => true;
}
