import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

class MapSearchService {
  static const _maxResults = 20;

  MapSearchService({
    required PeakRepository peakRepository,
    required GpxTrackRepository gpxTrackRepository,
    required RouteRepository routeRepository,
    required TasmapRepository tasmapRepository,
  }) : _peakRepository = peakRepository,
       _gpxTrackRepository = gpxTrackRepository,
       _routeRepository = routeRepository,
       _tasmapRepository = tasmapRepository;

  final PeakRepository _peakRepository;
  final GpxTrackRepository _gpxTrackRepository;
  final RouteRepository _routeRepository;
  final TasmapRepository _tasmapRepository;

  List<Peak> searchPeaks(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }
    return _peakRepository
        .searchPeaks(trimmedQuery)
        .take(_maxResults)
        .toList(growable: false);
  }

  List<MapSearchResult> search({
    required String query,
    required MapSearchEntityFilter entityFilter,
    required MapSearchSort sort,
    String? regionKey,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final results = switch (entityFilter) {
      MapSearchEntityFilter.all => [
        ..._peakResults(trimmedQuery, regionKey: regionKey),
        ..._trackResults(trimmedQuery, regionKey: regionKey),
        ..._routeResults(trimmedQuery, regionKey: regionKey),
        ..._mapResults(trimmedQuery, regionKey: regionKey),
      ],
      MapSearchEntityFilter.peaks => _peakResults(
        trimmedQuery,
        regionKey: regionKey,
      ),
      MapSearchEntityFilter.tracksRoutes => [
        ..._trackResults(trimmedQuery, regionKey: regionKey),
        ..._routeResults(trimmedQuery, regionKey: regionKey),
      ],
      MapSearchEntityFilter.maps => _mapResults(
        trimmedQuery,
        regionKey: regionKey,
      ),
      MapSearchEntityFilter.natural ||
      MapSearchEntityFilter.roads => const <MapSearchResult>[],
    };

    final sortedResults = List<MapSearchResult>.from(results)
      ..sort((left, right) {
        final comparison = left.normalizedTitle.compareTo(
          right.normalizedTitle,
        );
        if (comparison != 0) {
          return sort == MapSearchSort.nameAscending ? comparison : -comparison;
        }
        return left.id.compareTo(right.id);
      });
    if (sortedResults.length <= _maxResults) {
      return sortedResults;
    }
    return sortedResults.take(_maxResults).toList(growable: false);
  }

  List<MapSearchResult> _peakResults(String query, {String? regionKey}) {
    return _peakRepository
        .searchPeaks(query)
        .map((peak) => _peakResult(peak, regionKey: regionKey))
        .whereType<MapSearchResult>()
        .toList(growable: false);
  }

  List<MapSearchResult> _trackResults(String query, {String? regionKey}) {
    final loweredQuery = query.toLowerCase();
    return _gpxTrackRepository
        .getAllTracks()
        .where((track) => track.trackName.toLowerCase().contains(loweredQuery))
        .map((track) => _trackResult(track, regionKey: regionKey))
        .whereType<MapSearchResult>()
        .toList(growable: false);
  }

  List<MapSearchResult> _routeResults(String query, {String? regionKey}) {
    final loweredQuery = query.toLowerCase();
    return _routeRepository
        .getAllRoutes()
        .where((route) => route.name.toLowerCase().contains(loweredQuery))
        .map((route) => _routeResult(route, regionKey: regionKey))
        .whereType<MapSearchResult>()
        .toList(growable: false);
  }

  List<MapSearchResult> _mapResults(String query, {String? regionKey}) {
    return _tasmapRepository
        .findByName(query)
        .map((map) => _mapResult(map, regionKey: regionKey))
        .whereType<MapSearchResult>()
        .toList(growable: false);
  }

  MapSearchResult? _peakResult(Peak peak, {String? regionKey}) {
    final anchor = LatLng(peak.latitude, peak.longitude);
    final regionData = _regionForPoint(anchor, fallbackRegionKey: peak.region);
    final resolvedRegionKey = regionData?.key ?? peak.region;
    if (!_matchesRegion(resolvedRegionKey, regionKey)) {
      return null;
    }
    final mapName = _mapNameForPoint(anchor);
    final subtitle = _joinSummaryParts([mapName, regionData?.name]);
    return MapSearchResult.peak(
      id: '${peak.osmId}',
      title: peak.name,
      subtitle: subtitle,
      anchor: anchor,
      trailingText: peak.elevation == null
          ? '—'
          : formatElevation(peak.elevation!.round()),
      regionKey: resolvedRegionKey,
      regionName: regionData?.name,
      mapName: mapName,
      peak: peak,
    );
  }

  MapSearchResult? _trackResult(GpxTrack track, {String? regionKey}) {
    final anchor = _firstPointForTrack(track);
    if (anchor == null) {
      return null;
    }
    final regionData = _regionForPoint(anchor);
    if (!_matchesRegion(regionData?.key, regionKey)) {
      return null;
    }
    final mapName = _mapNameForPoint(anchor);
    return MapSearchResult.track(
      id: '${track.gpxTrackId}',
      title: track.trackName.trim().isEmpty ? 'Unnamed Track' : track.trackName,
      subtitle: _joinSummaryParts([
        formatDistance2d3d(track.distance2d, track.distance3d),
        formatElevation(track.highestElevation.round()),
        mapName,
        regionData?.name,
      ]),
      anchor: anchor,
      regionKey: regionData?.key,
      regionName: regionData?.name,
      mapName: mapName,
      track: track,
    );
  }

  MapSearchResult? _routeResult(app_route.Route route, {String? regionKey}) {
    final anchor = _firstPointForRoute(route);
    if (anchor == null) {
      return null;
    }
    final regionData = _regionForPoint(anchor);
    if (!_matchesRegion(regionData?.key, regionKey)) {
      return null;
    }
    final mapName = _mapNameForPoint(anchor);
    return MapSearchResult.route(
      id: '${route.id}',
      title: route.name.trim().isEmpty ? 'Unnamed Route' : route.name,
      subtitle: _joinSummaryParts([
        formatDistance2d3d(route.distance2d, route.distance3d),
        'Up ${formatAscent(route.ascent)}',
        'Down ${formatElevation(route.descent.round())}',
        formatElevation(route.highestElevation.round()),
        mapName,
        regionData?.name,
      ]),
      anchor: anchor,
      regionKey: regionData?.key,
      regionName: regionData?.name,
      mapName: mapName,
      route: route,
    );
  }

  MapSearchResult? _mapResult(Tasmap50k map, {String? regionKey}) {
    final anchor = _anchorForMap(map);
    if (anchor == null) {
      return null;
    }
    final regionData = _regionForPoint(anchor);
    if (!_matchesRegion(regionData?.key, regionKey)) {
      return null;
    }
    return MapSearchResult.map(
      id: '${map.id}:${map.series}:${map.name}',
      title: map.name,
      subtitle: regionData?.name ?? '—',
      anchor: anchor,
      regionKey: regionData?.key,
      regionName: regionData?.name,
      map: map,
    );
  }

  LatLng? _firstPointForTrack(GpxTrack track) {
    final points = track.getPoints();
    if (points.isNotEmpty) {
      return points.first;
    }
    final caches = GpxTrack.decodeDisplayTrackPointsByZoom(
      track.displayTrackPointsByZoom,
    );
    for (
      var zoom = MapConstants.trackMinZoom;
      zoom <= MapConstants.trackMaxZoom;
      zoom++
    ) {
      final segments = caches[zoom];
      if (segments == null) {
        continue;
      }
      for (final segment in segments) {
        if (segment.isNotEmpty) {
          return segment.first;
        }
      }
    }
    return null;
  }

  LatLng? _firstPointForRoute(app_route.Route route) {
    if (route.gpxRoute.isNotEmpty) {
      return route.gpxRoute.first;
    }
    final segments = route.getSegmentsForZoom(MapConstants.defaultZoom.toInt());
    for (final segment in segments) {
      if (segment.isNotEmpty) {
        return segment.first;
      }
    }
    return null;
  }

  LatLng? _anchorForMap(Tasmap50k map) {
    final center = _tasmapRepository.getMapCenter(map);
    if (center != null) {
      return center;
    }
    final bounds = _tasmapRepository.getMapBounds(map);
    if (bounds == null) {
      return null;
    }
    return LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
  }

  String? _mapNameForPoint(LatLng point) {
    return resolveSheetMapNameForPoint(
      tasmapRepository: _tasmapRepository,
      point: point,
    );
  }

  RegionManifestRegionData? _regionForPoint(
    LatLng point, {
    String? fallbackRegionKey,
  }) {
    final region = regionManifestCatalog.regionForPoint(point);
    if (region != null) {
      return region;
    }
    if (fallbackRegionKey == null) {
      return null;
    }
    return regionManifestCatalog.regionByKey(fallbackRegionKey);
  }

  bool _matchesRegion(String? resolvedRegionKey, String? regionKey) {
    return regionKey == null || resolvedRegionKey == regionKey;
  }

  String _joinSummaryParts(Iterable<String?> parts) {
    final filtered = parts
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return '—';
    }
    return filtered.join(' · ');
  }
}
