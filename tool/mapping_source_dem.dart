import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:math' as math;
import 'package:gdal_dart/gdal_dart.dart';

Future<Map<String, Object?>> validateSourceDem(
  String path, {
  Gdal? gdal,
}) async {
  final handle = await File(path).open();
  try {
    final header = await handle.read(4);
    final magic = header.join(',');
    if (!const {
      '73,73,42,0',
      '77,77,0,42',
      '73,73,43,0',
      '77,77,0,43',
    }.contains(magic)) {
      throw FormatException('Required DEM is not a TIFF/BigTIFF: $path');
    }
  } finally {
    await handle.close();
  }
  final libraryPath =
      Platform.environment['GDAL_LIBRARY_PATH'] ??
      (Platform.isMacOS && File('/opt/homebrew/lib/libgdal.dylib').existsSync()
          ? '/opt/homebrew/lib/libgdal.dylib'
          : Platform.isMacOS
          ? 'libgdal.dylib'
          : 'libgdal.so');
  final native = gdal ?? Gdal(libraryPath: libraryPath);
  if (gdal == null && Platform.isMacOS) {
    for (final root in [
      if (Platform.environment['PROJ_DATA'] case final String data) data,
      '/opt/homebrew/share/proj',
      '/usr/local/share/proj',
    ]) {
      if (Directory(root).existsSync()) {
        native.setConfigOption('PROJ_DATA', root);
        native.setConfigOption('PROJ_LIB', root);
        break;
      }
    }
  }
  native.setConfigOption('GDAL_PAM_ENABLED', 'NO');
  native.setConfigOption('GDAL_DISABLE_READDIR_ON_OPEN', 'EMPTY_DIR');
  final dataset = native.openGeoTiff(path);
  SpatialReference? sourceSrs;
  SpatialReference? wgs84;
  CoordinateTransform? transform;
  try {
    final library = DynamicLibrary.open(libraryPath);
    final driver = library
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>)
        >('GDALGetDatasetDriver')(dataset.nativeHandle);
    final driverName = library
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Void>),
          Pointer<Utf8> Function(Pointer<Void>)
        >('GDALGetDriverShortName')(driver)
        .toDartString();
    if (driverName != 'GTiff') {
      throw FormatException('DEM must use GDAL GTiff/BigTIFF: $path');
    }
    if (dataset.width <= 0 || dataset.height <= 0 || dataset.bandCount < 1) {
      throw FormatException('Invalid DEM dimensions/band: $path');
    }
    final geo = dataset.geoTransform;
    final determinant =
        geo.pixelWidth * geo.pixelHeight - geo.rotationX * geo.rotationY;
    if (geo.toList().any((n) => !n.isFinite) ||
        !determinant.isFinite ||
        determinant == 0) {
      throw FormatException('Invalid DEM geotransform: $path');
    }
    sourceSrs = dataset.spatialReference;
    wgs84 = native.spatialReferenceFromEpsg(4326);
    transform = native.coordinateTransform(sourceSrs, wgs84);
    for (final corner in [
      (0, 0),
      (dataset.width, 0),
      (0, dataset.height),
      (dataset.width, dataset.height),
    ]) {
      final (lon, lat) = transform.transformPoint(
        geo.originX + corner.$1 * geo.pixelWidth + corner.$2 * geo.rotationX,
        geo.originY + corner.$1 * geo.rotationY + corner.$2 * geo.pixelHeight,
      );
      if (!lon.isFinite ||
          !lat.isFinite ||
          lat < -90 ||
          lat > 90 ||
          lon < -180 ||
          lon > 180) {
        throw FormatException('Unusable DEM WGS84 transform: $path');
      }
    }
    final band = dataset.band(1);
    if (band.dataType == RasterDataType.unknown ||
        band.blockWidth <= 0 ||
        band.blockHeight <= 0) {
      throw FormatException(
        'Unsupported numeric DEM band/block dimensions: $path',
      );
    }
    final noData = band.noDataValue;
    var blocks = 0;
    final progress = Stopwatch()..start();
    for (var y = 0; y < dataset.height; y += band.blockHeight) {
      for (var x = 0; x < dataset.width; x += band.blockWidth) {
        final samples = band.readAsFloat64(
          window: RasterWindow(
            xOffset: x,
            yOffset: y,
            width: math.min(band.blockWidth, dataset.width - x),
            height: math.min(band.blockHeight, dataset.height - y),
          ),
        );
        if (samples.any(
          (n) =>
              !n.isFinite &&
              !(noData != null && (n == noData || n.isNaN && noData.isNaN)),
        )) {
          throw FormatException(
            'Nonfinite non-NoData DEM sample: $path block $x,$y',
          );
        }
        blocks++;
        if (progress.elapsed >= const Duration(seconds: 5)) {
          stderr.writeln(
            'DEM validation progress: $path band=1 blocks=$blocks',
          );
          progress.reset();
        }
      }
    }
    return {
      'driver': driverName,
      'width': dataset.width,
      'height': dataset.height,
      'crs': dataset.projectionWkt,
      'noData': noData?.isFinite == false ? noData.toString() : noData,
      'blockCount': blocks,
    };
  } on Object catch (error) {
    throw FormatException('$path: $error');
  } finally {
    transform?.close();
    wgs84?.close();
    sourceSrs?.close();
    dataset.close();
  }
}
