import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/natural_feature.dart';

void main() {
  test(
    'legacy track result retains its previous local-time interpretation',
    () {
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: 'Arthurs Peak',
        trackDate: DateTime.utc(2026, 7, 22, 14),
        startDateTime: DateTime.utc(2026, 7, 22, 23, 39, 42),
      );

      final result = MapSearchResult.track(
        id: '173',
        title: track.trackName,
        subtitle: '',
        anchor: const LatLng(-43, 147),
        track: track,
      );

      expect(result.displayDate, track.trackDate!.toLocal());
    },
  );

  test(
    'resolved calendar date stays component-preserving in search results',
    () {
      final track = GpxTrack(
        contentHash: 'canonical',
        trackName: 'Walk',
        trackDateStatus: 1,
        trackDateDerivationVersion: 1,
        trackDate: DateTime.utc(2026, 12, 31),
        startDateTime: DateTime.utc(2027, 1, 1, 7, 30),
      );
      final result = MapSearchResult.track(
        id: '1',
        title: track.trackName,
        subtitle: '',
        anchor: const LatLng(34, -118),
        track: track,
      );
      expect(result.displayDate, DateTime.utc(2026, 12, 31));
    },
  );

  test('unresolved new imports cannot fall back to the start timestamp', () {
    final track = GpxTrack(
      contentHash: 'unknown',
      trackName: 'Unknown walk',
      trackDateStatus: 3,
      trackDateFailureReason: 'missing_time',
      startDateTime: DateTime.utc(2027, 1, 1, 7, 30),
    );
    final result = MapSearchResult.track(
      id: '1',
      title: track.trackName,
      subtitle: '',
      anchor: const LatLng(34, -118),
      track: track,
    );
    expect(result.displayDate, isNull);
  });

  test('natural result retains collision-free OSM identity payload', () {
    final feature = NaturalFeature(
      name: 'Lake Echo',
      tag: 'lake',
      latitude: -43,
      longitude: 147,
      osmId: 12345,
      osmType: 'way',
    );

    final result = MapSearchResult.natural(
      id: 'way-12345',
      title: feature.name,
      subtitle: 'Lake · Tasmania',
      anchor: const LatLng(-43, 147),
      naturalFeature: feature,
    );

    expect(result.type, MapSearchResultType.natural);
    expect(result.naturalFeature, same(feature));
    expect(result.id, 'way-12345');
  });
}
