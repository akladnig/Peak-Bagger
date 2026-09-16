import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets(
    'shared app bar shows left search and filter controls on map route',
    (tester) async {
      await _pumpApp(tester, TestMapNotifier(_baseState()));

      final appBarRect = tester.getRect(
        find.byKey(const Key('shared-app-bar')),
      );
      final searchRect = tester.getRect(
        find.byKey(const Key('app-bar-search-trigger')),
      );
      final filterRect = tester.getRect(
        find.byKey(const Key('app-bar-map-filter-trigger')),
      );
      final dividerRect = tester.getRect(
        find.byKey(const Key('app-bar-map-filter-divider')),
      );

      expect(find.byKey(const Key('shared-app-bar')), findsOneWidget);
      expect(find.byKey(const Key('app-bar-title')), findsOneWidget);
      expect(find.byKey(const Key('app-bar-search-trigger')), findsOneWidget);
      expect(
        find.byKey(const Key('app-bar-map-filter-trigger')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('app-bar-map-filter-divider')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('app-bar-home')), findsNothing);
      expect(searchRect.center.dx, lessThan(appBarRect.center.dx));
      expect(filterRect.left, greaterThan(searchRect.right));
      expect(dividerRect.left, greaterThan(filterRect.right));
    },
  );

  testWidgets('popup renders peak track route and map results', (tester) async {
    final notifier = TestMapNotifier(
      _baseState(),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1, 'Bonnet Track')]),
      ),
      routeRepository: RouteRepository.test(
        InMemoryRouteStorage([_route(1, 'Bonnet Route')]),
      ),
    );
    await _pumpApp(tester, notifier);

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Bonnet Hill'), findsOneWidget);
    expect(find.text('Bonnet Track'), findsOneWidget);
    expect(find.text('Bonnet Route'), findsOneWidget);
  });

  testWidgets('selecting every result clears the prior search selection', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      _stateWithSearchSelection(),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1, 'Bonnet Track')]),
      ),
      routeRepository: RouteRepository.test(
        InMemoryRouteStorage([_route(1, 'Bonnet Route')]),
      ),
    );
    await _pumpApp(tester, notifier);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-search-result-peak-6406')));
    await tester.pumpAndSettle();
    expect(container.read(mapProvider).selectedPeaks.single.osmId, 6406);
    expect(container.read(mapProvider).selectedTrackId, isNull);
    expect(container.read(mapProvider).selectedRouteId, isNull);
    expect(container.read(mapProvider).selectedMap, isNull);

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-search-result-track-1')));
    await tester.pumpAndSettle();
    expect(container.read(mapProvider).selectedTrackId, 1);
    expect(container.read(mapProvider).selectedLocation, isNotNull);
    expect(container.read(mapProvider).selectedPeaks, isEmpty);
    expect(container.read(mapProvider).selectedRouteId, isNull);
    expect(container.read(mapProvider).selectedMap, isNull);

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-search-result-route-1')));
    await tester.pumpAndSettle();
    expect(container.read(mapProvider).selectedRouteId, 1);
    expect(container.read(mapProvider).selectedLocation, isNotNull);
    expect(container.read(mapProvider).selectedPeaks, isEmpty);
    expect(container.read(mapProvider).selectedTrackId, isNull);
    expect(container.read(mapProvider).selectedMap, isNull);

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Alpha');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('map-search-result-map-0:TS01:Alpha Map')),
    );
    await tester.pumpAndSettle();
    expect(container.read(mapProvider).selectedMap?.name, 'Alpha Map');
    expect(container.read(mapProvider).selectedMapFocusSerial, greaterThan(0));
    expect(container.read(mapProvider).selectedPeaks, isEmpty);
    expect(container.read(mapProvider).selectedTrackId, isNull);
    expect(container.read(mapProvider).selectedRouteId, isNull);
  });

  testWidgets(
    'Roads selects a route-graph way at the current zoom and clears selection',
    (tester) async {
      const anchor = LatLng(-43.1, 147.1);
      final notifier = TestMapNotifier(
        _stateWithSearchSelection(),
        namedWaySearch: _FakeNamedWaySearch([
          const NamedRouteGraphWayCandidate(
            osmWayId: 123,
            name: 'Road to Bonnet',
            highway: 'track',
            surface: 'fine_gravel',
            anchor: anchor,
            routingCoverageKey: 'tasmania',
            generation: 1,
            chunkKey: 'chunk-1',
          ),
        ]),
      );
      await _pumpApp(tester, notifier);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      final zoomBeforeSelection = container.read(mapProvider).zoom;

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('map-search-input')), 'Road');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-search-entity-roads')));
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).searchPopupEntityFilter,
        MapSearchEntityFilter.roads,
      );
      expect(
        find.byKey(const Key('map-search-result-road-123')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('map-search-result-road-123')));
      await tester.pumpAndSettle();

      final state = container.read(mapProvider);
      expect(find.byKey(const Key('map-search-popup')), findsNothing);
      expect(state.center, anchor);
      expect(state.zoom, zoomBeforeSelection);
      expect(state.selectedLocation, anchor);
      expect(state.selectedPeaks, isEmpty);
      expect(state.selectedTrackId, isNull);
      expect(state.selectedRouteId, isNull);
      expect(state.selectedMap, isNull);
    },
  );

  testWidgets('search-result selection clears associated popups', (
    tester,
  ) async {
    final notifier = TestMapNotifier(_stateWithSearchSelection());
    await _pumpApp(tester, notifier);
    notifier.state = notifier.state.copyWith(
      driveEtaPopup: const DriveEtaPopupState(
        requestId: 1,
        anchor: LatLng(-43.0, 147.0),
        title: 'Previous result',
        status: DriveEtaPopupStatus.success,
      ),
    );
    await tester.pump();

    notifier.clearSearchResultSelection();

    expect(notifier.state.selectedPeaks, isEmpty);
    expect(notifier.state.selectedTrackId, isNull);
    expect(notifier.state.selectedRouteId, isNull);
    expect(notifier.state.selectedMap, isNull);
    expect(notifier.state.driveEtaPopup, isNull);
  });

  testWidgets('Roads stays enabled without route-graph coverage', (
    tester,
  ) async {
    await _pumpApp(tester, TestMapNotifier(_baseState()));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Road');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-entity-roads')));
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).searchPopupEntityFilter,
      MapSearchEntityFilter.roads,
    );
    expect(find.text('No results found'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, TestMapNotifier notifier) async {
  final tasmapRepository = await TestTasmapRepository.create(
    maps: [_resolvedMap()],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
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

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [_peak(6406, 'Bonnet Hill')],
  );
}

MapState _stateWithSearchSelection() {
  final peak = _peak(6406, 'Bonnet Hill');
  return _baseState().copyWith(
    selectedPeaks: [peak],
    selectedTrackId: 1,
    selectedRouteId: 1,
    selectedMap: _resolvedMap(),
    tasmapDisplayMode: TasmapDisplayMode.selectedMap,
  );
}

class _FakeNamedWaySearch implements NamedRouteGraphWaySearch {
  const _FakeNamedWaySearch(this.candidates);

  final List<NamedRouteGraphWayCandidate> candidates;

  @override
  List<NamedRouteGraphWayCandidate> searchNamedWays(String query) => candidates;
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
