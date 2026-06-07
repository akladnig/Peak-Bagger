import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

part 'package:peak_bagger/generated/region_manifest_catalog.g.dart';

class RegionManifestBasemapData {
  const RegionManifestBasemapData({
    required this.key,
    required this.name,
    required this.tileUrl,
    required this.attribution,
    this.maxZoom,
  });

  final String key;
  final String name;
  final String tileUrl;
  final String attribution;
  final int? maxZoom;
}

class RegionManifestRegionData {
  const RegionManifestRegionData({
    required this.key,
    required this.polygons,
    required this.basemapKeys,
  });

  final String key;
  final List<List<LatLng>> polygons;
  final List<String> basemapKeys;

  bool containsPoint(LatLng point) {
    for (final polygon in polygons) {
      if (polygonContainsPoint(point, polygon)) {
        return true;
      }
    }
    return false;
  }
}

class RegionManifestCatalogData {
  const RegionManifestCatalogData({
    required this.basemaps,
    required this.regions,
  });

  final List<RegionManifestBasemapData> basemaps;
  final List<RegionManifestRegionData> regions;
}

const regionManifestCatalog = RegionManifestCatalog._();

final Map<String, RegionManifestBasemapData> _basemapByKey = {
  for (final basemap in regionManifestCatalogData.basemaps) basemap.key: basemap,
};

final Map<String, Basemap> _basemapEnumByKey = {
  for (final basemap in Basemap.values) basemap.name: basemap,
};

final Map<String, RegionManifestRegionData> _regionByKey = {
  for (final region in regionManifestCatalogData.regions) region.key: region,
};

class RegionManifestCatalog {
  const RegionManifestCatalog._();

  RegionManifestBasemapData? basemapByKey(String key) {
    return _basemapByKey[key];
  }

  Basemap? basemapEnumByKey(String key) {
    return _basemapEnumByKey[key];
  }

  RegionManifestRegionData? regionByKey(String key) {
    return _regionByKey[key];
  }

  RegionManifestRegionData? regionForPoint(LatLng point) {
    for (final region in regionManifestCatalogData.regions) {
      if (region.containsPoint(point)) {
        return region;
      }
    }
    return null;
  }

  String? regionKeyForPoint(LatLng point) {
    return regionForPoint(point)?.key;
  }

  List<RegionManifestBasemapData> basemapsForRegionKey(String regionKey) {
    final region = _regionByKey[regionKey];
    if (region == null) {
      return const [];
    }

    final basemaps = <RegionManifestBasemapData>[];
    final seen = <String>{};
    for (final key in region.basemapKeys) {
      if (!seen.add(key)) {
        continue;
      }
      final basemap = _basemapByKey[key];
      if (basemap != null) {
        basemaps.add(basemap);
      }
    }

    return List.unmodifiable(basemaps);
  }

  List<RegionManifestBasemapData> basemapsForPoint(LatLng point) {
    final region = regionForPoint(point);
    if (region == null) {
      return const [];
    }

    return basemapsForRegionKey(region.key);
  }

  RegionManifestBasemapData? basemapForEnum(Basemap basemap) {
    return basemapByKey(basemap.name);
  }
}
