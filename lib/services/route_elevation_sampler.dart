import 'dart:io';
import 'dart:math' as math;

import 'package:gdal_dart/gdal_dart.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

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
  const RouteElevationSamplingException(
    this.message, {
    this.kind = RouteElevationSamplingErrorKind.generic,
  });

  const RouteElevationSamplingException.regionUnavailable()
    : this(
        RouteElevationMessages.regionUnavailable,
        kind: RouteElevationSamplingErrorKind.regionUnavailable,
      );

  const RouteElevationSamplingException.tasmaniaDataUnavailable()
    : this(
        RouteElevationMessages.tasmaniaDataUnavailable,
        kind: RouteElevationSamplingErrorKind.tasmaniaDataUnavailable,
      );

  final String message;
  final RouteElevationSamplingErrorKind kind;

  @override
  String toString() => message;
}

enum RouteElevationSamplingErrorKind {
  generic,
  regionUnavailable,
  tasmaniaDataUnavailable,
}

abstract final class RouteElevationMessages {
  static const regionUnavailable = 'Elevation unavailable for this region';
  static const tasmaniaDataUnavailable =
      'Tasmania elevation data is unavailable on this device';
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

enum RouteElevationDemKind { none, tasmaniaElvisRuntime }

class RouteElevationDemResolution {
  const RouteElevationDemResolution.none()
    : kind = RouteElevationDemKind.none,
      datasetPath = null;

  const RouteElevationDemResolution.tasmaniaElvisRuntime(this.datasetPath)
    : kind = RouteElevationDemKind.tasmaniaElvisRuntime;

  final RouteElevationDemKind kind;
  final String? datasetPath;
}

typedef RegionKeyForPointResolver = String? Function(LatLng point);
typedef TasmaniaDemRootResolver = String Function();

class RouteElevationDemResolver {
  RouteElevationDemResolver({
    RegionKeyForPointResolver? regionKeyForPoint,
    TasmaniaDemRootResolver? tasmaniaDemRootResolver,
  }) : _regionKeyForPoint =
           regionKeyForPoint ?? regionManifestCatalog.regionKeyForPoint,
       _tasmaniaDemRootResolver =
           tasmaniaDemRootResolver ?? resolveTasmaniaDemRoot;

  final RegionKeyForPointResolver _regionKeyForPoint;
  final TasmaniaDemRootResolver _tasmaniaDemRootResolver;

  RouteElevationDemResolution resolveForPoints(List<LatLng> points) {
    final allPointsInTasmania =
        points.isNotEmpty &&
        points.every(
          (point) =>
              _regionKeyForPoint(point) == DemConstants.tasmaniaRegionKey,
        );
    if (!allPointsInTasmania) {
      return const RouteElevationDemResolution.none();
    }

    try {
      final tasmaniaDemRoot = _tasmaniaDemRootResolver();
      return RouteElevationDemResolution.tasmaniaElvisRuntime(
        p.join(tasmaniaDemRoot, DemConstants.tasmaniaElvisRuntimeDemFileName),
      );
    } catch (_) {
      throw const RouteElevationSamplingException.tasmaniaDataUnavailable();
    }
  }
}

class RegionAwareRouteElevationSampler implements RouteElevationSampler {
  RegionAwareRouteElevationSampler({
    RouteElevationDemResolver? demResolver,
    DemDatasetOpener? datasetOpener,
    bool Function(String path)? fileExists,
    this._sampleSpacingMetres = DemConstants.sampleSpacingMetres,
  }) : _demResolver = demResolver ?? RouteElevationDemResolver(),
       _datasetOpener = datasetOpener ?? const GdalDemDatasetOpener(),
       _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final RouteElevationDemResolver _demResolver;
  final DemDatasetOpener _datasetOpener;
  final bool Function(String path) _fileExists;
  final double _sampleSpacingMetres;

  final Map<String, Future<DemDataset>> _datasetFutures = {};

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

    final resolution = _demResolver.resolveForPoints(points);
    if (resolution.kind == RouteElevationDemKind.none) {
      throw const RouteElevationSamplingException.regionUnavailable();
    }

    final dataset = await _openDataset(resolution);
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

    final resolution = _demResolver.resolveForPoints(points);
    if (resolution.kind == RouteElevationDemKind.none) {
      return List<double?>.filled(points.length, null, growable: false);
    }

    final dataset = await _openDataset(resolution);
    return points
        .map((point) => dataset.sampleElevation(point))
        .toList(growable: false);
  }

  Future<DemDataset> _openDataset(RouteElevationDemResolution resolution) {
    final datasetPath = resolution.datasetPath;
    if (datasetPath == null || !_fileExists(datasetPath)) {
      throw const RouteElevationSamplingException.tasmaniaDataUnavailable();
    }

    return _datasetFutures.putIfAbsent(datasetPath, () async {
      try {
        return await _datasetOpener.open(datasetPath);
      } on RouteElevationSamplingException {
        rethrow;
      } catch (_) {
        _datasetFutures.remove(datasetPath);
        throw const RouteElevationSamplingException.tasmaniaDataUnavailable();
      }
    });
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
