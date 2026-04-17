import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/track_peak_correlation_service.dart';

void main() {
  test('matches peaks inside the threshold', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(osmId: 1, name: 'Near Peak', latitude: -41.5, longitude: 146.55),
      ],
      thresholdMeters: 50,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg><trkpt lat="-41.5" lon="146.5" /><trkpt lat="-41.5" lon="146.6" /></trkseg></trk></gpx>',
    );

    expect(matches, hasLength(1));
    expect(matches.single.osmId, 1);
  });

  test('matches peaks exactly on the threshold boundary', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(
          osmId: 2,
          name: 'Boundary Peak',
          latitude: -41.5,
          longitude: 146.5,
        ),
      ],
      thresholdMeters: 0,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg><trkpt lat="-41.5" lon="146.5" /><trkpt lat="-41.5" lon="146.6" /></trkseg></trk></gpx>',
    );

    expect(matches, hasLength(1));
    expect(matches.single.osmId, 2);
  });

  test('collapses duplicate peaks matched by multiple segments', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(
          osmId: 3,
          name: 'Duplicate Peak',
          latitude: -41.5,
          longitude: 146.55,
        ),
      ],
      thresholdMeters: 50,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg>'
      '<trkpt lat="-41.5" lon="146.5" />'
      '<trkpt lat="-41.5" lon="146.55" />'
      '<trkpt lat="-41.5" lon="146.6" />'
      '</trkseg></trk></gpx>',
    );

    expect(matches, hasLength(1));
    expect(matches.single.osmId, 3);
  });

  test('falls back to point distance for one-point tracks', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(osmId: 4, name: 'Point Peak', latitude: -41.5, longitude: 146.5),
      ],
      thresholdMeters: 0,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg><trkpt lat="-41.5" lon="146.5" /></trkseg></trk></gpx>',
    );

    expect(matches, hasLength(1));
    expect(matches.single.osmId, 4);
  });

  test('returns no peaks when none are within threshold', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(osmId: 5, name: 'Far Peak', latitude: -40.0, longitude: 145.0),
      ],
      thresholdMeters: 50,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg><trkpt lat="-41.5" lon="146.5" /><trkpt lat="-41.5" lon="146.6" /></trkseg></trk></gpx>',
    );

    expect(matches, isEmpty);
  });

  test('does not match peaks on the line extension beyond the segment', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(osmId: 6, name: 'Extension Peak', latitude: 0.0, longitude: 0.002),
      ],
      thresholdMeters: 10,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg><trkpt lat="0.0" lon="0.0" />'
      '<trkpt lat="0.0" lon="0.001" /></trkseg></trk></gpx>',
    );

    expect(matches, isEmpty);
  });

  test('uses longitude-aware bounding boxes at Tasmania latitudes', () {
    final service = TrackPeakCorrelationService(
      peaks: [
        Peak(osmId: 7, name: 'Edge Peak', latitude: -41.5, longitude: 146.51),
      ],
      thresholdMeters: 900,
    );

    final matches = service.matchPeaks(
      '<gpx><trk><trkseg>'
      '<trkpt lat="-41.5" lon="146.5" />'
      '<trkpt lat="-41.5" lon="146.5001" />'
      '</trkseg></trk></gpx>',
    );

    expect(matches, hasLength(1));
    expect(matches.single.osmId, 7);
  });
}
