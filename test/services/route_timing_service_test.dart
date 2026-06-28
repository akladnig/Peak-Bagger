import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/route_timing_service.dart';

void main() {
  test('scarfDistance adds the weighted ascent contribution', () {
    expect(
      scarfDistance(distanceMetres: 1000, ascentMetres: 100),
      closeTo(1792, 0.000001),
    );
  });

  test('scarfTime converts the scarf distance to elapsed seconds', () {
    expect(scarfTime(distanceMetres: 1000, ascentMetres: 100), 1290);
  });

  test('naismithTime combines flat distance ascent and descent', () {
    expect(
      naismithTime(distanceMetres: 1000, ascentMetres: 100, descentMetres: 100),
      1500,
    );
  });

  test('formatRouteTime renders hh:mm:ss', () {
    expect(formatRouteTime(3661), '01:01:01');
  });

  test('routeTimingExplanation renders verified walk copy', () {
    expect(
      routeTimingExplanation(
        estimatedTime: 1,
        routeTimingSource: RouteTimingSources.verifiedWalk,
      ),
      'Estimated time has been derived from a verified walk',
    );
  });

  test('routeTimingExplanation renders Naismith copy', () {
    expect(
      routeTimingExplanation(
        estimatedTime: 1,
        routeTimingSource: RouteTimingSources.naismith,
      ),
      "Estimated time has been derived using Naismith's rule using 5.0 km/h, 100:00m per 1000 m ascent and 30:00m per 1000 m descent",
    );
  });

  test('routeTimingExplanation renders extended route copy', () {
    expect(
      routeTimingExplanation(
        estimatedTime: 1,
        routeTimingSource: RouteTimingSources.extendedRoute,
      ),
      "Estimated time has been derived from the original route plus manually added segments estimated using Naismith's rule using 5.0 km/h, 100:00m per 1000 m ascent and 30:00m per 1000 m descent",
    );
  });

  test('resolveRouteTimingDisplay recalculates fully manual routes', () {
    final points = const [LatLng(0, 0), LatLng(0, 0.008983)];
    const elevations = [0, 100];
    final distanceMetres = Distance().as(
      LengthUnit.Meter,
      points[0],
      points[1],
    );

    final display = resolveRouteTimingDisplay(
      points: points,
      elevations: elevations,
      estimatedTimeMillis: 123,
      routeTimingSource: RouteTimingSources.naismith,
      routeTimingProfileJson: null,
      routeTimingSegmentKindsJson: null,
      walkingSpeedKmh: 4.0,
    );

    expect(display.walkingSpeedEnabled, isTrue);
    expect(display.effectiveWalkingSpeedKmh, 4.0);
    expect(
      display.naismithDurationMillis,
      naismithTime(
            distanceMetres: distanceMetres,
            ascentMetres: 100,
            descentMetres: 0,
            speedMetresPerSecond: 4.0 / 3.6,
          ) *
          Duration.millisecondsPerSecond,
    );
    expect(
      display.scarfDurationMillis,
      scarfTime(
            distanceMetres: distanceMetres,
            ascentMetres: 100,
            speedMetresPerSecond: 4.0 / 3.6,
          ) *
          Duration.millisecondsPerSecond,
    );
  });

  test(
    'resolveRouteTimingDisplay uses stored mixed fallback for legacy mixed routes',
    () {
      final display = resolveRouteTimingDisplay(
        points: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.51)],
        elevations: const [100, 120],
        estimatedTimeMillis: 5400000,
        routeTimingSource: RouteTimingSources.extendedRoute,
        routeTimingProfileJson: '[0,5400]',
        routeTimingSegmentKindsJson: null,
        walkingSpeedKmh: null,
      );

      expect(display.walkingSpeedEnabled, isFalse);
      expect(display.naismithDurationMillis, 5400000);
      expect(display.scarfDurationMillis, isNull);
      expect(display.naismithUsesStoredMixedTotal, isTrue);
      expect(display.limitationMessage, isNotNull);
    },
  );

  test('resolveRouteTimingDisplay keeps fully preserved routes fixed', () {
    final slow = resolveRouteTimingDisplay(
      points: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.51)],
      elevations: const [100, 120],
      estimatedTimeMillis: 5400000,
      routeTimingSource: RouteTimingSources.verifiedWalk,
      routeTimingProfileJson: '[0,5400]',
      routeTimingSegmentKindsJson: '["${RouteTimingSegmentKinds.preserved}"]',
      walkingSpeedKmh: 4.0,
    );
    final fast = resolveRouteTimingDisplay(
      points: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.51)],
      elevations: const [100, 120],
      estimatedTimeMillis: 5400000,
      routeTimingSource: RouteTimingSources.verifiedWalk,
      routeTimingProfileJson: '[0,5400]',
      routeTimingSegmentKindsJson: '["${RouteTimingSegmentKinds.preserved}"]',
      walkingSpeedKmh: 5.0,
    );

    expect(slow.naismithDurationMillis, 5400000);
    expect(slow.scarfDurationMillis, 5400000);
    expect(fast.naismithDurationMillis, 5400000);
    expect(fast.scarfDurationMillis, 5400000);
  });
}
