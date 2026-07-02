import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class AppBarSearchRobot {
  AppBarSearchRobot(this.tester);

  final WidgetTester tester;

  Finder get searchTrigger => find.byKey(const Key('app-bar-search-trigger'));
  Finder get searchInput => find.byKey(const Key('map-search-input'));

  Future<void> pumpApp() async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([_peak(6406, 'Bonnet Hill')]),
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: LatLngBounds(
          const LatLng(-43.5, 145.5),
          const LatLng(-40.5, 148.5),
        ),
        peaks: [_peak(6406, 'Bonnet Hill')],
      ),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1, 'Bonnet Track')]),
      ),
      peakRepository: peakRepository,
      routeRepository: RouteRepository.test(
        InMemoryRouteStorage([_route(1, 'Bonnet Route')]),
      ),
    );
    final tasmapRepository = await TestTasmapRepository.create(
      maps: [_resolvedMap()],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          peakRepositoryProvider.overrideWithValue(peakRepository),
          tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(tasmapRepository),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openFromAppBar() async {
    await tester.tap(searchTrigger);
    await tester.pumpAndSettle();
  }

  Future<void> openFromKeyboard() async {
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      platform: 'macos',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, platform: 'macos');
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF, platform: 'macos');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');
  }

  Future<void> enterQuery(String query) async {
    await tester.enterText(searchInput, query);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  }

  Future<void> tapPeakResult() async {
    await tester.tap(find.byKey(const Key('map-search-result-peak-6406')));
    await tester.pumpAndSettle();
  }

  Future<void> tapTrackResult() async {
    await tester.tap(find.byKey(const Key('map-search-result-track-1')));
    await tester.pumpAndSettle();
  }

  Future<void> tapRouteResult() async {
    await tester.tap(find.byKey(const Key('map-search-result-route-1')));
    await tester.pumpAndSettle();
  }

  Future<void> tapMapResult() async {
    await tester.tap(
      find.byKey(const Key('map-search-result-map-0:TS01:Alpha Map')),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer container() {
    return ProviderScope.containerOf(tester.element(searchTrigger));
  }
}

Peak _peak(int osmId, String name) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: -43.0,
    longitude: 147.0,
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
    gpxRoute: const [LatLng(-43.0, 147.0), LatLng(-43.001, 147.001)],
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
