import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';

void main() {
  group('PeakDeleteGuard', () {
    late _FakePeakDeleteGuardSource source;
    late PeakDeleteGuard guard;

    setUp(() {
      source = _FakePeakDeleteGuardSource();
      guard = PeakDeleteGuard(source);
    });

    test('returns blockers in deterministic type order and ignores bad JSON', () {
      final peak = Peak(
        id: 7,
        osmId: 123,
        name: 'Cradle',
        latitude: -41,
        longitude: 146,
      );

      source.gpxTracks = [
        GpxTrack(
          gpxTrackId: 2,
          contentHash: 'hash',
          trackName: 'Z Track',
        ),
      ]..first.peaks.add(peak);
      source.peakLists = [
        PeakList(name: 'Broken list', peakList: '{not json'),
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 999, points: 2),
            const PeakListItem(peakOsmId: 123, points: 4),
          ]),
        ),
      ];
      source.peaksBagged = [
        PeaksBagged(baggedId: 3, peakId: 123, gpxId: 77),
        PeaksBagged(baggedId: 4, peakId: 123, gpxId: 78),
      ];

      final result = guard.check(peak);

      expect(result.canDelete, isFalse);
      expect(
        result.blockers
            .map((blocker) => (blocker.dependencyType, blocker.displayName))
            .toList(),
        [
          (PeakDeleteDependencyType.gpxTrack, 'Z Track'),
          (PeakDeleteDependencyType.peakList, 'Abels'),
          (PeakDeleteDependencyType.peaksBagged, 'bagged record'),
          (PeakDeleteDependencyType.peaksBagged, 'bagged record'),
        ],
      );
    });

    test('returns an empty blocker list when the peak is unused', () {
      final peak = Peak(
        id: 7,
        osmId: 123,
        name: 'Cradle',
        latitude: -41,
        longitude: 146,
      );

      final result = guard.check(peak);

      expect(result.canDelete, isTrue);
      expect(result.blockers, isEmpty);
    });
  });
}

class _FakePeakDeleteGuardSource implements PeakDeleteGuardSource {
  List<GpxTrack> gpxTracks = const [];
  List<PeakList> peakLists = const [];
  List<PeaksBagged> peaksBagged = const [];

  @override
  List<GpxTrack> loadGpxTracks() => gpxTracks;

  @override
  List<PeakList> loadPeakLists() => peakLists;

  @override
  List<PeaksBagged> loadPeaksBagged() => peaksBagged;
}
