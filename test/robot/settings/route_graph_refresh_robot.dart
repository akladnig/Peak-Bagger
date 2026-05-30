import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/route_graph_refresh_service.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class RouteGraphRefreshRobot {
  RouteGraphRefreshRobot(
    this.tester,
    this.repository,
    this.notifier,
    this.service,
  ) : tasmapNotifier = TestTasmapNotifier(repository);

  final WidgetTester tester;
  final TestTasmapRepository repository;
  final TestPeakNotifier notifier;
  final TestTasmapNotifier tasmapNotifier;
  final RouteGraphRefreshService service;

  Finder get refreshRouteGraphTile =>
      find.byKey(const Key('refresh-route-graph-tile'));
  Finder get routeGraphRefreshConfirm =>
      find.byKey(const Key('route-graph-refresh-confirm'));
  Finder get routeGraphRefreshCancel =>
      find.byKey(const Key('route-graph-refresh-cancel'));
  Finder get routeGraphRefreshStatus =>
      find.byKey(const Key('route-graph-refresh-status'));
  Finder get routeGraphRefreshResultClose =>
      find.byKey(const Key('route-graph-refresh-result-close'));
  Finder get routeGraphRefreshErrorClose =>
      find.byKey(const Key('route-graph-refresh-error-close'));
  Finder get settingsScrollable => find.byType(Scrollable).last;

  Future<void> pumpApp() async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(() => tasmapNotifier),
          tasmapRepositoryProvider.overrideWithValue(repository),
          routeGraphRefreshServiceProvider.overrideWithValue(service),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openRefreshDialog() async {
    await tester.scrollUntilVisible(
      refreshRouteGraphTile,
      200,
      scrollable: settingsScrollable,
    );
    await tester.tap(refreshRouteGraphTile);
    await tester.pump();
  }

  Future<void> confirmRefresh() async {
    await tester.tap(routeGraphRefreshConfirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> cancelRefresh() async {
    await tester.tap(routeGraphRefreshCancel);
    await tester.pump();
  }

  void expectConfirmDialogVisible() {
    expect(find.text('Refresh Route Graph?'), findsOneWidget);
  }

  void expectStatusVisible(String expected) {
    final text = tester.widget<Text>(routeGraphRefreshStatus);
    expect(text.data, expected);
  }

  void expectResultVisible() {
    expect(find.text('Route Graph Refreshed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('route graph elements refreshed.'),
      ),
      findsOneWidget,
    );
    expect(routeGraphRefreshResultClose, findsOneWidget);
  }

  void expectFailureVisible(String contains) {
    expect(find.text('Route Graph Refresh Failed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(contains),
      ),
      findsOneWidget,
    );
    expect(routeGraphRefreshErrorClose, findsOneWidget);
  }
}

class ReadyRouteGraphStore implements RouteGraphStore {
  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
