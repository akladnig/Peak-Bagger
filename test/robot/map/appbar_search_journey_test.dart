import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/map_search_service.dart';

import 'appbar_search_robot.dart';

void main() {
  testWidgets('journey: open from app bar and select peak', (tester) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromAppBar();
    await robot.enterQuery('Bonnet');
    await robot.tapPeakResult();

    final state = robot.container().read(mapProvider);
    expect(state.selectedPeaks.map((peak) => peak.osmId), contains(6406));
  });

  testWidgets('journey: open from cmd+f and select track', (tester) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromKeyboard();
    await robot.enterQuery('Bonnet');
    await robot.tapTrackResult();

    final state = robot.container().read(mapProvider);
    expect(state.selectedTrackId, 1);
    expect(state.selectedLocation, isNotNull);
  });

  testWidgets('journey: select route and map results', (tester) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromAppBar();
    await robot.enterQuery('Bonnet');
    await robot.tapRouteResult();

    var state = robot.container().read(mapProvider);
    expect(state.selectedRouteId, 1);

    await robot.openFromAppBar();
    await robot.enableMapsCategory();
    await robot.enterQuery('Alpha');
    await robot.tapMapResult();

    state = robot.container().read(mapProvider);
    expect(state.selectedMap?.name, 'Alpha Map');
    expect(state.selectedMapFocusSerial, greaterThan(0));
  });

  testWidgets('journey: select Natural result navigates without selection', (
    tester,
  ) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();
    robot
        .container()
        .read(mapProvider.notifier)
        .setSelectedLocation(const LatLng(-43.0, 147.0));
    await tester.pump();

    await robot.openFromAppBar();
    final openState = robot.container().read(mapProvider);
    expect(openState.searchPopupCategories, MapSearchService.defaultCategories);
    expect(find.byKey(const Key('map-search-entity-natural')), findsOneWidget);

    await robot.enterQuery('echo');
    expect(
      find.byKey(const Key('map-search-result-natural-way-12345')),
      findsOneWidget,
    );
    await robot.tapNaturalResult();

    final state = robot.container().read(mapProvider);
    expect(find.byKey(const Key('map-search-popup')), findsNothing);
    expect(state.selectedLocation, isNull);
    expect(state.selectedPeaks, isEmpty);
    expect(state.peakInfo, isNull);
    expect(state.center.latitude, closeTo(-42.75, 0.000001));
    expect(state.center.longitude, closeTo(147.25, 0.000001));
    expect(state.zoom, MapConstants.defaultZoom);
  });

  testWidgets('journey: picker date selects matching track and bagged peak', (
    tester,
  ) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromAppBar();
    await robot.selectTrackDate('28 Jul 1962');
    expect(find.byKey(const Key('map-search-result-track-1')), findsOneWidget);
    expect(
      find.byKey(const Key('map-search-result-peak-6406')),
      findsOneWidget,
    );
    await robot.tapTrackResult();

    var state = robot.container().read(mapProvider);
    expect(state.selectedTrackId, 1);

    await robot.openFromAppBar();
    await robot.selectTrackDate('28 Jul 1962');
    await robot.tapPeakResult();

    state = robot.container().read(mapProvider);
    expect(state.selectedPeaks.map((peak) => peak.osmId), contains(6406));
  });

  testWidgets('journey: typed single date and range search tracks', (
    tester,
  ) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromAppBar();
    await robot.enterQuery('28 Jul 62');
    expect(find.byKey(const Key('map-search-result-track-1')), findsOneWidget);
    expect(find.byKey(const Key('map-search-result-track-2')), findsNothing);

    await robot.enterQuery('28/7/62..30/7/62');
    expect(find.byKey(const Key('map-search-result-track-1')), findsOneWidget);
    expect(find.byKey(const Key('map-search-result-track-2')), findsOneWidget);
  });
}
