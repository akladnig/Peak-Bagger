import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/services/tile_cache_download_scope.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/mapping_catalog_fixture.dart';
import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({
      'gpx_filter_outlier_filter': 'hampel',
      'gpx_filter_elevation_smoother': 'median',
      'gpx_filter_position_smoother': 'movingAverage',
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'all Settings selectors preserve options, no-op Enter and commit ($scale)',
      (tester) async {
        final container = await _pump(tester, scale: scale);
        final prefs = await SharedPreferences.getInstance();
        await _reveal(tester, 'gpx-filter-settings-section');
        await tester.tap(find.text('Track Filter'));
        await tester.pumpAndSettle();
        final cases = <({String key, List<Object> values})>[
          (key: 'gpx-filter-hampel-window', values: [5, 7, 9, 11]),
          (key: 'gpx-filter-elevation-window', values: [5, 7, 9]),
          (key: 'gpx-filter-position-window', values: [3, 5, 7]),
          (
            key: 'gpx-filter-outlier-filter',
            values: GpxTrackOutlierFilter.values,
          ),
          (
            key: 'gpx-filter-elevation-smoother',
            values: GpxTrackElevationSmoother.values,
          ),
          (
            key: 'gpx-filter-position-smoother',
            values: GpxTrackPositionSmoother.values,
          ),
          (
            key: 'theme-scheme-variant-dropdown',
            values: DynamicSchemeVariant.values,
          ),
          (
            key: 'peak-correlation-distance-meters',
            values: peakCorrelationDistanceOptions,
          ),
          (
            key: 'peak-correlation-elevation-meters',
            values: peakCorrelationElevationOptions,
          ),
        ];
        for (final entry in cases) {
          await _reveal(tester, entry.key);
          final finder = find.byKey(ValueKey(entry.key));
          final before = tester.widget<SharedDropdown<dynamic>>(finder);
          expect(before.trigger, SharedDropdownTrigger.labelledField);
          expect(before.rows, SharedDropdownRows.labelOnly);
          expect(before.choices.map((c) => c.value), entry.values);
          final committed = before.value;
          final stored = {
            for (final key in prefs.getKeys()) key: prefs.get(key),
          };
          final width = tester.getSize(_trigger(entry.key)).width;
          await tester.tap(_trigger(entry.key));
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(
            tester.widget<SharedDropdown<dynamic>>(finder).value,
            committed,
          );
          expect({
            for (final key in prefs.getKeys()) key: prefs.get(key),
          }, stored);
          await tester.tap(_trigger(entry.key));
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          final next =
              entry.values[(entry.values.indexOf(committed) + 1) %
                  entry.values.length];
          expect(tester.widget<SharedDropdown<dynamic>>(finder).value, next);
          expect(tester.getSize(_trigger(entry.key)).width, width);
          expect(tester.takeException(), isNull);
        }
        // A dependency changes synchronously before the old widget rebuilds.
        await container
            .read(gpxFilterSettingsProvider.notifier)
            .setOutlierFilter(GpxTrackOutlierFilter.hampel);
        await _reveal(tester, 'gpx-filter-hampel-window');
        final stale = tester
            .widget<SharedDropdown<int>>(
              find.byKey(const Key('gpx-filter-hampel-window')),
            )
            .onSelected;
        final notifier = container.read(gpxFilterSettingsProvider.notifier);
        final pending = notifier.setOutlierFilter(GpxTrackOutlierFilter.none);
        final previousWindow = container
            .read(gpxFilterSettingsProvider)
            .requireValue
            .hampelWindow;
        stale(11);
        await pending;
        expect(
          container.read(gpxFilterSettingsProvider).requireValue.hampelWindow,
          previousWindow,
        );
      },
    );
  }

  testWidgets(
    'Tile Cache Search selects all only in its active eligible surface',
    (tester) async {
      await _pump(tester, tileCache: true);
      final fieldFinder = find.byKey(const Key('tile-cache-map-search-field'));
      await _reveal(tester, 'tile-cache-map-search-field', tileCache: true);
      final field = tester.widget<TextField>(fieldFinder);
      expect(field.decoration!.labelText, 'Search ⌘F');
      expect(field.decoration!.hintText, 'Search Tasmap sheets');
      expect(
        tester.getSemantics(fieldFinder).getSemanticsData().label,
        contains('Tile Cache map-sheet Search'),
      );
      await tester.enterText(fieldFinder, 'existing query');
      await _findShortcut(tester);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 14),
      );
      expect(field.controller!.text, 'existing query');

      await _reveal(tester, 'tile-cache-min-zoom', tileCache: true);
      await tester.tap(_trigger('tile-cache-min-zoom'));
      await tester.pumpAndSettle();
      field.controller!.selection = const TextSelection.collapsed(offset: 2);
      await _findShortcut(tester);
      expect(field.controller!.selection.extentOffset, 2);
      expect(find.byKey(const Key('shared-dropdown-menu')), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(TileCacheSettingsScreen), findsOneWidget);
      expect(find.byKey(const Key('shared-dropdown-menu')), findsNothing);

      final context = tester.element(fieldFinder);
      final dialog = showDialog<void>(
        context: context,
        requestFocus: false,
        builder: (_) => const AlertDialog(content: Text('Obscuring dialog')),
      );
      await tester.pumpAndSettle();
      await _findShortcut(tester);
      expect(field.controller!.selection.extentOffset, 2);
      Navigator.of(context).pop();
      await dialog;
      await tester.pumpAndSettle();
      // No queued focus/select-all after the obscuring surface closes.
      expect(field.controller!.selection.extentOffset, 2);
      await _findShortcut(tester);
      expect(field.controller!.selection.extentOffset, 14);
      final page = Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other route')),
        ),
      );
      await tester.pumpAndSettle();
      field.controller!.selection = const TextSelection.collapsed(offset: 3);
      await _findShortcut(tester);
      expect(field.controller!.selection.extentOffset, 3);
      Navigator.of(tester.element(find.text('Other route'))).pop();
      await page;
      await tester.pumpAndSettle();
      expect(field.controller!.selection.extentOffset, 3);
    },
  );

  testWidgets(
    'Tile zoom menus retain 0–18 order, bounded values, locks and cleanup',
    (tester) async {
      final progress = StreamController<DownloadProgress>();
      addTearDown(() {
        unawaited(progress.close());
      });
      await _pump(
        tester,
        tileCache: true,
        starter:
            ({required basemap, required region, required skipExistingTiles}) =>
                (
                  tileEvents: const Stream<TileEvent>.empty(),
                  downloadProgress: progress.stream,
                ),
      );
      for (final key in ['tile-cache-min-zoom', 'tile-cache-max-zoom']) {
        await _reveal(tester, key, tileCache: true);
        final finder = find.byKey(ValueKey(key));
        final dropdown = tester.widget<SharedDropdown<int>>(finder);
        expect(
          dropdown.choices.map((c) => c.value),
          List.generate(19, (i) => i),
        );
        await tester.tap(_trigger(key));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        expect(
          tester.widget<SharedDropdown<int>>(finder).value,
          dropdown.value,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          tester.widget<SharedDropdown<int>>(finder).value,
          dropdown.value + 1,
        );
      }
      final stale = tester
          .widget<SharedDropdown<int>>(
            find.byKey(const Key('tile-cache-max-zoom')),
          )
          .onSelected;
      await _reveal(tester, 'tile-cache-download-button', tileCache: true);
      final download = tester
          .widget<ListTile>(find.byKey(const Key('tile-cache-download-button')))
          .onTap!;
      download();
      stale(18);
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('tile-cache-map-search-field')),
      );
      field.controller!.selection = const TextSelection.collapsed(offset: 1);
      await _findShortcut(tester);
      expect(field.controller!.selection.extentOffset, 1);
      expect(
        tester
            .widget<SharedDropdown<int>>(
              find.byKey(const Key('tile-cache-max-zoom')),
            )
            .value,
        15,
      );
      expect(field.enabled, isFalse);
      await progress.close();
      await tester.pumpAndSettle();
      expect(field.controller!.selection.extentOffset, 1);
      await _reveal(tester, 'tile-cache-max-zoom', tileCache: true);
      await tester.tap(_trigger('tile-cache-max-zoom'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1600, 1100);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-dropdown-menu')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double scale = 1,
  bool tileCache = false,
  TileCacheDownloadStarter? starter,
}) async {
  tester.view.physicalSize = const Size(1280, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = await TestTasmapRepository.create();
  addTearDown(repository.dispose);
  final container = ProviderContainer(
    overrides: [
      ...mappingCatalogTestOverrides,
      mapProvider.overrideWith(
        () => TestMapNotifier(
          const MapState(
            center: LatLng(-41.5, 146.5),
            zoom: 10,
            basemap: Basemap.tracestrack,
          ),
        ),
      ),
      tasmapRepositoryProvider.overrideWithValue(repository),
      tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: MyTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: tileCache
            ? TileCacheSettingsScreen(downloadStarter: starter)
            : const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _reveal(
  WidgetTester tester,
  String key, {
  bool tileCache = false,
}) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byKey(
            ValueKey(
              tileCache ? 'tile-cache-scrollable' : 'settings-scrollable',
            ),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (key.startsWith('gpx-filter-') && key != 'gpx-filter-settings-section') {
      await tester.scrollUntilVisible(
        find.byKey(const Key('gpx-filter-settings-section')),
        200,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('Track Filter'));
      if (finder.evaluate().isEmpty) {
        await tester.tap(find.text('Track Filter'));
        await tester.pumpAndSettle();
      }
    }
    await tester.scrollUntilVisible(
      finder,
      200,
      maxScrolls: 80,
      scrollable: find
          .descendant(
            of: find.byKey(
              ValueKey(
                tileCache ? 'tile-cache-scrollable' : 'settings-scrollable',
              ),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _trigger(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(InputDecorator),
);

Future<void> _findShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}
