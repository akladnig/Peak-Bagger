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
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('app bar search opens and closes', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('map-search-input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-search-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('map-search-input')), findsNothing);
    expect(container.read(mapProvider).showPeakSearch, isFalse);
  });

  testWidgets('search opens with default filter region sort and empty query', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    final state = container.read(mapProvider);
    expect(state.searchPopupEntityFilter, MapSearchEntityFilter.all);
    expect(state.searchPopupRegionKey, 'tasmania');
    expect(state.searchPopupSort, MapSearchSort.nameAscending);
    expect(state.searchPopupGroup, MapSearchGroup.none);
    expect(state.searchPopupQuery, isEmpty);
  });

  testWidgets('peak search shows empty state for no matches', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'zzz');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('selecting a peak search result centers on the peak', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.widgetWithText(ListTile, 'Bonnet Hill'));
    await tester.pump();

    final state = container.read(mapProvider);
    expect(find.byKey(const Key('map-search-input')), findsNothing);
    expect(state.selectedPeaks.map((peak) => peak.osmId), contains(6406));
    expect(state.center, const LatLng(-43.0, 147.0));
    expect(state.selectedLocation, isNull);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
  });

  testWidgets('peak search result shows height and map name', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));

    final tile = find.widgetWithText(ListTile, 'Bonnet Hill');
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('410 m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('Resolved Map')),
      findsOneWidget,
    );
  });

  testWidgets('peak search result shows a dash for unknown height', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithUnknownHeightPeak());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));

    final tile = find.widgetWithText(ListTile, 'Bonnet Hill');
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('—')), findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.textContaining('Resolved Map')),
      findsOneWidget,
    );
  });

  testWidgets(
    'entity buttons filter results and disabled placeholders stay inert',
    (tester) async {
      final trackRepository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1, 'Bonnet Track')]),
      );
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final notifier = TestMapNotifier(
        _mapStateWithPeaks(),
        gpxTrackRepository: trackRepository,
        routeRepository: routeRepository,
      );
      await _pumpMapAppWithNotifier(tester, notifier);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-search-input')),
        'Bonnet',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('map-search-result-track-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('map-search-entity-peaks')));
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).searchPopupEntityFilter,
        MapSearchEntityFilter.peaks,
      );
      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-search-result-track-1')), findsNothing);

      final naturalButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('map-search-entity-natural')),
      );
      expect(naturalButton.onPressed, isNull);
    },
  );

  testWidgets('region menu shows manifest labels and stores canonical key', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('map-search-filter-button')));
    await tester.tap(find.byKey(const Key('map-search-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tasmania'), findsWidgets);
    await tester.tap(find.byKey(const Key('map-search-region-tasmania')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupRegionKey, 'tasmania');

    await tester.ensureVisible(find.byKey(const Key('map-search-filter-button')));
    await tester.tap(find.byKey(const Key('map-search-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-region-none')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupRegionKey, isNull);

    final filterButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const Key('map-search-filter-trigger')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(filterButton.style, isNotNull);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('subregion menu options are available before typing and update label', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('No results found'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('map-search-filter-button')));
    await tester.tap(find.byKey(const Key('map-search-filter-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-search-region-fvg')), findsWidgets);
    expect(find.byKey(const Key('map-search-region-veneto')), findsWidgets);
    expect(
      find.byKey(const Key('map-search-region-trentino-alto-adige')),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('map-search-region-emilia-romagna')),
      findsWidgets,
    );
    expect(find.text('Italy North East'), findsWidgets);

    await tester.tap(find.byKey(const Key('map-search-region-fvg')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupRegionKey, 'fvg');
    expect(find.text('FVG'), findsOneWidget);
  });

  testWidgets('group menu stores selection and groups by type', (tester) async {
    final trackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([_track(1, 'A Track')]),
    );
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([_route(1, 'A Route')]),
    );
    final notifier = TestMapNotifier(
      _mapStateForGrouping(),
      gpxTrackRepository: trackRepository,
      routeRepository: routeRepository,
    );
    await _pumpMapAppWithNotifier(tester, notifier);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'A');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('map-search-group-button')));
    await tester.tap(find.byKey(const Key('map-search-group-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-group-type')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupGroup, MapSearchGroup.type);
    expect(
      find.byKey(const Key('map-search-group-header-peaks')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map-search-group-header-tracks-routes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map-search-group-header-maps')),
      findsOneWidget,
    );
  });

  testWidgets('group menu groups by region and clears back to none', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithRegionalPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    container.read(mapProvider.notifier).setSearchPopupRegionKey(null);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-search-entity-peaks')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Peak');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('map-search-group-button')));
    await tester.tap(find.byKey(const Key('map-search-group-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-group-region')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupGroup, MapSearchGroup.region);
    expect(
      find.byKey(const Key('map-search-group-header-tasmania')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map-search-group-header-new-south-wales')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('map-search-group-button')));
    await tester.tap(find.byKey(const Key('map-search-group-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-group-none')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupGroup, MapSearchGroup.none);
    expect(find.text('Group'), findsOneWidget);
  });
}

Future<void> _pumpMapApp(WidgetTester tester, MapState state) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  final tasmapRepository = await TestTasmapRepository.create(
    maps: [_resolvedMap()],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
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

Future<void> _pumpMapAppWithNotifier(
  WidgetTester tester,
  MapNotifier notifier,
) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  final tasmapRepository = await TestTasmapRepository.create(
    maps: [_resolvedMap()],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
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

MapState _mapStateWithPeaks() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
        gridZoneDesignator: '55G',
        mgrs100kId: 'AB',
        easting: '12345',
        northing: '54321',
      ),
      Peak(
        osmId: 7000,
        name: 'Other Peak',
        latitude: -42.9,
        longitude: 147.1,
        elevation: 380,
        gridZoneDesignator: '55G',
        mgrs100kId: 'AB',
        easting: '12346',
        northing: '54322',
      ),
    ],
  );
}

MapState _mapStateWithUnknownHeightPeak() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -43.0,
        longitude: 147.0,
        elevation: null,
        gridZoneDesignator: '55G',
        mgrs100kId: 'AB',
        easting: '12345',
        northing: '54321',
      ),
    ],
  );
}

MapState _mapStateForGrouping() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'A Peak',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
        region: 'tasmania',
      ),
    ],
  );
}

MapState _mapStateWithRegionalPeaks() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Tas Peak',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
        region: 'tasmania',
      ),
      Peak(
        osmId: 7000,
        name: 'NSW Peak',
        latitude: -33.7,
        longitude: 149.0,
        elevation: 500,
        region: 'new-south-wales',
      ),
    ],
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
    name: 'Resolved Map',
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

String _pointString(LatLng point) {
  return mgrs.Mgrs.forward([
    point.longitude,
    point.latitude,
  ], 5).replaceAll(RegExp(r'[\n\s]'), '').substring(3);
}
