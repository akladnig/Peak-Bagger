import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('peak search opens and closes', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('peak-search-input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-search-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('peak-search-input')), findsNothing);
    expect(container.read(mapProvider).showPeakSearch, isFalse);
  });

  testWidgets('peak search shows empty state for no matches', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('peak-search-input')), 'zzz');
    await tester.pump();

    expect(find.text('No peaks found'), findsOneWidget);
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

    await tester.enterText(
      find.byKey(const Key('peak-search-input')),
      'Bonnet',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ListTile, 'Bonnet Hill'));
    await tester.pump();

    final state = container.read(mapProvider);
    expect(find.byKey(const Key('peak-search-input')), findsNothing);
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

    await tester.enterText(
      find.byKey(const Key('peak-search-input')),
      'Bonnet',
    );
    await tester.pump();

    final tile = find.widgetWithText(ListTile, 'Bonnet Hill');
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('410 m')), findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Resolved Map')),
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

    await tester.enterText(
      find.byKey(const Key('peak-search-input')),
      'Bonnet',
    );
    await tester.pump();

    final tile = find.widgetWithText(ListTile, 'Bonnet Hill');
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('—')), findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Resolved Map')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpMapApp(WidgetTester tester, MapState state) async {
  final tasmapRepository = await TestTasmapRepository.create(
    maps: [
      _resolvedMap(),
    ],
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

String _pointString(LatLng point) {
  return mgrs.Mgrs.forward([point.longitude, point.latitude], 5)
      .replaceAll(RegExp(r'[\n\s]'), '')
      .substring(3);
}
