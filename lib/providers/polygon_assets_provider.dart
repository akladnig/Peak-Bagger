import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

final polygonAssetRepositoryProvider = Provider<PolygonAssetRepository>((ref) {
  return PolygonAssetRepository();
});

final polygonAssetsProvider = FutureProvider<List<MapPolygonAsset>>((
  ref,
) async {
  final repository = ref.read(polygonAssetRepositoryProvider);
  return repository.loadPolygons();
});
