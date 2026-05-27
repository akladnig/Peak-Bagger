import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';

void main() {
  group('GpxExportService', () {
    test('plans and writes track exports', () async {
      final downloadsDir = await Directory.systemTemp.createTemp('gpx-track');
      addTearDown(() async => downloadsDir.delete(recursive: true));
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => downloadsDir,
        routeExportsDirectoryResolver: () => downloadsDir,
      );
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: 'Track 1',
        gpxFile: '<gpx>track</gpx>',
      );

      final plan = service.planTrackExport(track);

      expect(plan.path, p.join(downloadsDir.path, 'Track-1.gpx'));
      expect(plan.contents, '<gpx>track</gpx>');
      expect(service.fileExists(plan), isFalse);

      final writtenPath = await service.writeExport(plan);

      expect(writtenPath, plan.path);
      expect(await File(plan.path).readAsString(), '<gpx>track</gpx>');
      expect(service.fileExists(plan), isTrue);
    });

    test('fallbacks empty track names to track-export', () {
      final downloadsDir = Directory.systemTemp;
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => downloadsDir,
        routeExportsDirectoryResolver: () => downloadsDir,
      );
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: '   ',
        gpxFile: '<gpx />',
      );

      final plan = service.planTrackExport(track);

      expect(plan.path, p.join(downloadsDir.path, 'track-export.gpx'));
    });

    test('builds route GPX with metadata and no elevations by default', () async {
      final routesDir = Directory.systemTemp;
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => routesDir,
        routeExportsDirectoryResolver: () => routesDir,
      );
      final route = app_route.Route(
        name: 'Route 1',
        gpxRoute: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.6, 146.6),
        ],
      );

      final plan = await service.planRouteExport(route);

      expect(plan.path, p.join(routesDir.path, 'Route-1.gpx'));
      expect(
        plan.contents,
        '<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">'
        '<metadata><author><name>Adrian Kladnig</name></author></metadata>'
        '<rte><name>Route-1</name>'
        '<rtept lat="-41.500000" lon="146.500000"></rtept>'
        '<rtept lat="-41.600000" lon="146.600000"></rtept>'
        '</rte></gpx>',
      );
    });

    test('adds correlated peak waypoints before route points', () async {
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => Directory.systemTemp,
        routeExportsDirectoryResolver: () => Directory.systemTemp,
        peakListLoader: () => [
          Peak(
            osmId: 1,
            name: 'Peak One',
            elevation: 1234,
            latitude: -41.5,
            longitude: 146.5,
          ),
        ],
        peakCorrelationThresholdLoader: () async => 100,
      );
      final route = app_route.Route(
        name: 'Route 1',
        gpxRoute: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.6, 146.6),
        ],
      );

      final plan = await service.planRouteExport(route);

      expect(
        plan.contents,
        contains(
          '<metadata><author><name>Adrian Kladnig</name></author></metadata>'
          '<wpt lat="-41.500000" lon="146.500000"><ele>1234</ele><name>Peak One</name></wpt>'
          '<rte><name>Route-1</name>',
        ),
      );
      expect(
        plan.contents.indexOf('<wpt '),
        lessThan(plan.contents.indexOf('<rte>')),
      );
    });

    test('includes route elevations when resolver supplies them', () async {
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => Directory.systemTemp,
        routeExportsDirectoryResolver: () => Directory.systemTemp,
        routePointElevationsResolver: (points) async => [
          for (var index = 0; index < points.length; index++)
            index == 0 ? 123.5 : null,
        ],
      );
      final route = app_route.Route(
        name: 'Route 2',
        gpxRoute: const [LatLng(-41.5, 146.5)],
      );

      final plan = await service.planRouteExport(route);

      expect(
        plan.contents,
        '<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">'
        '<metadata><author><name>Adrian Kladnig</name></author></metadata>'
        '<rte><name>Route-2</name>'
        '<rtept lat="-41.500000" lon="146.500000"><ele>123.5</ele></rtept>'
        '</rte></gpx>',
      );
    });

    test('emits stored route waypoints and suppresses duplicate correlated peaks', () async {
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => Directory.systemTemp,
        routeExportsDirectoryResolver: () => Directory.systemTemp,
        peakListLoader: () => [
          Peak(
            osmId: 1,
            name: 'Peak One',
            elevation: 1234,
            latitude: -41.5,
            longitude: 146.5,
          ),
        ],
        peakCorrelationThresholdLoader: () async => 100,
      );
      final route = app_route.Route(
        name: 'Route 1',
        gpxRoute: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.6, 146.6),
        ],
        routeWaypoints: const [
          RouteWaypoint(
            latitude: -41.5,
            longitude: 146.5,
            label: 'Peak One',
            sequence: 1,
            isPeakDerived: true,
            peakOsmId: 1,
            peakName: 'Peak One',
          ),
          RouteWaypoint(
            latitude: -41.6,
            longitude: 146.6,
            label: 'Waypoint 1',
            sequence: 2,
            isPeakDerived: false,
          ),
        ],
      );

      final plan = await service.planRouteExport(route);

      expect(plan.contents, contains('<wpt lat="-41.500000" lon="146.500000"><ele>1234</ele><name>Peak One</name></wpt>'));
      expect(plan.contents, contains('<wpt lat="-41.600000" lon="146.600000"><name>Waypoint 1</name></wpt>'));
      expect(
        RegExp(r'<wpt lat="-41\.500000" lon="146\.500000">').allMatches(plan.contents),
        hasLength(1),
      );
    });

    test('rejects blank route names and empty route point lists', () async {
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => Directory.systemTemp,
        routeExportsDirectoryResolver: () => Directory.systemTemp,
      );

      await expectLater(
        service.planRouteExport(
          app_route.Route(name: '   ', gpxRoute: const [LatLng(-41.5, 146.5)]),
        ),
        throwsA(isA<GpxExportException>()),
      );
      await expectLater(
        service.planRouteExport(app_route.Route(name: 'Route 3', gpxRoute: const [])),
        throwsA(isA<GpxExportException>()),
      );
    });

    test('uses plan-then-write split for overwrite checks', () async {
      final downloadsDir = await Directory.systemTemp.createTemp('gpx-overwrite');
      addTearDown(() async => downloadsDir.delete(recursive: true));
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => downloadsDir,
        routeExportsDirectoryResolver: () => downloadsDir,
      );
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: 'Overwrite Track',
        gpxFile: '<gpx>one</gpx>',
      );
      final plan = service.planTrackExport(track);

      expect(service.fileExists(plan), isFalse);
      await service.writeExport(plan);
      expect(service.fileExists(plan), isTrue);
      expect(await File(plan.path).readAsString(), '<gpx>one</gpx>');
    });

    test('plans next version path when export already exists', () async {
      final downloadsDir = await Directory.systemTemp.createTemp('gpx-version');
      addTearDown(() async => downloadsDir.delete(recursive: true));
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => downloadsDir,
        routeExportsDirectoryResolver: () => downloadsDir,
      );
      final original = GpxExportPlan(
        path: p.join(downloadsDir.path, 'test.gpx'),
        contents: '<gpx />',
      );

      await File(original.path).writeAsString('base');
      await File(p.join(downloadsDir.path, 'test_1.gpx')).writeAsString('v1');

      final versioned = service.planNewVersionExport(original);

      expect(versioned.path, p.join(downloadsDir.path, 'test_2.gpx'));
      expect(versioned.contents, '<gpx />');
    });
  });
}
