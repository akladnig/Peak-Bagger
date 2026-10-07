import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

export 'package:peak_bagger/services/mapping_store_core.dart'
    show Basemap, MappingCatalog, MappingCatalogRegion, MappingCatalogBasemap;

typedef RegionManifestRegionData = MappingCatalogRegion;
typedef RegionManifestBasemapData = MappingCatalogBasemap;

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

List<String> localTopoRegionKeysForBounds(
  LatLngBounds? bounds, {
  required MappingCatalog catalog,
  LocalTopoCapabilitySnapshot? snapshot,
}) {
  final activeSnapshot = snapshot ?? localTopoRuntime.capabilitySnapshot;
  if (bounds == null || activeSnapshot == null) {
    return const [];
  }

  final visibleRegions = catalog.regionsForBounds(bounds);
  return [
    for (final region in visibleRegions)
      if (activeSnapshot.supportsRegionKey(region.key)) region.key,
  ];
}

bool isLocalTopoAvailableForBounds(
  LatLngBounds? bounds, {
  required MappingCatalog catalog,
  LocalTopoCapabilitySnapshot? snapshot,
}) {
  return localTopoRegionKeysForBounds(
    bounds,
    catalog: catalog,
    snapshot: snapshot,
  ).isNotEmpty;
}

bool isTasmaniaOverlayEligible({
  required MappingCatalog catalog,
  required LatLng point,
  required LatLngBounds? visibleBounds,
  LocalTopoCapabilitySnapshot? snapshot,
}) {
  final activeSnapshot = snapshot ?? localTopoRuntime.capabilitySnapshot;
  if (activeSnapshot == null ||
      catalog.regionKeyForPoint(point) != 'tasmania') {
    return false;
  }

  final boundsIntersectTasmania =
      visibleBounds != null &&
      catalog
          .regionsForBounds(visibleBounds)
          .any((region) => region.key == 'tasmania');
  if (!boundsIntersectTasmania) {
    return false;
  }

  return activeSnapshot.overlayCapabilities.any(
    (overlay) => overlay.resolveRegion('tasmania') != null,
  );
}

List<RegionManifestBasemapData> basemapsForDrawer({
  required MappingCatalog catalog,
  required LatLng point,
  required LatLngBounds? visibleBounds,
}) {
  final basemaps = catalog.basemapsForPoint(point).toList(growable: true);
  if (!isLocalTopoAvailableForBounds(visibleBounds, catalog: catalog)) {
    return List.unmodifiable(basemaps);
  }

  final localTopo = catalog.basemapByKey(Basemap.localTopo.name);
  if (localTopo != null &&
      basemaps.every((basemap) => basemap.key != localTopo.key)) {
    basemaps.add(localTopo);
  }
  return List.unmodifiable(basemaps);
}

/// Flutter map operations over the immutable, ready-scope catalog.
extension MappingCatalogMapOperations on MappingCatalog {
  static const _intersectionEpsilon = 1e-9;

  Basemap? basemapEnumByKey(String key) {
    for (final basemap in Basemap.values) {
      if (basemap.name == key) return basemap;
    }
    return null;
  }

  List<RegionManifestRegionData> allRegions() {
    return regions;
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
    for (final region in regions) {
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
    final region = regionByKey(regionKey);
    if (region == null) {
      return const [];
    }

    final basemaps = <RegionManifestBasemapData>[];
    final seen = <String>{};
    for (final key in region.basemapKeys) {
      if (!seen.add(key)) {
        continue;
      }
      final basemapEnum = basemapEnumByKey(key);
      if (basemapEnum != null && !isBasemapAvailable(basemapEnum)) {
        continue;
      }
      final basemap = basemapByKey(key);
      if (basemap != null) {
        basemaps.add(basemap);
      }
    }

    return List.unmodifiable(basemaps);
  }

  List<RegionManifestBasemapData> basemapsForPoint(LatLng point) {
    var region = regionForPoint(point);
    if (region == null) {
      return const [];
    }
    if (region.basemapKeys.isEmpty) {
      region =
          regionByKey(peakListFilterRegionKey(region.key) ?? region.key) ??
          region;
    }

    final basemaps = <RegionManifestBasemapData>[];
    final seen = <String>{};
    for (final key in region.basemapKeys) {
      if (!seen.add(key)) {
        continue;
      }

      final basemapEnum = basemapEnumByKey(key);
      if (basemapEnum != null && !isBasemapAvailable(basemapEnum)) {
        continue;
      }

      final basemap = basemapByKey(key);
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
}
