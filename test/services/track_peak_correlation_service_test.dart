import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/track_peak_correlation_service.dart';

void main() {
  test('matches a peak within the 10 m elevation threshold', () {
    final matches = _service(
      _peak(),
    ).matchPeaks(_track('<trkpt lat="0" lon="0"><ele>108</ele></trkpt>'));

    expect(matches, hasLength(1));
  });

  test('rejects a horizontally close peak outside the elevation threshold', () {
    final matches = _service(
      _peak(),
    ).matchPeaks(_track('<trkpt lat="0" lon="0"><ele>111</ele></trkpt>'));

    expect(matches, isEmpty);
  });

  test('includes exact horizontal and vertical threshold boundaries', () {
    final matches = _service(
      _peak(),
      distanceThresholdMeters: 0,
    ).matchPeaks(_track('<trkpt lat="0" lon="0"><ele>110</ele></trkpt>'));

    expect(matches, hasLength(1));
  });

  test('rejects a peak without an elevation', () {
    final matches = _service(
      _peak(elevation: null),
    ).matchPeaks(_track('<trkpt lat="0" lon="0"><ele>100</ele></trkpt>'));

    expect(matches, isEmpty);
  });

  for (final elevationXml in <String>[
    '',
    '<ele></ele>',
    '<ele>not-a-number</ele>',
    '<ele>NaN</ele>',
    '<ele>Infinity</ele>',
  ]) {
    test('rejects unavailable one-point elevation: $elevationXml', () {
      final matches = _service(
        _peak(),
      ).matchPeaks(_track('<trkpt lat="0" lon="0">$elevationXml</trkpt>'));

      expect(matches, isEmpty);
    });
  }

  test('rejects a segment with a missing endpoint elevation', () {
    final matches = _service(_peak(longitude: .001)).matchPeaks(
      _track(
        '<trkpt lat="0" lon="0"><ele>100</ele></trkpt>'
        '<trkpt lat="0" lon="0.002"></trkpt>',
      ),
    );

    expect(matches, isEmpty);
  });

  test('interpolates elevation at an interior closest segment position', () {
    final matches =
        _service(
          _peak(longitude: .001, elevation: 150),
          distanceThresholdMeters: 0,
          elevationThresholdMeters: 0,
        ).matchPeaks(
          _track(
            '<trkpt lat="0" lon="0"><ele>100</ele></trkpt>'
            '<trkpt lat="0" lon="0.002"><ele>200</ele></trkpt>',
          ),
        );

    expect(matches, hasLength(1));
  });

  test('matches when another nearby segment meets the elevation threshold', () {
    final matches =
        _service(
          _peak(longitude: .001, elevation: 200),
          distanceThresholdMeters: 50,
        ).matchPeaks(
          '<gpx><trk>'
          '<trkseg><trkpt lat="0" lon="0"><ele>100</ele></trkpt>'
          '<trkpt lat="0" lon="0.002"><ele>100</ele></trkpt></trkseg>'
          '<trkseg><trkpt lat="0.0001" lon="0"><ele>200</ele></trkpt>'
          '<trkpt lat="0.0001" lon="0.002"><ele>200</ele></trkpt></trkseg>'
          '</trk></gpx>',
        );

    expect(matches, hasLength(1));
  });

  test('matches a nearby elevation-valid position on the same segment', () {
    final matches =
        _service(
          _peak(longitude: .00043),
          distanceThresholdMeters: 10,
        ).matchPeaks(
          _track(
            '<trkpt lat="0" lon="0"><ele>0</ele></trkpt>'
            '<trkpt lat="0" lon="0.001"><ele>200</ele></trkpt>',
          ),
        );

    expect(matches, hasLength(1));
  });

  test('matches when an equal-distance position meets elevation threshold', () {
    final matches = _service(_peak(elevation: 200)).matchPeaks(
      '<gpx><trk>'
      '<trkseg><trkpt lat="0" lon="0"><ele>100</ele></trkpt></trkseg>'
      '<trkseg><trkpt lat="0" lon="0"><ele>200</ele></trkpt></trkseg>'
      '</trk></gpx>',
    );

    expect(matches, hasLength(1));
  });

  test('does not match a line extension beyond a segment', () {
    final matches =
        _service(
          _peak(longitude: .002),
          distanceThresholdMeters: 10,
        ).matchPeaks(
          _track(
            '<trkpt lat="0" lon="0"><ele>100</ele></trkpt>'
            '<trkpt lat="0" lon="0.001"><ele>100</ele></trkpt>',
          ),
        );

    expect(matches, isEmpty);
  });

  test('matches supported route points with elevation', () {
    final matches = _service(_peak()).matchPeaks(
      '<gpx><rte><rtept lat="0" lon="0"><ele>100</ele></rtept></rte></gpx>',
    );

    expect(matches, hasLength(1));
  });

  test('includes a matching peak at most once per track', () {
    final matches = _service(_peak()).matchPeaks(
      _track(
        '<trkpt lat="0" lon="0"><ele>100</ele></trkpt>'
        '<trkpt lat="0" lon="0.001"><ele>100</ele></trkpt>'
        '<trkpt lat="0" lon="0.002"><ele>100</ele></trkpt>',
      ),
    );

    expect(matches, hasLength(1));
    expect(matches.single.osmId, 1);
  });
}

TrackPeakCorrelationService _service(
  Peak peak, {
  int distanceThresholdMeters = 50,
  int elevationThresholdMeters = 10,
}) {
  return TrackPeakCorrelationService(
    peaks: [peak],
    thresholdMeters: distanceThresholdMeters,
    elevationThresholdMeters: elevationThresholdMeters,
  );
}

Peak _peak({
  int osmId = 1,
  double? elevation = 100,
  double latitude = 0,
  double longitude = 0,
}) {
  return Peak(
    osmId: osmId,
    name: 'Peak',
    elevation: elevation,
    latitude: latitude,
    longitude: longitude,
  );
}

String _track(String points) =>
    '<gpx><trk><trkseg>$points</trkseg></trk></gpx>';
