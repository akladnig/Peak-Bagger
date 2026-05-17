import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/my_lists_summary_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

import '../harness/test_map_notifier.dart';

void main() {
  test('recomputes when peak lists or climb data change', () async {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          peakListId: 1,
          name: 'Alpha',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 1, points: 1),
            const PeakListItem(peakOsmId: 2, points: 1),
          ]),
        ),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(baggedId: 1, peakId: 1, gpxId: 10, date: DateTime.utc(2026, 5, 15)),
      ]),
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        tracks: [_track(10, peakIds: [1])],
        showTracks: true,
      ),
      peaksBaggedRepository: peaksBaggedRepository,
    );

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => mapNotifier),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
        peaksBaggedRepositoryProvider.overrideWithValue(peaksBaggedRepository),
      ],
    );
    addTearDown(container.dispose);

    var rows = container.read(myListsSummaryProvider);
    expect(rows, hasLength(1));
    expect(rows.single.totalPeaks, 2);
    expect(rows.single.climbed, 1);

    await peaksBaggedRepository.rebuildFromTracks([_track(10, peakIds: [1, 2])]);
    mapNotifier.setTracks([_track(10, peakIds: [1, 2])]);
    rows = container.read(myListsSummaryProvider);
    expect(rows.single.climbed, 2);
    expect(rows.single.percentageLabel, '100%');

    await peakListRepository.save(
      PeakList(
        peakListId: 1,
        name: 'Alpha',
        peakList: encodePeakListItems([
          const PeakListItem(peakOsmId: 1, points: 1),
          const PeakListItem(peakOsmId: 2, points: 1),
          const PeakListItem(peakOsmId: 3, points: 1),
        ]),
      ),
    );
    container.read(peakListRevisionProvider.notifier).increment();

    rows = container.read(myListsSummaryProvider);
    expect(rows.single.totalPeaks, 3);
    expect(rows.single.climbed, 2);
    expect(rows.single.unclimbed, 1);
  });

  test('returns empty state when no usable lists exist', () {
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    );
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              tracks: const [],
            ),
            peaksBaggedRepository: peaksBaggedRepository,
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(peaksBaggedRepository),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(myListsSummaryProvider), isEmpty);
  });
}

GpxTrack _track(
  int id, {
  required List<int> peakIds,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: DateTime.utc(2026, 5, 15, 10),
  );
  track.peaks.addAll(
    peakIds.map(
      (peakId) => Peak(
        osmId: peakId,
        name: 'Peak $peakId',
        latitude: -42,
        longitude: 146,
      ),
    ),
  );
  return track;
}
