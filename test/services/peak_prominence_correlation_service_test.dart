import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_prominence_correlation_service.dart';
import 'package:peak_bagger/services/peak_prominence_csv_service.dart';

void main() {
  const service = PeakProminenceCorrelationService();

  Peak peak({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    double? elevation,
  }) {
    return Peak(
      id: id,
      osmId: id + 100,
      name: name,
      latitude: latitude,
      longitude: longitude,
      elevation: elevation,
    );
  }

  PeakProminenceCsvRow row({
    required double latitude,
    required double longitude,
    required double elevation,
    double keySaddleLatitude = 0,
    double keySaddleLongitude = 0,
    double prominence = 0,
  }) {
    return PeakProminenceCsvRow(
      lineNumber: 1,
      latitude: latitude,
      longitude: longitude,
      elevation: elevation,
      keySaddleLatitude: keySaddleLatitude,
      keySaddleLongitude: keySaddleLongitude,
      prominence: prominence,
    );
  }

  test('matches a single peak in the spatial window', () {
    final result = service.correlate(
      row: row(
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Mt Anne',
          latitude: -41.5001,
          longitude: 146.5001,
          elevation: 1100,
        ),
      ],
    );

    expect(result.peak?.id, 1);
    expect(result.action, 'spatial-match');
    expect(result.skippedDuplicatePeaks, isEmpty);
  });

  test('falls back to lat lon only when peak elevation is missing', () {
    final result = service.correlate(
      row: row(
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
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
  });

  test('chooses the smallest id when multiple peaks qualify', () {
    final result = service.correlate(
      row: row(
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
      ),
      peaks: [
        peak(
          id: 7,
          name: 'Later Peak',
          latitude: -41.5001,
          longitude: 146.5001,
          elevation: 1102,
        ),
        peak(
          id: 3,
          name: 'First Peak',
          latitude: -41.5002,
          longitude: 146.5002,
          elevation: 1102,
        ),
      ],
    );

    expect(result.peak?.id, 3);
    expect(result.action, 'closest-location-tie-break');
    expect(result.skippedDuplicatePeaks, hasLength(1));
    expect(result.skippedDuplicatePeaks.single.id, 7);
  });

  test('leaves rows unresolved when no peaks qualify', () {
    final result = service.correlate(
      row: row(
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
      ),
      peaks: [
        peak(
          id: 1,
          name: 'Far Away',
          latitude: -10,
          longitude: 10,
          elevation: 500,
        ),
      ],
    );

    expect(result.peak, isNull);
    expect(result.action, 'unresolved');
  });
}
