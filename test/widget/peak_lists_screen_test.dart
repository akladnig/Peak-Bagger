import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_region_filter_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_mini_map_cluster_display_settings_provider.dart';
import 'package:peak_bagger/providers/peak_marker_info_settings_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/map_screen_peak_layer.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/services/fab_colour_resolver.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_peak_list_file_picker.dart';
import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_repository.dart';

final Expando<List<PeakListItem>> _registeredPeakListItems = Expando<List<PeakListItem>>();

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('empty state renders copy and shell panes', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    expect(find.byKey(const Key('peak-lists-summary-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-details-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-mini-map')), findsOneWidget);
    expect(find.byKey(const Key('shared-app-bar')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-app-bar-content')), findsOneWidget);
    expect(
      find.byKey(const Key('peak-lists-region-fab-scroller')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-lists-add-list-fab')), findsNothing);
    expect(find.byKey(const Key('peak-lists-import-fab')), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const Key('peak-lists-import-fab')),
          )
          .mouseCursor,
      SystemMouseCursors.click,
    );
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const Key('peak-lists-import-fab')),
          )
          .backgroundColor,
      Colors.transparent,
    );
    final summaryHeaderCenter = tester.getCenter(
      find.byKey(const Key('peak-lists-summary-header')),
    );
    final summaryPaneRect = tester.getRect(
      find.byKey(const Key('peak-lists-summary-pane')),
    );
    final importFabRect = tester.getRect(
      find.byKey(const Key('peak-lists-import-fab')),
    );
    expect(
      tester.getCenter(find.byKey(const Key('peak-lists-import-fab'))).dy,
      closeTo(summaryHeaderCenter.dy + 10, 1),
    );
    expect(importFabRect.right, lessThanOrEqualTo(summaryPaneRect.right));
    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
    expect(
      find.text('No peak lists exist. Import a CSV to get started.'),
      findsNWidgets(2),
    );
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Peak Name'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Ascent\nDate'), findsOneWidget);
    expect(find.text('Ascents'), findsWidgets);
    expect(find.text('Difficulty'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
  });

  testWidgets('peaks app bar renders manifest-backed region fabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semanticsHandle = tester.ensureSemantics();

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    final appBarRect = tester.getRect(find.byKey(const Key('shared-app-bar')));
    expect(appBarRect.height, closeTo(kToolbarHeight, 1));

    final titleRect = tester.getRect(find.byKey(const Key('app-bar-title')));
    final firstFabRect = tester.getRect(
      find.byKey(const Key('peak-lists-region-fab-tasmania')),
    );
    final scrollerRect = tester.getRect(
      find.byKey(const Key('peak-lists-region-fab-scroller')),
    );
    expect(firstFabRect.left, greaterThan(titleRect.right));
    expect(firstFabRect.center.dy, closeTo(titleRect.center.dy, 1));
    expect(scrollerRect.right, greaterThan(appBarRect.center.dx));

    for (final (index, regionKey, shortName, fullName) in const [
      (0, 'tasmania', 'Tas', 'Tasmania'),
      (1, 'italy-nord-est', 'Italy NE', 'Italy North East'),
      (2, 'italy-nord-ovest', 'Italy NW', 'Italy North West'),
      (3, 'slovenia', 'Slovenia', 'Slovenia'),
    ]) {
      final buttonFinder = find.byKey(Key('peak-lists-region-fab-$regionKey'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text(shortName), findsOneWidget);
      expect(_tooltipMessageFor(tester, regionKey), fullName);
      final button = tester.widget<OutlinedButton>(buttonFinder);
      final backgroundColor = button.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      );
      expect(backgroundColor, Color(defaultFABPalette[index]));
      expect(find.bySemanticsLabel(fullName), findsOneWidget);
    }

    expect(find.byKey(const Key('peak-lists-add-list-fab')), findsNothing);
    expect(find.byKey(const Key('peak-lists-import-fab')), findsOneWidget);

    final sloveniaFinder = find.byKey(
      const Key('peak-lists-region-fab-slovenia'),
    );
    await tester.ensureVisible(sloveniaFinder);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(sloveniaFinder).center.dy,
      closeTo(appBarRect.center.dy, 1),
    );

    semanticsHandle.dispose();
  });

  testWidgets('selected peak rows use shared elevation formatting', (
    tester,
  ) async {
    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Giants', [100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Big Peak', -42.0, 146.0, elevation: 12345),
        ]),
      ),
      initialPeakListId: 1,
    );

    expect(find.text('12,345 m'), findsOneWidget);
  });

  testWidgets('initialPeakListId opens the selected peak list', (tester) async {
    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Alpha List', [200]),
          _buildPeakList(2, 'Beta List', [300]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(200, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(300, 'Beta Peak', -42.1, 146.1, elevation: 1100),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 200, gpxId: 10),
        ]),
      ),
      initialPeakListId: 2,
    );

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Beta List',
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const Key('peak-lists-row-decoration-2')),
          )
          .decoration,
      isNotNull,
    );
  });

  testWidgets(
    'region filters default to all manifest-backed regions and hide unsupported legacy-region lists',
    (tester) async {
      final fixture = _buildRegionFilterFixture();

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: fixture.repository,
        peakRepository: fixture.peakRepository,
      );

      for (final regionKey in const [
        'tasmania',
        'italy-nord-est',
        'italy-nord-ovest',
        'slovenia',
      ]) {
        expect(
          find.byKey(Key('peak-lists-region-fab-$regionKey')),
          findsOneWidget,
        );
      }

      for (final label in const ['Tas', 'Italy NE', 'Italy NW', 'Slovenia']) {
        expect(find.text(label), findsOneWidget);
      }

      expect(find.byKey(const Key('peak-lists-row-1')), findsOneWidget);
      expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
      expect(find.byKey(const Key('peak-lists-row-3')), findsOneWidget);
      expect(find.byKey(const Key('peak-lists-row-4')), findsOneWidget);
      expect(find.byKey(const Key('peak-lists-row-5')), findsNothing);
    },
  );

  testWidgets('region filters restore a saved selection from preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      peakListRegionFilterPreferenceKey: ['italy-nord-est'],
    });
    final fixture = _buildRegionFilterFixture();

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: fixture.repository,
      peakRepository: fixture.peakRepository,
    );

    expect(find.byKey(const Key('peak-lists-row-1')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-3')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-row-4')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-5')), findsNothing);
  });

  testWidgets('region filters toggle independently and keep union semantics', (
    tester,
  ) async {
    final fixture = _buildRegionFilterFixture();

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: fixture.repository,
      peakRepository: fixture.peakRepository,
    );

    await tester.tap(find.byKey(const Key('peak-lists-region-fab-tasmania')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-row-1')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-3')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-row-4')), findsNothing);

    await tester.tap(find.byKey(const Key('peak-lists-region-fab-tasmania')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-row-1')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-3')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-row-4')), findsOneWidget);
  });

  testWidgets('all-off is a valid persisted region filter state', (
    tester,
  ) async {
    final fixture = _buildRegionFilterFixture();

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: fixture.repository,
      peakRepository: fixture.peakRepository,
    );

    for (final regionKey in const [
      'tasmania',
      'italy-nord-est',
      'italy-nord-ovest',
      'slovenia',
    ]) {
      final buttonFinder = find.byKey(Key('peak-lists-region-fab-$regionKey'));
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    }

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(peakListRegionFilterPreferenceKey), isEmpty);
    expect(find.byKey(const Key('peak-lists-row-1')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-3')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-4')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-5')), findsNothing);
    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Peak List Details',
    );
  });

  testWidgets(
    'filter handoff selects the first remaining visible list and stays handed off when the hidden list returns',
    (tester) async {
      final fixture = _buildRegionFilterFixture();

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: fixture.repository,
        peakRepository: fixture.peakRepository,
      );

      tester
          .widget<InkWell>(find.byKey(const Key('peak-lists-row-1')))
          .onTap!();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'Tas Only',
      );
      expect(
        find.byKey(const Key('peak-lists-details-row-100')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-lists-mini-map-marker-100-unticked')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('peak-lists-region-fab-tasmania')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'FVG Only',
      );
      expect(find.byKey(const Key('peak-lists-details-row-100')), findsNothing);
      expect(
        find.byKey(const Key('peak-lists-details-row-300')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-lists-mini-map-marker-300-unticked')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('peak-lists-region-fab-tasmania')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'FVG Only',
      );
    },
  );

  testWidgets('all-off clears selection, details, and mini-map state', (
    tester,
  ) async {
    final fixture = _buildRegionFilterFixture();

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: fixture.repository,
      peakRepository: fixture.peakRepository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-3'))).onTap!();
    await tester.pumpAndSettle();

    tester
        .widget<InkWell>(
          find
              .descendant(
                of: find.byKey(const Key('peak-lists-details-row-300')),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    );

    for (final regionKey in const [
      'tasmania',
      'italy-nord-est',
      'italy-nord-ovest',
      'slovenia',
    ]) {
      await container
          .read(peakListRegionFilterProvider.notifier)
          .toggleRegion(regionKey);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('peak-lists-row-1')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
    expect(find.byKey(const Key('peak-lists-row-3')), findsNothing);
    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Peak List Details',
    );
    expect(find.byKey(const Key('peak-lists-details-row-100')), findsNothing);
    expect(find.byKey(const Key('peak-lists-details-row-300')), findsNothing);
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-100-unticked')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-300-unticked')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
      findsNothing,
    );
  });

  testWidgets('summary rows use click cursor and hover theme', (tester) async {
    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Alpha List', [200]),
          _buildPeakList(2, 'Beta List', [300]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(200, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(300, 'Beta Peak', -42.1, 146.1, elevation: 1100),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 200, gpxId: 10),
        ]),
      ),
      initialPeakListId: 2,
    );

    final row = find.byKey(const Key('peak-lists-row-1'));
    expect(tester.widget<InkWell>(row).mouseCursor, SystemMouseCursors.click);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getTopLeft(row) + const Offset(20, 20));
    await tester.pump();

    final theme = Theme.of(tester.element(row));
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final hoveredText = tester.widget<Text>(
      find.descendant(of: row, matching: find.text('Alpha List')),
    );
    final hoveredDecoration = tester.widget<Container>(
      find.byKey(const Key('peak-lists-row-decoration-1')),
    );

    expect(hoveredDecoration.decoration, isNotNull);
    expect(
      (hoveredDecoration.decoration! as BoxDecoration).color,
      rowTheme.hoverColor,
    );
    expect(hoveredText.style?.color, rowTheme.hoveredTextColor);
  });

  testWidgets('tapping a peak row opens and closes the detail dialog', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    tester
        .widget<InkWell>(
          find
              .descendant(
                of: find.byKey(const Key('peak-lists-details-row-200')),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsOneWidget);
    expect(find.text('Beta Peak'), findsWidgets);

    await tester.tap(find.byKey(const Key('peak-list-peak-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
  });

  testWidgets('detail rows use click cursor and hover theme', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    final row = find.byKey(const Key('peak-lists-details-row-200'));
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: row, matching: find.byType(InkWell)),
          )
          .mouseCursor,
      SystemMouseCursors.click,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final hoveredCell = find.descendant(
      of: row,
      matching: find.text('Beta Peak'),
    );
    await mouse.moveTo(tester.getCenter(hoveredCell));
    await tester.pump();

    final theme = Theme.of(tester.element(row));
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final hoveredText = tester.widget<Text>(
      find.descendant(of: row, matching: find.text('Beta Peak')),
    );

    expect(hoveredText.style?.color, rowTheme.hoveredTextColor);
  });

  testWidgets('summary and detail sort headers use click cursors', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    for (final key in const [
      'peak-lists-sort-name',
      'peak-lists-sort-totalPeaks',
      'peak-lists-sort-climbed',
      'peak-lists-sort-percentage',
      'peak-lists-sort-unclimbed',
      'peak-lists-sort-ascents',
      'peak-lists-details-sort-rating',
      'peak-lists-details-sort-name',
      'peak-lists-details-sort-elevation',
      'peak-lists-details-sort-ascentDate',
      'peak-lists-details-sort-ascents',
      'peak-lists-details-sort-difficulty',
      'peak-lists-details-sort-duration',
    ]) {
      expect(
        tester.widget<InkWell>(find.byKey(Key(key))).mouseCursor,
        SystemMouseCursors.click,
      );
    }
  });

  testWidgets('bagged revision refreshes peak list counts', (tester) async {
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
      ]),
    );

    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [100, 200]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
        ]),
      ),
      peaksBaggedRepository: peaksBaggedRepository,
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-percentage-1')))
          .data,
      '50%',
    );

    await peaksBaggedRepository.rebuildFromTracks([
      GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Track 10',
          trackDate: DateTime.utc(2026, 5, 15),
        )
        ..peaks.addAll([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1),
        ]),
    ]);
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    ).read(peaksBaggedRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-percentage-1')))
          .data,
      '100%',
    );
  });

  testWidgets('peak rename refreshes Tassy Full rows', (tester) async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
      ]),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tassy Full', [100]),
        ]),
      ),
      peakRepository: peakRepository,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    expect(find.text('Alpha Peak'), findsWidgets);

    await peakRepository.save(
      _buildPeak(100, 'Renamed Peak', -42.0, 146.0, elevation: 1200),
    );
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    ).read(peakRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(find.text('Renamed Peak'), findsWidgets);
    expect(find.text('Alpha Peak'), findsNothing);
  });

  testWidgets('negative peak ids appear in peak lists counts and rows', (
    tester,
  ) async {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        _buildPeakList(1, 'Tas Peaks', [-1]),
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(-1, 'Tinderbox Hill', -42.0, 146.0, elevation: 300),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    );

    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
    );

    await peaksBaggedRepository.rebuildFromTracks([
      GpxTrack(
        gpxTrackId: 10,
        contentHash: 'hash-10',
        trackName: 'Track 10',
        trackDate: DateTime.utc(2026, 5, 15),
      )..peaks.add(_buildPeak(-1, 'Tinderbox Hill', -42.0, 146.0)),
    ]);
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    ).read(peaksBaggedRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '1',
    );
    expect(find.byKey(const Key('peak-lists-details-row--1')), findsOneWidget);
    expect(find.text('Tinderbox Hill'), findsWidgets);
  });

  testWidgets('tapping a mini-map marker opens peak info popup', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create(
      maps: [
        Tasmap50k(
          series: 'TS07',
          name: 'Test Map',
          parentSeries: '8211',
          mgrs100kIds: 'EN',
          eastingMin: 10000,
          eastingMax: 20000,
          northingMin: 60000,
          northingMax: 70000,
        ),
      ],
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(
      find.byKey(const Key('peak-lists-mini-map-marker-200-unticked')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-mini-map-popup')), findsOneWidget);
    expect(find.text('Beta Peak'), findsWidgets);
    final highlightedRowContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('peak-lists-details-row-200')),
            matching: find.byType(Container),
          )
          .first,
    );
    final highlightedDecoration =
        highlightedRowContainer.decoration as BoxDecoration?;
    expect(highlightedDecoration, isNotNull);
    expect(
      highlightedDecoration!.color,
      darken(
        Theme.of(
          tester.element(find.byKey(const Key('peak-lists-details-pane'))),
        ).colorScheme.primaryContainer,
        0.30,
      ),
    );
    expect(highlightedDecoration.border, isA<Border>());

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('peak-lists-mini-map'))) +
          const Offset(10, 10),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-mini-map-popup')), findsNothing);
    expect(find.byKey(const Key('peak-lists-details-row-200')), findsOneWidget);
  });

  testWidgets(
    'mini-map popup omits drop marker and never renders the selected location marker',
    (tester) async {
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          selectedLocation: const LatLng(-42.3, 146.3),
        ),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
            _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
          ]),
        ),
        mapNotifier: mapNotifier,
      );

      expect(
        find.byKey(const Key('peak-lists-selected-location-marker')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('peak-lists-mini-map-marker-200-unticked')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('peak-lists-mini-map-popup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-lists-selected-location-marker')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('peak-info-popup-drop-marker')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'summary peak links open the exact popup without opening the detail dialog',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
            _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(
              baggedId: 1,
              peakId: 100,
              gpxId: 10,
              date: DateTime.utc(2024, 3, 2),
            ),
            PeaksBagged(
              baggedId: 2,
              peakId: 200,
              gpxId: 11,
              date: DateTime.utc(2024, 3, 2),
            ),
          ]),
        ),
      );

      expect(
        find.byKey(const Key('peak-lists-summary-link-100')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-lists-summary-link-200')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('peak-lists-summary-link-200')),
            )
            .mouseCursor,
        SystemMouseCursors.click,
      );

      await tester.tap(find.byKey(const Key('peak-lists-summary-link-200')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('peak-lists-mini-map-popup')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('peak-lists-mini-map-popup')),
          matching: find.text('Beta Peak'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
      expect(
        find.byKey(const Key('peak-info-popup-drop-marker')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('peak-lists-selected-location-marker')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'Tas Peaks',
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('peak-lists-mini-map'))),
      );
      expect(container.read(mapProvider).selectedLocation, isNull);
    },
  );

  testWidgets(
    'popup peak title navigates to the main map repeatedly without opening the main peak popup',
    (tester) async {
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-42.5, 147.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
          selectedPeaks: [
            Peak(
              osmId: 999,
              name: 'Existing Peak',
              latitude: -41.2,
              longitude: 146.2,
            ),
          ],
        ),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
            _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(
              baggedId: 1,
              peakId: 100,
              gpxId: 10,
              date: DateTime.utc(2024, 3, 2),
            ),
            PeaksBagged(
              baggedId: 2,
              peakId: 200,
              gpxId: 11,
              date: DateTime.utc(2024, 3, 2),
            ),
          ]),
        ),
        mapNotifier: mapNotifier,
      );

      await tester.tap(find.byKey(const Key('peak-lists-summary-link-100')));
      await tester.pumpAndSettle();

      final titleLink = find.byKey(const Key('peak-info-popup-title-link'));
      expect(titleLink, findsOneWidget);
      expect(
        tester.widget<InkWell>(titleLink).mouseCursor,
        SystemMouseCursors.click,
      );
      expect(find.text('Available Tracks'), findsNothing);

      final firstSerial = mapNotifier.state.cameraRequestSerial;
      await tester.tap(titleLink);
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
      expect(find.byKey(const Key('peak-info-popup')), findsNothing);
      expect(mapNotifier.state.cameraRequestSerial, greaterThan(firstSerial));
      expect(mapNotifier.state.center.latitude, closeTo(-42.0, 0.001));
      expect(mapNotifier.state.center.longitude, closeTo(146.0, 0.001));
      expect(mapNotifier.state.zoom, MapConstants.defaultZoom);
      expect(
        mapNotifier.state.selectedPeaks.map((peak) => peak.osmId).toList(),
        [999],
      );

      final secondSerialBaseline = mapNotifier.state.cameraRequestSerial;
      router.go('/peaks');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-lists-summary-link-100')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('peak-info-popup-title-link')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
      expect(
        mapNotifier.state.cameraRequestSerial,
        greaterThan(secondSerialBaseline),
      );
      expect(mapNotifier.state.center.latitude, closeTo(-42.0, 0.001));
      expect(mapNotifier.state.center.longitude, closeTo(146.0, 0.001));
    },
  );

  testWidgets(
    'popup ascent rows link valid tracks while unresolved rows stay plain text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
        ),
      );
      final gpxTrackRepository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([
          GpxTrack(
            gpxTrackId: 10,
            contentHash: 'hash-10',
            trackName: 'Ridge Walk',
            gpxFile: '<gpx></gpx>',
            displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
              [const LatLng(-42.05, 145.95), const LatLng(-41.95, 146.05)],
            ]),
          ),
        ]),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(
              baggedId: 1,
              peakId: 100,
              gpxId: 10,
              date: DateTime.utc(2024, 3, 2),
            ),
            PeaksBagged(
              baggedId: 2,
              peakId: 100,
              gpxId: 999,
              date: DateTime.utc(2024, 3, 1),
            ),
          ]),
        ),
        mapNotifier: mapNotifier,
        overrides: [
          gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
        ],
      );

      await tester.tap(find.byKey(const Key('peak-lists-summary-link-100')));
      await tester.pumpAndSettle();

      final ascentLink = find.byKey(
        const Key('peak-info-popup-ascent-link-10'),
      );
      expect(find.text('My Ascents:'), findsOneWidget);
      expect(find.text('Available Tracks'), findsNothing);
      expect(ascentLink, findsOneWidget);
      expect(
        tester.widget<InkWell>(ascentLink).mouseCursor,
        SystemMouseCursors.click,
      );
      expect(
        find.byKey(const Key('peak-info-popup-ascent-text-999')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-info-popup-ascent-link-999')),
        findsNothing,
      );

      final firstFocusBaseline = mapNotifier.state.selectedTrackFocusSerial;
      await tester.tap(ascentLink);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
      expect(mapNotifier.state.selectedTrackId, 10);
      expect(mapNotifier.state.showTracks, isTrue);
      expect(
        mapNotifier.state.selectedTrackFocusSerial,
        greaterThan(firstFocusBaseline),
      );

      final secondFocusBaseline = mapNotifier.state.selectedTrackFocusSerial;
      router.go('/peaks');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-lists-summary-link-100')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('peak-info-popup-ascent-link-10')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
      expect(mapNotifier.state.selectedTrackId, 10);
      expect(
        mapNotifier.state.selectedTrackFocusSerial,
        greaterThan(secondFocusBaseline),
      );
    },
  );

  testWidgets('mini-map stays icon only when peak info is enabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-mini-map'))),
    );
    await container
        .read(peakMarkerInfoSettingsProvider.notifier)
        .setShowPeakInfo(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-200-unticked')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-marker-name-200')), findsNothing);
    expect(find.byKey(const Key('peak-marker-height-200')), findsNothing);
  });

  testWidgets('hovering a mini-map marker shows hover ring', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    final marker = find.byKey(
      const Key('peak-lists-mini-map-marker-200-unticked'),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: tester.getCenter(marker));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(marker));
    await tester.pump();

    expect(find.byKey(const Key('peak-marker-hover-200')), findsOneWidget);

    await gesture.moveTo(
      tester.getTopLeft(find.byKey(const Key('peak-lists-mini-map'))) -
          const Offset(20, 20),
    );
    await tester.pump();

    expect(find.byKey(const Key('peak-marker-hover-200')), findsNothing);
  });

  testWidgets('peak list mini-map clusters when toggle is on', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Clustered Peaks', [100, 200]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.00005, 146.00005, elevation: 1100),
        ]),
      ),
      overrides: [
        peakListMiniMapClusterDisplaySettingsProvider.overrideWith(
          _StaticPeakListMiniMapClusterDisplayOnNotifier.new,
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-lists-mini-map-cluster-0')),
      findsOneWidget,
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<PeakViewportPainter>()
        .first;
    expect(
      painter.clusterRingStyle,
      PeakClusterRingStyle.proportionalTickedUnticked,
    );
  });

  testWidgets('mini-map cursor becomes click over cluster marker', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Clustered Peaks', [100, 200]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.00005, 146.00005, elevation: 1100),
        ]),
      ),
      overrides: [
        peakListMiniMapClusterDisplaySettingsProvider.overrideWith(
          _StaticPeakListMiniMapClusterDisplayOnNotifier.new,
        ),
      ],
    );

    final cluster = find.byKey(const Key('peak-lists-mini-map-cluster-0'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: tester.getCenter(cluster));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(cluster));
    await tester.pump();

    expect(
      tester
          .widget<MouseRegion>(
            find.byKey(const Key('peak-lists-mini-map-interaction-region')),
          )
          .cursor,
      SystemMouseCursors.click,
    );
  });

  testWidgets(
    'peak list mini-map shows individual markers when toggle is off',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Clustered Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.0, 146.01, elevation: 1100),
          ]),
        ),
        overrides: [
          peakListMiniMapClusterDisplaySettingsProvider.overrideWith(
            _StaticPeakListMiniMapClusterDisplayOffNotifier.new,
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('peak-lists-mini-map-cluster-0')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('peak-lists-mini-map-marker-100-unticked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-lists-mini-map-marker-200-unticked')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'peak list mini-map cluster tap expands camera and keeps selection',
    (tester) async {
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Clustered Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.00005, 146.00005, elevation: 1100),
          ]),
        ),
        mapNotifier: mapNotifier,
        overrides: [
          peakListMiniMapClusterDisplaySettingsProvider.overrideWith(
            _StaticPeakListMiniMapClusterDisplayOnNotifier.new,
          ),
        ],
      );

      await tester.pumpAndSettle();

      tester
          .widget<InkWell>(
            find
                .descendant(
                  of: find.byKey(const Key('peak-lists-details-row-100')),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .onTap!();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('peak-lists-mini-map-cluster-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-lists-mini-map-popup')), findsNothing);
      expect(
        find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
        findsOneWidget,
      );
    },
  );

  testWidgets('selecting an offscreen peak centers the details row', (
    tester,
  ) async {
    final peaks = [
      for (var index = 1; index <= 20; index++)
        _buildPeak(
          index,
          'Peak $index',
          -42.0 - (index * 0.01),
          146.0 + (index * 0.01),
        ),
    ];

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [for (var i = 1; i <= 20; i++) i]),
        ]),
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage(peaks)),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 1, gpxId: 10),
        ]),
      ),
    );

    final rowFinder = find.byKey(const Key('peak-lists-details-row-12'));
    tester
        .widget<InkWell>(
          find.descendant(of: rowFinder, matching: find.byType(InkWell)).first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    final rowCenter = tester.getCenter(rowFinder);
    final cardCenter = tester.getCenter(
      find
          .descendant(
            of: find.byKey(const Key('peak-lists-details-pane')),
            matching: find.byType(Card),
          )
          .first,
    );
    final rowContainer = tester.widget<Container>(
      find.descendant(of: rowFinder, matching: find.byType(Container)).first,
    );

    final rowDecoration = rowContainer.decoration as BoxDecoration?;
    expect(rowDecoration, isNotNull);
    expect(
      rowDecoration!.color,
      darken(
        Theme.of(
          tester.element(find.byKey(const Key('peak-lists-details-pane'))),
        ).colorScheme.primaryContainer,
        0.30,
      ),
    );
    expect(rowDecoration.border, isA<Border>());
    expect(rowCenter.dy, closeTo(cardCenter.dy, 120));
  });

  testWidgets('add dialog selects the first saved alphabetical peak', (
    tester,
  ) async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(300, 'Zulu Peak', -41.0, 146.0),
        _buildPeak(100, 'Alpha Peak', -41.1, 146.1),
        _buildPeak(200, 'Mike Peak', -41.2, 146.2),
      ]),
    );
    final peakListRepository = _peakListRepository(
      [PeakList(name: 'Tasmania')..peakListId = 1],
      peakRepository: peakRepository,
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-lists-add-peak')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-300')));
    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-100')));
    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-200')));
    await tester.pump();

    expect(find.byKey(const Key('peak-selected-row-100')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('peak-selected-points-300')),
      '7',
    );
    await tester.enterText(
      find.byKey(const Key('peak-selected-points-100')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('peak-selected-points-200')),
      '5',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('peak-list-peak-save')));
    await tester.pumpAndSettle();

    final selectedRowFinder = find.byKey(
      const Key('peak-lists-details-row-100'),
    );
    expect(selectedRowFinder, findsOneWidget);
    final selectedRowContainer = tester.widget<Container>(
      find
          .descendant(of: selectedRowFinder, matching: find.byType(Container))
          .first,
    );
    final selectedRowDecoration =
        selectedRowContainer.decoration as BoxDecoration?;
    expect(selectedRowDecoration, isNotNull);
    expect(selectedRowDecoration!.color, isNotNull);
    expect(
      _storedMemberships(peakListRepository, 'Tasmania'),
      [(100, 3), (200, 5), (300, 7)],
    );
  });

  testWidgets('add dialog cancel keeps the current selection', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: _peakListRepository([
        PeakList(name: 'Tasmania')..peakListId = 1,
      ]),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -41.1, 146.1),
          _buildPeak(200, 'Mike Peak', -41.2, 146.2),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    final selectedTitleBefore = tester
        .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
        .data;

    await tester.tap(find.byKey(const Key('peak-lists-add-peak')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-peak-cancel')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      selectedTitleBefore,
    );
    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
  });

  testWidgets(
    'add dialog updates the selected list without creating Tassy Full',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(300, 'Zulu Peak', -41.0, 146.0),
          _buildPeak(100, 'Alpha Peak', -41.1, 146.1),
          _buildPeak(200, 'Mike Peak', -41.2, 146.2),
        ]),
      );
      final peakListRepository = _peakListRepository(
        [PeakList(name: 'Tasmania')..peakListId = 1],
        peakRepository: peakRepository,
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: peakListRepository,
        peakRepository: peakRepository,
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
      );

      tester
          .widget<InkWell>(find.byKey(const Key('peak-lists-row-1')))
          .onTap!();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-lists-add-peak')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-300')));
      await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-100')));
      await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-200')));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('peak-selected-points-300')),
        '7',
      );
      await tester.enterText(
        find.byKey(const Key('peak-selected-points-100')),
        '3',
      );
      await tester.enterText(
        find.byKey(const Key('peak-selected-points-200')),
        '5',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('peak-list-peak-save')));
      await tester.pumpAndSettle();

      expect(
        _storedMemberships(peakListRepository, 'Tasmania'),
        [(100, 3), (200, 5), (300, 7)],
      );
      expect(peakListRepository.findByName('Tassy Full'), isNull);
    },
  );

  testWidgets('summary metrics use unique peak ids and latest ascent dates', (
    tester,
  ) async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
        _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
        _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
      ]),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(
            1,
            'Tas Peaks',
            [200, 300, 100, 100],
            pointsByPeakId: const {200: 7, 300: 3, 100: 5},
          ),
        ]),
      ),
      peakRepository: peakRepository,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(
            baggedId: 1,
            peakId: 100,
            gpxId: 10,
            date: DateTime.utc(2024, 1, 12),
          ),
          PeaksBagged(
            baggedId: 2,
            peakId: 100,
            gpxId: 11,
            date: DateTime.utc(2024, 3, 2),
          ),
          PeaksBagged(
            baggedId: 3,
            peakId: 200,
            gpxId: 12,
            date: DateTime.utc(2024, 3, 2),
          ),
        ]),
      ),
    );

    expect(find.byKey(const Key('peak-lists-total-1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-total-1'))).data,
      '3',
    );
    expect(find.byKey(const Key('peak-lists-climbed-1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '2',
    );
    expect(find.byKey(const Key('peak-lists-percentage-1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-percentage-1')))
          .data,
      '67%',
    );
    expect(find.byKey(const Key('peak-lists-unclimbed-1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-unclimbed-1'))).data,
      '1',
    );
    final summaryText = _summarySentenceText(tester);
    expect(summaryText, contains('Tas Peaks contains 3 peaks.'));
    expect(
      summaryText,
      contains(
        'Alpha Peak and Beta Peak are your most recent ascent, climbed on 2 Mar 2024.',
      ),
    );
    expect(
      summaryText,
      contains(
        'Climbed 2 of 3 peaks (67%) and earned a total 12 points out of 15.',
      ),
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-100-ticked')),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-200-ticked')),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-300-unticked')),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-lists-details-row-300')),
        matching: find.text('2 Mar 2024'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('peak-lists-details-ascents-200')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-details-ascents-200')))
          .data,
      '1',
    );
    expect(
      find.byKey(const Key('peak-lists-details-ascents-100')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-details-ascents-100')))
          .data,
      '2',
    );
    expect(
      find.byKey(const Key('peak-lists-details-ascents-300')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-details-ascents-300')))
          .data,
      '',
    );
  });

  testWidgets(
    'empty rows stay visible without unsupported details message',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: _peakListRepository([
          _buildPeakList(1, 'Empty List', []),
        ]),
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
      );

      expect(find.byKey(const Key('peak-lists-row-1')), findsOneWidget);
      expect(find.text('Empty List'), findsNWidgets(2));
      expect(find.byKey(const Key('peak-lists-delete-1')), findsOneWidget);
      expect(find.byKey(const Key('peak-lists-total-1')), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.byKey(const Key('peak-lists-unsupported-message')), findsNothing);
    },
  );

  testWidgets(
    'derived metric sorts keep zero-member rows ordered deterministically and indicators stay deterministic',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: _peakListRepository([
          _buildPeakList(1, 'Bravo', [100]),
          _buildPeakList(2, 'Empty List', []),
        ]),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([_buildPeak(100, 'Alpha Peak', -42.0, 146.0)]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
          ]),
        ),
      );

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-percentage')),
            )
            .icon,
        isNot(Icons.unfold_more),
      );
      expect(
        tester
            .widget<Icon>(find.byKey(const Key('peak-lists-sort-icon-name')))
            .icon,
        Icons.unfold_more,
      );

      await tester.ensureVisible(
        find.byKey(const Key('peak-lists-sort-totalPeaks')),
      );
      await tester.tap(find.byKey(const Key('peak-lists-sort-totalPeaks')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-totalPeaks')),
            )
            .icon,
        isNot(Icons.unfold_more),
      );
      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-percentage')),
            )
            .icon,
        Icons.unfold_more,
      );

      final bravoTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-row-1')))
          .dy;
      final emptyTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-row-2')))
          .dy;
      expect(emptyTop, lessThan(bravoTop));
    },
  );

  testWidgets('first list auto-selects and row tap updates details title', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(_buildLists(['Abels', 'Connoisseurs'])),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
    );

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );
    final selectedRowContainer = tester.widget<Container>(
      find.byKey(const Key('peak-lists-row-decoration-1')),
    );
    final selectedRowDecoration =
        selectedRowContainer.decoration as BoxDecoration?;
    expect(selectedRowDecoration, isNotNull);
    expect(selectedRowDecoration!.color, isNotNull);
    expect(selectedRowDecoration.border, isA<Border>());

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-2'))).onTap!();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Connoisseurs',
    );
  });

  testWidgets('long peak names wrap in the details table', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Wrap Me', [100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'kunanyi / Mount Wellington', -42.0, 146.0),
        ]),
      ),
    );

    final nameText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('peak-lists-details-row-100')),
        matching: find.text('kunanyi / Mount Wellington'),
      ),
    );

    expect(nameText.maxLines, 2);
    expect(nameText.softWrap, isTrue);
  });

  testWidgets('tapping a detail row draws a peak circle', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Circle Me', [101, 102]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(101, 'Alpha Peak', -42.0, 146.0),
          _buildPeak(102, 'Bravo Peak', -42.1, 146.1),
        ]),
      ),
    );

    expect(
      find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
      findsNothing,
    );

    tester
        .widget<InkWell>(
          find
              .descendant(
                of: find.byKey(const Key('peak-lists-details-row-102')),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
      findsOneWidget,
    );
  });

  testWidgets('summary metrics format large counts and point totals', (
    tester,
  ) async {
    final peakIds = List<int>.generate(1234, (index) => index + 1);

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(
            1,
            'Tas Peaks',
            peakIds,
            pointsByPeakId: {for (final peakId in peakIds) peakId: 1},
          ),
        ]),
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-total-1'))).data,
      '1,234',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-unclimbed-1'))).data,
      '1,234',
    );

    final summaryText = _summarySentenceText(tester);
    expect(summaryText, contains('Tas Peaks contains 1,234 peaks.'));
    expect(
      summaryText,
      contains(
        'Climbed 0 of 1,234 peaks (0%) and earned a total 0 points out of 1,234.',
      ),
    );
  });

  testWidgets('selected peak circle layers above markers in mini map', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    tester
        .widget<InkWell>(
          find
              .descendant(
                of: find.byKey(const Key('peak-lists-details-row-100')),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    final miniMap = tester.widget<FlutterMap>(
      find.descendant(
        of: find.byKey(const Key('peak-lists-mini-map')),
        matching: find.byType(FlutterMap),
      ),
    );

    expect(
      miniMap.children.indexWhere((child) => child is CircleLayer),
      greaterThan(miniMap.children.indexWhere((child) => child is MarkerLayer)),
    );
  });

  testWidgets(
    'screen-level mini-map keyboard zoom and pan shortcuts move only the mini-map',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final initialState = _miniMapDebugState(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
      await tester.pump();

      final zoomedState = _miniMapDebugState(tester);
      expect(zoomedState.zoom, greaterThan(initialState.zoom));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'Tas Peaks',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final pannedRightState = _miniMapDebugState(tester);
      expect(
        pannedRightState.center.longitude,
        greaterThan(zoomedState.center.longitude),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyH);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyH);
      await tester.pump();

      final pannedLeftState = _miniMapDebugState(tester);
      expect(
        pannedLeftState.center.longitude,
        lessThan(pannedRightState.center.longitude),
      );
    },
  );

  testWidgets(
    'mini-map shows grab and grabbing cursors and drag-pan commits once on release',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final initialState = _miniMapDebugState(tester);
      final region = find.byKey(
        const Key('peak-lists-mini-map-interaction-region'),
      );
      final emptyPoint =
          tester.getTopLeft(find.byKey(const Key('peak-lists-mini-map'))) +
          const Offset(16, 16);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: emptyPoint);
      await tester.pump();
      await gesture.moveTo(emptyPoint);
      await tester.pump();

      expect(
        tester.widget<MouseRegion>(region).cursor,
        SystemMouseCursors.grab,
      );

      await gesture.down(emptyPoint);
      await tester.pump();

      expect(
        tester.widget<MouseRegion>(region).cursor,
        SystemMouseCursors.grabbing,
      );

      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final draggedState = _miniMapDebugState(tester);
      expect(draggedState.canGoPrevious, isTrue);
      expect(draggedState.canGoNext, isFalse);
      expect(
        draggedState.center.longitude,
        lessThan(initialState.center.longitude),
      );
      expect(find.byKey(const Key('peak-lists-mini-map-popup')), findsNothing);
    },
  );

  testWidgets(
    'drag release over a peak does not open a popup or change selection',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final marker = find.byKey(
        const Key('peak-lists-mini-map-marker-100-unticked'),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: tester.getCenter(marker));
      await tester.pump();
      await gesture.down(tester.getCenter(marker));
      await tester.pump();
      await gesture.moveBy(const Offset(18, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.byKey(const Key('peak-lists-mini-map-popup')), findsNothing);
      expect(
        find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'mini-map keyboard shortcuts are suppressed by editable text and dialogs',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final initialState = _miniMapDebugState(tester);

      await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('peak-list-import-dialog')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
      await tester.pump();

      expect(_miniMapDebugState(tester).zoom, initialState.zoom);

      await tester.tap(find.byKey(const Key('peak-list-import-cancel')));
      await tester.pumpAndSettle();

      tester
          .widget<InkResponse>(find.byKey(const Key('peak-lists-delete-1')))
          .onTap!();
      await tester.pumpAndSettle();
      expect(find.text('Delete Peak List?'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final dialogState = _miniMapDebugState(tester);
      expect(dialogState.center.latitude, initialState.center.latitude);
      expect(dialogState.center.longitude, initialState.center.longitude);

      await tester.tap(find.byKey(const Key('cancel-delete')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'cmd bracket replays mini-map camera history and silently no-ops at the ends',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final initialState = _miniMapDebugState(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
      await tester.pump();
      final zoomedState = _miniMapDebugState(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final pannedState = _miniMapDebugState(tester);

      expect(pannedState.canGoPrevious, isTrue);
      expect(pannedState.canGoNext, isFalse);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketLeft);
      final previousState = _miniMapDebugState(tester);
      expect(previousState.zoom, zoomedState.zoom);
      expect(previousState.center.longitude, zoomedState.center.longitude);
      expect(previousState.canGoPrevious, isTrue);
      expect(previousState.canGoNext, isTrue);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketLeft);
      final oldestState = _miniMapDebugState(tester);
      expect(oldestState.zoom, initialState.zoom);
      expect(oldestState.center.longitude, initialState.center.longitude);
      expect(oldestState.canGoPrevious, isFalse);
      expect(oldestState.canGoNext, isTrue);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketLeft);
      final noPreviousState = _miniMapDebugState(tester);
      expect(noPreviousState.zoom, oldestState.zoom);
      expect(noPreviousState.center.longitude, oldestState.center.longitude);
      expect(noPreviousState.canGoPrevious, isFalse);
      expect(noPreviousState.canGoNext, isTrue);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketRight);
      await _sendMetaChord(tester, LogicalKeyboardKey.bracketRight);
      final newestState = _miniMapDebugState(tester);
      expect(newestState.zoom, pannedState.zoom);
      expect(newestState.center.longitude, pannedState.center.longitude);
      expect(newestState.canGoPrevious, isTrue);
      expect(newestState.canGoNext, isFalse);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketRight);
      final noNextState = _miniMapDebugState(tester);
      expect(noNextState.zoom, newestState.zoom);
      expect(noNextState.center.longitude, newestState.center.longitude);
      expect(noNextState.canGoNext, isFalse);
    },
  );

  testWidgets(
    'new camera changes after moving backward clear forward mini-map history',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketLeft);
      final rewoundState = _miniMapDebugState(tester);
      expect(rewoundState.canGoNext, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
      await tester.pump();

      final branchedState = _miniMapDebugState(tester);
      expect(branchedState.canGoNext, isFalse);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketRight);
      final noForwardState = _miniMapDebugState(tester);
      expect(noForwardState.zoom, branchedState.zoom);
      expect(noForwardState.center.longitude, branchedState.center.longitude);
      expect(noForwardState.canGoNext, isFalse);
    },
  );

  testWidgets(
    'trackpad horizontal motion is a no-op and vertical zoom commits on pan-zoom end',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Tas Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final initialState = _miniMapDebugState(tester);
      final region = find.byKey(
        const Key('peak-lists-mini-map-interaction-region'),
      );
      final center = tester.getCenter(region);

      var gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomUpdate(center, pan: const Offset(120, 0));
      await tester.pump();
      expect(_miniMapDebugState(tester).zoom, initialState.zoom);
      await gesture.up();
      await tester.pump();

      final horizontalState = _miniMapDebugState(tester);
      expect(horizontalState.zoom, initialState.zoom);
      expect(horizontalState.center.longitude, initialState.center.longitude);
      expect(horizontalState.canGoPrevious, isFalse);

      gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomUpdate(center, pan: const Offset(0, 120));
      await tester.pump();

      expect(_miniMapDebugState(tester).zoom, initialState.zoom);

      await gesture.up();
      await tester.pump();

      final committedState = _miniMapDebugState(tester);
      expect(committedState.zoom, greaterThan(initialState.zoom));
      expect(committedState.center.latitude, initialState.center.latitude);
      expect(committedState.center.longitude, initialState.center.longitude);
      expect(committedState.canGoPrevious, isTrue);
    },
  );

  testWidgets('mouse-wheel zoom burst commits once after debounce', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [100, 200]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final initialState = _miniMapDebugState(tester);
    final region = find.byKey(
      const Key('peak-lists-mini-map-interaction-region'),
    );
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: center);
    await tester.pump();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -20),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -20),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();

    expect(_miniMapDebugState(tester).zoom, initialState.zoom);
    expect(_miniMapDebugState(tester).canGoPrevious, isFalse);

    await tester.pump(MapConstants.cameraSaveDebounce);

    final committedState = _miniMapDebugState(tester);
    expect(committedState.zoom, greaterThan(initialState.zoom));
    expect(committedState.canGoPrevious, isTrue);

    await _sendMetaChord(tester, LogicalKeyboardKey.bracketLeft);
    final rewoundState = _miniMapDebugState(tester);
    expect(rewoundState.zoom, initialState.zoom);
    expect(rewoundState.center.longitude, initialState.center.longitude);
  });

  testWidgets(
    'cluster expansion commits one mini-map history entry when the camera changes',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Clustered Peaks', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', -42.00005, 146.00005, elevation: 1100),
          ]),
        ),
        overrides: [
          peakListMiniMapClusterDisplaySettingsProvider.overrideWith(
            _StaticPeakListMiniMapClusterDisplayOnNotifier.new,
          ),
        ],
      );
      await tester.pumpAndSettle();

      final initialState = _miniMapDebugState(tester);

      await tester.tap(
        find.byKey(const Key('peak-lists-mini-map-cluster-0')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final expandedState = _miniMapDebugState(tester);
      expect(expandedState.canGoPrevious, isTrue);

      await _sendMetaChord(tester, LogicalKeyboardKey.bracketLeft);
      final rewoundState = _miniMapDebugState(tester);
      expect(rewoundState.zoom, initialState.zoom);
      expect(rewoundState.center.longitude, initialState.center.longitude);
    },
  );

  testWidgets(
    'changing the selected peak list resets mini-map history to the new fitted camera',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(
              1,
              'Tas Peaks',
              [100],
              minLat: -42.5,
              maxLat: -41.5,
              minLng: 145.5,
              maxLng: 146.5,
            ),
            _buildPeakList(
              2,
              'Alps Peaks',
              [200],
              minLat: 46.0,
              maxLat: 46.5,
              minLng: 12.5,
              maxLng: 13.5,
            ),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
            _buildPeak(200, 'Beta Peak', 46.2, 13.0, elevation: 2200),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(_miniMapDebugState(tester).canGoPrevious, isTrue);

      tester
          .widget<InkWell>(find.byKey(const Key('peak-lists-row-1')))
          .onTap!();
      await tester.pumpAndSettle();

      final resetState = _miniMapDebugState(tester);
      expect(resetState.canGoPrevious, isFalse);
      expect(resetState.canGoNext, isFalse);
      expect(resetState.center.latitude, lessThan(-40));
      expect(resetState.center.longitude, greaterThan(100));
    },
  );

  testWidgets(
    'mini map initial fit uses stored peak-list bounds when peaks are unresolved',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(
              1,
              'FVG 500',
              [100],
              minLat: 46.0,
              maxLat: 46.5,
              minLng: 12.5,
              maxLng: 13.5,
            ),
          ]),
        ),
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      );

      final miniMap = tester.widget<FlutterMap>(
        find.descendant(
          of: find.byKey(const Key('peak-lists-mini-map')),
          matching: find.byType(FlutterMap),
        ),
      );
      final fit = miniMap.options.initialCameraFit! as FitBounds;

      expect(fit.bounds.southWest.latitude, 46.0);
      expect(fit.bounds.northEast.latitude, 46.5);
      expect(fit.bounds.southWest.longitude, 12.5);
      expect(fit.bounds.northEast.longitude, 13.5);
    },
  );

  testWidgets(
    'mini map rebuild switches initial fit to the selected list bounds',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(
              1,
              'Tas Peaks',
              [100],
              minLat: -42.5,
              maxLat: -41.5,
              minLng: 145.5,
              maxLng: 146.5,
            ),
            _buildPeakList(
              2,
              'FVG 500',
              [200],
              minLat: 46.0,
              maxLat: 46.5,
              minLng: 12.5,
              maxLng: 13.5,
            ),
          ]),
        ),
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      );

      await tester.tap(
        find.byKey(const Key('peak-lists-row-2')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final miniMap = tester.widget<FlutterMap>(
        find.descendant(
          of: find.byKey(const Key('peak-lists-mini-map')),
          matching: find.byType(FlutterMap),
        ),
      );
      final fit = miniMap.options.initialCameraFit! as FitBounds;

      expect(fit.bounds.southWest.latitude, 46.0);
      expect(fit.bounds.northEast.latitude, 46.5);
      expect(fit.bounds.southWest.longitude, 12.5);
      expect(fit.bounds.northEast.longitude, 13.5);
    },
  );

  testWidgets('details table sorts rows by tapped headers', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Sort Me', [30, 10, 20]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(30, 'Zulu Peak', -42.0, 146.0, elevation: 900),
          _buildPeak(10, 'Alpha Peak', -42.1, 146.1, elevation: 700),
          _buildPeak(20, 'Bravo Peak', -42.2, 146.2, elevation: 700),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(
            baggedId: 1,
            peakId: 10,
            gpxId: 10,
            date: DateTime.utc(2024, 1, 11),
          ),
          PeaksBagged(
            baggedId: 2,
            peakId: 20,
            gpxId: 11,
            date: DateTime.utc(2024, 1, 12),
          ),
        ]),
      ),
    );

    expect(
      tester
          .widget<Icon>(
            find.byKey(const Key('peak-lists-details-sort-icon-name')),
          )
          .icon,
      Icons.unfold_more,
    );

    final elevationHeaderSize = tester.getSize(
      find.byKey(const Key('peak-lists-details-sort-elevation')),
    );
    final elevationHeaderStyle = Theme.of(
      tester.element(
        find.byKey(const Key('peak-lists-details-sort-elevation')),
      ),
    ).textTheme.labelLarge;
    final elevationTextPainter = TextPainter(
      text: TextSpan(text: 'Height', style: elevationHeaderStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    expect(
      elevationHeaderSize.width,
      greaterThanOrEqualTo(elevationTextPainter.width + 30),
    );

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-name')),
    );
    await tester.tap(find.byKey(const Key('peak-lists-details-sort-name')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Icon>(
            find.byKey(const Key('peak-lists-details-sort-icon-name')),
          )
          .icon,
      Icons.arrow_upward,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const Key('peak-lists-details-sort-icon-elevation')),
          )
          .icon,
      Icons.unfold_more,
    );

    final alphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final bravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final zuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(alphaTop, lessThan(bravoTop));
    expect(bravoTop, lessThan(zuluTop));

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-elevation')),
    );
    await tester.tap(
      find.byKey(const Key('peak-lists-details-sort-elevation')),
    );
    await tester.pumpAndSettle();

    final lowAlphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final lowBravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final highZuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(lowAlphaTop, lessThan(lowBravoTop));
    expect(lowBravoTop, lessThan(highZuluTop));

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.tap(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.pumpAndSettle();

    final datedAlphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final datedBravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final blankZuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(datedAlphaTop, lessThan(datedBravoTop));
    expect(datedBravoTop, lessThan(blankZuluTop));

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.tap(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.pumpAndSettle();

    final descendingBravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final descendingAlphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final descendingBlankZuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(descendingBravoTop, lessThan(descendingAlphaTop));
    expect(descendingAlphaTop, lessThan(descendingBlankZuluTop));
  });

  testWidgets(
    'details table shows exact metadata column order and star or duration displays',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Metadata List', [100, 200]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(
              100,
              'Alpha Peak',
              -42.0,
              146.0,
              elevation: 1200,
              rating: 3.74,
              difficulty: 'EE',
              durationMinutes: 255,
              region: 'fvg',
            ),
            _buildPeak(200, 'Blank Peak', -42.1, 146.1, elevation: 1100),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
      );

      final ratingHeaderX = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-sort-rating')))
          .dx;
      final nameHeaderX = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-sort-name')))
          .dx;
      final heightHeaderX = tester
          .getTopLeft(
            find.byKey(const Key('peak-lists-details-sort-elevation')),
          )
          .dx;
      final ascentHeaderX = tester
          .getTopLeft(
            find.byKey(const Key('peak-lists-details-sort-ascentDate')),
          )
          .dx;
      final ascentsHeaderX = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-sort-ascents')))
          .dx;
      final difficultyHeaderX = tester
          .getTopLeft(
            find.byKey(const Key('peak-lists-details-sort-difficulty')),
          )
          .dx;
      final durationHeaderX = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-sort-duration')))
          .dx;

      expect(ratingHeaderX, lessThan(nameHeaderX));
      expect(nameHeaderX, lessThan(heightHeaderX));
      expect(heightHeaderX, lessThan(ascentHeaderX));
      expect(ascentHeaderX, lessThan(ascentsHeaderX));
      expect(ascentsHeaderX, lessThan(difficultyHeaderX));
      expect(difficultyHeaderX, lessThan(durationHeaderX));

      final alphaRatingCell = find.byKey(
        const Key('peak-lists-details-rating-100'),
      );
      expect(alphaRatingCell, findsOneWidget);
      expect(
        find.descendant(of: alphaRatingCell, matching: find.byIcon(Icons.star)),
        findsNWidgets(3),
      );
      expect(
        find.descendant(
          of: alphaRatingCell,
          matching: find.byIcon(Icons.star_half),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: alphaRatingCell,
          matching: find.byIcon(Icons.star_border),
        ),
        findsOneWidget,
      );
      expect(find.text('3.74'), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('peak-lists-details-difficulty-100')),
            )
            .data,
        'EE',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('peak-lists-details-duration-100')),
            )
            .data,
        '4:15',
      );

      final blankRatingCell = find.byKey(
        const Key('peak-lists-details-rating-200'),
      );
      expect(blankRatingCell, findsOneWidget);
      expect(
        find.descendant(of: blankRatingCell, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('peak-lists-details-difficulty-200')),
            )
            .data,
        '',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('peak-lists-details-duration-200')),
            )
            .data,
        '',
      );
    },
  );

  testWidgets(
    'details table sorts rating, difficulty, and duration with blank-last metadata rules',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Metadata Sorts', [10, 20, 30, 40]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(
              10,
              'Tas Hard',
              -42.0,
              146.0,
              elevation: 1200,
              rating: 4.49,
              difficulty: 'Hard',
              durationMinutes: 300,
              durationLabel: '4-5 hours',
              region: 'tasmania',
            ),
            _buildPeak(
              20,
              'Tas Easy',
              -42.1,
              146.1,
              elevation: 1100,
              rating: 4.26,
              difficulty: 'Easy',
              durationMinutes: 255,
              region: 'tasmania',
            ),
            _buildPeak(
              30,
              'FVG Peak',
              46.2,
              13.2,
              elevation: 2100,
              rating: 4.9,
              difficulty: 'T',
              durationMinutes: 180,
              region: 'fvg',
            ),
            _buildPeak(40, 'Blank Peak', -42.2, 146.2, elevation: 900),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('peak-lists-details-sort-rating')),
      );
      await tester.tap(find.byKey(const Key('peak-lists-details-sort-rating')));
      await tester.pumpAndSettle();

      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-40')))
              .dy,
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('peak-lists-details-sort-difficulty')),
      );
      await tester.tap(
        find.byKey(const Key('peak-lists-details-sort-difficulty')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-40')))
              .dy,
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('peak-lists-details-sort-duration')),
      );
      await tester.tap(
        find.byKey(const Key('peak-lists-details-sort-duration')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('peak-lists-details-row-40')))
              .dy,
        ),
      );

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('peak-lists-details-duration-20')),
            )
            .data,
        '4:15',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('peak-lists-details-duration-10')),
            )
            .data,
        '4-5 hours',
      );
    },
  );

  testWidgets(
    'selecting a peak list defaults details to ascent date descending',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Sort Me', [30, 10, 20]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(30, 'Zulu Peak', -42.0, 146.0, elevation: 900),
            _buildPeak(10, 'Alpha Peak', -42.1, 146.1, elevation: 700),
            _buildPeak(20, 'Bravo Peak', -42.2, 146.2, elevation: 700),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(
              baggedId: 1,
              peakId: 10,
              gpxId: 10,
              date: DateTime.utc(2024, 1, 11),
            ),
            PeaksBagged(
              baggedId: 2,
              peakId: 20,
              gpxId: 11,
              date: DateTime.utc(2024, 1, 12),
            ),
          ]),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('peak-lists-row-1')));
      await tester.tap(
        find.byKey(const Key('peak-lists-row-1')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-details-sort-icon-ascentDate')),
            )
            .icon,
        Icons.arrow_downward,
      );

      final bravoTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
          .dy;
      final alphaTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
          .dy;
      final zuluTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
          .dy;

      expect(bravoTop, lessThan(alphaTop));
      expect(alphaTop, lessThan(zuluTop));
    },
  );

  testWidgets('supported floor render stays desktop-only and wraps rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        _buildPeakList(
          1,
          'This is a very long peak list name that should wrap on the summary pane',
          [101],
        ),
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          101,
          'This is a very long peak name that should wrap on the details pane',
          -42.0,
          146.0,
        ),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(
          baggedId: 1,
          peakId: 101,
          gpxId: 10,
          date: DateTime.utc(2024, 1, 12),
        ),
      ]),
    );

    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
    );

    expect(find.byKey(const Key('peak-lists-summary-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-details-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-mini-map')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'This is a very long peak list name that should wrap on the summary pane',
    );
    expect(
      tester.getSize(find.byKey(const Key('peak-lists-row-1'))).height,
      lessThan(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('peak-lists-details-row-101')))
          .height,
      greaterThan(48),
    );
  });

  testWidgets('import completion selects returned list identity', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: repository,
      importRunner:
          ({required String listName, required String csvPath}) async {
            final saved = await repository.save(
              PeakList(name: listName),
            );
            ProviderScope.containerOf(
              tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
            ).read(peakListRevisionProvider.notifier).increment();
            return PeakListImportPresentationResult(
              updated: false,
              importedCount: 1,
              skippedCount: 0,
              peakListId: saved.peakListId,
              listName: saved.name,
            );
          },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-row-1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );
  });

  testWidgets('open list action navigates back to the imported list', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    );
    final completer = Completer<PeakListImportPresentationResult>();

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: repository,
      importRunner: ({required String listName, required String csvPath}) {
        return completer.future;
      },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();

    router.go('/');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.byType(Text),
      ),
      findsNothing,
    );

    final saved = await repository.save(PeakList(name: 'Abels'));
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    ).read(peakListRevisionProvider.notifier).increment();
    completer.complete(
      PeakListImportPresentationResult(
        updated: false,
        importedCount: 1,
        skippedCount: 0,
        peakListId: saved.peakListId,
        listName: saved.name,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open List'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );
  });

  testWidgets('renaming the selected list refreshes title and row', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Abels')..peakListId = 1,
        PeakList(name: 'Bravo')..peakListId = 2,
      ]),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );

    await repository.save(
      PeakList(peakListId: 1, name: 'Abels Renamed'),
    );
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    ).read(peakListRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels Renamed',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-lists-row-1')),
        matching: find.text('Abels Renamed'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'delete cancel keeps row and confirmed non-selected delete preserves selection',
    (tester) async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage(_buildLists(['Abels', 'Connoisseurs'])),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: repository,
      );

      await tester.ensureVisible(find.byKey(const Key('peak-lists-delete-2')));
      await tester.tap(find.byKey(const Key('peak-lists-delete-2')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Peak List?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel-delete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-lists-row-2')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('peak-lists-delete-2')));
      await tester.tap(find.byKey(const Key('peak-lists-delete-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'Abels',
      );
    },
  );

  testWidgets('deleting selected rows moves next, previous, then empty', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(_buildLists(['Abels', 'Bravo', 'Charlie'])),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-2'))).onTap!();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('peak-lists-delete-2')));
    await tester.tap(find.byKey(const Key('peak-lists-delete-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Charlie',
    );

    await tester.ensureVisible(find.byKey(const Key('peak-lists-delete-3')));
    await tester.tap(find.byKey(const Key('peak-lists-delete-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );

    await tester.ensureVisible(find.byKey(const Key('peak-lists-delete-1')));
    await tester.tap(find.byKey(const Key('peak-lists-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
  });

  testWidgets(
    'deleting active list bumps revision and reconciles map selection',
    (tester) async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage(_buildLists(['Abels', 'Bravo'])),
      );
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {2},
        ),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: repository,
        mapNotifier: mapNotifier,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
      );

      tester
          .widget<InkWell>(find.byKey(const Key('peak-lists-row-2')))
          .onTap!();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('peak-lists-delete-2')));
      await tester.tap(find.byKey(const Key('peak-lists-delete-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(container.read(peakListRevisionProvider), 1);
      expect(mapNotifier.reloadPeakMarkersCallCount, 0);
      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.allPeaks,
      );
      expect(container.read(mapProvider).selectedPeakListIds, isEmpty);
    },
  );

  testWidgets('import fab opens dialog and cancel closes it', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-import-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-import-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
  });

  testWidgets('import stays disabled until a file is selected', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    var importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);
  });

  testWidgets(
    'selecting a file enables import and empty name shows validation',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
        repository: PeakListRepository.test(InMemoryPeakListStorage()),
      );

      await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-list-select-file')));
      await tester.pumpAndSettle();

      final importButton = tester.widget<FilledButton>(
        find.byKey(const Key('peak-list-import-button')),
      );
      expect(importButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('peak-list-import-button')));
      await tester.pumpAndSettle();

      expect(find.text('A list name is required'), findsOneWidget);
    },
  );

  testWidgets('file picker cancel is a no-op', (tester) async {
    final filePicker = TestPeakListFilePicker(selectedFilePath: null);
    await _pumpPeakListsApp(
      tester,
      filePicker: filePicker,
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    expect(filePicker.pickCallCount, 1);
    expect(find.text('No file selected'), findsOneWidget);
  });

  testWidgets('file picker failure uses modal pattern', (tester) async {
    final filePicker = TestPeakListFilePicker(
      pickError: PlatformException(
        code: 'ENTITLEMENT_NOT_FOUND',
        message: 'Read-Only or Read-Write entitlement is required.',
      ),
    );
    await _pumpPeakListsApp(
      tester,
      filePicker: filePicker,
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    expect(find.text('Peak List Import Failed'), findsOneWidget);
    expect(
      find.text('Read-Only or Read-Write entitlement is required.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('peak-list-import-error-close')),
      findsOneWidget,
    );
  });

  testWidgets(
    'duplicate name confirm path updates through background handoff',
    (tester) async {
      var importCallCount = 0;
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
        repository: PeakListRepository.test(InMemoryPeakListStorage()),
        duplicateNameChecker: (name) async => true,
        importRunner:
            ({required String listName, required String csvPath}) async {
              importCallCount += 1;
              return const PeakListImportPresentationResult(
                updated: true,
                importedCount: 1234,
                skippedCount: 1234,
              );
            },
      );

      await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('peak-list-select-file')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('peak-list-name-field')),
        'Abels',
      );
      await tester.tap(find.byKey(const Key('peak-list-import-button')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This list already exists - do you want to update the existing list?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('peak-list-update-confirm')));
      await tester.pumpAndSettle();

      expect(importCallCount, 1);
      expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
      expect(find.textContaining('Import complete:'), findsOneWidget);
    },
  );

  testWidgets(
    'accepted import closes immediately and failure uses background job path',
    (tester) async {
      final completer = Completer<PeakListImportPresentationResult>();
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
        repository: PeakListRepository.test(InMemoryPeakListStorage()),
        importRunner: ({required String listName, required String csvPath}) {
          return completer.future;
        },
      );

      await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('peak-list-select-file')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('peak-list-name-field')),
        'Abels',
      );
      await tester.tap(find.byKey(const Key('peak-list-import-button')));
      await tester.pump();

      completer.completeError(StateError('boom'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
      expect(find.byKey(const Key('background-jobs-entry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('background-jobs-entry')));
      await tester.pump();

      expect(find.byKey(const Key('background-jobs-panel')), findsOneWidget);
      expect(
        find.byKey(const Key('background-jobs-label-background-job-1')),
        findsOneWidget,
      );
      expect(find.text('Failed'), findsOneWidget);
    },
  );

  testWidgets('ranked import failure shows the exact validation message', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
      importRunner:
          ({required String listName, required String csvPath}) async {
            throw const FormatException(
              'row 2 is missing osmId (Monte Amariana)',
            );
          },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'FVG Ranked',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Import failed:'), findsOneWidget);
    expect(
      find.textContaining('row 2 is missing osmId (Monte Amariana)'),
      findsOneWidget,
    );
    expect(
      find.text('FormatException: row 2 is missing osmId (Monte Amariana)'),
      findsNothing,
    );
  });

  testWidgets('app-owned export import succeeds through the existing dialog', (
    tester,
  ) async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          101,
          'Old Peak',
          -41.85916,
          145.97754,
          elevation: 1200,
        ).copyWith(sourceOfTruth: Peak.sourceOfTruthOsm),
      ]),
    );
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(),
      peakRepository: peakRepository,
    );
    final service = PeakListImportService(
      peakRepository: peakRepository,
      peakListRepository: repository,
      csvLoader: (_) async => _appOwnedCsv([
        _appOwnedCsvRowForPeak(
          _buildPeak(
            101,
            'Imported Peak',
            -41.85916,
            145.97754,
            elevation: 1363,
          ).copyWith(
            altName: 'Imported Alt',
            country: 'Australia',
            county: 'Central Highlands',
            range: 'Du Cane',
            region: 'tasmania',
            sourceOfTruth: Peak.sourceOfTruthHwc,
          ),
          points: 3,
        ),
        _appOwnedCsvRowForPeak(
          _buildPeak(
            202,
            'Created Peak',
            -41.9000,
            145.9500,
            elevation: 1400,
          ).copyWith(
            country: 'Australia',
            county: 'Kentish',
            range: 'Great Western Tiers',
            region: 'tasmania',
            sourceOfTruth: Peak.sourceOfTruthPeakBagger,
          ),
          points: 7,
        ),
      ]),
      importRootLoader: () async => '/tmp/Bushwalking',
      logWriter: (logPath, entries) async {},
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/export.csv'),
      repository: repository,
      peakRepository: peakRepository,
      importRunner: _buildImportRunnerForTest(
        tester: tester,
        repository: repository,
        service: service,
      ),
      duplicateNameChecker: (name) async => false,
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Round Trip Import',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();

    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Round Trip Import',
    );
    expect(
      _storedMemberships(repository, 'Round Trip Import'),
      [(101, 3), (202, 7)],
    );
    expect(peakRepository.findByOsmId(101)?.name, 'Imported Peak');
    expect(peakRepository.findByOsmId(202)?.name, 'Created Peak');
  });

  testWidgets('old export header failure stays in the import flow', (
    tester,
  ) async {
    final peakRepository = PeakRepository.test(InMemoryPeakStorage());
    final repository = PeakListRepository.test(InMemoryPeakListStorage());
    final service = PeakListImportService(
      peakRepository: peakRepository,
      peakListRepository: repository,
      csvLoader: (_) async =>
          'Name,Alt Name,Elevation,Zone,mgrs100kId,Easting,Northing,Points,osmId\n'
          'Legacy Peak,,1200,55G,EP,00000,50223,3,101\n',
      importRootLoader: () async => '/tmp/Bushwalking',
      logWriter: (logPath, entries) async {},
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/legacy.csv'),
      repository: repository,
      peakRepository: peakRepository,
      importRunner: _buildImportRunnerForTest(
        tester: tester,
        repository: repository,
        service: service,
      ),
      duplicateNameChecker: (name) async => false,
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Legacy Export',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Import failed:'), findsOneWidget);
    expect(
      find.textContaining('CSV is missing required column: Height'),
      findsOneWidget,
    );

    expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peak-list-import-dialog')), findsOneWidget);
    expect(repository.getAllPeakLists(), isEmpty);
  });

  testWidgets('malformed app-owned export shows exact failure message', (
    tester,
  ) async {
    final peakRepository = PeakRepository.test(InMemoryPeakStorage());
    final repository = PeakListRepository.test(InMemoryPeakListStorage());
    final service = PeakListImportService(
      peakRepository: peakRepository,
      peakListRepository: repository,
      csvLoader: (_) async => _appOwnedCsv([
        {
          'name': 'Broken Peak',
          'altName': '',
          'elevation': '1200',
          'prominence': '',
          'rating': '',
          'difficulty': '',
          'duration': '',
          'viaFerrata': '',
          'gridZoneDesignator': '55G',
          'mgrs100kId': 'EP',
          'easting': '00000',
          'northing': '50223',
          'points': 'oops',
          'osmId': '101',
          'peakbaggerPid': '',
          'country': 'Australia',
          'region': 'tasmania',
          'county': 'Kentish',
          'range': 'Range',
          'notes': '',
          'verified': '',
          'sourceOfTruth': Peak.sourceOfTruthOsm,
        },
      ]),
      importRootLoader: () async => '/tmp/Bushwalking',
      logWriter: (logPath, entries) async {},
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/broken.csv'),
      repository: repository,
      peakRepository: peakRepository,
      importRunner: _buildImportRunnerForTest(
        tester: tester,
        repository: repository,
        service: service,
      ),
      duplicateNameChecker: (name) async => false,
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Broken Import',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Import failed:'), findsOneWidget);
    expect(
      find.textContaining('invalid points "oops" on row 2 (Broken Peak)'),
      findsOneWidget,
    );
    expect(repository.getAllPeakLists(), isEmpty);
  });
}

Future<void> _pumpPeakListsApp(
  WidgetTester tester, {
  required PeakListFilePicker filePicker,
  required PeakListRepository repository,
  PeakRepository? peakRepository,
  PeaksBaggedRepository? peaksBaggedRepository,
  TestTasmapRepository? tasmapRepository,
  PeakListImportRunner? importRunner,
  PeakListDuplicateNameChecker? duplicateNameChecker,
  TestMapNotifier? mapNotifier,
  List overrides = const [],
}) async {
  final effectivePeakRepository = peakRepository ?? PeakRepository.test(InMemoryPeakStorage());
  final effectiveRepository = _effectivePeakListRepository(
    repository,
    peakRepository: effectivePeakRepository,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () =>
              mapNotifier ??
              TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 15,
                  basemap: Basemap.tracestrack,
                ),
              ),
        ),
        peakListRepositoryProvider.overrideWithValue(effectiveRepository),
        peakRepositoryProvider.overrideWithValue(effectivePeakRepository),
        tasmapRepositoryProvider.overrideWithValue(
          tasmapRepository ?? await TestTasmapRepository.create(),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          peaksBaggedRepository ??
              PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
        peakListFilePickerProvider.overrideWithValue(filePicker),
        peakListImportBackgroundRunnerProvider.overrideWithValue(({
          required String listName,
          required String csvPath,
          PeakListImportProgressCallback? onProgress,
        }) async {
          final runner =
              importRunner ??
              ({required String listName, required String csvPath}) async {
                return const PeakListImportPresentationResult(
                  updated: false,
                  importedCount: 1,
                  skippedCount: 0,
                );
              };
          return runner(listName: listName, csvPath: csvPath);
        }),
        peakListDuplicateNameCheckerProvider.overrideWithValue(
          duplicateNameChecker ?? ((name) async => false),
        ),
        ...overrides,
      ],
      child: const App(),
    ),
  );
  await tester.pump();

  router.go('/peaks');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpPeakListsScreen(
  WidgetTester tester, {
  required PeakListFilePicker filePicker,
  required PeakListRepository repository,
  PeakRepository? peakRepository,
  PeaksBaggedRepository? peaksBaggedRepository,
  TestTasmapRepository? tasmapRepository,
  PeakListImportRunner? importRunner,
  PeakListDuplicateNameChecker? duplicateNameChecker,
  TestMapNotifier? mapNotifier,
  int? initialPeakListId,
  List overrides = const [],
}) async {
  final effectivePeakRepository = peakRepository ?? PeakRepository.test(InMemoryPeakStorage());
  final effectiveRepository = _effectivePeakListRepository(
    repository,
    peakRepository: effectivePeakRepository,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () =>
              mapNotifier ??
              TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 15,
                  basemap: Basemap.tracestrack,
                ),
              ),
        ),
        peakListRepositoryProvider.overrideWithValue(effectiveRepository),
        peakRepositoryProvider.overrideWithValue(effectivePeakRepository),
        tasmapRepositoryProvider.overrideWithValue(
          tasmapRepository ?? await TestTasmapRepository.create(),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          peaksBaggedRepository ??
              PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
        peakListFilePickerProvider.overrideWithValue(filePicker),
        peakListImportBackgroundRunnerProvider.overrideWithValue(({
          required String listName,
          required String csvPath,
          PeakListImportProgressCallback? onProgress,
        }) async {
          final runner =
              importRunner ??
              ({required String listName, required String csvPath}) async {
                return const PeakListImportPresentationResult(
                  updated: false,
                  importedCount: 1,
                  skippedCount: 0,
                );
              };
          return runner(listName: listName, csvPath: csvPath);
        }),
        peakListDuplicateNameCheckerProvider.overrideWithValue(
          duplicateNameChecker ?? ((name) async => false),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        home: PeakListsScreen(initialPeakListId: initialPeakListId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

List<PeakList> _buildLists(List<String> names) {
  return [
    for (var index = 0; index < names.length; index++)
      PeakList(name: names[index])..peakListId = index + 1,
  ];
}

PeakListRepository _effectivePeakListRepository(
  PeakListRepository repository, {
  required PeakRepository peakRepository,
}) {
  if (repository.runtimeType != PeakListRepository ||
      repository.peakRepository != null) {
    return repository;
  }
  return _peakListRepository(
    repository.getAllPeakLists(),
    peakRepository: peakRepository,
  );
}

PeakListRepository _peakListRepository(
  List<PeakList> peakLists, {
  PeakRepository? peakRepository,
}) {
  final listsById = {for (final peakList in peakLists) peakList.peakListId: peakList};
  final repository = peakRepository ?? PeakRepository.test(InMemoryPeakStorage());
  final items = <PeakListItemEntity>[];
  var itemId = 1;
  for (final peakList in peakLists) {
    for (final item in _registeredPeakListItems[peakList] ?? const <PeakListItem>[]) {
      items.add(
        PeakListItemEntity(id: itemId++, points: item.points)
          ..peakList.target = listsById[peakList.peakListId]!
          ..peak.target =
              repository.findByOsmId(item.peakOsmId) ??
              Peak(
                osmId: item.peakOsmId,
                name: 'Peak ${item.peakOsmId}',
                latitude: -42,
                longitude: 146,
              ),
      );
    }
  }

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    peakRepository: repository,
    itemStorage: InMemoryPeakListItemEntityStorage(items),
  );
}

List<(int, int)> _storedMemberships(
  PeakListRepository repository,
  String listName,
) {
  final peakList = repository.findByName(listName)!;
  return repository
      .getPeakListItemsForList(peakList.peakListId)
      .map((item) => (item.peakOsmId, item.points))
      .toList(growable: false);
}

String _summarySentenceText(WidgetTester tester) {
  final placeholder = String.fromCharCode(0xFFFC);
  final summaryFinder = find.byKey(const Key('peak-lists-summary-sentence'));
  final summary = tester.widget<Text>(summaryFinder);
  var text = summary.textSpan?.toPlainText() ?? summary.data ?? '';
  final inlineLinkTexts = tester
      .widgetList<Text>(
        find.descendant(
          of: summaryFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data != null,
          ),
        ),
      )
      .map((widget) => widget.data!)
      .toList(growable: false);
  for (final inlineLinkText in inlineLinkTexts) {
    text = text.replaceFirst(placeholder, inlineLinkText);
  }
  return text;
}

PeakListMiniMapDebugState _miniMapDebugState(WidgetTester tester) {
  return tester
      .widget<PeakListMiniMapDebugProbe>(
        find.byKey(const Key('peak-lists-mini-map-debug-probe')),
      )
      .state;
}

Future<void> _sendMetaChord(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');
  await tester.sendKeyDownEvent(key, platform: 'macos');
  await tester.pump();
  await tester.sendKeyUpEvent(key, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');
  await tester.pump();
}

String _tooltipMessageFor(WidgetTester tester, String regionKey) {
  return tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.byKey(Key('peak-lists-region-fab-$regionKey')),
              matching: find.byType(Tooltip),
            ),
          )
          .message ??
      '';
}

({PeakListRepository repository, PeakRepository peakRepository})
_buildRegionFilterFixture() {
  return (
    repository: PeakListRepository.test(
      InMemoryPeakListStorage([
        _buildPeakList(1, 'Tas Only', [100], region: 'tasmania'),
        _buildPeakList(2, 'NSW Only', [200], region: 'new-south-wales'),
        _buildPeakList(3, 'FVG Only', [300], region: 'fvg'),
        _buildPeakList(4, 'Mixed Regions', [
          100,
          200,
        ], region: PeakList.mixedRegion),
        _buildPeakList(5, 'Legacy Region', [100], region: 'legacy-region'),
      ]),
    ),
    peakRepository: PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(100, 'Alpha Peak', -42.0, 146.0, region: 'tasmania'),
        _buildPeak(200, 'Beta Peak', -35.3, 148.9, region: 'new-south-wales'),
        _buildPeak(300, 'Gamma Peak', 46.2, 13.2, region: 'fvg'),
      ]),
    ),
  );
}

PeakListImportRunner _buildImportRunnerForTest({
  required WidgetTester tester,
  required PeakListRepository repository,
  required PeakListImportService service,
}) {
  return ({required String listName, required String csvPath}) async {
    final result = await service.importPeakList(
      listName: listName,
      csvPath: csvPath,
    );
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    ).read(peakListRevisionProvider.notifier).increment();
    return PeakListImportPresentationResult(
      updated: result.updated,
      importedCount: result.importedCount,
      skippedCount: result.skippedCount,
      warningCount: result.warningEntries.length,
      warningMessage: result.warningMessage,
      peakListId: result.peakListId,
      listName: repository.findByName(listName.trim())?.name ?? listName.trim(),
    );
  };
}

String _appOwnedCsv(List<Map<String, String>> rows) {
  final lines = [
    PeakListCsvExportService.csvHeaders.join(','),
    for (final row in rows)
      PeakListCsvExportService.csvHeaders
          .map((header) => _csvCell(row[header] ?? ''))
          .join(','),
  ];
  return '${lines.join('\n')}\n';
}

Map<String, String> _appOwnedCsvRowForPeak(Peak source, {required int points}) {
  final peak = _peakWithGrid(source);
  return {
    'name': peak.name,
    'altName': peak.altName,
    'elevation': peak.elevation?.toString() ?? '',
    'prominence': peak.prominence?.toString() ?? '',
    'rating': peak.rating?.toStringAsFixed(1) ?? '',
    'difficulty': peak.difficulty,
    'duration': peak.durationLabel.trim().isNotEmpty
        ? peak.durationLabel
        : formatPeakDurationMinutes(peak.durationMinutes),
    'viaFerrata': peak.viaFerrata,
    'gridZoneDesignator': peak.gridZoneDesignator,
    'mgrs100kId': peak.mgrs100kId,
    'easting': peak.easting,
    'northing': peak.northing,
    'points': '$points',
    'osmId': '${peak.osmId}',
    'peakbaggerPid': peak.peakbaggerPid?.toString() ?? '',
    'country': peak.country,
    'region': peak.region ?? '',
    'county': peak.county,
    'range': peak.range,
    'notes': peak.notes,
    'verified': peak.verified.toString(),
    'sourceOfTruth': peak.sourceOfTruth,
  };
}

Peak _peakWithGrid(Peak peak) {
  if (peak.gridZoneDesignator.isNotEmpty &&
      peak.mgrs100kId.isNotEmpty &&
      peak.easting.isNotEmpty &&
      peak.northing.isNotEmpty) {
    return peak;
  }

  final mgrs = PeakMgrsConverter.fromLatLng(
    LatLng(peak.latitude, peak.longitude),
  );
  return peak.copyWith(
    gridZoneDesignator: mgrs.gridZoneDesignator,
    mgrs100kId: mgrs.mgrs100kId,
    easting: mgrs.easting,
    northing: mgrs.northing,
  );
}

String _csvCell(String value) {
  if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
    return value;
  }
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

PeakList _buildPeakList(
  int id,
  String name,
  List<int> peakIds, {
  Map<int, int> pointsByPeakId = const {},
  String region = Peak.defaultRegion,
  double? minLat,
  double? maxLat,
  double? minLng,
  double? maxLng,
}) {
  final peakList = PeakList(
    name: name,
    region: region,
    minLat: minLat,
    maxLat: maxLat,
    minLng: minLng,
    maxLng: maxLng,
  )..peakListId = id;
  _registeredPeakListItems[peakList] = [
    for (final peakId in peakIds)
      PeakListItem(peakOsmId: peakId, points: pointsByPeakId[peakId] ?? 0),
  ];
  return peakList;
}

Peak _buildPeak(
  int osmId,
  String name,
  double latitude,
  double longitude, {
  double? elevation,
  double? rating,
  String difficulty = '',
  int? durationMinutes,
  String durationLabel = '',
  String? region,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: latitude,
    longitude: longitude,
    elevation: elevation,
    rating: rating,
    difficulty: difficulty,
    durationMinutes: durationMinutes,
    durationLabel: durationLabel,
    region: region,
  );
}

class _StaticPeakListMiniMapClusterDisplayOnNotifier
    extends PeakListMiniMapClusterDisplaySettingsNotifier {
  @override
  bool build() => true;
}

class _StaticPeakListMiniMapClusterDisplayOffNotifier
    extends PeakListMiniMapClusterDisplaySettingsNotifier {
  @override
  bool build() => false;
}
