import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
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

    test('builds route GPX with metadata and no elevations by default', () {
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

      final plan = service.planRouteExport(route);

      expect(plan.path, p.join(routesDir.path, 'Route-1.gpx'));
      expect(
        plan.contents,
        '<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">'
        '<metadata><author><name>Adrian Kladnig</name></author></metadata>'
        '<rte><name>Route-1</name>'
        '<rtept lat="-41.50000000" lon="146.50000000"></rtept>'
        '<rtept lat="-41.60000000" lon="146.60000000"></rtept>'
        '</rte></gpx>',
      );
    });

    test('includes route elevations when resolver supplies them', () {
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => Directory.systemTemp,
        routeExportsDirectoryResolver: () => Directory.systemTemp,
        routePointElevationResolver: (_, index) => index == 0 ? 123.5 : null,
      );
      final route = app_route.Route(
        name: 'Route 2',
        gpxRoute: const [LatLng(-41.5, 146.5)],
      );

      final plan = service.planRouteExport(route);

      expect(
        plan.contents,
        '<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">'
        '<metadata><author><name>Adrian Kladnig</name></author></metadata>'
        '<rte><name>Route-2</name>'
        '<rtept lat="-41.50000000" lon="146.50000000"><ele>123.5</ele></rtept>'
        '</rte></gpx>',
      );
    });

    test('rejects blank route names and empty route point lists', () {
      final service = GpxExportService(
        trackDownloadsDirectoryResolver: () => Directory.systemTemp,
        routeExportsDirectoryResolver: () => Directory.systemTemp,
      );

      expect(
        () => service.planRouteExport(app_route.Route(name: '   ', gpxRoute: const [LatLng(-41.5, 146.5)])),
        throwsA(isA<GpxExportException>()),
      );
      expect(
        () => service.planRouteExport(app_route.Route(name: 'Route 3', gpxRoute: const [])),
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
  });
}
