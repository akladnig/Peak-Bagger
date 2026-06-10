import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peakbagger_peak_correlation_service.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

void main() {
  const service = PeakBaggerPeakCorrelationService();

  Peak peak({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    double? elevation,
    String altName = '',
  }) {
    return Peak(
      id: id,
      osmId: id + 100,
      name: name,
      altName: altName,
      elevation: elevation,
      latitude: latitude,
      longitude: longitude,
    );
  }

  final details = PeakBaggerPeakDetails(
    peakbaggerPid: 74023,
    name: 'Mt Anne',
    latitude: -41.5,
    longitude: 146.5,
    elevation: 1103,
    prominence: 561,
    country: 'Australia',
    county: 'Tasmania',
    range: 'Tasmania',
  );

  test('matches a single peak in the spatial window', () {
    final result = service.correlate(
      peakBaggerPeak: details,
      peaks: [peak(id: 1, name: 'Mt Anne', latitude: -41.5001, longitude: 146.5001, elevation: 1100)],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'spatial-match');
    expect(result.note, 'matched via strong spatial match');
    expect(result.safeToCreate, isFalse);
  });

  test('uses the closest location when multiple peaks are in range', () {
    final result = service.correlate(
      peakBaggerPeak: details,
      peaks: [
        peak(id: 1, name: 'Mt Anne A', latitude: -41.5001, longitude: 146.5001, elevation: 1100),
        peak(id: 2, name: 'Mt Anne B', latitude: -41.5002, longitude: 146.5002, elevation: 1100),
      ],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'closest-location-tie-break');
    expect(result.detail, contains('selected Mt Anne A'));
    expect(result.safeToCreate, isFalse);
  });

  test('rejects effectively tied closest-location candidates', () {
    final result = service.correlate(
      peakBaggerPeak: details,
      peaks: [
        peak(id: 1, name: 'Mt Anne A', latitude: -41.5001, longitude: 146.5001, elevation: 1100),
        peak(id: 2, name: 'Mt Anne B', latitude: -41.5001, longitude: 146.5001, elevation: 1100),
      ],
    );

    expect(result.peak, isNull);
    expect(result.action, 'closest-location-tie');
    expect(result.safeToCreate, isFalse);
  });

  test('falls back to strong normalized-name matching', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Cradle Mountain',
        latitude: -99,
        longitude: 0,
        elevation: 100,
      ),
      peaks: [
        peak(id: 1, name: 'Cradle Mountin', latitude: -10, longitude: 10, elevation: 500),
      ],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'strong-name-fallback');
    expect(result.safeToCreate, isFalse);
  });

  test('prefers a unique exact-name match over other strong-name candidates', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Mount Giblin',
        latitude: -43.006468,
        longitude: 146.185842,
        elevation: 884,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Mount Giblin',
          latitude: -43.00799,
          longitude: 146.16562,
          elevation: 881,
        ),
        peak(
          id: 2,
          name: 'Giblin Peak',
          altName: 'Mount Giblin',
          latitude: -43.0065,
          longitude: 146.1858,
          elevation: 884,
        ),
      ],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'strong-name-exact');
    expect(result.note, contains('matched via exact name'));
    expect(result.note, contains('spatial diff:'));
    expect(result.safeToCreate, isFalse);
  });

  test('resolves among duplicate exact-name peaks by closest fit', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 77037,
        name: 'Mount Razorback',
        latitude: -41.86567,
        longitude: 145.418247,
        elevation: 580,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Mount Razorback',
          latitude: -41.8668,
          longitude: 145.4198,
          elevation: 581,
        ),
        peak(
          id: 2,
          name: 'Mount Razorback',
          latitude: -41.88,
          longitude: 145.45,
          elevation: 579,
        ),
      ],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'strong-name-exact');
    expect(result.note, contains('spatial diff:'));
    expect(result.safeToCreate, isFalse);
  });

  test('matches spatially when the existing peak elevation is missing', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Mt Anne',
          latitude: -41.5001,
          longitude: 146.5001,
          elevation: null,
        ),
      ],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'spatial-match');
    expect(result.safeToCreate, isFalse);
  });

  test('returns unresolved when nothing matches', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Unknown Peak',
        latitude: 0,
        longitude: 0,
        elevation: 1,
      ),
      peaks: [
        peak(id: 1, name: 'Cradle', latitude: -10, longitude: 10, elevation: 500),
      ],
    );

    expect(result.peak, isNull);
    expect(result.action, 'unresolved');
    expect(result.detail, 'no confident spatial match and no strong-name match');
    expect(
      result.note,
      'unresolved: no confident spatial match and no strong-name match',
    );
    expect(result.safeToCreate, isTrue);
  });

  test('reports nearest distance when no spatial match is within 1000m', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Unknown Peak',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Nearby Peak',
          latitude: -41.5005,
          longitude: 146.5005,
          elevation: 500,
        ),
      ],
    );

    expect(result.peak, isNull);
    expect(result.action, 'unresolved');
    expect(result.detail, contains('no confident spatial match and no strong-name match'));
    expect(result.detail, contains('nearest '));
    expect(result.detail, contains('m)'));
    expect(result.safeToCreate, isTrue);
  });

  test('reports spatial failure separately from multiple strong-name candidates', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Cradle Mountain',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Cradle',
          altName: 'Cradle Mountain',
          latitude: -42.0,
          longitude: 147.0,
          elevation: 500,
        ),
        peak(
          id: 2,
          name: 'Mount Cradle',
          altName: 'Cradle Mountain',
          latitude: -42.1,
          longitude: 147.1,
          elevation: 600,
        ),
      ],
    );

    expect(result.peak, isNull);
    expect(result.action, 'unresolved');
    expect(
      result.detail,
      contains('multiple exact-name candidates'),
    );
    expect(result.safeToCreate, isFalse);
  });

  test('weak name match blocks safeToCreate without becoming a strong-name match', () {
    final result = service.correlate(
      peakBaggerPeak: const PeakBaggerPeakDetails(
        peakbaggerPid: 1,
        name: 'Asbestos Range High Point',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Asbestos Range',
          latitude: -45.0,
          longitude: 150.0,
          elevation: 500,
        ),
      ],
    );

    expect(result.peak, isNull);
    expect(result.action, 'unresolved');
    expect(result.detail, 'no confident spatial match and no strong-name match');
    expect(result.safeToCreate, isFalse);
  });
}
