import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/services/route_repository.dart';

import '../map/map_route_robot.dart';

class RouteGraphRobot {
  RouteGraphRobot(
    this.tester,
    MapState initialState, {
    required List<Object> routePlanningOutcomes,
    List<Object> routeElevationOutcomes = const [],
    RouteRepository? routeRepository,
  }) : _robot = MapRouteRobot(
         tester,
         initialState,
         routePlanningOutcomes: routePlanningOutcomes,
         routeElevationOutcomes: routeElevationOutcomes,
         routeRepository: routeRepository,
       );

  final WidgetTester tester;
  final MapRouteRobot _robot;

  Finder get routeLoadingText => find.byKey(const Key('route-loading-text'));
  Finder get routeErrorText => find.byKey(const Key('route-error-text'));
  Finder get routeRetryButton => find.byKey(const Key('route-retry-button'));
  Finder get routeDistanceText => find.byKey(const Key('route-distance-text'));
  Finder get routeBottomSheet => find.byKey(const Key('route-bottom-sheet'));
  Finder get routeSaveButton => find.byKey(const Key('route-save-button'));

  Future<void> pumpApp() => _robot.pumpApp();

  Future<void> openMap() => _robot.openMap();

  Future<void> enterRouteMode() => _robot.enterRouteMode();

  Future<void> tapRoutePoint(Offset offset) => _robot.tapRoutePoint(offset);

  Future<void> enterRouteName(String value) => _robot.enterRouteName(value);

  Future<void> saveRoute() => _robot.saveRoute();

  Future<void> tapRetry() async {
    await tester.tap(routeRetryButton);
    await tester.pumpAndSettle();
  }

  void expectLoadingVisible() {
    expect(routeLoadingText, findsOneWidget);
  }

  void expectErrorVisible(String contains) {
    expect(routeErrorText, findsOneWidget);
    expect(find.textContaining(contains), findsOneWidget);
  }

  void expectRetryVisible() {
    expect(routeRetryButton, findsOneWidget);
  }

  void expectRouteReady() {
    expect(routeLoadingText, findsNothing);
    expect(routeErrorText, findsNothing);
    expect(routeDistanceText, findsOneWidget);
  }

  List<app_route.Route> savedRoutes() => _robot.savedRoutes();

  ProviderContainer container() => _robot.container();
}
