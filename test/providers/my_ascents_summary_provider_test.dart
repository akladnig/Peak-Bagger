import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/my_ascents_summary_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

void main() {
  test('recomputes when peaks or bagged ascents change', () async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _peak(10, 'Alpha', elevation: 1234),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        _bagged(1, peakId: 10, date: DateTime.utc(2026, 5, 15)),
      ]),
    );

    final container = ProviderContainer(
      overrides: [
        peakRepositoryProvider.overrideWithValue(peakRepository),
        peaksBaggedRepositoryProvider.overrideWithValue(peaksBaggedRepository),
      ],
    );
    addTearDown(container.dispose);

    var source = container.read(myAscentsSummaryProvider);
    expect(source.baggedRows, hasLength(1));
    expect(source.peaksByOsmId[10]?.name, 'Alpha');

    await peakRepository.save(
      _peak(10, 'Bravo', elevation: 1200),
    );
    container.read(peakRevisionProvider.notifier).increment();

    source = container.read(myAscentsSummaryProvider);
    expect(source.peaksByOsmId[10]?.name, 'Bravo');

    await peaksBaggedRepository.rebuildFromTracks([
      _track(100, peakIds: [10, 20]),
    ]);
    container.read(peaksBaggedRevisionProvider.notifier).increment();

    source = container.read(myAscentsSummaryProvider);
    expect(source.baggedRows, hasLength(2));
  });

  test('returns empty dataset for empty repositories', () {
    final container = ProviderContainer(
      overrides: [
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final source = container.read(myAscentsSummaryProvider);
    expect(source.isEmpty, isTrue);
  });
}

Peak _peak(
  int osmId,
  String name, {
  double? elevation,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: -41,
    longitude: 146,
  );
}

PeaksBagged _bagged(
  int baggedId, {
  required int peakId,
  required DateTime? date,
}) {
  return PeaksBagged(
    baggedId: baggedId,
    peakId: peakId,
    gpxId: 100 + baggedId,
    date: date,
  );
}

GpxTrack _track(int id, {required List<int> peakIds}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: DateTime.utc(2026, 5, 15),
  );
  track.peaks.addAll(
    peakIds
        .map(
          (peakId) => Peak(
            osmId: peakId,
            name: 'Peak $peakId',
            latitude: -41,
            longitude: 146,
          ),
        )
        .toList(growable: false),
  );
  return track;
}
