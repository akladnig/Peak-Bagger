import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

class GpxStorageDestination {
  const GpxStorageDestination({required this.country, this.region});

  final String country;
  final String? region;

  String get relativeFolder => region == null ? country : '$country/$region';

  String trackFolderPath({String? bushwalkingRoot}) {
    final tracksRoot = resolveBushwalkingTracksPath(
      bushwalkingRoot: bushwalkingRoot,
    );
    return region == null
        ? p.join(tracksRoot, country)
        : p.join(tracksRoot, country, region!);
  }

  String routeFolderPath({String? bushwalkingRoot}) {
    final routesRoot = resolveBushwalkingRoutesPath(
      bushwalkingRoot: bushwalkingRoot,
    );
    return region == null
        ? p.join(routesRoot, country)
        : p.join(routesRoot, country, region!);
  }
}

class GpxStorageDestinationResolver {
  GpxStorageDestinationResolver({
    PolygonAssetRepository? polygonAssetRepository,
  }) : _polygonAssetRepository =
           polygonAssetRepository ?? PolygonAssetRepository();

  final PolygonAssetRepository _polygonAssetRepository;
  List<MapPolygonAsset>? _polygonCache;

  Future<GpxStorageDestination?> resolveForPoint(LatLng point) async {
    final polygons = await _loadPolygonAssets();
    if (polygons.isNotEmpty) {
      final assetByName = {
        for (final asset in polygons) _assetNameFor(asset): asset,
      };

      for (final assetName in _destinationPriority) {
        final asset = assetByName[assetName];
        if (asset != null && polygonContainsPoint(point, asset.points)) {
          return _destinationForAsset(assetName);
        }
      }
    }

    return _fallbackDestination(point);
  }

  Future<List<MapPolygonAsset>> _loadPolygonAssets() async {
    _polygonCache ??= await _polygonAssetRepository.loadPolygons();
    return _polygonCache!;
  }

  static const List<String> _destinationPriority = [
    'italy-nord-est.poly',
    'italy-nord-ovest.poly',
    'slovenia.poly',
    'croatia.poly',
    'tasmania.poly',
    'new-south-wales.poly',
  ];

  static String _assetNameFor(MapPolygonAsset asset) {
    return asset.assetPath.split('/').last;
  }

  static GpxStorageDestination _destinationForAsset(String assetName) {
    return switch (assetName) {
      'italy-nord-est.poly' => const GpxStorageDestination(
        country: 'Italy',
        region: 'nord-est',
      ),
      'italy-nord-ovest.poly' => const GpxStorageDestination(
        country: 'Italy',
        region: 'nord-ovest',
      ),
      'slovenia.poly' => const GpxStorageDestination(country: 'Slovenia'),
      'croatia.poly' => const GpxStorageDestination(country: 'Croatia'),
      'tasmania.poly' => const GpxStorageDestination(
        country: 'Australia',
        region: 'Tasmania',
      ),
      'new-south-wales.poly' => const GpxStorageDestination(
        country: 'Australia',
        region: 'NSW',
      ),
      _ => const GpxStorageDestination(country: ''),
    };
  }

  GpxStorageDestination? _fallbackDestination(LatLng point) {
    if (_isTasmanian(point)) {
      return const GpxStorageDestination(
        country: 'Australia',
        region: 'Tasmania',
      );
    }

    return null;
  }

  bool _isTasmanian(LatLng point) {
    return point.latitude >= -43.8 &&
        point.latitude <= -39.0 &&
        point.longitude >= 143.5 &&
        point.longitude <= 149.0;
  }
}
