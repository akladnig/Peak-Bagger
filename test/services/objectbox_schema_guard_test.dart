import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/objectbox_schema_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores the schema signature on first run', () async {
    SharedPreferences.setMockInitialValues({});

    final guard = ObjectBoxSchemaGuard(signatureLoader: () => 'schema-v1');

    await guard.verify();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('objectbox_schema_signature'), 'schema-v1');
  });

  test('updates the stored signature when the schema changes', () async {
    SharedPreferences.setMockInitialValues({
      'objectbox_schema_signature': 'schema-v1',
    });

    final guard = ObjectBoxSchemaGuard(signatureLoader: () => 'schema-v2');

    await guard.verify();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('objectbox_schema_signature'), 'schema-v2');
  });

  test('schema signature includes peak and peak list surface markers', () {
    final signature = ObjectBoxSchemaGuard.debugCurrentSchemaSignature();

    expect(signature, contains('Peak.altName:'));
    expect(signature, contains('Peak.peakbaggerPid:'));
    expect(signature, contains('Peak.prominence:'));
    expect(signature, contains('Peak.country:'));
    expect(signature, contains('Peak.county:'));
    expect(signature, contains('Peak.range:'));
    expect(signature, contains('Peak.verified:'));
    expect(signature, contains('Peak.sourceOfTruth:'));
    expect(signature, contains('PeakList.name:'));
    expect(signature, contains('PeakList.peakList:'));
    expect(signature, contains('PeaksBagged.peakId:'));
    expect(signature, contains('PeaksBagged.gpxId:'));
    expect(signature, contains('PeaksBagged.date:'));
    expect(signature, contains('Route.name:'));
    expect(signature, contains('Route.desc:'));
    expect(signature, contains('Route.gpxRouteJson:'));
    expect(signature, contains('Route.routeWaypointsJson:'));
    expect(signature, contains('Route.estimatedTime:'));
    expect(signature, contains('Route.routeTimingSource:'));
    expect(signature, contains('Route.routeTimingProfileJson:'));
    expect(signature, contains('Route.walkingSpeedKmh:'));
    expect(signature, contains('Route.routeTimingSegmentKindsJson:'));
    expect(signature, contains('Route.displayRoutePointsByZoom:'));
    expect(signature, contains('Route.colour:'));
  });
}
