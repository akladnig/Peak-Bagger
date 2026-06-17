import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/route_timing_service.dart';

void main() {
  test('scarfDistance adds the weighted ascent contribution', () {
    expect(
      scarfDistance(distanceMetres: 1000, ascentMetres: 100),
      closeTo(1792, 0.000001),
    );
  });

  test('scarfTime converts the scarf distance to elapsed seconds', () {
    expect(
      scarfTime(distanceMetres: 1000, ascentMetres: 100),
      1290,
    );
  });

  test('naismithTime combines flat distance ascent and descent', () {
    expect(
      naismithTime(
        distanceMetres: 1000,
        ascentMetres: 100,
        descentMetres: 100,
      ),
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
}
