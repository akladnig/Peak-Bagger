import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_info_content_resolver.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('resolves map, list, and ordered ascent rows for a peak', () async {
    final peak = Peak(
      osmId: 42,
      name: 'Alpha Peak',
      latitude: -42.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'EN',
      easting: '12345',
      northing: '67890',
    );
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 42, points: 10),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 99, points: 4),
          ]),
        )..peakListId = 2,
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(
          baggedId: 1,
          peakId: 42,
          gpxId: 11,
          date: DateTime.utc(2026, 5, 16),
        ),
        PeaksBagged(
          baggedId: 2,
          peakId: 42,
          gpxId: 10,
          date: DateTime.utc(2026, 5, 16),
        ),
        PeaksBagged(
          baggedId: 3,
          peakId: 42,
          gpxId: 12,
          date: DateTime.utc(2026, 5, 15),
        ),
      ]),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([
        GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Alpha Loop',
          trackDate: DateTime.utc(2026, 5, 16),
        ),
        GpxTrack(
          gpxTrackId: 11,
          contentHash: 'hash-11',
          trackName: 'South Wellington (18/03/2026)',
          trackDate: DateTime.utc(2026, 5, 16),
        ),
        GpxTrack(
          gpxTrackId: 12,
          contentHash: 'hash-12',
          trackName: '   ',
          trackDate: DateTime.utc(2026, 5, 15),
        ),
      ]),
    );
    final tasmapRepository = await TestTasmapRepository.create(
      maps: [
        Tasmap50k(
          series: 'TS07',
          name: 'Test Map',
          parentSeries: '8211',
          mgrs100kIds: 'EN',
          eastingMin: 10000,
          eastingMax: 20000,
          northingMin: 60000,
          northingMax: 70000,
        ),
      ],
    );

    final content = resolvePeakInfoContent(
      peak: peak,
      peakListRepository: peakListRepository,
      tasmapRepository: tasmapRepository,
      peaksBaggedRepository: peaksBaggedRepository,
      gpxTrackRepository: gpxTrackRepository,
    );

    expect(content.peak, same(peak));
    expect(content.mapName, 'Test Map');
    expect(content.listNames, ['Abels']);
    expect(
      content.ascentRows
          .map((row) => '${row.trackLabel} (${row.dateText})')
          .toList(growable: false),
      [
        'Alpha Loop (16 May 2026)',
        'South Wellington (16 May 2026)',
        'Track #12 (15 May 2026)',
      ],
    );
  });

  test('omits ascent rows when none exist', () async {
    final content = resolvePeakInfoContent(
      peak: Peak(
        osmId: 42,
        name: 'Alpha Peak',
        latitude: -42.0,
        longitude: 146.0,
      ),
      peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
      tasmapRepository: await TestTasmapRepository.create(),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    );

    expect(content.ascentRows, isEmpty);
  });

  test('omits ascent rows when bagged resolution fails', () async {
    final content = resolvePeakInfoContent(
      peak: Peak(
        osmId: 42,
        name: 'Alpha Peak',
        latitude: -42.0,
        longitude: 146.0,
      ),
      peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
      tasmapRepository: await TestTasmapRepository.create(),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        _ThrowingPeaksBaggedStorage(),
      ),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    );

    expect(content.ascentRows, isEmpty);
  });
}

class _ThrowingPeaksBaggedStorage implements PeaksBaggedStorage {
  @override
  List<PeaksBagged> getAll() {
    throw StateError('boom');
  }

  @override
  void replaceAll(
    List<PeaksBagged> rows, {
    void Function()? beforePutManyForTest,
  }) {}

  @override
  void sync(
    ({List<PeaksBagged> rows, List<int> removeIds}) plan, {
    void Function()? beforeWriteForTest,
  }) {}
}
