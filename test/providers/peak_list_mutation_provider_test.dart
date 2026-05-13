// ignore_for_file: use_super_parameters

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

void main() {
  test('successful source mutation refreshes Tassy Full and reconciles selection', () async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
          ]),
        )..peakListId = 1,
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
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListId: 999,
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final mutationRepository = container.read(peakListMutationRepositoryProvider);
    await mutationRepository.addPeakItem(
      peakListId: 1,
      item: const PeakListItem(peakOsmId: 22, points: 4),
    );

    expect(container.read(peakListRevisionProvider), 1);
    expect(container.read(mapProvider).peakListSelectionMode, PeakListSelectionMode.allPeaks);
    expect(container.read(mapProvider).selectedPeakListId, isNull);
    expect(
      decodePeakListItems(repository.findByName('Tassy Full')!.peakList)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [(11, 2), (22, 4)],
    );
  });

  test('refresh failure keeps the source mutation committed and skips revision bump', () async {
    final repository = PeakListRepository.test(
      _FailingTassyFullStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
          ]),
        )..peakListId = 1,
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
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListId: 999,
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final mutationRepository = container.read(peakListMutationRepositoryProvider);
    await mutationRepository.addPeakItem(
      peakListId: 1,
      item: const PeakListItem(peakOsmId: 22, points: 4),
    );

    expect(container.read(peakListRevisionProvider), 0);
    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListId, 999);
    expect(
      decodePeakListItems(repository.findByName('Abels')!.peakList)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [(11, 2), (22, 4)],
    );
    expect(repository.findByName('Tassy Full'), isNull);
  });
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}

class _FailingTassyFullStorage extends InMemoryPeakListStorage {
  _FailingTassyFullStorage([List<PeakList> peakLists = const []])
    : super(peakLists);

  @override
  Future<PeakList> put(PeakList peakList) {
    if (peakList.name == 'Tassy Full') {
      throw StateError('boom');
    }

    return super.put(peakList);
  }

  @override
  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) {
    if (peakList.name == 'Tassy Full') {
      throw StateError('boom');
    }

    return super.replaceByName(peakList, beforePutForTest: beforePutForTest);
  }
}
