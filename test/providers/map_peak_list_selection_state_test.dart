import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

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
    'explicit reconcile follows visible bounds, preserves empty visible selections, and skips zero-region pruning',
    () {
      final repository = _peakListRepository(
        peakLists: [
          PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 7,
          PeakList(name: 'Zero', region: 'new-south-wales')..peakListId = 8,
          PeakList(name: 'Empty', region: 'tasmania')..peakListId = 9,
        ],
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
          Peak(
            osmId: 9999,
            name: 'NSW Peak',
            latitude: -33.7,
            longitude: 149.0,
            region: 'new-south-wales',
          ),
        ],
        memberships: const [
          (peakListId: 7, peakOsmId: 6406, points: 1),
          (peakListId: 8, peakOsmId: 9999, points: 1),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => _InitialStateMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 15,
                basemap: Basemap.tracestrack,
                visibleBounds: LatLngBounds(
                  const LatLng(-43.5, 145.5),
                  const LatLng(-40.5, 148.5),
                ),
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
      expect(container.read(mapProvider).selectedPeakListIds, {7, 9});
      expect(container.read(mapProvider).previousSpecificPeakListIds, {7, 9});

      container.read(mapProvider.notifier).state = container
          .read(mapProvider.notifier)
          .state
          .copyWith(
            selectedPeakListIds: {7, 8, 9},
            previousSpecificPeakListIds: {7, 8, 9},
          );

      container
          .read(mapProvider.notifier)
          .updateVisibleBounds(
            LatLngBounds(const LatLng(-10.0, 10.0), const LatLng(-5.0, 15.0)),
          );

      container.read(mapProvider.notifier).reconcileSelectedPeakList();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListIds, {7, 8, 9});
      expect(container.read(mapProvider).previousSpecificPeakListIds, {
        7,
        8,
        9,
      });

      container
          .read(mapProvider.notifier)
          .updateVisibleBounds(
            LatLngBounds(
              const LatLng(-44.0, 145.0),
              const LatLng(-33.0, 149.5),
            ),
          );

      container.read(mapProvider.notifier).reconcileSelectedPeakList();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListIds, {7, 8, 9});
      expect(container.read(mapProvider).previousSpecificPeakListIds, {
        7,
        8,
        9,
      });
    },
  );

  test(
    'mixed-region list stays selected when cached bounds intersect viewport',
    () {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Mixed Cached',
            region: PeakList.mixedRegion,
            minLat: -43.2,
            maxLat: -42.8,
            minLng: 146.8,
            maxLng: 147.2,
          )..peakListId = 7,
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
                visibleBounds: LatLngBounds(
                  const LatLng(-43.5, 145.5),
                  const LatLng(-40.5, 148.5),
                ),
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7},
                previousSpecificPeakListIds: {7},
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
    },
  );

  test(
    'mixed-region list stays selected when member peaks intersect viewport',
    () {
      final repository = _peakListRepository(
        peakLists: [
          PeakList(name: 'Mixed Members', region: PeakList.mixedRegion)
            ..peakListId = 7,
        ],
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
        ],
        memberships: const [(peakListId: 7, peakOsmId: 6406, points: 1)],
      );

      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => _InitialStateMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 15,
                basemap: Basemap.tracestrack,
                visibleBounds: LatLngBounds(
                  const LatLng(-43.5, 145.5),
                  const LatLng(-40.5, 148.5),
                ),
                peaks: [
                  Peak(
                    osmId: 6406,
                    name: 'Bonnet Hill',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                ],
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {7},
                previousSpecificPeakListIds: {7},
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

PeakListRepository _peakListRepository({
  required List<PeakList> peakLists,
  List<Peak> peaks = const [],
  List<({int peakListId, int peakOsmId, int points})> memberships = const [],
}) {
  final peaksByOsmId = {
    for (final peak in peaks) peak.osmId: peak,
    for (final membership in memberships)
      if (!peaks.any((peak) => peak.osmId == membership.peakOsmId))
        membership.peakOsmId: Peak(
          osmId: membership.peakOsmId,
          name: 'Peak ${membership.peakOsmId}',
          latitude: -42,
          longitude: 146,
        ),
  };
  final peakListsById = {for (final peakList in peakLists) peakList.peakListId: peakList};

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    peakRepository: PeakRepository.test(
      InMemoryPeakStorage(peaksByOsmId.values.toList(growable: false)),
    ),
    itemStorage: InMemoryPeakListItemEntityStorage([
      for (var index = 0; index < memberships.length; index++)
        PeakListItemEntity(id: index + 1, points: memberships[index].points)
          ..peakList.target = peakListsById[memberships[index].peakListId]!
          ..peak.target = peaksByOsmId[memberships[index].peakOsmId]!,
    ]),
  );
}
