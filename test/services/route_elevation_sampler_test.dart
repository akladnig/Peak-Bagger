import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';

void main() {
  test('known polyline summary uses densified DEM samples', () async {
    final sampler = BundledDemRouteElevationSampler(
      source: DemConstants.selectedConfig,
      assetCache: _FakeDemAssetCache('/tmp/thelist.tif'),
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
    final sampler = BundledDemRouteElevationSampler(
      assetCache: _FakeDemAssetCache('/tmp/thelist.tif'),
      datasetOpener: _FakeDemDatasetOpener(_LookupDemDataset((_) => 100)),
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
    final sampler = BundledDemRouteElevationSampler(
      assetCache: _FakeDemAssetCache('/tmp/thelist.tif'),
      datasetOpener: _FakeDemDatasetOpener(
        _LookupDemDataset((point) => point.longitude == 0 ? null : 20),
      ),
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
    final assetCache = _FakeDemAssetCache('/tmp/thelist.tif');
    final datasetOpener = _FakeDemDatasetOpener(_LookupDemDataset((_) => 100));
    final sampler = BundledDemRouteElevationSampler(
      assetCache: assetCache,
      datasetOpener: datasetOpener,
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

    expect(assetCache.calls, 1);
    expect(datasetOpener.calls, 1);
  });
}

class _FakeDemAssetCache implements DemAssetCache {
  _FakeDemAssetCache(this.path);

  final String path;
  int calls = 0;

  @override
  Future<String> localPathForAsset(String assetPath) async {
    calls += 1;
    return path;
  }
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
