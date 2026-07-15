import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets(
    'filter popup renders fixed rows and clear filters keeps the panel open',
    (tester) async {
      final notifier = TestMapNotifier(_baseState());
      await _pumpApp(tester, notifier);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('shared-app-bar'))),
      );

      expect(_filterTriggerText('Filter'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app-bar-map-filter-trigger')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('map-metadata-filter-popup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('map-metadata-filter-row-rating')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('map-metadata-filter-row-difficulty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('map-metadata-filter-row-duration')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('map-metadata-filter-duration-trigger')),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Any',
        '4h',
        '8h',
        '12h',
        '2d',
        '5d',
        '10d',
        '2d+',
      ]) {
        expect(
          find.byKey(Key('map-metadata-filter-duration-option-$label')),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.byKey(const Key('map-metadata-filter-duration-option-4h')),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).peakDurationFilter,
        PeakDurationFilterOption.upTo4Hours,
      );
      expect(
        find.byKey(const Key('map-metadata-filter-popup')),
        findsOneWidget,
      );
      expect(_filterTriggerText('1 Filter'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-metadata-filter-clear')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('map-metadata-filter-popup')),
        findsOneWidget,
      );
      expect(
        container.read(mapProvider).peakDurationFilter,
        PeakDurationFilterOption.any,
      );
      expect(_filterTriggerText('Filter'), findsOneWidget);

      final backdropRect = tester.getRect(
        find.byKey(const Key('map-metadata-filter-backdrop')),
      );
      await tester.tapAt(backdropRect.bottomRight - const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-metadata-filter-popup')), findsNothing);
    },
  );

  testWidgets(
    'filter selections apply immediately and persist across route revisits',
    (tester) async {
      final notifier = TestMapNotifier(_baseState());
      await _pumpApp(tester, notifier);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('shared-app-bar'))),
      );

      await tester.tap(find.byKey(const Key('app-bar-map-filter-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-metadata-filter-rating-trigger')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-metadata-filter-rating-option-4.5')),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).peakRatingFilter,
        PeakRatingFilterOption.atLeast4_5,
      );
      expect(
        container
            .read(filteredPeaksProvider)
            .map((peak) => peak.osmId)
            .toList(),
        [200, 300],
      );
      expect(_filterTriggerText('1 Filter'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      router.go('/map');
      await tester.pumpAndSettle();

      expect(_filterTriggerText('1 Filter'), findsOneWidget);
      expect(
        container.read(mapProvider).peakRatingFilter,
        PeakRatingFilterOption.atLeast4_5,
      );
      expect(
        container
            .read(filteredPeaksProvider)
            .map((peak) => peak.osmId)
            .toList(),
        [200, 300],
      );
    },
  );

  testWidgets(
    'stale selected difficulty stays visible while scope options refresh',
    (tester) async {
      final notifier = TestMapNotifier(_baseState());
      await _pumpApp(tester, notifier);

      await tester.tap(find.byKey(const Key('app-bar-map-filter-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-metadata-filter-difficulty-trigger')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('map-metadata-filter-difficulty-option-fvg-t')),
      );
      await tester.pumpAndSettle();

      notifier.state = notifier.state.copyWith(
        peaks: [
          _peak(
            100,
            'Tas Easy',
            -42.0,
            146.0,
            rating: 4.2,
            difficulty: 'Easy',
            durationMinutes: 240,
            region: 'tasmania',
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('T (Fvg)'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('map-metadata-filter-difficulty-trigger')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('map-metadata-filter-difficulty-option-tasmania-easy'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('map-metadata-filter-difficulty-option-fvg-t')),
        findsNothing,
      );
    },
  );
}

Finder _filterTriggerText(String label) {
  return find.descendant(
    of: find.byKey(const Key('app-bar-map-filter-trigger')),
    matching: find.text(label),
  );
}

Future<void> _pumpApp(WidgetTester tester, TestMapNotifier notifier) async {
  final tasmapRepository = await TestTasmapRepository.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
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

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      _peak(
        100,
        'Tas Easy',
        -42.0,
        146.0,
        rating: 4.2,
        difficulty: 'Easy',
        durationMinutes: 240,
        region: 'tasmania',
      ),
      _peak(
        200,
        'FVG T',
        46.2,
        13.2,
        rating: 4.8,
        difficulty: 'T',
        durationMinutes: 180,
        region: 'fvg',
      ),
      _peak(
        300,
        'Slovenia Long',
        46.4,
        14.5,
        rating: 4.9,
        difficulty: 'T4',
        durationMinutes: 3000,
        region: 'slovenia',
      ),
      _peak(400, 'Blank Peak', -42.2, 146.2, region: 'tasmania'),
    ],
  );
}

Peak _peak(
  int osmId,
  String name,
  double latitude,
  double longitude, {
  double? rating,
  String difficulty = '',
  int? durationMinutes,
  String durationLabel = '',
  required String region,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: latitude,
    longitude: longitude,
    rating: rating,
    difficulty: difficulty,
    durationMinutes: durationMinutes,
    durationLabel: durationLabel,
    region: region,
  );
}
