import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/map_search_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/csv_importer.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('empty query returns no results', () async {
    final service = await _service();

    expect(service.searchPeaks(''), isEmpty);
    final page = service.searchPage(
      query: '   ',
      entityFilter: MapSearchEntityFilter.all,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.none,
      offset: 0,
    );

    expect(page.results, isEmpty);
    expect(page.isExhausted, isTrue);
  });

  test(
    'under-threshold trimmed popup query returns no results without peak search work',
    () async {
      final tasmapRepository = await TestTasmapRepository.create();
      final service = MapSearchService(
        peakRepository: PeakRepository.test(_ThrowingPeakStorage()),
        gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        routeRepository: RouteRepository.test(InMemoryRouteStorage()),
        tasmapRepository: tasmapRepository,
      );

      final page = service.searchPage(
        query: ' a ',
        entityFilter: MapSearchEntityFilter.peaks,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        offset: 0,
      );
      expect(page.results, isEmpty);
      expect(page.isExhausted, isTrue);
      expect(MapConstants.searchPopupMinimumQueryLength, 3);
    },
  );

  test(
    'threshold-meeting popup query applies current entity filter region filter and sort',
    () async {
      final service = await _service(
        peaks: [
          Peak(
            osmId: 1,
            name: 'Alpha Peak',
            latitude: -33.7,
            longitude: 149.0,
            elevation: 500,
            region: 'new-south-wales',
          ),
          Peak(
            osmId: 2,
            name: 'Apex Peak',
            latitude: -33.8,
            longitude: 149.1,
            elevation: 510,
            region: 'new-south-wales',
          ),
          _peak(3, 'Tas Peak'),
        ],
        tracks: [_trackAt(1, 'Apex Track', const LatLng(-33.8, 149.1))],
      );

      final page = service.searchPage(
        query: 'pea',
        entityFilter: MapSearchEntityFilter.peaks,
        regionKey: 'new-south-wales',
        sort: MapSearchSort.nameDescending,
        group: MapSearchGroup.none,
        offset: 0,
      );
      final results = page.results;

      expect(results.map((result) => result.type).toSet(), {
        MapSearchResultType.peak,
      });
      expect(results.map((result) => result.title), [
        'Apex Peak',
        'Alpha Peak',
      ]);
      expect(
        results.every((result) => result.regionKey == 'new-south-wales'),
        isTrue,
      );
      expect(page.isExhausted, isTrue);
    },
  );

  test(
    'popup page returns first page and exhaustion metadata for peaks',
    () async {
      final service = await _service(
        peaks: List.generate(
          25,
          (index) =>
              _peak(index + 1, 'Peak ${index.toString().padLeft(2, '0')}'),
        ),
      );

      final firstPage = service.searchPage(
        query: 'peak',
        entityFilter: MapSearchEntityFilter.peaks,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        offset: 0,
      );
      final secondPage = service.searchPage(
        query: 'peak',
        entityFilter: MapSearchEntityFilter.peaks,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        offset: 20,
      );
      final emptyPage = service.searchPage(
        query: 'peak',
        entityFilter: MapSearchEntityFilter.peaks,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        offset: 40,
      );

      expect(firstPage.results, hasLength(20));
      expect(firstPage.results.first.title, 'Peak 00');
      expect(firstPage.isExhausted, isFalse);
      expect(secondPage.results, hasLength(5));
      expect(secondPage.results.first.title, 'Peak 20');
      expect(secondPage.isExhausted, isTrue);
      expect(emptyPage.results, isEmpty);
      expect(emptyPage.isExhausted, isTrue);
    },
  );

  test(
    'all mode preserves one mixed globally sorted list across pages',
    () async {
      final service = await _service(
        peaks: [_peak(1, 'Alpha Peak')],
        tracks: [_track(1, 'Alpha Track')],
        routes: [_route(1, 'Alpha Route')],
        maps: [_resolvedMap()],
      );

      final firstPage = service.searchPage(
        query: 'alpha',
        entityFilter: MapSearchEntityFilter.all,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        offset: 0,
        limit: 2,
      );
      final secondPage = service.searchPage(
        query: 'alpha',
        entityFilter: MapSearchEntityFilter.all,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        offset: 2,
        limit: 2,
      );

      expect(firstPage.results.map((result) => result.title), [
        'Alpha Map',
        'Alpha Peak',
      ]);
      expect(secondPage.results.map((result) => result.title), [
        'Alpha Route',
        'Alpha Track',
      ]);
      expect(firstPage.isExhausted, isFalse);
      expect(secondPage.isExhausted, isTrue);
    },
  );

  test('tracks routes and maps also page with exhaustion metadata', () async {
    final service = await _service(
      tracks: List.generate(
        25,
        (index) =>
            _track(index + 1, 'Track ${index.toString().padLeft(2, '0')}'),
      ),
      maps: List.generate(
        25,
        (index) => _resolvedMapNamed(
          'Map ${index.toString().padLeft(2, '0')}',
          'TS${(index + 1).toString().padLeft(2, '0')}',
        ),
      ),
    );

    final trackFirstPage = service.searchPage(
      query: 'track',
      entityFilter: MapSearchEntityFilter.tracksRoutes,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.none,
      offset: 0,
    );
    final trackSecondPage = service.searchPage(
      query: 'track',
      entityFilter: MapSearchEntityFilter.tracksRoutes,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.none,
      offset: 20,
    );
    final mapFirstPage = service.searchPage(
      query: 'map',
      entityFilter: MapSearchEntityFilter.maps,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.none,
      offset: 0,
    );
    final mapSecondPage = service.searchPage(
      query: 'map',
      entityFilter: MapSearchEntityFilter.maps,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.none,
      offset: 20,
    );

    expect(trackFirstPage.results, hasLength(20));
    expect(trackFirstPage.isExhausted, isFalse);
    expect(trackSecondPage.results, hasLength(5));
    expect(trackSecondPage.isExhausted, isTrue);
    expect(mapFirstPage.results, hasLength(20));
    expect(mapFirstPage.isExhausted, isFalse);
    expect(mapSecondPage.results, hasLength(5));
    expect(mapSecondPage.isExhausted, isTrue);
  });

  test('grouped mode pages from final grouped display order', () async {
    final service = await _service(
      peaks: [_peak(1, 'Alpha Peak')],
      tracks: [_track(1, 'Alpha Track')],
      routes: [_route(1, 'Alpha Route')],
      maps: [_resolvedMap()],
    );

    final firstPage = service.searchPage(
      query: 'alpha',
      entityFilter: MapSearchEntityFilter.all,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.type,
      offset: 0,
      limit: 2,
    );
    final secondPage = service.searchPage(
      query: 'alpha',
      entityFilter: MapSearchEntityFilter.all,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.type,
      offset: 2,
      limit: 2,
    );

    expect(firstPage.results.map((result) => result.type), [
      MapSearchResultType.map,
      MapSearchResultType.peak,
    ]);
    expect(secondPage.results.map((result) => result.type), [
      MapSearchResultType.route,
      MapSearchResultType.track,
    ]);
  });

  test('peak enrichment runs only for the requested page window', () async {
    final tasmapRepository = _CountingTasmapRepository();
    final service = MapSearchService(
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage(
          List.generate(
            30,
            (index) =>
                _peak(index + 1, 'Peak ${index.toString().padLeft(2, '0')}'),
          ),
        ),
      ),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      tasmapRepository: tasmapRepository,
    );

    final page = service.searchPage(
      query: 'peak',
      entityFilter: MapSearchEntityFilter.peaks,
      sort: MapSearchSort.nameAscending,
      group: MapSearchGroup.none,
      offset: 10,
      limit: 5,
    );

    expect(page.results, hasLength(5));
    expect(tasmapRepository.findByPointCallCount, 5);
  });

  test('peak search is case-insensitive and capped', () async {
    final service = await _service(
      peaks: List.generate(25, (index) => _peak(index + 1, 'Peak $index')),
    );

    final results = service.searchPeaks('peak');

    expect(results, hasLength(20));
    expect(results.first.name, 'Peak 0');
  });

  test('generic search returns track route and map results', () async {
    final service = await _service(
      tracks: [_track(1, 'Alpha Track')],
      routes: [_route(1, 'Alpha Route')],
      maps: [_resolvedMap()],
    );

    final results = service.search(
      query: 'alpha',
      entityFilter: MapSearchEntityFilter.all,
      sort: MapSearchSort.nameAscending,
    );

    expect(
      results.map((result) => result.type),
      contains(MapSearchResultType.track),
    );
    expect(
      results.map((result) => result.type),
      contains(MapSearchResultType.route),
    );
    expect(
      results.map((result) => result.type),
      contains(MapSearchResultType.map),
    );
  });

  test('track without runtime geometry is excluded', () async {
    final service = await _service(
      tracks: [GpxTrack(contentHash: 'a', trackName: 'Broken Track')],
    );

    final results = service.search(
      query: 'broken',
      entityFilter: MapSearchEntityFilter.tracksRoutes,
      sort: MapSearchSort.nameAscending,
    );

    expect(results, isEmpty);
  });

  test(
    'region filter uses canonical keys while keeping manifest labels',
    () async {
      final service = await _service(
        peaks: [
          _peak(1, 'Tas Peak'),
          Peak(
            osmId: 2,
            name: 'NSW Peak',
            latitude: -33.7,
            longitude: 149.0,
            elevation: 500,
            region: 'new-south-wales',
          ),
        ],
      );

      final results = service.search(
        query: 'peak',
        entityFilter: MapSearchEntityFilter.peaks,
        regionKey: 'new-south-wales',
        sort: MapSearchSort.nameAscending,
      );

      expect(results, hasLength(1));
      expect(results.single.regionKey, 'new-south-wales');
      expect(results.single.regionName, 'New South Wales');
    },
  );

  test('subregion filter matches peaks by stored peak region only', () async {
    final service = await _service(
      peaks: [
        Peak(
          osmId: 1,
          name: 'FVG Peak',
          latitude: 46.4084,
          longitude: 13.0475,
          elevation: 1906,
          region: 'fvg',
        ),
        Peak(
          osmId: 2,
          name: 'Legacy North East Peak',
          latitude: 46.4084,
          longitude: 13.0475,
          elevation: 1800,
          region: 'italy-nord-est',
        ),
        Peak(
          osmId: 3,
          name: 'Veneto Peak',
          latitude: 45.7332,
          longitude: 10.8061,
          elevation: 2218,
          region: 'veneto',
        ),
      ],
    );

    final results = service.search(
      query: 'peak',
      entityFilter: MapSearchEntityFilter.peaks,
      regionKey: 'fvg',
      sort: MapSearchSort.nameAscending,
    );

    expect(results, hasLength(1));
    expect(results.single.title, 'FVG Peak');
    expect(results.single.regionKey, 'fvg');
    expect(results.single.regionName, 'FVG');
  });

  test(
    'all mode keeps non-peak results on broader model for subregion filter',
    () async {
      final service = await _service(
        peaks: [
          Peak(
            osmId: 1,
            name: 'Alpha Peak',
            latitude: 46.4084,
            longitude: 13.0475,
            elevation: 1906,
            region: 'fvg',
          ),
          Peak(
            osmId: 2,
            name: 'Alpha Veneto Peak',
            latitude: 45.7332,
            longitude: 10.8061,
            elevation: 2218,
            region: 'veneto',
          ),
        ],
        tracks: [_trackAt(1, 'Alpha Track', const LatLng(46.4084, 13.0475))],
      );

      final results = service.search(
        query: 'alpha',
        entityFilter: MapSearchEntityFilter.all,
        regionKey: 'fvg',
        sort: MapSearchSort.nameAscending,
      );

      expect(
        results.map((result) => result.type),
        contains(MapSearchResultType.peak),
      );
      expect(
        results.map((result) => result.type),
        contains(MapSearchResultType.track),
      );
      expect(
        results.where((result) => result.type == MapSearchResultType.peak),
        hasLength(1),
      );
      expect(
        results
            .firstWhere((result) => result.type == MapSearchResultType.peak)
            .title,
        'Alpha Peak',
      );
      expect(
        results
            .firstWhere((result) => result.type == MapSearchResultType.track)
            .regionKey,
        'italy-nord-est',
      );
    },
  );

  test('broader italy north east filter includes subregion peaks', () async {
    final service = await _service(
      peaks: [
        Peak(
          osmId: 1,
          name: 'FVG Peak',
          latitude: 46.4084,
          longitude: 13.0475,
          elevation: 1906,
          region: 'fvg',
        ),
        Peak(
          osmId: 2,
          name: 'Legacy North East Peak',
          latitude: 46.3,
          longitude: 12.9,
          elevation: 1800,
          region: 'italy-nord-est',
        ),
      ],
    );

    final results = service.search(
      query: 'peak',
      entityFilter: MapSearchEntityFilter.peaks,
      regionKey: 'italy-nord-est',
      sort: MapSearchSort.nameAscending,
    );

    expect(results, hasLength(2));
    expect(
      results.map((result) => result.title),
      containsAll(['FVG Peak', 'Legacy North East Peak']),
    );
  });

  test('descending sort reorders results live', () async {
    final service = await _service(
      peaks: [_peak(1, 'Alpha Peak'), _peak(2, 'Beta Peak')],
    );

    final results = service.search(
      query: 'peak',
      entityFilter: MapSearchEntityFilter.peaks,
      sort: MapSearchSort.nameDescending,
    );

    expect(results.first.title, 'Beta Peak');
    expect(results.last.title, 'Alpha Peak');
  });

  test('popup peak search uses the popup-specific repository seam', () async {
    final tasmapRepository = await TestTasmapRepository.create();
    final service = MapSearchService(
      peakRepository: PeakRepository.test(_PopupOnlyPeakStorage()),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      tasmapRepository: tasmapRepository,
    );

    final results = service.search(
      query: 'alpha',
      entityFilter: MapSearchEntityFilter.peaks,
      sort: MapSearchSort.nameAscending,
    );

    expect(results.map((result) => result.title), ['Alpha Peak']);
  });

  test(
    'type grouping can be derived from result kinds and sorted descending',
    () async {
      final service = await _service(
        peaks: [_peak(1, 'Alpha Peak')],
        tracks: [_track(1, 'Alpha Track')],
        routes: [_route(1, 'Alpha Route')],
        maps: [_resolvedMap()],
      );

      final results = service.search(
        query: 'alpha',
        entityFilter: MapSearchEntityFilter.all,
        sort: MapSearchSort.nameDescending,
      );

      expect(
        results.map((result) => result.type),
        contains(MapSearchResultType.peak),
      );
      expect(
        results.map((result) => result.type),
        contains(MapSearchResultType.track),
      );
      expect(
        results.map((result) => result.type),
        contains(MapSearchResultType.route),
      );
      expect(
        results.map((result) => result.type),
        contains(MapSearchResultType.map),
      );
    },
  );
}

Future<MapSearchService> _service({
  List<Peak> peaks = const [],
  List<GpxTrack> tracks = const [],
  List<app_route.Route> routes = const [],
  List<Tasmap50k> maps = const [],
}) async {
  final tasmapRepository = await TestTasmapRepository.create(maps: maps);
  return MapSearchService(
    peakRepository: PeakRepository.test(InMemoryPeakStorage(peaks)),
    gpxTrackRepository: GpxTrackRepository.test(
      InMemoryGpxTrackStorage(tracks),
    ),
    routeRepository: RouteRepository.test(InMemoryRouteStorage(routes)),
    tasmapRepository: tasmapRepository,
  );
}

Peak _peak(int osmId, String name) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: -43,
    longitude: 147,
    elevation: 410,
    region: 'tasmania',
  );
}

GpxTrack _track(int id, String name) {
  return _trackAt(id, name, const LatLng(-43.0, 147.0));
}

GpxTrack _trackAt(int id, String name, LatLng start) {
  final segments = [
    [start, LatLng(start.latitude - 0.001, start.longitude + 0.001)],
  ];
  return GpxTrack(
    gpxTrackId: id,
    contentHash: '$id',
    trackName: name,
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson(segments),
    distance2d: 1200,
    distance3d: 1230,
    highestElevation: 500,
    ascent: 120,
  );
}

app_route.Route _route(int id, String name) {
  return app_route.Route(
    id: id,
    name: name,
    gpxRoute: const [LatLng(-43.0, 147.0), LatLng(-43.002, 147.002)],
    distance2d: 900,
    distance3d: 930,
    ascent: 80,
    descent: 70,
    highestElevation: 450,
  );
}

Tasmap50k _resolvedMap() {
  return _resolvedMapNamed('Alpha Map', 'TS01');
}

Tasmap50k _resolvedMapNamed(String name, String series) {
  const center = LatLng(-43.0, 147.0);
  final vertices = [
    LatLng(center.latitude + 0.05, center.longitude - 0.05),
    LatLng(center.latitude + 0.05, center.longitude + 0.05),
    LatLng(center.latitude - 0.05, center.longitude + 0.05),
    LatLng(center.latitude - 0.05, center.longitude - 0.05),
  ];
  final pointStrings = vertices.map(_pointString).toList(growable: false);
  final mgrsCodes = pointStrings
      .map((point) => point.substring(0, 2))
      .toSet()
      .join(' ');
  return Tasmap50k(
    series: series,
    name: name,
    parentSeries: 'P1',
    mgrs100kIds: mgrsCodes,
    eastingMin: 0,
    eastingMax: 99999,
    northingMin: 0,
    northingMax: 99999,
    p1: pointStrings[0],
    p2: pointStrings[1],
    p3: pointStrings[2],
    p4: pointStrings[3],
  );
}

String _pointString(LatLng point) {
  return mgrs.Mgrs.forward([
    point.longitude,
    point.latitude,
  ], 5).replaceAll(RegExp(r'[\n\s]'), '').substring(3);
}

class _ThrowingPeakStorage implements PeakStorage {
  @override
  int get count => 0;

  @override
  bool get isEmpty => true;

  @override
  Future<void> addMany(List<Peak> peaks) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(int peakId) async {}

  @override
  List<Peak> getAll() {
    throw StateError(
      'Peak search should not execute for under-threshold popup queries',
    );
  }

  @override
  Peak? getById(int peakId) => null;

  @override
  List<Peak> getByName(String query) {
    throw StateError(
      'Peak search should not execute for under-threshold popup queries',
    );
  }

  @override
  List<Peak> getSearchPopupPeakNameCandidates(String query) {
    throw StateError(
      'Popup-specific peak search should not execute for under-threshold queries',
    );
  }

  @override
  Peak put(Peak peak) => peak;

  @override
  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
  }) async {}
}

class _PopupOnlyPeakStorage implements PeakStorage {
  @override
  int get count => 1;

  @override
  bool get isEmpty => false;

  @override
  Future<void> addMany(List<Peak> peaks) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(int peakId) async {}

  @override
  List<Peak> getAll() {
    throw StateError('Popup peak search should not scan all peaks for names');
  }

  @override
  Peak? getById(int peakId) => null;

  @override
  List<Peak> getByName(String query) {
    throw StateError('Popup peak search should not use the generic name seam');
  }

  @override
  List<Peak> getSearchPopupPeakNameCandidates(String query) {
    return [
      Peak(
        osmId: 7,
        name: 'Alpha Peak',
        latitude: -43,
        longitude: 147,
        elevation: 410,
        region: 'tasmania',
      ),
    ];
  }

  @override
  Peak put(Peak peak) => peak;

  @override
  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
  }) async {}
}

class _CountingTasmapRepository implements TasmapRepository {
  int findByPointCallCount = 0;

  @override
  int get mapCount => 0;

  @override
  Future<void> addMaps(List<Tasmap50k> maps) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<TasmapCsvImportResult> clearAndReloadFromCsv(String csvPath) {
    throw UnimplementedError();
  }

  @override
  List<Tasmap50k> findByMgrs100kId(String mgrsCode) => const [];

  @override
  Tasmap50k? findByMgrsCodeAndCoordinates(String mgrsString) => null;

  @override
  List<Tasmap50k> findByName(String name) => const [];

  @override
  Tasmap50k? findByPoint(LatLng point) {
    findByPointCallCount += 1;
    return null;
  }

  @override
  List<Tasmap50k> findBySeries(String series) => const [];

  @override
  List<Tasmap50k> getAllMaps() => const [];

  @override
  LatLngBounds? getMapBounds(Tasmap50k map) => null;

  @override
  LatLng? getMapCenter(Tasmap50k map) => null;

  @override
  List<LatLng> getMapPolygonPoints(Tasmap50k map) => const [];

  @override
  bool isEmpty() => true;

  @override
  Future<TasmapCsvImportResult?> loadFromCsvIfEmpty(String csvPath) async =>
      null;

  @override
  List<Tasmap50k> searchMaps(String prefix) => const [];
}
