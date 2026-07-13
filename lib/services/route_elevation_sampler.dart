import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:gdal_dart/gdal_dart.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/geo.dart';

const _distance = Distance();

class RouteElevationSummary {
  const RouteElevationSummary({
    required this.requestId,
    required this.geometryVersion,
    this.distance3d = 0,
    this.ascent = 0,
    this.descent = 0,
    this.startElevation = 0,
    this.endElevation = 0,
    this.lowestElevation = 0,
    this.highestElevation = 0,
  });

  const RouteElevationSummary.zero({
    required this.requestId,
    required this.geometryVersion,
  }) : distance3d = 0,
       ascent = 0,
       descent = 0,
       startElevation = 0,
       endElevation = 0,
       lowestElevation = 0,
       highestElevation = 0;

  final int requestId;
  final int geometryVersion;
  final double distance3d;
  final double ascent;
  final double descent;
  final double startElevation;
  final double endElevation;
  final double lowestElevation;
  final double highestElevation;
}

class RouteElevationSamplingException implements Exception {
  const RouteElevationSamplingException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RouteElevationSampler {
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  });

  Future<List<double?>> samplePointElevations(List<LatLng> points);
}

class NoopRouteElevationSampler implements RouteElevationSampler {
  const NoopRouteElevationSampler();

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    return RouteElevationSummary.zero(
      requestId: requestId,
      geometryVersion: geometryVersion,
    );
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.filled(points.length, null, growable: false);
  }
}

abstract interface class DemAssetCache {
  Future<String> localPathForAsset(String assetPath);
}

class BundledDemAssetCache implements DemAssetCache {
  const BundledDemAssetCache();

  @override
  Future<String> localPathForAsset(String assetPath) async {
    final supportDir = await getApplicationSupportDirectory();
    final demDir = Directory(p.join(supportDir.path, 'dem_cache'));
    await demDir.create(recursive: true);

    final file = File(p.join(demDir.path, p.basename(assetPath)));
    if (!await file.exists()) {
      final bytes = await rootBundle.load(assetPath);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }

    return file.path;
  }
}

abstract interface class DemDataset {
  double? sampleElevation(LatLng point);
}

abstract interface class DemDatasetOpener {
  Future<DemDataset> open(String datasetPath);
}

class GdalDemDatasetOpener implements DemDatasetOpener {
  const GdalDemDatasetOpener();

  @override
  Future<DemDataset> open(String datasetPath) async {
    return GdalDemDataset.open(datasetPath);
  }
}

class BundledDemRouteElevationSampler implements RouteElevationSampler {
  BundledDemRouteElevationSampler({
    DemSourceConfig? source,
    DemAssetCache? assetCache,
    DemDatasetOpener? datasetOpener,
    this._sampleSpacingMetres = DemConstants.sampleSpacingMetres,
  }) : _source = source ?? DemConstants.selectedConfig,
       _assetCache = assetCache ?? const BundledDemAssetCache(),
       _datasetOpener = datasetOpener ?? const GdalDemDatasetOpener();

  final DemSourceConfig _source;
  final DemAssetCache _assetCache;
  final DemDatasetOpener _datasetOpener;
  final double _sampleSpacingMetres;

  Future<DemDataset>? _datasetFuture;

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    if (points.length < 2) {
      return RouteElevationSummary.zero(
        requestId: requestId,
        geometryVersion: geometryVersion,
      );
    }

    final dataset = await (_datasetFuture ??= _openDataset());
    final densifiedPoints = _densifyRoute(points);
    final sampledElevations = <double>[];

    for (final point in densifiedPoints) {
      sampledElevations.add(dataset.sampleElevation(point) ?? 0);
    }

    return _buildSummary(
      elevations: sampledElevations,
      sampledPoints: densifiedPoints,
      requestId: requestId,
      geometryVersion: geometryVersion,
    );
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    if (points.isEmpty) {
      return const [];
    }

    final dataset = await (_datasetFuture ??= _openDataset());
    return points
        .map((point) => dataset.sampleElevation(point))
        .toList(growable: false);
  }

  Future<DemDataset> _openDataset() async {
    final datasetPath = await _assetCache.localPathForAsset(_source.assetPath);
    return _datasetOpener.open(datasetPath);
  }

  List<LatLng> _densifyRoute(List<LatLng> points) {
    if (points.length < 2) {
      return List<LatLng>.from(points, growable: false);
    }

    final densified = <LatLng>[points.first];
    for (var index = 1; index < points.length; index++) {
      final start = points[index - 1];
      final end = points[index];
      final segmentDistance = _distance.as(LengthUnit.Meter, start, end);
      final steps = math.max(
        1,
        (segmentDistance / _sampleSpacingMetres).ceil(),
      );

      for (var step = 1; step <= steps; step++) {
        densified.add(_interpolatePoint(start, end, step / steps));
      }
    }

    return densified;
  }

  RouteElevationSummary _buildSummary({
    required List<double> elevations,
    required List<LatLng> sampledPoints,
    required int requestId,
    required int geometryVersion,
  }) {
    if (elevations.isEmpty || sampledPoints.length < 2) {
      return RouteElevationSummary.zero(
        requestId: requestId,
        geometryVersion: geometryVersion,
      );
    }

    final (uphill: ascent, downhill: descent) = calculateUphillDownhill(
      elevations,
    );
    var distance3d = 0.0;
    for (var index = 1; index < sampledPoints.length; index++) {
      final distance2d = _distance.as(
        LengthUnit.Meter,
        sampledPoints[index - 1],
        sampledPoints[index],
      );
      final elevationDelta = elevations[index] - elevations[index - 1];
      distance3d += math.sqrt(
        distance2d * distance2d + elevationDelta * elevationDelta,
      );
    }

    final lowestElevation = elevations.reduce(math.min);
    final highestElevation = elevations.reduce(math.max);

    return RouteElevationSummary(
      requestId: requestId,
      geometryVersion: geometryVersion,
      distance3d: distance3d.roundToDouble(),
      ascent: ascent.roundToDouble(),
      descent: descent.roundToDouble(),
      startElevation: elevations.first.roundToDouble(),
      endElevation: elevations.last.roundToDouble(),
      lowestElevation: lowestElevation.roundToDouble(),
      highestElevation: highestElevation.roundToDouble(),
    );
  }

  LatLng _interpolatePoint(LatLng start, LatLng end, double fraction) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
  }
}

class GdalDemDataset implements DemDataset {
  GdalDemDataset._(
    this._source,
    this._wgs84,
    this._datasetSrs,
    this._toDataset,
    this._band,
    this._geoTransform,
    this._width,
    this._height,
    this._noDataValue,
  );

  factory GdalDemDataset.open(String datasetPath) {
    final gdal = Gdal(libraryPath: _resolveGdalLibraryPath());
    _configureGdalDataPaths(gdal);
    final source = gdal.openGeoTiffSource(datasetPath);
    final wgs84 = gdal.spatialReferenceFromEpsg(4326);
    final datasetSrs = source.dataset.spatialReference;
    final toDataset = gdal.coordinateTransform(wgs84, datasetSrs);

    return GdalDemDataset._(
      source,
      wgs84,
      datasetSrs,
      toDataset,
      source.band(1),
      source.geoTransform,
      source.width,
      source.height,
      source.noDataValue,
    );
  }

  static String? _resolveGdalLibraryPath() {
    final configured = Platform.environment['GDAL_LIBRARY_PATH'];
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    if (!Platform.isMacOS) {
      return null;
    }

    const commonMacOsPaths = <String>[
      '/opt/homebrew/lib/libgdal.dylib',
      '/usr/local/lib/libgdal.dylib',
    ];
    for (final path in commonMacOsPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return null;
  }

  static void _configureGdalDataPaths(Gdal gdal) {
    if (!Platform.isMacOS) {
      return;
    }

    const commonProjPaths = <String>[
      '/opt/homebrew/share/proj',
      '/usr/local/share/proj',
    ];
    const commonGdalDataPaths = <String>[
      '/opt/homebrew/share/gdal',
      '/usr/local/share/gdal',
    ];

    final projPath = _firstExistingDirectory(commonProjPaths);
    if (projPath != null) {
      gdal.setConfigOption('PROJ_DATA', projPath);
      gdal.setConfigOption('PROJ_LIB', projPath);
    }

    final gdalDataPath = _firstExistingDirectory(commonGdalDataPaths);
    if (gdalDataPath != null) {
      gdal.setConfigOption('GDAL_DATA', gdalDataPath);
    }
  }

  static String? _firstExistingDirectory(List<String> paths) {
    for (final path in paths) {
      if (Directory(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  // Keep native resources alive for the dataset lifetime.
  // ignore: unused_field
  final GeoTiffSource _source;
  // ignore: unused_field
  final SpatialReference _wgs84;
  // ignore: unused_field
  final SpatialReference _datasetSrs;
  final CoordinateTransform _toDataset;
  final RasterBand _band;
  final GeoTransform _geoTransform;
  final int _width;
  final int _height;
  final double? _noDataValue;

  @override
  double? sampleElevation(LatLng point) {
    final (x, y) = _toDataset.transformPoint(point.longitude, point.latitude);
    final pixelLocation = _toPixel(x, y);
    final pixelX = pixelLocation.$1.round();
    final pixelY = pixelLocation.$2.round();

    if (pixelX < 0 || pixelX >= _width || pixelY < 0 || pixelY >= _height) {
      return null;
    }

    final sample = _band
        .readAsFloat64(
          window: RasterWindow(
            xOffset: pixelX,
            yOffset: pixelY,
            width: 1,
            height: 1,
          ),
        )
        .first;

    if (_noDataValue != null && sample == _noDataValue) {
      return null;
    }

    return sample;
  }

  (double, double) _toPixel(double x, double y) {
    final determinant =
        _geoTransform.pixelWidth * _geoTransform.pixelHeight -
        _geoTransform.rotationX * _geoTransform.rotationY;
    if (determinant == 0) {
      throw const RouteElevationSamplingException('Invalid DEM transform.');
    }

    final dx = x - _geoTransform.originX;
    final dy = y - _geoTransform.originY;
    final pixel =
        (_geoTransform.pixelHeight * dx - _geoTransform.rotationX * dy) /
        determinant;
    final line =
        (-_geoTransform.rotationY * dx + _geoTransform.pixelWidth * dy) /
        determinant;
    return (pixel, line);
  }
}
