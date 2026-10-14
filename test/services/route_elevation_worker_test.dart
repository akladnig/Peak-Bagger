import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gdal_dart/gdal_dart.dart';
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_runtime_selection.dart';
import '../harness/mapping_runtime_fixture.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_elevation_worker.dart';
import 'package:peak_bagger/services/mapping_session_protection.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import '../harness/route_elevation_fixture.dart';

void main() {
  test(
    'lazy preparation opens once without sampling and shares subsequent requests',
    () async {
      final events = ReceivePort();
      final seen = <Object?>[];
      events.listen(seen.add);
      addTearDown(events.close);
      final sampler = WorkerRouteElevationSampler(
        catalog: elevationMappingCatalog,
        fileSystem: FakeDemFileSystem(),
        datasetOpener: _ReportingOpener(events.sendPort),
      );
      addTearDown(sampler.dispose);
      await sampler.prepareForPoints(elevationRoutePoints);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        equals(['open', '/mapping/$elvisRuntimePath', 'route-elevation']),
      ]);
      expect(await sampler.samplePointElevations(elevationRoutePoints), [
        closeTo(100, 1e-8),
        closeTo(110, 1e-8),
      ]);
      expect(
        seen.where((event) => event is List && event.first == 'open'),
        hasLength(1),
      );
    },
  );

  test(
    'later activation cannot redirect a session worker lazy DEM open',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final first = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(first.close);
      final events = ReceivePort();
      final messages = StreamIterator(events);
      addTearDown(() async {
        await messages.cancel();
        events.close();
      });
      final sampler = WorkerRouteElevationSampler(
        catalog: first.catalog,
        fileSystem: FakeDemFileSystem(),
        datasetOpener: _ReportingOpener(events.sendPort),
      );
      addTearDown(sampler.dispose);
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-14T01:00:00Z',
      );
      final second = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(second.close);
      expect(second.catalog.rootPath, contains(runtimeGenerationB));
      expect(await sampler.samplePointElevations(elevationRoutePoints), [
        closeTo(100, 1e-8),
        closeTo(110, 1e-8),
      ]);
      await messages.moveNext();
      expect(messages.current, [
        'open',
        '${first.catalog.rootPath}/$elvisRuntimePath',
        'route-elevation',
      ]);
    },
  );

  test('dispatch freezes geometry before lazy worker startup awaits', () async {
    final sampler = WorkerRouteElevationSampler(
      catalog: elevationMappingCatalog,
      fileSystem: FakeDemFileSystem(),
      datasetOpener: FakeDemDatasetOpener(_Dataset()),
    );
    addTearDown(sampler.dispose);
    final points = List<LatLng>.of(elevationRoutePoints);
    final sampling = sampler.samplePointElevations(points);
    points.clear();
    expect(await sampling, [closeTo(100, 1e-8), closeTo(110, 1e-8)]);
  });

  test(
    'worker native raster results equal full recomputation across draft changes',
    () async {
      final root = await Directory.systemTemp.createTemp('route-native-worker');
      await Directory('${root.path}/DEM/Elvis').create(recursive: true);
      final path = '${root.path}/$elvisRuntimePath';
      final gdal = Gdal(libraryPath: GdalDemDataset.resolveGdalLibraryPath());
      if (Platform.isMacOS) {
        gdal.setConfigOption('PROJ_DATA', '/opt/homebrew/share/proj');
        gdal.setConfigOption('PROJ_LIB', '/opt/homebrew/share/proj');
      }
      final writer = gdal.createGeoTiff(
        path,
        width: 8,
        height: 4,
        dataType: RasterDataType.float64,
      );
      writer.setProjection(gdal.getOrCreateWKT('EPSG:4326'));
      writer.setGeoTransform(
        GeoTransform.fromList([146.5, 0.001, 0, -41.5, 0, -0.001]),
      );
      writer.writeAsFloat64(
        1,
        Float64List.fromList([
          for (var row = 0; row < 4; row++) ...[
            100,
            130,
            110,
            140,
            90,
            150,
            120,
            100,
          ],
        ]),
      );
      writer.close();
      final fixture = elevationMappingCatalog;
      final catalog = MappingCatalog(
        rootPath: root.path,
        regions: fixture.regions,
        basemaps: fixture.basemaps,
        tasmapCatalogPath: fixture.tasmapCatalogPath,
        naturalFeaturesCatalogPath: fixture.naturalFeaturesCatalogPath,
        demSources: fixture.demSources,
        routingCoverageRegionKeys: fixture.routingCoverageRegionKeys,
      );
      final baseline = RegionAwareRouteElevationSampler(catalog: catalog);
      final worker = WorkerRouteElevationSampler(catalog: catalog);
      addTearDown(() async {
        await worker.dispose();
        await baseline.dispose();
        await root.delete(recursive: true);
      });
      const points = [
        LatLng(-41.5, 146.5),
        LatLng(-41.501, 146.502),
        LatLng(-41.502, 146.504),
      ];
      var version = 0;
      for (final geometry in [
        points.take(2).toList(),
        points,
        points.reversed.toList(),
        points.take(2).toList(),
        points,
      ]) {
        version++;
        expect(
          await worker.samplePointElevations(geometry),
          await baseline.samplePointElevations(geometry),
        );
        final expected = await baseline.sampleRoute(
          points: geometry,
          requestId: version,
          geometryVersion: version,
        );
        final actual = await worker.sampleRoute(
          points: geometry,
          requestId: version,
          geometryVersion: version,
        );
        expect(
          [
            actual.distance3d,
            actual.ascent,
            actual.descent,
            actual.startElevation,
            actual.endElevation,
            actual.lowestElevation,
            actual.highestElevation,
          ],
          [
            expected.distance3d,
            expected.ascent,
            expected.descent,
            expected.startElevation,
            expected.endElevation,
            expected.lowestElevation,
            expected.highestElevation,
          ],
        );
      }
    },
  );

  test(
    'unexpected worker exit fails pending requests and releases generation',
    () async {
      var released = false;
      final protection = MappingSessionProtection(() => released = true);
      final sampler = WorkerRouteElevationSampler(
        catalog: elevationMappingCatalog.withSessionProtection(protection),
        fileSystem: FakeDemFileSystem(),
        datasetOpener: _ExitOpener(),
      );
      await expectLater(
        sampler.samplePointElevations(elevationRoutePoints),
        throwsStateError,
      );
      protection.close();
      await sampler.dispose();
      expect(released, isTrue);
    },
  );

  test(
    'a closed session rejects lazy startup and disposal still completes',
    () async {
      final protection = MappingSessionProtection(() {});
      protection.close();
      final sampler = WorkerRouteElevationSampler(
        catalog: elevationMappingCatalog.withSessionProtection(protection),
        fileSystem: FakeDemFileSystem(),
        datasetOpener: FakeDemDatasetOpener(_Dataset()),
      );
      await expectLater(
        sampler.samplePointElevations(elevationRoutePoints),
        throwsStateError,
      );
      await sampler.dispose().timeout(const Duration(seconds: 1));
    },
  );

  test(
    'worker source failure retains local context and retry opens the same dataset',
    () async {
      final events = ReceivePort();
      final messages = StreamIterator(events);
      addTearDown(() async {
        await messages.cancel();
        events.close();
      });
      final sampler = WorkerRouteElevationSampler(
        catalog: elevationMappingCatalog,
        fileSystem: FakeDemFileSystem(),
        datasetOpener: _FailOnceOpener(events.sendPort),
      );
      addTearDown(sampler.dispose);
      await expectLater(
        sampler.samplePointElevations(elevationRoutePoints),
        throwsA(
          isA<MappingStoreOperationException>().having(
            (error) => error.paths,
            'paths',
            [elvisRuntimePath],
          ),
        ),
      );
      expect(await sampler.samplePointElevations(elevationRoutePoints), [
        closeTo(100, 1e-8),
        closeTo(110, 1e-8),
      ]);
      await messages.moveNext();
      expect(messages.current, '/mapping/$elvisRuntimePath');
      await messages.moveNext();
      expect(messages.current, '/mapping/$elvisRuntimePath');
    },
  );

  test(
    'disposal drains pending native work before releasing its generation',
    () async {
      final events = ReceivePort();
      final messages = StreamIterator(events);
      addTearDown(() async {
        await messages.cancel();
        events.close();
      });
      var released = false;
      final protection = MappingSessionProtection(() => released = true);
      final sampler = WorkerRouteElevationSampler(
        catalog: elevationMappingCatalog.withSessionProtection(protection),
        fileSystem: FakeDemFileSystem(),
        datasetOpener: _ControlledOpener(events.sendPort),
      );
      final result = sampler.samplePointElevations(elevationRoutePoints);
      await messages.moveNext();
      final continueOpen = messages.current as SendPort;
      protection.close();
      expect(released, isFalse);
      final closing = sampler.dispose();
      await expectLater(
        sampler.samplePointElevations(elevationRoutePoints),
        throwsStateError,
      );
      continueOpen.send(null);
      await result;
      await closing;
      expect(released, isTrue);
      await messages.moveNext();
      expect(messages.current, 'closed');
      await sampler.dispose();
    },
  );

  test(
    'native opening and exact summary sampling execute off the caller isolate',
    () async {
      final events = ReceivePort();
      addTearDown(events.close);
      final seen = <Object?>[];
      events.listen(seen.add);
      final sampler = WorkerRouteElevationSampler(
        catalog: elevationMappingCatalog,
        fileSystem: FakeDemFileSystem(),
        datasetOpener: _ReportingOpener(events.sendPort),
      );
      addTearDown(sampler.dispose);
      final elevations = await sampler.samplePointElevations(
        elevationRoutePoints,
      );
      final summary = await sampler.sampleRoute(
        points: elevationRoutePoints,
        requestId: 2,
        geometryVersion: 7,
      );
      await Future<void>.delayed(Duration.zero);
      expect(elevations, [closeTo(100, 1e-8), closeTo(110, 1e-8)]);
      expect(summary.requestId, 2);
      expect(summary.geometryVersion, 7);
      expect(summary.startElevation, 100);
      expect(summary.endElevation, 110);
      expect(summary.ascent, 10);
      expect(summary.descent, 0);
      expect(
        seen,
        contains(
          equals(['open', '/mapping/$elvisRuntimePath', 'route-elevation']),
        ),
      );
      expect(
        seen.where((event) => event is List && event.first == 'open'),
        hasLength(1),
      );
    },
  );
}

class _ExitOpener implements DemDatasetOpener {
  @override
  Future<DemDataset> open(String path) async => Isolate.exit();
}

class _FailOnceOpener implements DemDatasetOpener {
  _FailOnceOpener(this.events);
  final SendPort events;
  bool failed = false;
  @override
  Future<DemDataset> open(String path) async {
    events.send(path);
    if (!failed) {
      failed = true;
      throw const FormatException('Invalid test raster');
    }
    return _Dataset();
  }
}

class _ControlledOpener implements DemDatasetOpener {
  _ControlledOpener(this.events);
  final SendPort events;
  @override
  Future<DemDataset> open(String path) async {
    final resume = ReceivePort();
    events.send(resume.sendPort);
    await resume.first;
    resume.close();
    return _ClosingDataset(events);
  }
}

class _ClosingDataset extends _Dataset {
  _ClosingDataset(this.events);
  final SendPort events;
  @override
  void close() => events.send('closed');
}

class _ReportingOpener implements DemDatasetOpener {
  _ReportingOpener(this.events);
  final SendPort events;
  @override
  Future<DemDataset> open(String path) async {
    events.send(['open', path, Isolate.current.debugName]);
    return _Dataset();
  }
}

class _Dataset implements DisposableDemDataset {
  @override
  double? sampleElevation(LatLng point) =>
      100 + (point.longitude - 146.5) * 10000;
  @override
  void close() {}
}
