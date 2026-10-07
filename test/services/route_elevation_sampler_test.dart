import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';

import '../harness/route_elevation_fixture.dart';

void main() {
  test('resolver selects only the catalog ELVIS reference for Tasmania', () {
    final resolver = RouteElevationDemResolver(
      catalog: elevationMappingCatalog,
    );
    final resolution = resolver.resolveForPoints(elevationRoutePoints);
    expect(resolution.kind, RouteElevationDemKind.tasmaniaElvisRuntime);
    expect(resolution.sourceKey, 'elvisRuntime');
    expect(resolution.relativePath, elvisRuntimePath);
    for (final points in <List<LatLng>>[
      [],
      const [LatLng(-33.86, 151.2), LatLng(-33.87, 151.21)],
      const [LatLng(-41.5, 146.5), LatLng(-33.86, 151.2)],
    ]) {
      final resolution = resolver.resolveForPoints(points);
      expect(resolution.kind, RouteElevationDemKind.none);
      expect(resolution.relativePath, isNull);
      expect(resolution.sourceKey, isNull);
    }
  });

  test('DEM keys canonicalize geometry independently of request IDs', () {
    final resolution = RouteElevationDemResolver(
      catalog: elevationMappingCatalog,
    ).resolveForPoints(elevationRoutePoints);
    final key = resolution.operationKey(
      points: elevationRoutePoints,
      geometryVersion: 7,
    );
    expect(key.kind, MappingStoreOperationKind.demRead);
    expect(key.parameters, {
      'demSourceKey': 'elvisRuntime',
      'routeGeometryIdentity': '[[-41.5,146.5],[-41.501,146.501]]',
      'geometryVersion': '7',
    });
    expect(
      key,
      resolution.operationKey(
        points: List.of(elevationRoutePoints),
        geometryVersion: 7,
      ),
    );
    expect(
      key,
      isNot(
        resolution.operationKey(
          points: elevationRoutePoints,
          geometryVersion: 8,
        ),
      ),
    );
    expect(
      key,
      isNot(
        resolution.operationKey(
          points: elevationRoutePoints.reversed.toList(),
          geometryVersion: 7,
        ),
      ),
    );
    expect(
      resolution.operationKey(
        points: const [LatLng(-0.0, 0)],
        geometryVersion: 7,
      ),
      resolution.operationKey(
        points: const [LatLng(0, -0.0)],
        geometryVersion: 7,
      ),
    );
  });

  test('known polyline summary uses densified DEM samples', () async {
    final opener = FakeDemDatasetOpener(
      LookupDemDataset((point) {
        final sampleIndex = (point.longitude * 1000).round();
        return switch (sampleIndex) {
          0 => 10,
          1 => 50,
          2 => 20,
          _ => 60,
        };
      }),
    );
    final sampler = _sampler(
      opener,
      regionKeyForPoint: (_) => 'tasmania',
      spacing: 100,
    );
    final summary = await sampler.sampleRoute(
      points: const [LatLng(0, 0), LatLng(0, 0.003)],
      requestId: 3,
      geometryVersion: 7,
    );
    expect(summary.requestId, 3);
    expect(summary.geometryVersion, 7);
    expect(summary.ascent, 50);
    expect(summary.descent, 0);
    expect(summary.startElevation, 10);
    expect(summary.endElevation, 60);
    expect(summary.lowestElevation, 10);
    expect(summary.highestElevation, 60);
    expect(summary.distance3d, greaterThan(0));
    expect(opener.openedPaths, ['/mapping/$elvisRuntimePath']);
  });

  test('short route returns zero without opening a DEM', () async {
    final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100));
    final summary = await _sampler(opener).sampleRoute(
      points: [elevationRoutePoints.first],
      requestId: 1,
      geometryVersion: 1,
    );
    expect(summary.ascent, 0);
    expect(summary.descent, 0);
    expect(summary.distance3d, 0);
    expect(opener.openedPaths, isEmpty);
  });

  test(
    'nodata sample retains existing zero-elevation summary behavior',
    () async {
      final sampler = _sampler(
        FakeDemDatasetOpener(
          LookupDemDataset((point) => point.longitude == 0 ? null : 20),
        ),
        regionKeyForPoint: (_) => 'tasmania',
        spacing: 1000,
      );
      final summary = await sampler.sampleRoute(
        points: const [LatLng(0, 0), LatLng(0, 0.001)],
        requestId: 1,
        geometryVersion: 1,
      );
      expect(summary.startElevation, 0);
      expect(summary.endElevation, 20);
      expect(summary.ascent, 20);
      expect(summary.distance3d, greaterThan(0));
    },
  );

  test(
    'cached dataset is revalidated and cannot mask a changed symlink',
    () async {
      final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100));
      final fs = FakeDemFileSystem();
      final sampler = _sampler(opener, fileSystem: fs);
      expect(await sampler.samplePointElevations(elevationRoutePoints), [
        100,
        100,
      ]);
      await sampler.sampleRoute(
        points: elevationRoutePoints,
        requestId: 2,
        geometryVersion: 2,
      );
      expect(opener.openedPaths, hasLength(1));
      expect(fs.checkedPaths, hasLength(2));
      fs.failure = FakeDemAccessFailure.outsideRoot;
      await expectLater(
        sampler.samplePointElevations(elevationRoutePoints),
        throwsA(_mappingFailure),
      );
      expect(opener.openedPaths, hasLength(1));
      fs.failure = null;
      expect(await sampler.samplePointElevations(elevationRoutePoints), [
        100,
        100,
      ]);
      expect(opener.openedPaths, hasLength(2));
    },
  );

  for (final failure in FakeDemAccessFailure.values) {
    test(
      '$failure ELVIS fails as Mapping without opening another DEM',
      () async {
        final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100));
        final fs = FakeDemFileSystem()..failure = failure;
        final sampler = _sampler(opener, fileSystem: fs);
        await expectLater(
          sampler.sampleRoute(
            points: elevationRoutePoints,
            requestId: 1,
            geometryVersion: 7,
          ),
          throwsA(_mappingFailure),
        );
        expect(opener.openedPaths, isEmpty);
        fs.failure = null;
        expect(await sampler.samplePointElevations(elevationRoutePoints), [
          100,
          100,
        ]);
        expect(opener.openedPaths, ['/mapping/$elvisRuntimePath']);
      },
    );
  }

  test(
    'malformed open fails with source context and is not cached on retry',
    () async {
      final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100))
        ..error = const FormatException('Malformed GeoTIFF');
      final sampler = _sampler(opener);
      await expectLater(
        sampler.samplePointElevations(elevationRoutePoints),
        throwsA(_mappingFailure),
      );
      opener.error = null;
      expect(await sampler.samplePointElevations(elevationRoutePoints), [
        100,
        100,
      ]);
      expect(opener.openedPaths, [
        '/mapping/$elvisRuntimePath',
        '/mapping/$elvisRuntimePath',
      ]);
    },
  );

  for (final invalidSample in <Object>[
    const FormatException('Invalid transform'),
    double.nan,
    double.infinity,
  ]) {
    test(
      'invalid raster sample $invalidSample fails the complete operation',
      () async {
        final sampler = _sampler(
          FakeDemDatasetOpener(
            LookupDemDataset((point) {
              if (point == elevationRoutePoints.first) return 100;
              if (invalidSample is double) return invalidSample;
              throw invalidSample;
            }),
          ),
        );
        await expectLater(
          sampler.samplePointElevations(elevationRoutePoints),
          throwsA(_mappingFailure),
        );
        await expectLater(
          sampler.sampleRoute(
            points: elevationRoutePoints,
            requestId: 1,
            geometryVersion: 7,
          ),
          throwsA(_mappingFailure),
        );
      },
    );
  }

  test('mixed-region and outside routes never open any runtime DEM', () async {
    final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100));
    final sampler = _sampler(opener);
    const points = [LatLng(-41.5, 146.5), LatLng(-33.86, 151.2)];
    expect(await sampler.samplePointElevations(points), [null, null]);
    await expectLater(
      sampler.sampleRoute(points: points, requestId: 1, geometryVersion: 1),
      throwsA(
        isA<RouteElevationSamplingException>().having(
          (error) => error.kind,
          'kind',
          RouteElevationSamplingErrorKind.regionUnavailable,
        ),
      ),
    );
    expect(opener.openedPaths, isEmpty);
  });

  for (final libraryFailure in <Object>[
    StateError('Host library missing'),
    ArgumentError('Incompatible GDAL symbols'),
  ]) {
    test(
      '$libraryFailure is lazy and retains the exact device exception',
      () async {
        var resolutions = 0;
        var loads = 0;
        final sampler = RegionAwareRouteElevationSampler(
          catalog: elevationMappingCatalog,
          fileSystem: FakeDemFileSystem(),
          datasetOpener: GdalDemDatasetOpener(
            libraryPathResolver: () {
              resolutions++;
              return '/host/libgdal.dylib';
            },
            libraryLoader: (path) {
              loads++;
              expect(path, '/host/libgdal.dylib');
              throw libraryFailure;
            },
          ),
        );
        expect(resolutions, 0);
        expect(loads, 0);
        await sampler.samplePointElevations(const [LatLng(-33.86, 151.2)]);
        expect(resolutions, 0);
        for (var request = 0; request < 2; request++) {
          await expectLater(
            sampler.sampleRoute(
              points: elevationRoutePoints,
              requestId: request,
              geometryVersion: 7,
            ),
            throwsA(
              isA<RouteElevationSamplingException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    RouteElevationSamplingErrorKind.tasmaniaDataUnavailable,
                  )
                  .having(
                    (error) => error.message,
                    'message',
                    RouteElevationMessages.tasmaniaDataUnavailable,
                  ),
            ),
          );
        }
        expect(resolutions, 2);
        expect(loads, 2);
      },
    );
  }
}

final _mappingFailure = isA<MappingStoreOperationException>().having(
  (error) => error.paths,
  'paths',
  [elvisRuntimePath],
);

RegionAwareRouteElevationSampler _sampler(
  DemDatasetOpener opener, {
  FakeDemFileSystem? fileSystem,
  RegionKeyForPointResolver? regionKeyForPoint,
  double spacing = 25,
}) => RegionAwareRouteElevationSampler(
  catalog: elevationMappingCatalog,
  demResolver: RouteElevationDemResolver(
    catalog: elevationMappingCatalog,
    regionKeyForPoint: regionKeyForPoint,
  ),
  datasetOpener: opener,
  fileSystem: fileSystem ?? FakeDemFileSystem(),
  sampleSpacingMetres: spacing,
);
