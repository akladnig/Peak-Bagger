import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/widgets/left_tooltip_fab.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';
import 'package:peak_bagger/widgets/map_tracks_routes_drawer.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('grouped rail renders icon-only copy and SVG placeholder', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        selectedMap: _selectedMap(),
        tasmapDisplayMode: TasmapDisplayMode.overlay,
      ),
    );

    await _pumpRail(tester, notifier);

    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Loc'), findsOneWidget);
    expect(find.byKey(const Key('map-action-tools-group')), findsOneWidget);
    expect(find.byKey(const Key('map-action-view-group')), findsOneWidget);
    expect(find.byKey(const Key('map-action-location-group')), findsOneWidget);

    expect(
      _messagesFor(find.byKey(const Key('map-action-tools-group')), tester),
      containsAll(<String>['Import GPX', 'Create Route']),
    );
    expect(
      _messagesFor(find.byKey(const Key('map-action-view-group')), tester),
      containsAll(<String>[
        'Select Basemaps',
        'Show Map Grid',
        'Select Peak List',
        'Show Tracks/Routes (T)',
        'Show Trails',
      ]),
    );
    expect(
      _messagesFor(find.byKey(const Key('map-action-location-group')), tester),
      containsAll(<String>[
        'Search Peaks',
        'Goto Location',
        'Center on marker',
        'My location',
      ]),
    );
    expect(
      _messageForButton(find.byKey(const Key('map-info-fab')), tester),
      'Info',
    );

    final createRouteFab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('create-route-fab')),
    );
    expect(createRouteFab.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('create-route-fab')),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapActionRail)),
    );

    await tester.ensureVisible(find.byKey(const Key('grid-map-fab')));
    await tester.pumpAndSettle();
    final gridFab = find.byKey(const Key('grid-map-fab'));
    await tester.tap(gridFab);
    await tester.pump();
    expect(container.read(mapProvider).tasmapDisplayMode, TasmapDisplayMode.none);

    final infoFab = find.byKey(const Key('map-info-fab'));
    await tester.ensureVisible(infoFab);
    await tester.pumpAndSettle();
    await tester.tap(infoFab);
    await tester.pump();
    expect(container.read(mapProvider).showInfoPopup, isTrue);

    final showTrailsFab = find.byKey(const Key('show-trails-fab'));
    await tester.ensureVisible(showTrailsFab);
    await tester.pumpAndSettle();
    await tester.tap(showTrailsFab);
    await tester.pump();
    expect(container.read(mapProvider).showTrails, isTrue);
    expect(find.byKey(const Key('tracks-routes-drawer')), findsNothing);

    final showTracksFab = find.byKey(const Key('show-tracks-fab'));
    await tester.ensureVisible(showTracksFab);
    await tester.pumpAndSettle();
    await tester.tap(showTracksFab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracks-routes-drawer')), findsOneWidget);
  });

  testWidgets('grouped rail fits a short viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpRail(
      tester,
      TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
          selectedMap: _selectedMap(),
          tasmapDisplayMode: TasmapDisplayMode.overlay,
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('map-action-location-group')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final toolsTop = tester.getTopLeft(
      find.byKey(const Key('map-action-tools-group')),
    );
    final toolsBottom = tester.getBottomLeft(
      find.byKey(const Key('map-action-tools-group')),
    );
    final viewTop = tester.getTopLeft(
      find.byKey(const Key('map-action-view-group')),
    );
    final viewBottom = tester.getBottomLeft(
      find.byKey(const Key('map-action-view-group')),
    );
    final locationTop = tester.getTopLeft(
      find.byKey(const Key('map-action-location-group')),
    );
    final infoTop = tester.getTopLeft(find.byKey(const Key('map-info-fab')));

    expect(toolsTop.dy, lessThan(viewTop.dy));
    expect(viewTop.dy, lessThan(locationTop.dy));
    expect(viewTop.dy - toolsBottom.dy, closeTo(UiConstants.groupSpacing, 0.001));
    expect(
      locationTop.dy - viewBottom.dy,
      closeTo(UiConstants.groupSpacing, 0.001),
    );
    expect(infoTop.dy, greaterThan(locationTop.dy));
  });

  testWidgets('route drafting hides tools and location groups', (tester) async {
    await _pumpRail(
      tester,
      TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
          selectedMap: _selectedMap(),
          tasmapDisplayMode: TasmapDisplayMode.overlay,
          isRouteDrafting: true,
        ),
      ),
    );

    expect(find.byKey(const Key('map-action-tools-group')), findsNothing);
    expect(find.byKey(const Key('map-action-location-group')), findsNothing);
    expect(find.byKey(const Key('create-route-fab')), findsNothing);
    expect(find.byKey(const Key('map-action-view-group')), findsOneWidget);
    expect(find.byKey(const Key('map-info-fab')), findsOneWidget);
  });
}

Future<void> _pumpRail(WidgetTester tester, TestMapNotifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        routeRepositoryProvider.overrideWithValue(
          RouteRepository.test(InMemoryRouteStorage()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          endDrawer: const MapTracksRoutesDrawer(),
          body: Stack(children: const [MapActionRail()]),
        ),
      ),
    ),
  );
  await tester.pump();
}

Tasmap50k _selectedMap() {
  return Tasmap50k(
    series: 'TS07',
    name: 'Adamsons',
    parentSeries: '8211',
    mgrs100kIds: 'DM DN',
    eastingMin: 60000,
    eastingMax: 99999,
    northingMin: 80000,
    northingMax: 9999,
    mgrsMid: 'DM',
    eastingMid: 80000,
    northingMid: 95000,
    p1: 'DN6000009999',
    p2: 'DN9999909999',
    p3: 'DM6000080000',
    p4: 'DM9999980000',
  );
}

List<String> _messagesFor(Finder finder, WidgetTester tester) {
  return tester
      .widgetList<LeftTooltipFab>(
        find.descendant(of: finder, matching: find.byType(LeftTooltipFab)),
      )
      .map((widget) => widget.message)
      .toList(growable: false);
}

String _messageForButton(Finder finder, WidgetTester tester) {
  return tester
      .widget<LeftTooltipFab>(
        find.ancestor(of: finder, matching: find.byType(LeftTooltipFab)),
      )
      .message;
}
