import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';

typedef TileCacheDownloadStarter = ({
  Stream<TileEvent> tileEvents,
  Stream<DownloadProgress> downloadProgress,
}) Function({
  required Basemap basemap,
  required DownloadableRegion region,
  required bool skipExistingTiles,
});

List<Tasmap50k> sortTileCacheMapsByName(Iterable<Tasmap50k> maps) {
  final sorted = maps.toList(growable: false);
  sorted.sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) {
      return byName;
    }

    final bySeries = a.series.toLowerCase().compareTo(b.series.toLowerCase());
    if (bySeries != 0) {
      return bySeries;
    }

    return a.id.compareTo(b.id);
  });
  return sorted;
}

Tasmap50k? selectInitialTileCacheMap(Iterable<Tasmap50k> maps) {
  final sorted = sortTileCacheMapsByName(maps);
  if (sorted.isEmpty) {
    return null;
  }

  return sorted.first;
}

DownloadableRegion<CustomPolygonRegion> buildTileCacheDownloadRegion({
  required List<LatLng> polygonPoints,
  required int minZoom,
  required int maxZoom,
  required TileLayer options,
}) {
  if (polygonPoints.isEmpty) {
    throw ArgumentError.value(
      polygonPoints,
      'polygonPoints',
      'must not be empty',
    );
  }

  return CustomPolygonRegion(List<LatLng>.unmodifiable(polygonPoints))
      .toDownloadable(
        minZoom: minZoom,
        maxZoom: maxZoom,
        options: options,
      );
}
