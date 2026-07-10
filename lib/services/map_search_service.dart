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
import 'package:peak_bagger/services/map_search_region_filter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

class MapSearchService {
  static const popupPageSize = 20;

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
        .take(popupPageSize)
        .toList(growable: false);
  }

  List<MapSearchResult> search({
    required String query,
    required MapSearchEntityFilter entityFilter,
    required MapSearchSort sort,
    String? regionKey,
  }) {
    return searchPage(
      query: query,
      entityFilter: entityFilter,
      sort: sort,
      regionKey: regionKey,
      group: MapSearchGroup.none,
      offset: 0,
      limit: popupPageSize,
    ).results;
  }

  MapSearchPage searchPage({
    required String query,
    required MapSearchEntityFilter entityFilter,
    required MapSearchSort sort,
    required MapSearchGroup group,
    String? regionKey,
    required int offset,
    int limit = popupPageSize,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty ||
        trimmedQuery.length < MapConstants.searchPopupMinimumQueryLength) {
      return const MapSearchPage(results: [], isExhausted: true);
    }

    final pageOffset = offset < 0 ? 0 : offset;
    if (limit <= 0) {
      return const MapSearchPage(results: [], isExhausted: true);
    }

    if (entityFilter == MapSearchEntityFilter.peaks &&
        group == MapSearchGroup.none) {
      return _peakPage(
        trimmedQuery,
        sort: sort,
        regionKey: regionKey,
        offset: pageOffset,
        limit: limit,
      );
    }

    final entries = _orderedEntries(
      query: trimmedQuery,
      entityFilter: entityFilter,
      regionKey: regionKey,
      sort: sort,
      group: group,
    );

    if (pageOffset >= entries.length) {
      return const MapSearchPage(results: [], isExhausted: true);
    }

    final end = (pageOffset + limit).clamp(0, entries.length);
    final pageEntries = entries.sublist(pageOffset, end);
    return MapSearchPage(
      results: pageEntries
          .map((entry) => entry.toResult(this))
          .toList(growable: false),
      isExhausted: end >= entries.length,
    );
  }

  MapSearchPage _peakPage(
    String query, {
    required MapSearchSort sort,
    String? regionKey,
    required int offset,
    required int limit,
  }) {
    final peaks = _peakRepository
        .searchPopupPeakCandidates(
          query: query,
          sort: sort,
          regionKey: regionKey,
          offset: offset,
          limit: limit + 1,
        )
        .toList(growable: false);
    final pagePeaks = peaks.take(limit);
    return MapSearchPage(
      results: pagePeaks
          .map((peak) => _peakResult(peak, regionKey: regionKey))
          .whereType<MapSearchResult>()
          .toList(growable: false),
      isExhausted: peaks.length <= limit,
    );
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
    if (!peakMatchesSearchRegion(
      storedPeakRegionKey: peak.region,
      resolvedRegionKey: resolvedRegionKey,
      filterRegionKey: regionKey,
    )) {
      return null;
    }
    final mapName = _mapNameForPoint(anchor);
    final displayRegionKey = isNorthEastSubregionKey(peak.region)
        ? peak.region
        : resolvedRegionKey;
    final displayRegionName = mapSearchRegionLabel(displayRegionKey);
    final subtitle = _joinSummaryParts([mapName, displayRegionName]);
    return MapSearchResult.peak(
      id: '${peak.osmId}',
      title: peak.name,
      subtitle: subtitle,
      anchor: anchor,
      trailingText: peak.elevation == null
          ? '—'
          : formatElevation(peak.elevation!.round()),
      regionKey: displayRegionKey,
      regionName: displayRegionName,
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
    if (!nonPeakMatchesSearchRegion(
      resolvedRegionKey: regionData?.key,
      filterRegionKey: regionKey,
    )) {
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
    if (!nonPeakMatchesSearchRegion(
      resolvedRegionKey: regionData?.key,
      filterRegionKey: regionKey,
    )) {
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
    if (!nonPeakMatchesSearchRegion(
      resolvedRegionKey: regionData?.key,
      filterRegionKey: regionKey,
    )) {
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

  List<_SearchPageEntry> _orderedEntries({
    required String query,
    required MapSearchEntityFilter entityFilter,
    required String? regionKey,
    required MapSearchSort sort,
    required MapSearchGroup group,
  }) {
    final entries = switch (entityFilter) {
      MapSearchEntityFilter.all => <_SearchPageEntry>[
        ..._allPeakEntries(query, sort: sort, regionKey: regionKey),
        ..._trackResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
        ..._routeResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
        ..._mapResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
      ],
      MapSearchEntityFilter.peaks => _allPeakEntries(
        query,
        sort: sort,
        regionKey: regionKey,
      ),
      MapSearchEntityFilter.tracksRoutes => <_SearchPageEntry>[
        ..._trackResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
        ..._routeResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
      ],
      MapSearchEntityFilter.maps => _mapResults(
        query,
        regionKey: regionKey,
      ).map(_SearchPageResultEntry.new).toList(growable: false),
      MapSearchEntityFilter.natural ||
      MapSearchEntityFilter.roads => const <_SearchPageEntry>[],
    };

    final ordered = List<_SearchPageEntry>.from(entries)
      ..sort(
        (left, right) => _compareEntries(left, right, sort: sort, group: group),
      );
    return ordered;
  }

  List<_SearchPageEntry> _allPeakEntries(
    String query, {
    required MapSearchSort sort,
    required String? regionKey,
  }) {
    final entries = <_SearchPageEntry>[];
    var offset = 0;
    while (true) {
      final peaks = _peakRepository.searchPopupPeakCandidates(
        query: query,
        sort: sort,
        regionKey: regionKey,
        offset: offset,
        limit: popupPageSize,
      );
      if (peaks.isEmpty) {
        break;
      }
      entries.addAll(
        peaks.map(
          (peak) => _SearchPagePeakEntry(
            peak: peak,
            displayRegionName: _peakDisplayRegionName(peak),
          ),
        ),
      );
      if (peaks.length < popupPageSize) {
        break;
      }
      offset += peaks.length;
    }
    return entries;
  }

  int _compareEntries(
    _SearchPageEntry left,
    _SearchPageEntry right, {
    required MapSearchSort sort,
    required MapSearchGroup group,
  }) {
    if (group != MapSearchGroup.none) {
      final labelComparison = _compareLabels(
        left.groupLabel(group),
        right.groupLabel(group),
        sort,
      );
      if (labelComparison != 0) {
        return labelComparison;
      }
    }

    final titleComparison = left.normalizedTitle.compareTo(
      right.normalizedTitle,
    );
    if (titleComparison != 0) {
      return sort == MapSearchSort.nameAscending
          ? titleComparison
          : -titleComparison;
    }
    return left.id.compareTo(right.id);
  }

  int _compareLabels(String left, String right, MapSearchSort sort) {
    final comparison = left.toLowerCase().compareTo(right.toLowerCase());
    if (comparison == 0) {
      return 0;
    }
    return sort == MapSearchSort.nameAscending ? comparison : -comparison;
  }

  String _peakDisplayRegionKey(Peak peak) {
    final anchor = LatLng(peak.latitude, peak.longitude);
    final regionData = _regionForPoint(anchor, fallbackRegionKey: peak.region);
    final resolvedRegionKey = regionData?.key ?? peak.region;
    return isNorthEastSubregionKey(peak.region)
        ? peak.region!
        : (resolvedRegionKey ?? '');
  }

  String _peakDisplayRegionName(Peak peak) {
    final displayRegionKey = _peakDisplayRegionKey(peak);
    return mapSearchRegionLabel(displayRegionKey) ?? 'Unknown Region';
  }
}

sealed class _SearchPageEntry {
  const _SearchPageEntry();

  String get id;
  String get normalizedTitle;
  String groupLabel(MapSearchGroup group);
  MapSearchResult toResult(MapSearchService service);
}

class _SearchPageResultEntry extends _SearchPageEntry {
  const _SearchPageResultEntry(this.result);

  final MapSearchResult result;

  @override
  String get id => result.id;

  @override
  String get normalizedTitle => result.normalizedTitle;

  @override
  String groupLabel(MapSearchGroup group) {
    return switch (group) {
      MapSearchGroup.none => '',
      MapSearchGroup.region => result.regionName ?? 'Unknown Region',
      MapSearchGroup.type => switch (result.type) {
        MapSearchResultType.peak => 'Peaks',
        MapSearchResultType.track ||
        MapSearchResultType.route => 'Tracks/Routes',
        MapSearchResultType.map => 'Maps',
      },
    };
  }

  @override
  MapSearchResult toResult(MapSearchService service) => result;
}

class _SearchPagePeakEntry extends _SearchPageEntry {
  const _SearchPagePeakEntry({
    required this.peak,
    required this.displayRegionName,
  });

  final Peak peak;
  final String displayRegionName;

  @override
  String get id => '${peak.osmId}';

  @override
  String get normalizedTitle => peak.name.trim().toLowerCase();

  @override
  String groupLabel(MapSearchGroup group) {
    return switch (group) {
      MapSearchGroup.none => '',
      MapSearchGroup.region => displayRegionName,
      MapSearchGroup.type => 'Peaks',
    };
  }

  @override
  MapSearchResult toResult(MapSearchService service) {
    return service._peakResult(peak, regionKey: null)!;
  }
}
