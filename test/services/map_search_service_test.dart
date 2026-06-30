import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
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
  final segments = [
    [const LatLng(-43.0, 147.0), const LatLng(-43.001, 147.001)],
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
