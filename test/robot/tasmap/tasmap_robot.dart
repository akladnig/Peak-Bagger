import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';

import '../../harness/test_tasmap_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class TasmapRobot {
  TasmapRobot(this.tester, this.initialState, this.repository)
    : mapNotifier = TestTasmapMapNotifier(initialState, repository),
      tasmapNotifier = TestTasmapNotifier(repository);

  final WidgetTester tester;
  final MapState initialState;
  final TestTasmapRepository repository;
  final TestTasmapMapNotifier mapNotifier;
  final TestTasmapNotifier tasmapNotifier;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get gotoMapFab => find.byKey(const Key('goto-map-fab'));
  Finder get gotoMapInput => find.byKey(const Key('goto-map-input'));
  Finder get gotoMapSubmit => find.byKey(const Key('goto-map-submit'));
  Finder get resetMapDataTile => find.byKey(const Key('reset-map-data-tile'));
  Finder get tasmapOutlineLayer =>
      find.byKey(const Key('tasmap-outline-layer'));

  Future<void> openSettings() async {
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> returnToMap() async {
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> resetTasmapData() async {
    await tester.tap(resetMapDataTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openGotoInput() async {
    await tester.tap(gotoMapFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enterGotoQuery(String query) async {
    await tester.enterText(gotoMapInput, query);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> selectGotoSuggestion(String mapName) async {
    await tester.tap(find.widgetWithText(ListTile, mapName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectMapReady() {
    expect(mapInteractionRegion, findsOneWidget);
    expect(gotoMapFab, findsOneWidget);
  }

  void expectResetStatusVisible() {
    expect(find.text('Map data reset successfully!'), findsWidgets);
  }

  void expectSelectedMapOutlineVisible() {
    expect(find.byType(TasmapOutlineLayer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TasmapOutlineLayer),
        matching: find.byType(PolygonLayer),
      ),
      findsOneWidget,
    );
  }

  void expectSelectedMapLabelVisible(String expectedLabel) {
    final layerFinder = find.descendant(
      of: find.byKey(const Key('tasmap-layer')),
      matching: find.byType(PolygonLayer),
    );

    expect(layerFinder, findsOneWidget);

    final layer = tester.widget<PolygonLayer>(layerFinder);
    expect(layer.polygons, hasLength(1));
    expect(layer.polygons.single.label, expectedLabel);
  }

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          tasmapStateProvider.overrideWith(() => tasmapNotifier),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> dispose() async {
    await repository.dispose();
  }
}
