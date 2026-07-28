import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';

void main() {
  test('region resolver uses fixed ELVIS runtime path for Tasmania routes', () {
    final resolver = RouteElevationDemResolver(
      tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
    );

    final resolution = resolver.resolveForPoints(const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
    ]);

    expect(resolution.kind, RouteElevationDemKind.tasmaniaElvisRuntime);
    expect(resolution.datasetPath, '/tmp/tasmania-dem/elvis_runtime_10m.tif');
  });

  test(
    'region resolver returns none when any route point is outside Tasmania',
    () {
      final resolver = RouteElevationDemResolver(
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      );

      final resolution = resolver.resolveForPoints(const [
        LatLng(-41.5, 146.5),
        LatLng(-33.865143, 151.2099),
      ]);

      expect(resolution.kind, RouteElevationDemKind.none);
      expect(resolution.datasetPath, isNull);
    },
  );

  test('known polyline summary uses densified DEM samples', () async {
    final sampler = RegionAwareRouteElevationSampler(
      demResolver: RouteElevationDemResolver(
        regionKeyForPoint: (_) => 'tasmania',
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      ),
      datasetOpener: _FakeDemDatasetOpener(
        _LookupDemDataset((point) {
          final sampleIndex = (point.longitude * 1000).round();
          return switch (sampleIndex) {
            0 => 10,
            1 => 50,
            2 => 20,
            3 => 60,
            _ => 60,
          };
        }),
      ),
      fileExists: (_) => true,
      sampleSpacingMetres: 100,
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
  });

  test('short route returns zero summary', () async {
    final sampler = RegionAwareRouteElevationSampler(
      demResolver: RouteElevationDemResolver(
        regionKeyForPoint: (_) => 'tasmania',
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      ),
      datasetOpener: _FakeDemDatasetOpener(_LookupDemDataset((_) => 100)),
      fileExists: (_) => true,
    );

    final summary = await sampler.sampleRoute(
      points: const [LatLng(-41.5, 146.5)],
      requestId: 1,
      geometryVersion: 1,
    );

    expect(summary.ascent, 0);
    expect(summary.descent, 0);
    expect(summary.distance3d, 0);
  });

  test('missing DEM sample falls back to zero elevation', () async {
    final sampler = RegionAwareRouteElevationSampler(
      demResolver: RouteElevationDemResolver(
        regionKeyForPoint: (_) => 'tasmania',
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      ),
      datasetOpener: _FakeDemDatasetOpener(
        _LookupDemDataset((point) => point.longitude == 0 ? null : 20),
      ),
      fileExists: (_) => true,
      sampleSpacingMetres: 1000,
    );

    final summary = await sampler.sampleRoute(
      points: const [LatLng(0, 0), LatLng(0, 0.001)],
      requestId: 1,
      geometryVersion: 1,
    );

    expect(summary.ascent, 20);
    expect(summary.descent, 0);
    expect(summary.startElevation, 0);
    expect(summary.endElevation, 20);
    expect(summary.lowestElevation, 0);
    expect(summary.highestElevation, 20);
    expect(summary.distance3d, greaterThan(0));
  });

  test('dataset bootstrap is cached across requests', () async {
    final datasetOpener = _FakeDemDatasetOpener(_LookupDemDataset((_) => 100));
    final sampler = RegionAwareRouteElevationSampler(
      demResolver: RouteElevationDemResolver(
        regionKeyForPoint: (_) => 'tasmania',
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      ),
      datasetOpener: datasetOpener,
      fileExists: (_) => true,
    );

    await sampler.sampleRoute(
      points: const [LatLng(0, 0), LatLng(0, 0.001)],
      requestId: 1,
      geometryVersion: 1,
    );
    await sampler.sampleRoute(
      points: const [LatLng(0, 0), LatLng(0, 0.002)],
      requestId: 2,
      geometryVersion: 2,
    );

    expect(datasetOpener.calls, 1);
  });

  test(
    'non-Tasmania point sampling short-circuits without opening a dataset',
    () async {
      final datasetOpener = _FakeDemDatasetOpener(
        _LookupDemDataset((_) => 100),
      );
      final sampler = RegionAwareRouteElevationSampler(
        demResolver: RouteElevationDemResolver(
          regionKeyForPoint: (_) => null,
          tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
        ),
        datasetOpener: datasetOpener,
        fileExists: (_) => true,
      );

      final elevations = await sampler.samplePointElevations(const [
        LatLng(-33.865143, 151.2099),
        LatLng(-33.87, 151.21),
      ]);

      expect(elevations, [null, null]);
      expect(datasetOpener.calls, 0);
    },
  );

  test('non-Tasmania route summary reports region unavailable', () async {
    final sampler = RegionAwareRouteElevationSampler(
      demResolver: RouteElevationDemResolver(
        regionKeyForPoint: (_) => null,
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      ),
      fileExists: (_) => true,
    );

    await expectLater(
      () => sampler.sampleRoute(
        points: const [LatLng(-33.865143, 151.2099), LatLng(-33.87, 151.21)],
        requestId: 1,
        geometryVersion: 1,
      ),
      throwsA(
        isA<RouteElevationSamplingException>().having(
          (error) => error.message,
          'message',
          RouteElevationMessages.regionUnavailable,
        ),
      ),
    );
  });

  test('missing Tasmania runtime DEM reports the exact device error', () async {
    final sampler = RegionAwareRouteElevationSampler(
      demResolver: RouteElevationDemResolver(
        regionKeyForPoint: (_) => 'tasmania',
        tasmaniaDemRootResolver: () => '/tmp/tasmania-dem',
      ),
      fileExists: (_) => false,
    );

    await expectLater(
      () => sampler.sampleRoute(
        points: const [LatLng(-41.5, 146.5), LatLng(-41.55, 146.55)],
        requestId: 1,
        geometryVersion: 1,
      ),
      throwsA(
        isA<RouteElevationSamplingException>().having(
          (error) => error.message,
          'message',
          RouteElevationMessages.tasmaniaDataUnavailable,
        ),
      ),
    );
  });
}

class _FakeDemDatasetOpener implements DemDatasetOpener {
  _FakeDemDatasetOpener(this.dataset);

  final DemDataset dataset;
  int calls = 0;

  @override
  Future<DemDataset> open(String datasetPath) async {
    calls += 1;
    return dataset;
  }
}

class _LookupDemDataset implements DemDataset {
  _LookupDemDataset(this.lookup);

  final double? Function(LatLng point) lookup;

  @override
  double? sampleElevation(LatLng point) => lookup(point);
}
