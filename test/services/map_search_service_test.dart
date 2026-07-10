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
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('empty query returns no results', () async {
    final service = await _service();

    expect(service.searchPeaks(''), isEmpty);
    expect(
      service.search(
        query: '   ',
        entityFilter: MapSearchEntityFilter.all,
        sort: MapSearchSort.nameAscending,
      ),
      isEmpty,
    );
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

      expect(
        service.search(
          query: ' a ',
          entityFilter: MapSearchEntityFilter.peaks,
          sort: MapSearchSort.nameAscending,
        ),
        isEmpty,
      );
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

      final results = service.search(
        query: 'pea',
        entityFilter: MapSearchEntityFilter.peaks,
        regionKey: 'new-south-wales',
        sort: MapSearchSort.nameDescending,
      );

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
    },
  );

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
    series: 'TS01',
    name: 'Alpha Map',
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
