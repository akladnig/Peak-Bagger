import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

part 'package:peak_bagger/generated/region_manifest_catalog.g.dart';

const mapyCzApiKey = String.fromEnvironment('MAPY_CZ_API_KEY');
const tracestrackApiKey = String.fromEnvironment('TRACESTRACK_API_KEY');
const tracestrackReferer = String.fromEnvironment(
  'TRACESTRACK_REFERER',
  defaultValue: 'https://tracestrack.com/',
);

bool get hasMapyCzApiKey => mapyCzApiKey.trim().isNotEmpty;
bool get hasTracestrackApiKey => tracestrackApiKey.trim().isNotEmpty;

bool isBasemapAvailable(Basemap basemap) {
  return switch (basemap) {
    Basemap.mapyCz => hasMapyCzApiKey,
    Basemap.localTopo => localTopoRuntime.hasCapabilitySnapshot,
    _ => true,
  };
}

class RegionManifestBasemapData {
  const RegionManifestBasemapData({
    required this.key,
    required this.name,
    required this.tileUrl,
    required this.attribution,
    this.maxZoom,
    this.coveragePolygons = const [],
  });

  final String key;
  final String name;
  final String tileUrl;
  final String attribution;
  final int? maxZoom;
  final List<List<LatLng>> coveragePolygons;

  bool isAvailableForPoint(LatLng point) {
    if (coveragePolygons.isEmpty) {
      return true;
    }

    for (final polygon in coveragePolygons) {
      if (polygonContainsPoint(point, polygon)) {
        return true;
      }
    }

    return false;
  }
}

class RegionManifestRegionData {
  const RegionManifestRegionData({
    required this.key,
    required this.name,
    required this.shortName,
    required this.priority,
    required this.showInPeakList,
    this.peakListFilterAliases = const [],
    required this.polygons,
    required this.basemapKeys,
    required this.mapSet,
  });

  final String key;
  final String name;
  final String shortName;
  final ManifestPriority priority;
  final bool? showInPeakList;
  final List<String> peakListFilterAliases;
  final List<List<LatLng>> polygons;
  final List<String> basemapKeys;
  final List<String> mapSet;

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
  for (final basemap in regionManifestCatalogData.basemaps)
    basemap.key: basemap,
};

final Map<String, Basemap> _basemapEnumByKey = {
  for (final basemap in Basemap.values) basemap.name: basemap,
};

final Map<String, RegionManifestRegionData> _regionByKey = {
  for (final region in regionManifestCatalogData.regions) region.key: region,
};

final Map<String, RegionManifestRegionData> _regionByDisplayName = {
  for (final region in regionManifestCatalogData.regions)
    region.name.trim(): region,
};

final Map<String, String> _peakListFilterRegionKeyByIdentifier = {
  for (final region in regionManifestCatalogData.regions)
    for (final alias in region.peakListFilterAliases) alias: region.key,
};

class RegionManifestCatalog {
  const RegionManifestCatalog._();

  static const _intersectionEpsilon = 1e-9;

  RegionManifestBasemapData? basemapByKey(String key) {
    return _basemapByKey[key];
  }

  Basemap? basemapEnumByKey(String key) {
    return _basemapEnumByKey[key];
  }

  RegionManifestRegionData? regionByKey(String key) {
    return _regionByKey[key];
  }

  RegionManifestRegionData? regionByDisplayName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return _regionByDisplayName[trimmed];
  }

  String? regionKeyByDisplayName(String? displayName) {
    return regionByDisplayName(displayName)?.key;
  }

  List<RegionManifestRegionData> allRegions() {
    return List.unmodifiable(regionManifestCatalogData.regions);
  }

  List<RegionManifestRegionData> peakListRegions() {
    return List.unmodifiable(
      regionManifestCatalogData.regions.where(
        (region) => region.showInPeakList == true,
      ),
    );
  }

  String? peakListFilterRegionKey(String? regionKey) {
    final normalized = _normalizePeakListFilterIdentifier(regionKey);
    if (normalized == null) {
      return null;
    }

    return _peakListFilterRegionKeyByIdentifier[normalized] ?? normalized;
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

  List<RegionManifestRegionData> regionsForPointByPriority(LatLng point) {
    final matches = <RegionManifestRegionData>[
      for (final region in regionManifestCatalogData.regions)
        if (region.containsPoint(point)) region,
    ];
    matches.sort(_compareRegionPriorityDescending);
    return List.unmodifiable(matches);
  }

  List<RegionManifestRegionData> highestPriorityRegionsForPoint(LatLng point) {
    final matches = regionsForPointByPriority(point);
    if (matches.isEmpty) {
      return const [];
    }

    final bestPriority = matches.first.priority;
    return List.unmodifiable(
      matches.where((region) => region.priority.compareTo(bestPriority) == 0),
    );
  }

  RegionManifestRegionData? uniqueHighestPriorityRegionForPoint(LatLng point) {
    final matches = highestPriorityRegionsForPoint(point);
    return matches.length == 1 ? matches.single : null;
  }

  List<RegionManifestRegionData> regionsForBounds(LatLngBounds bounds) {
    if (!_hasUsableBounds(bounds)) {
      return const [];
    }

    final matches = <RegionManifestRegionData>[];
    for (final region in regionManifestCatalogData.regions) {
      if (_boundsIntersectRegion(bounds, region)) {
        matches.add(region);
      }
    }

    return List.unmodifiable(matches);
  }

  Set<String> mapSetForBounds(LatLngBounds bounds) {
    final mapSet = <String>{};
    for (final region in regionsForBounds(bounds)) {
      mapSet.addAll(region.mapSet);
    }
    return Set.unmodifiable(mapSet);
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
      final basemapEnum = _basemapEnumByKey[key];
      if (basemapEnum != null && !isBasemapAvailable(basemapEnum)) {
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

    final basemaps = <RegionManifestBasemapData>[];
    final seen = <String>{};
    for (final key in region.basemapKeys) {
      if (!seen.add(key)) {
        continue;
      }

      final basemapEnum = _basemapEnumByKey[key];
      if (basemapEnum != null && !isBasemapAvailable(basemapEnum)) {
        continue;
      }

      final basemap = _basemapByKey[key];
      if (basemap == null || !basemap.isAvailableForPoint(point)) {
        continue;
      }

      basemaps.add(basemap);
    }

    return List.unmodifiable(basemaps);
  }

  RegionManifestBasemapData? basemapForEnum(Basemap basemap) {
    return basemapByKey(basemap.name);
  }

  bool _boundsIntersectRegion(
    LatLngBounds bounds,
    RegionManifestRegionData region,
  ) {
    for (final polygon in region.polygons) {
      if (_boundsIntersectPolygon(bounds, polygon)) {
        return true;
      }
    }
    return false;
  }

  bool _boundsIntersectPolygon(LatLngBounds bounds, List<LatLng> polygon) {
    final rectangleCorners = _rectangleCorners(bounds);
    for (final corner in rectangleCorners) {
      if (polygonContainsPoint(corner, polygon)) {
        return true;
      }
    }

    for (final point in polygon) {
      if (_boundsContainsPoint(bounds, point)) {
        return true;
      }
    }

    final rectangleEdges = _closedEdges(rectangleCorners);
    final polygonEdges = _closedEdges(polygon);
    for (final rectangleEdge in rectangleEdges) {
      for (final polygonEdge in polygonEdges) {
        if (_segmentsIntersect(
          rectangleEdge.$1,
          rectangleEdge.$2,
          polygonEdge.$1,
          polygonEdge.$2,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  List<LatLng> _rectangleCorners(LatLngBounds bounds) => [
    LatLng(bounds.south, bounds.west),
    LatLng(bounds.north, bounds.west),
    LatLng(bounds.north, bounds.east),
    LatLng(bounds.south, bounds.east),
  ];

  List<(LatLng, LatLng)> _closedEdges(List<LatLng> points) {
    if (points.length < 2) {
      return const [];
    }

    return [
      for (var i = 0; i < points.length; i++)
        (points[i], points[(i + 1) % points.length]),
    ];
  }

  bool _boundsContainsPoint(LatLngBounds bounds, LatLng point) {
    return point.latitude >= bounds.south &&
        point.latitude <= bounds.north &&
        point.longitude >= bounds.west &&
        point.longitude <= bounds.east;
  }

  bool _segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);

    if (o1 == 0 && _pointOnSegment(a, c, b)) {
      return true;
    }
    if (o2 == 0 && _pointOnSegment(a, d, b)) {
      return true;
    }
    if (o3 == 0 && _pointOnSegment(c, a, d)) {
      return true;
    }
    if (o4 == 0 && _pointOnSegment(c, b, d)) {
      return true;
    }

    return o1 != o2 && o3 != o4;
  }

  int _orientation(LatLng a, LatLng b, LatLng c) {
    final cross =
        (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
    if (cross.abs() <= _intersectionEpsilon) {
      return 0;
    }
    return cross > 0 ? 1 : 2;
  }

  bool _pointOnSegment(LatLng a, LatLng point, LatLng b) {
    return point.latitude <=
            (a.latitude > b.latitude ? a.latitude : b.latitude) +
                _intersectionEpsilon &&
        point.latitude + _intersectionEpsilon >=
            (a.latitude < b.latitude ? a.latitude : b.latitude) &&
        point.longitude <=
            (a.longitude > b.longitude ? a.longitude : b.longitude) +
                _intersectionEpsilon &&
        point.longitude + _intersectionEpsilon >=
            (a.longitude < b.longitude ? a.longitude : b.longitude);
  }

  bool _hasUsableBounds(LatLngBounds bounds) {
    return bounds.south.isFinite &&
        bounds.north.isFinite &&
        bounds.west.isFinite &&
        bounds.east.isFinite &&
        bounds.south < bounds.north &&
        bounds.west < bounds.east;
  }

  String? _normalizePeakListFilterIdentifier(String? regionKey) {
    final trimmed = regionKey?.trim();
    if (trimmed == null) {
      return null;
    }
    if (trimmed.isEmpty) {
      return 'tasmania';
    }

    return trimmed.toLowerCase();
  }

  int _compareRegionPriorityDescending(
    RegionManifestRegionData left,
    RegionManifestRegionData right,
  ) {
    final priorityComparison = right.priority.compareTo(left.priority);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return left.key.compareTo(right.key);
  }
}
