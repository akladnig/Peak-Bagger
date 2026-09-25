import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/track_date_query_parser.dart';

class MapSearchService {
  static const popupPageSize = 20;
  static const defaultCategories = <MapSearchCategory>{
    MapSearchCategory.peaks,
    MapSearchCategory.tracksRoutes,
    MapSearchCategory.natural,
  };

  MapSearchService({
    required this._peakRepository,
    required this._gpxTrackRepository,
    required this._routeRepository,
    required this._tasmapRepository,
    required this._peaksBaggedRepository,
    this.naturalFeatureRepository,
    this.namedWaySearch,
  });

  final PeakRepository _peakRepository;
  final GpxTrackRepository _gpxTrackRepository;
  final RouteRepository _routeRepository;
  final TasmapRepository _tasmapRepository;
  final PeaksBaggedRepository _peaksBaggedRepository;
  final NaturalFeatureRepository? naturalFeatureRepository;
  final NamedRouteGraphWaySearch? namedWaySearch;

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
    Set<MapSearchCategory>? categories,
    @Deprecated('Use categories.') MapSearchEntityFilter? entityFilter,
    required MapSearchSort sort,
    String? regionKey,
    TrackDateRange? trackDateRange,
  }) {
    return searchPage(
      query: query,
      categories: _resolvedCategories(categories, entityFilter),
      sort: sort,
      regionKey: regionKey,
      group: MapSearchGroup.none,
      trackDateRange: trackDateRange,
      offset: 0,
      limit: popupPageSize,
    ).results;
  }

  MapSearchPage searchPage({
    required String query,
    Set<MapSearchCategory>? categories,
    @Deprecated('Use categories.') MapSearchEntityFilter? entityFilter,
    required MapSearchSort sort,
    required MapSearchGroup group,
    String? regionKey,
    required int offset,
    int limit = popupPageSize,
    TrackDateRange? trackDateRange,
  }) {
    final resolvedCategories = _resolvedCategories(categories, entityFilter);
    final trimmedQuery = query.trim();
    if (trackDateRange == null &&
        (trimmedQuery.isEmpty ||
            trimmedQuery.length < MapConstants.searchPopupMinimumQueryLength)) {
      return const MapSearchPage(results: [], isExhausted: true);
    }

    final pageOffset = offset < 0 ? 0 : offset;
    if (limit <= 0) {
      return const MapSearchPage(results: [], isExhausted: true);
    }

    if (trackDateRange == null &&
        resolvedCategories.length == 1 &&
        resolvedCategories.contains(MapSearchCategory.peaks) &&
        group == MapSearchGroup.none) {
      return _peakPage(
        trimmedQuery,
        sort: sort,
        regionKey: regionKey,
        offset: pageOffset,
        limit: limit,
      );
    }

    final entries = trackDateRange == null
        ? _orderedEntries(
            query: trimmedQuery,
            categories: resolvedCategories,
            regionKey: regionKey,
            sort: sort,
            group: group,
          )
        : _orderedRangeEntries(
            query: trimmedQuery,
            range: trackDateRange,
            categories: resolvedCategories,
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

  Set<MapSearchCategory> _resolvedCategories(
    Set<MapSearchCategory>? categories,
    MapSearchEntityFilter? entityFilter,
  ) {
    if (categories != null) {
      return categories;
    }
    return switch (entityFilter ?? MapSearchEntityFilter.all) {
      MapSearchEntityFilter.all => MapSearchCategory.values.toSet(),
      MapSearchEntityFilter.peaks => {MapSearchCategory.peaks},
      MapSearchEntityFilter.tracksRoutes => {MapSearchCategory.tracksRoutes},
      MapSearchEntityFilter.natural => {MapSearchCategory.natural},
      MapSearchEntityFilter.roads => {MapSearchCategory.roads},
      MapSearchEntityFilter.maps => {MapSearchCategory.maps},
    };
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
    final latestBaggedDatesByPeakId = _latestBaggedDatesByPeakId();
    return MapSearchPage(
      results: pagePeaks
          .map(
            (peak) => _peakResult(
              peak,
              regionKey: regionKey,
              displayDate: latestBaggedDatesByPeakId[peak.osmId],
            ),
          )
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

  List<MapSearchResult> _naturalResults(String query, {String? regionKey}) {
    final normalizedQuery = query.trim().toLowerCase();
    return (naturalFeatureRepository?.getAllNaturalFeatures() ?? const [])
        .where((naturalFeature) {
          return naturalFeature.name.trim().toLowerCase().contains(
                normalizedQuery,
              ) ||
              (naturalFeature.altName.trim().isNotEmpty &&
                  naturalFeature.altName.trim().toLowerCase().contains(
                    normalizedQuery,
                  ));
        })
        .map(
          (naturalFeature) =>
              _naturalResult(naturalFeature, query, regionKey: regionKey),
        )
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

  List<MapSearchResult> _roadResults(String query, {String? regionKey}) {
    final candidates = namedWaySearch?.searchNamedWays(query) ?? const [];
    final orderedCandidates = List<NamedRouteGraphWayCandidate>.from(candidates)
      ..sort((left, right) {
        final coverageComparison = left.routingCoverageKey.compareTo(
          right.routingCoverageKey,
        );
        if (coverageComparison != 0) {
          return coverageComparison;
        }
        final chunkComparison = left.chunkKey.compareTo(right.chunkKey);
        if (chunkComparison != 0) {
          return chunkComparison;
        }
        return left.osmWayId.compareTo(right.osmWayId);
      });
    final seenWayIds = <int>{};
    return orderedCandidates
        .where((candidate) => seenWayIds.add(candidate.osmWayId))
        .map((candidate) => _roadResult(candidate, regionKey: regionKey))
        .whereType<MapSearchResult>()
        .toList(growable: false);
  }

  MapSearchResult? _peakResult(
    Peak peak, {
    String? regionKey,
    DateTime? displayDate,
  }) {
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
    final displayRegionKey = _displayRegionKeyForPeak(
      storedPeakRegionKey: peak.region,
      resolvedRegionKey: resolvedRegionKey,
    );
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
      displayDate: displayDate,
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

  MapSearchResult? _naturalResult(
    NaturalFeature naturalFeature,
    String query, {
    String? regionKey,
  }) {
    final anchor = LatLng(naturalFeature.latitude, naturalFeature.longitude);
    final regionData = _regionForPoint(anchor);
    if (!nonPeakMatchesSearchRegion(
      resolvedRegionKey: regionData?.key,
      filterRegionKey: regionKey,
    )) {
      return null;
    }
    final normalizedQuery = query.trim().toLowerCase();
    final altName = naturalFeature.altName.trim();
    final title =
        altName.isNotEmpty && altName.toLowerCase().contains(normalizedQuery)
        ? '${naturalFeature.name} / $altName'
        : naturalFeature.name;
    return MapSearchResult.natural(
      id: '${naturalFeature.osmType}-${naturalFeature.osmId}',
      title: title,
      subtitle: _joinSummaryParts([
        _formatNaturalTag(naturalFeature.tag),
        regionData?.name,
      ]),
      anchor: anchor,
      regionKey: regionData?.key,
      regionName: regionData?.name,
      naturalFeature: naturalFeature,
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

  MapSearchResult? _roadResult(
    NamedRouteGraphWayCandidate candidate, {
    String? regionKey,
  }) {
    final regionData = _regionForPoint(candidate.anchor);
    if (!nonPeakMatchesSearchRegion(
      resolvedRegionKey: regionData?.key,
      filterRegionKey: regionKey,
    )) {
      return null;
    }
    return MapSearchResult.road(
      subtitle: _joinSummaryParts([
        _formatRoadTag(candidate.highway),
        _formatRoadTag(candidate.surface),
      ]),
      regionKey: regionData?.key,
      regionName: regionData?.name,
      road: MapSearchRoad(
        osmWayId: candidate.osmWayId,
        name: candidate.name,
        highway: candidate.highway,
        surface: candidate.surface,
        anchor: candidate.anchor,
        routingCoverageKey: candidate.routingCoverageKey,
        generation: candidate.generation,
        chunkKey: candidate.chunkKey,
      ),
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

  String? _formatRoadTag(String? value) {
    final formattedValues = value
        ?.split(';')
        .map((part) => part.trim().replaceAll('_', ' '))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part
              .split(RegExp(r'\s+'))
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
              )
              .join(' '),
        )
        .toList(growable: false);
    if (formattedValues == null || formattedValues.isEmpty) {
      return null;
    }
    return formattedValues.join(' / ');
  }

  String? _formatNaturalTag(String value) => _formatRoadTag(value);

  List<_SearchPageEntry> _orderedEntries({
    required String query,
    required Set<MapSearchCategory> categories,
    required String? regionKey,
    required MapSearchSort sort,
    required MapSearchGroup group,
  }) {
    final entries = <_SearchPageEntry>[
      if (categories.contains(MapSearchCategory.peaks))
        ..._allPeakEntries(query, sort: sort, regionKey: regionKey),
      if (categories.contains(MapSearchCategory.tracksRoutes)) ...[
        ..._trackResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
        ..._routeResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
      ],
      if (categories.contains(MapSearchCategory.natural))
        ..._naturalResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
      if (categories.contains(MapSearchCategory.maps))
        ..._mapResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
      if (categories.contains(MapSearchCategory.roads))
        ..._roadResults(
          query,
          regionKey: regionKey,
        ).map(_SearchPageResultEntry.new),
    ];

    final ordered = List<_SearchPageEntry>.from(entries)
      ..sort(
        (left, right) => _compareEntries(left, right, sort: sort, group: group),
      );
    return ordered;
  }

  List<_SearchPageEntry> _orderedRangeEntries({
    required String query,
    required TrackDateRange range,
    required Set<MapSearchCategory> categories,
    required String? regionKey,
    required MapSearchSort sort,
    required MapSearchGroup group,
  }) {
    final loweredQuery = query.toLowerCase();
    final dateMatchedTracks = _gpxTrackRepository
        .getAllTracks()
        .where((track) => range.containsTrackDate(track.trackDate))
        .toList(growable: false);
    final tracks = dateMatchedTracks
        .where(
          (track) =>
              loweredQuery.isEmpty ||
              track.trackName.toLowerCase().contains(loweredQuery),
        )
        .toList(growable: false);
    final matchingTrackIds = dateMatchedTracks
        .map((track) => track.gpxTrackId)
        .toSet();
    final baggedRows = _peaksBaggedRepository
        .getAll()
        .where((baggedPeak) => matchingTrackIds.contains(baggedPeak.gpxId))
        .toList(growable: false);
    final baggedDatesByPeakId = <int, DateTime?>{};
    for (final baggedRow in baggedRows) {
      final currentDate = baggedDatesByPeakId[baggedRow.peakId];
      final baggedDate = baggedRow.date;
      if (!baggedDatesByPeakId.containsKey(baggedRow.peakId) ||
          (baggedDate != null &&
              (currentDate == null || baggedDate.isAfter(currentDate)))) {
        baggedDatesByPeakId[baggedRow.peakId] = baggedDate;
      }
    }
    final peakIds = baggedDatesByPeakId.keys;
    final peaks = peakIds
        .map(_peakRepository.findByOsmId)
        .whereType<Peak>()
        .where(
          (peak) =>
              loweredQuery.isEmpty ||
              peak.name.toLowerCase().contains(loweredQuery),
        )
        .toList(growable: false);

    final entries = <_SearchPageEntry>[
      if (categories.contains(MapSearchCategory.peaks))
        ...peaks
            .map(
              (peak) => _peakResult(
                peak,
                regionKey: regionKey,
                displayDate: baggedDatesByPeakId[peak.osmId],
              ),
            )
            .whereType<MapSearchResult>()
            .map(_SearchPageResultEntry.new),
      if (categories.contains(MapSearchCategory.tracksRoutes))
        ...tracks
            .map((track) => _trackResult(track, regionKey: regionKey))
            .whereType<MapSearchResult>()
            .map(_SearchPageResultEntry.new),
    ];
    entries.sort(
      (left, right) => _compareEntries(left, right, sort: sort, group: group),
    );
    return entries;
  }

  List<_SearchPageEntry> _allPeakEntries(
    String query, {
    required MapSearchSort sort,
    required String? regionKey,
  }) {
    final latestBaggedDatesByPeakId = _latestBaggedDatesByPeakId();

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
            displayDate: latestBaggedDatesByPeakId[peak.osmId],
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

  Map<int, DateTime> _latestBaggedDatesByPeakId() {
    final latestDatesByPeakId = <int, DateTime>{};
    for (final baggedRow in _peaksBaggedRepository.getAll()) {
      final baggedDate = baggedRow.date;
      if (baggedDate == null) {
        continue;
      }
      final currentDate = latestDatesByPeakId[baggedRow.peakId];
      if (currentDate == null || baggedDate.isAfter(currentDate)) {
        latestDatesByPeakId[baggedRow.peakId] = baggedDate;
      }
    }
    return latestDatesByPeakId;
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
    return _displayRegionKeyForPeak(
          storedPeakRegionKey: peak.region,
          resolvedRegionKey: resolvedRegionKey,
        ) ??
        '';
  }

  String _peakDisplayRegionName(Peak peak) {
    final displayRegionKey = _peakDisplayRegionKey(peak);
    return mapSearchRegionLabel(displayRegionKey) ?? 'Unknown Region';
  }

  String? _displayRegionKeyForPeak({
    required String? storedPeakRegionKey,
    required String? resolvedRegionKey,
  }) {
    if (storedPeakRegionKey != null) {
      final broaderRegionKey = regionManifestCatalog.peakListFilterRegionKey(
        storedPeakRegionKey,
      );
      if (broaderRegionKey != null && broaderRegionKey != storedPeakRegionKey) {
        return storedPeakRegionKey;
      }
    }

    return resolvedRegionKey;
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
        MapSearchResultType.natural => 'Natural',
        MapSearchResultType.road => 'Roads',
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
    required this.displayDate,
  });

  final Peak peak;
  final String displayRegionName;
  final DateTime? displayDate;

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
    return service._peakResult(
      peak,
      regionKey: null,
      displayDate: displayDate,
    )!;
  }
}
