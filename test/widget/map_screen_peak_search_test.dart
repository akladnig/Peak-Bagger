import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/map_search_popup.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('AppBar Search popup opens and closes', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('map-search-input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-search-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('map-search-input')), findsNothing);
    expect(container.read(mapProvider).showPeakSearch, isFalse);
  });

  testWidgets(
    'Search popup opens with default filter region sort and empty query',
    (tester) async {
      await _pumpMapApp(tester, _mapStateWithPeaks());

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();

      final state = container.read(mapProvider);
      expect(state.searchPopupEntityFilter, MapSearchEntityFilter.all);
      expect(state.searchPopupRegionKey, 'tasmania');
      expect(state.searchPopupSort, MapSearchSort.nameAscending);
      expect(state.searchPopupGroup, MapSearchGroup.none);
      expect(state.searchPopupQuery, isEmpty);
    },
  );

  testWidgets('Search popup shows empty state for no matches', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'zzz');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets(
    'Track date picker applies a single date and an inclusive range',
    (tester) async {
      final notifier = TestMapNotifier(
        _mapStateWithPeaks(),
        gpxTrackRepository: GpxTrackRepository.test(
          InMemoryGpxTrackStorage([
            _track(1, 'First dated walk', trackDate: DateTime(2024, 7, 28)),
            _track(2, 'Second dated walk', trackDate: DateTime(2024, 7, 30)),
          ]),
        ),
      );
      await _pumpMapAppWithNotifier(tester, notifier);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Any date'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      final startInput = find.byKey(const Key('map-search-date-start-input'));
      await tester.tap(startInput);
      await tester.enterText(startInput, '28 Jul 2024');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('map-search-date-start-input')),
            )
            .controller!
            .text,
        '28 Jul 2024',
      );
      await tester.tap(find.byKey(const Key('map-search-date-apply')));
      await tester.pumpAndSettle();

      expect(find.text('28 Jul 2024'), findsOneWidget);
      expect(
        find.byKey(const Key('map-search-result-track-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-search-result-track-2')), findsNothing);
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNotNull);

      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      final endInput = find.byKey(const Key('map-search-date-end-input'));
      await tester.tap(endInput);
      await tester.enterText(endInput, '30 Jul 2024');
      await tester.pump();
      await tester.tap(find.byKey(const Key('map-search-date-apply')));
      await tester.pumpAndSettle();

      expect(find.text('28 Jul 2024 - 30 Jul 2024'), findsOneWidget);
      expect(
        find.byKey(const Key('map-search-result-track-2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-search-entity-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-search-date-picker')), findsNothing);
      expect(find.text('28 Jul 2024 - 30 Jul 2024'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-search-date-close')));
      await tester.pumpAndSettle();
      expect(find.text('28 Jul 2024 - 30 Jul 2024'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-search-date-picker')), findsNothing);
      expect(find.byKey(const Key('map-search-input')), findsOneWidget);
    },
  );

  testWidgets(
    'Track date picker keeps drafts local, navigates months, and clears in place',
    (tester) async {
      await _pumpMapApp(tester, _mapStateWithPeaks());
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      final initialMonth = tester.widget<Text>(
        find.byKey(const Key('map-search-date-start-calendar-label')),
      );
      await tester.tap(
        find.byKey(const Key('map-search-date-start-next-month')),
      );
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('map-search-date-start-calendar-label')),
            )
            .data,
        isNot(initialMonth.data),
      );

      final endInput = find.byKey(const Key('map-search-date-end-input'));
      await tester.tap(endInput);
      await tester.enterText(endInput, '28 Jul 2024');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('map-search-date-start-input')),
            )
            .controller!
            .text,
        '28 Jul 2024',
      );
      await tester.tap(find.byKey(const Key('map-search-date-cancel')));
      await tester.pumpAndSettle();

      expect(container.read(mapProvider).searchPopupTrackDateRange, isNull);
      expect(find.byKey(const Key('map-search-date-picker')), findsNothing);

      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      final startInput = find.byKey(const Key('map-search-date-start-input'));
      await tester.tap(startInput);
      await tester.enterText(startInput, '30 Jul 2024');
      await tester.pump();
      final reversedEndInput = find.byKey(
        const Key('map-search-date-end-input'),
      );
      await tester.tap(reversedEndInput);
      await tester.enterText(reversedEndInput, '28 Jul 2024');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('map-search-date-apply')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('map-search-date-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-search-date-picker')), findsOneWidget);
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNull);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('map-search-date-start-input')),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('Track date picker uses its injected clock for empty calendars', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchPopup(
            focusNode: focusNode,
            searchResults: const [],
            isLoadingMore: false,
            isExhausted: true,
            searchQuery: '',
            trackDateRange: null,
            entityFilter: MapSearchEntityFilter.all,
            selectedRegionKey: null,
            sort: MapSearchSort.nameAscending,
            group: MapSearchGroup.none,
            availableRegions: const <MapSearchRegionOption>[],
            onChanged: (_) {},
            onSelectEntityFilter: (_) {},
            onSelectTrackDateRange: (_) {},
            onSelectRegionKey: (_) {},
            onSelectSort: (_) {},
            onSelectGroup: (_) {},
            onLoadMore: () {},
            onClose: () {},
            onSelectResult: (_) {},
            clock: () => DateTime(1962, 7, 28),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('map-search-date-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('Jul 1962'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('map-search-date-start-day-28')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('map-search-date-start-input')),
          )
          .controller!
          .text,
      '28 Jul 1962',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    focusNode.dispose();
  });

  testWidgets('typed track date searches by range and rejects invalid dates', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      _mapStateWithPeaks(),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([
          _track(1, 'Dated Track', trackDate: DateTime(2024, 7, 28)),
        ]),
      ),
    );
    await _pumpMapAppWithNotifier(tester, notifier);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('map-search-input')),
      '28/7/24',
    );
    await tester.pump();

    expect(container.read(mapProvider).searchPopupQuery, isEmpty);
    expect(container.read(mapProvider).searchPopupTrackDateRange, isNotNull);
    expect(find.byKey(const Key('map-search-result-track-1')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('map-search-input')),
      '29/2/2023',
    );
    await tester.pump();

    expect(container.read(mapProvider).searchPopupTrackDateRange, isNull);
    expect(find.text('Enter a valid date or date range'), findsOneWidget);
    expect(find.byKey(const Key('map-search-result-track-1')), findsNothing);
  });

  testWidgets('typed dates keep raw text and synchronize the active range', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      _mapStateWithPeaks(),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([
          _track(1, 'Bonnet dated walk', trackDate: DateTime(1962, 7, 28)),
          _track(2, 'Other dated walk', trackDate: DateTime(1962, 7, 30)),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(
            baggedId: 1,
            peakId: 6406,
            gpxId: 1,
            date: DateTime(1962, 7, 28),
          ),
        ]),
      ),
    );
    await _pumpMapAppWithNotifier(tester, notifier);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    final input = find.byKey(const Key('map-search-input'));

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    for (final query in ['28/7/62', '28/07/1962', '28 Jul 62', '28 JUL 1962']) {
      await tester.enterText(input, query);
      await tester.pump();

      expect(container.read(mapProvider).searchPopupQuery, isEmpty);
      expect(tester.widget<TextField>(input).controller!.text, query);
      expect(find.text('28 Jul 1962'), findsOneWidget);
      expect(
        find.byKey(const Key('map-search-result-track-1')),
        findsOneWidget,
      );
    }

    await tester.enterText(input, '28 Jul 62..30 Jul 62');
    await tester.pump();
    expect(find.text('28 Jul 1962 - 30 Jul 1962'), findsOneWidget);
    expect(find.byKey(const Key('map-search-result-track-2')), findsOneWidget);
    expect(
      find.byKey(const Key('map-search-result-peak-6406')),
      findsOneWidget,
    );

    await tester.enterText(input, '28/7/62 - 30/7/62');
    await tester.pump();
    expect(find.text('28 Jul 1962 - 30 Jul 1962'), findsOneWidget);
  });

  testWidgets(
    'typed date replacements clear only typed ranges and reject invalid input',
    (tester) async {
      final notifier = TestMapNotifier(
        _mapStateWithPeaks(),
        gpxTrackRepository: GpxTrackRepository.test(
          InMemoryGpxTrackStorage([
            _track(1, 'Bonnet dated walk', trackDate: DateTime(1962, 7, 28)),
          ]),
        ),
      );
      await _pumpMapAppWithNotifier(tester, notifier);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      final input = find.byKey(const Key('map-search-input'));

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(input, '28 Jul 62');
      await tester.pump();
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNotNull);

      await tester.enterText(input, '28 Jul');
      await tester.pump();
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNull);
      expect(
        find.byKey(const Key('map-search-date-query-validation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-search-result-track-1')), findsNothing);

      await tester.enterText(input, '123 Peak');
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const Key('map-search-date-query-validation')),
        findsNothing,
      );
      expect(container.read(mapProvider).searchPopupQuery, '123 Peak');

      await tester.enterText(input, 'Bonnet 28 Jul 62');
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNull);
      expect(container.read(mapProvider).searchPopupQuery, 'Bonnet 28 Jul 62');

      await tester.enterText(input, '28 Jul 62');
      await tester.pump();
      await tester.tap(find.byKey(const Key('map-search-date-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-search-date-start-input')));
      await tester.enterText(
        find.byKey(const Key('map-search-date-start-input')),
        '28 Jul 1962',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('map-search-date-apply')));
      await tester.pumpAndSettle();
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNotNull);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);

      await tester.enterText(input, 'B');
      await tester.pump();
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNotNull);
      expect(
        find.byKey(const Key('map-search-result-track-1')),
        findsOneWidget,
      );

      await tester.enterText(input, '');
      await tester.pump();
      expect(container.read(mapProvider).searchPopupTrackDateRange, isNotNull);
    },
  );

  testWidgets(
    'Search popup keeps empty queries blank, shows helper under threshold, and only shows no-results after a real search',
    (tester) async {
      await _pumpMapApp(tester, _mapStateWithPeaks());

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();

      expect(find.text('No results found'), findsNothing);
      expect(
        find.text(
          'Type at least ${MapConstants.searchPopupMinimumQueryLength} characters',
        ),
        findsNothing,
      );

      await tester.enterText(find.byKey(const Key('map-search-input')), 'B');
      await tester.pump();

      expect(
        find.text(
          'Type at least ${MapConstants.searchPopupMinimumQueryLength} characters',
        ),
        findsOneWidget,
      );
      expect(find.text('No results found'), findsNothing);

      await tester.enterText(find.byKey(const Key('map-search-input')), 'ZZZ');
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('No results found'), findsOneWidget);
    },
  );

  testWidgets('selecting a Search popup peak result centers on the peak', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.widgetWithText(ListTile, 'Bonnet Hill'));
    await tester.pump();

    final state = container.read(mapProvider);
    expect(find.byKey(const Key('map-search-input')), findsNothing);
    expect(state.selectedPeaks.map((peak) => peak.osmId), contains(6406));
    expect(state.center, const LatLng(-43.0, 147.0));
    expect(state.selectedLocation, isNull);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
  });

  testWidgets(
    'Search popup clears stale results immediately when the query shrinks under threshold',
    (tester) async {
      await _pumpMapApp(tester, _mapStateWithPeaks());

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('map-search-input')),
        'Bonnet',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('map-search-input')), 'B');
      await tester.pump();

      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsNothing,
      );
      expect(
        find.text(
          'Type at least ${MapConstants.searchPopupMinimumQueryLength} characters',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Search popup result shows height and map name', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));

    final tile = find.widgetWithText(ListTile, 'Bonnet Hill');
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('410 m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('Resolved Map')),
      findsOneWidget,
    );
  });

  testWidgets('Search popup result shows a dash for unknown height', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithUnknownHeightPeak());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));

    final tile = find.widgetWithText(ListTile, 'Bonnet Hill');
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('—')), findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.textContaining('Resolved Map')),
      findsOneWidget,
    );
  });

  testWidgets(
    'entity buttons filter results and disabled placeholders stay inert',
    (tester) async {
      final trackRepository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1, 'Bonnet Track')]),
      );
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final notifier = TestMapNotifier(
        _mapStateWithPeaks(),
        gpxTrackRepository: trackRepository,
        routeRepository: routeRepository,
      );
      await _pumpMapAppWithNotifier(tester, notifier);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-search-input')),
        'Bonnet',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('map-search-result-track-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('map-search-entity-peaks')));
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).searchPopupEntityFilter,
        MapSearchEntityFilter.peaks,
      );
      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-search-result-track-1')), findsNothing);

      final naturalButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('map-search-entity-natural')),
      );
      expect(naturalButton.onPressed, isNull);
    },
  );

  testWidgets(
    'under-threshold control changes stay visible and the first threshold query applies them immediately',
    (tester) async {
      final trackRepository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([
          _trackAt(1, 'Peak Track', const LatLng(-33.8, 149.1)),
        ]),
      );
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final notifier = TestMapNotifier(
        _mapStateWithThresholdControlledResults(),
        gpxTrackRepository: trackRepository,
        routeRepository: routeRepository,
      );
      await _pumpMapAppWithNotifier(tester, notifier);

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('map-search-input')), 'P');
      await tester.pump();

      final helperText = find.text(
        'Type at least ${MapConstants.searchPopupMinimumQueryLength} characters',
      );
      expect(helperText, findsOneWidget);

      await tester.tap(find.byKey(const Key('map-search-entity-peaks')));
      await tester.pumpAndSettle();
      expect(helperText, findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('map-search-filter-button')),
      );
      await tester.tap(find.byKey(const Key('map-search-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-search-region-tasmania')).last,
      );
      await tester.pumpAndSettle();
      expect(helperText, findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('map-search-sort-button')),
      );
      await tester.tap(find.byKey(const Key('map-search-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-search-sort-name-descending')).last,
      );
      await tester.pumpAndSettle();
      expect(helperText, findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('map-search-group-button')),
      );
      await tester.tap(find.byKey(const Key('map-search-group-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-search-group-type')).last);
      await tester.pumpAndSettle();
      expect(helperText, findsOneWidget);

      await tester.enterText(find.byKey(const Key('map-search-input')), 'Pea');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('map-search-group-header-peaks')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-search-result-track-1')), findsNothing);
      expect(
        find.byKey(const Key('map-search-result-peak-8000')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('map-search-result-peak-7000')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('map-search-result-peak-6406')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'scrolling near the bottom appends results and shows inline loading more affordance',
    (tester) async {
      final notifier = TestMapNotifier(
        _mapStateWithPeaks(),
        gpxTrackRepository: GpxTrackRepository.test(
          InMemoryGpxTrackStorage(
            List.generate(25, (index) => _track(index + 1, 'Track $index')),
          ),
        ),
        searchPopupLoadMoreDelay: const Duration(milliseconds: 100),
      );
      await _pumpMapAppWithNotifier(tester, notifier);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-search-entity-tracks-routes')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-search-input')),
        'track',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(container.read(mapProvider).searchPopupLoadedCount, 20);
      expect(container.read(mapProvider).searchPopupIsLoadingMore, isFalse);
      expect(container.read(mapProvider).searchPopupIsExhausted, isFalse);

      await tester.drag(
        find.byKey(const Key('map-search-results-list')),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(find.byKey(const Key('map-search-loading-more')), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      expect(container.read(mapProvider).searchPopupLoadedCount, 20);
      expect(container.read(mapProvider).searchPopupIsLoadingMore, isTrue);

      await tester.drag(
        find.byKey(const Key('map-search-results-list')),
        const Offset(0, -400),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-search-loading-more')), findsNothing);
      expect(container.read(mapProvider).searchPopupLoadedCount, 25);
      expect(container.read(mapProvider).searchPopupIsLoadingMore, isFalse);
      expect(container.read(mapProvider).searchPopupIsExhausted, isTrue);
      expect(
        find.byKey(const Key('map-search-result-track-25')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'changing popup controls resets the visible list to the first page',
    (tester) async {
      final notifier = TestMapNotifier(
        _mapStateWithPeaks(),
        gpxTrackRepository: GpxTrackRepository.test(
          InMemoryGpxTrackStorage(
            List.generate(25, (index) => _track(index + 1, 'Track $index')),
          ),
        ),
      );
      await _pumpMapAppWithNotifier(tester, notifier);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-search-entity-tracks-routes')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-search-input')),
        'track',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('map-search-results-list')),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      expect(container.read(mapProvider).searchPopupLoadedCount, 25);

      await tester.ensureVisible(
        find.byKey(const Key('map-search-sort-button')),
      );
      await tester.tap(find.byKey(const Key('map-search-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-search-sort-name-descending')).last,
      );
      await tester.pumpAndSettle();

      expect(container.read(mapProvider).searchPopupLoadedCount, 20);
      expect(container.read(mapProvider).searchPopupIsLoadingMore, isFalse);
      expect(container.read(mapProvider).searchPopupIsExhausted, isFalse);
      expect(find.byKey(const Key('map-search-loading-more')), findsNothing);
    },
  );

  testWidgets('Search FAB reopens the shared Search popup with default state', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Bonnet');
    await tester.pump(const Duration(milliseconds: 250));
    container
        .read(mapProvider.notifier)
        .setSearchPopupEntityFilter(MapSearchEntityFilter.maps);
    container.read(mapProvider.notifier).setSearchPopupRegionKey(null);
    container
        .read(mapProvider.notifier)
        .setSearchPopupSort(MapSearchSort.nameDescending);
    container
        .read(mapProvider.notifier)
        .setSearchPopupGroup(MapSearchGroup.type);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-peaks-fab')));
    await tester.pumpAndSettle();

    _expectDefaultSearchPopupState(container);
  });

  testWidgets('Meta+F opens the shared Search popup with default state', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      platform: 'macos',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, platform: 'macos');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF, platform: 'macos');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');

    _expectDefaultSearchPopupState(container);
  });

  testWidgets('region menu shows manifest labels and stores canonical key', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('map-search-filter-button')),
    );
    await tester.tap(find.byKey(const Key('map-search-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tasmania'), findsWidgets);
    await tester.tap(find.byKey(const Key('map-search-region-tasmania')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupRegionKey, 'tasmania');

    await tester.ensureVisible(
      find.byKey(const Key('map-search-filter-button')),
    );
    await tester.tap(find.byKey(const Key('map-search-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-region-none')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupRegionKey, isNull);

    final filterButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const Key('map-search-filter-trigger')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(filterButton.style, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('map-search-filter-trigger')),
        matching: find.text('Filter'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'region menu options stay manifest-driven and selected labels use compact names',
    (tester) async {
      await _pumpMapApp(tester, _mapStateWithPeaks());

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();

      expect(find.text('No results found'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('map-search-filter-button')),
      );
      await tester.tap(find.byKey(const Key('map-search-filter-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-search-region-fvg')), findsNothing);
      expect(find.byKey(const Key('map-search-region-veneto')), findsNothing);
      expect(
        find.byKey(const Key('map-search-region-trentino-alto-adige')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('map-search-region-emilia-romagna')),
        findsNothing,
      );
      expect(find.byKey(const Key('map-search-region-italy')), findsNothing);
      expect(find.byKey(const Key('map-search-region-tasmania')), findsWidgets);
      expect(
        find.byKey(const Key('map-search-region-italy-nord-est')),
        findsWidgets,
      );
      expect(
        find.byKey(const Key('map-search-region-italy-nord-ovest')),
        findsWidgets,
      );
      expect(find.byKey(const Key('map-search-region-slovenia')), findsWidgets);
      expect(find.text('Italy North East'), findsWidgets);

      await tester.tap(
        find.byKey(const Key('map-search-region-italy-nord-est')).last,
      );
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).searchPopupRegionKey,
        'italy-nord-est',
      );
      expect(find.text('Italy NE'), findsOneWidget);
    },
  );

  testWidgets('group menu stores selection and groups by type', (tester) async {
    final trackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([_track(1, 'Alpha Track')]),
    );
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([_route(1, 'Alpha Route')]),
    );
    final notifier = TestMapNotifier(
      _mapStateForGrouping(),
      gpxTrackRepository: trackRepository,
      routeRepository: routeRepository,
    );
    await _pumpMapAppWithNotifier(tester, notifier, maps: [_alphaMap()]);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Alp');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('map-search-group-button')),
    );
    await tester.tap(find.byKey(const Key('map-search-group-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-group-type')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupGroup, MapSearchGroup.type);
    expect(
      find.byKey(const Key('map-search-group-header-peaks')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map-search-group-header-tracks-routes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map-search-group-header-maps')),
      findsOneWidget,
    );
  });

  testWidgets('group menu groups by region and clears back to none', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithRegionalPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
    await tester.pumpAndSettle();

    container.read(mapProvider.notifier).setSearchPopupRegionKey(null);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-search-entity-peaks')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('map-search-input')), 'Peak');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('map-search-group-button')),
    );
    await tester.tap(find.byKey(const Key('map-search-group-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-group-region')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupGroup, MapSearchGroup.region);
    expect(
      find.byKey(const Key('map-search-group-header-tas')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map-search-group-header-nsw')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('map-search-group-button')),
    );
    await tester.tap(find.byKey(const Key('map-search-group-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-search-group-none')).last);
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).searchPopupGroup, MapSearchGroup.none);
    expect(find.text('Group'), findsOneWidget);
  });
}

Future<void> _pumpMapApp(
  WidgetTester tester,
  MapState state, {
  List<Tasmap50k>? maps,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  final tasmapRepository = await TestTasmapRepository.create(
    maps: maps ?? [_resolvedMap()],
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

Future<void> _pumpMapAppWithNotifier(
  WidgetTester tester,
  MapNotifier notifier, {
  List<Tasmap50k>? maps,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  final tasmapRepository = await TestTasmapRepository.create(
    maps: maps ?? [_resolvedMap()],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
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

MapState _mapStateForGrouping() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Alpha Peak',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
        region: 'tasmania',
      ),
    ],
  );
}

MapState _mapStateWithThresholdControlledResults() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Peak Tasmania',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
        region: 'tasmania',
      ),
      Peak(
        osmId: 7000,
        name: 'Peak Alpha',
        latitude: -33.7,
        longitude: 149.0,
        elevation: 500,
        region: 'new-south-wales',
      ),
      Peak(
        osmId: 8000,
        name: 'Peak Zenith',
        latitude: -33.8,
        longitude: 149.1,
        elevation: 510,
        region: 'new-south-wales',
      ),
    ],
  );
}

GpxTrack _trackAt(int id, String name, LatLng start) {
  final segments = [
    [start, LatLng(start.latitude - 0.001, start.longitude + 0.001)],
  ];
  return GpxTrack(
    gpxTrackId: id,
    contentHash: '$id',
    trackName: name,
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson(segments),
    distance2d: 1200,
    distance3d: 1230,
    highestElevation: 500,
    ascent: 120,
  );
}

MapState _mapStateWithRegionalPeaks() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Tas Peak',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
        region: 'tasmania',
      ),
      Peak(
        osmId: 7000,
        name: 'NSW Peak',
        latitude: -33.7,
        longitude: 149.0,
        elevation: 500,
        region: 'new-south-wales',
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

Tasmap50k _alphaMap() {
  final map = _resolvedMap();
  return Tasmap50k(
    id: map.id,
    series: map.series,
    name: 'Alpha Map',
    parentSeries: map.parentSeries,
    mgrs100kIds: map.mgrs100kIds,
    eastingMin: map.eastingMin,
    eastingMax: map.eastingMax,
    northingMin: map.northingMin,
    northingMax: map.northingMax,
    p1: map.p1,
    p2: map.p2,
    p3: map.p3,
    p4: map.p4,
  );
}

GpxTrack _track(int id, String name, {DateTime? trackDate}) {
  final segments = [
    [const LatLng(-43.0, 147.0), const LatLng(-43.001, 147.001)],
  ];
  return GpxTrack(
    gpxTrackId: id,
    contentHash: '$id',
    trackName: name,
    trackDate: trackDate,
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson(segments),
    distance2d: 1200,
    distance3d: 1230,
    highestElevation: 500,
    ascent: 120,
  );
}

app_route.Route _route(int id, String name) {
  return app_route.Route(
    id: id,
    name: name,
    gpxRoute: const [LatLng(-43.0, 147.0), LatLng(-43.001, 147.001)],
    distance2d: 900,
    distance3d: 930,
    ascent: 80,
    descent: 70,
    highestElevation: 450,
  );
}

String _pointString(LatLng point) {
  return mgrs.Mgrs.forward([
    point.longitude,
    point.latitude,
  ], 5).replaceAll(RegExp(r'[\n\s]'), '').substring(3);
}

void _expectDefaultSearchPopupState(ProviderContainer container) {
  final state = container.read(mapProvider);
  expect(state.showPeakSearch, isTrue);
  expect(state.searchPopupQuery, isEmpty);
  expect(state.searchPopupResults, isEmpty);
  expect(state.searchPopupEntityFilter, MapSearchEntityFilter.all);
  expect(state.searchPopupRegionKey, 'tasmania');
  expect(state.searchPopupSort, MapSearchSort.nameAscending);
  expect(state.searchPopupGroup, MapSearchGroup.none);
}
