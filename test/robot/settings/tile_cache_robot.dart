import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class TileCacheRobot {
  TileCacheRobot(this.tester, this.repository)
      : tasmapNotifier = TestTasmapNotifier(repository);

  final WidgetTester tester;
  final TestTasmapRepository repository;
  final TestTasmapNotifier tasmapNotifier;

  Finder get tileCacheTile => find.text('Map Tile Cache');
  Finder get tileCacheSearchField =>
      find.byKey(const Key('tile-cache-map-search-field'));
  Finder get tileCacheSelectedMapChip =>
      find.byKey(const Key('tile-cache-selected-map-chip'));
  Finder get tileCacheDownloadButton =>
      find.byKey(const Key('tile-cache-download-button'));
  Finder mapSuggestion(int index) =>
      find.byKey(Key('tile-cache-map-suggestion-$index'));

  Future<void> pumpApp({required WidgetBuilder tileCacheBuilder}) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          tasmapStateProvider.overrideWith(() => tasmapNotifier),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: SettingsScreen(
            tileCacheSettingsScreenBuilder: tileCacheBuilder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTileCacheSettings() async {
    await tester.tap(tileCacheTile);
    await tester.pumpAndSettle();
  }

  Future<void> searchMaps(String query) async {
    await tester.scrollUntilVisible(
      tileCacheSearchField,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(tileCacheSearchField, query);
    await tester.pumpAndSettle();
  }

  Future<void> selectMapSuggestion(int index) async {
    await tester.tap(mapSuggestion(index));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToDownloadButton() async {
    await tester.scrollUntilVisible(
      tileCacheDownloadButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapDownload() async {
    await tester.tap(tileCacheDownloadButton);
    await tester.pumpAndSettle();
  }

  void expectSelectedMap(String name) {
    expect(
      find.descendant(
        of: tileCacheSelectedMapChip,
        matching: find.text(name),
      ),
      findsOneWidget,
    );
  }
}
