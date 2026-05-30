import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/route_graph_refresh_service.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('refresh route graph cancel is a no-op', (tester) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(_baseState());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('refresh-route-graph-tile')));
    await tester.pump();

     expect(find.text('Refresh Route Graph?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('route-graph-refresh-cancel')));
    await tester.pump();

    expect(find.byKey(const Key('route-graph-refresh-status')), findsNothing);
  });

  testWidgets('refresh route graph shows loading state', (tester) async {
    final repository = await TestTasmapRepository.create();
    final completer = Completer<RouteGraphRefreshResult>();
    final notifier = TestPeakNotifier(_baseState());
    final service = _TestRouteGraphRefreshService(() => completer.future);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
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

    await tester.tap(find.byKey(const Key('refresh-route-graph-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('route-graph-refresh-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final tile = tester.widget<ListTile>(
      find.byKey(const Key('refresh-route-graph-tile')),
    );
    expect(tile.onTap, isNull);
    expect(service.refreshCallCount, 1);

    completer.complete(const RouteGraphRefreshResult(elementCount: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final resultDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('2 route graph elements refreshed.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('refresh route graph shows result dialog', (tester) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(_baseState());
    final service = _TestRouteGraphRefreshService(
      () async => const RouteGraphRefreshResult(elementCount: 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
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

    await tester.tap(find.byKey(const Key('refresh-route-graph-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('route-graph-refresh-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final resultDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('Route Graph Refreshed'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('12 route graph elements refreshed.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('route-graph-refresh-result-close')), findsOneWidget);
  });

  testWidgets('refresh route graph shows failure dialog', (tester) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(_baseState());
    final service = _TestRouteGraphRefreshService(
      () async {
        throw StateError('boom');
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
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

    await tester.tap(find.byKey(const Key('refresh-route-graph-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('route-graph-refresh-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final failureDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: failureDialog,
        matching: find.text('Route Graph Refresh Failed'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: failureDialog, matching: find.textContaining('boom')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('route-graph-refresh-error-close')), findsOneWidget);
    expect(
      _container(tester).read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.failed,
    );

    await tester.tap(find.byKey(const Key('route-graph-refresh-error-close')));
    await tester.pump();

    expect(
      find.text(
        'Route graph unavailable. Use Refresh Route Graph to retry.',
      ),
      findsOneWidget,
    );
  });
}

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
  );
}

class _TestRouteGraphRefreshService extends RouteGraphRefreshService {
  _TestRouteGraphRefreshService(this._handler) : super(_NoopRouteGraphStore());

  final Future<RouteGraphRefreshResult> Function() _handler;
  int refreshCallCount = 0;

  @override
  Future<RouteGraphRefreshResult> refreshRouteGraph() {
    refreshCallCount += 1;
    return _handler();
  }
}

class _NoopRouteGraphStore implements RouteGraphStore {
  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('settings-scrollable'))),
  );
}
