import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('defaults to first name-sorted map chip', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create(
      maps: [
        _map(name: 'Zulu'),
        _map(name: 'Alpha'),
      ],
    );

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
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Map Tile Cache'));
    await tester.pumpAndSettle();

    expect(find.text('Cache Status'), findsOneWidget);
    expect(find.byKey(const Key('tile-cache-basemap-dropdown')), findsOneWidget);
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-cache-download-button')), findsOneWidget);
    expect(find.byKey(const Key('tile-cache-selected-map-chip')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tile-cache-selected-map-chip')),
        matching: find.text('Alpha'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search selects map and empty results keep selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create(
      maps: [
        _map(name: 'Zulu'),
        _map(name: 'Alpha'),
        _map(name: 'Adamsons'),
      ],
    );

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
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Map Tile Cache'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tile-cache-map-search-field')),
      'Ada',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tile-cache-map-suggestion-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tile-cache-map-suggestion-0')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('tile-cache-selected-map-chip')),
        matching: find.text('Adamsons'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('tile-cache-map-search-field')),
      'Nope',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tile-cache-map-suggestion-0')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('tile-cache-selected-map-chip')),
        matching: find.text('Adamsons'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('basemap changes keep the selected map', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create(
      maps: [
        _map(name: 'Zulu'),
        _map(name: 'Alpha'),
        _map(name: 'Adamsons'),
      ],
    );

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
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Map Tile Cache'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tile-cache-map-search-field')),
      'Ada',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-cache-map-suggestion-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tile-cache-basemap-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tasmap50k').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('tile-cache-selected-map-chip')),
        matching: find.text('Adamsons'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tasmap revision reseeds missing selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create(
      maps: [
        _map(name: 'Zulu'),
        _map(name: 'Alpha'),
      ],
    );
    final notifier = RevisionOnlyTasmapNotifier(repository);

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
          tasmapStateProvider.overrideWith(() => notifier),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Map Tile Cache'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('tile-cache-selected-map-chip')),
        matching: find.text('Alpha'),
      ),
      findsOneWidget,
    );

    await repository.clearAll();
    await repository.addMaps([
      _map(name: 'Zulu'),
      _map(name: 'Beta'),
    ]);
    notifier.bumpRevision();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('tile-cache-selected-map-chip')),
        matching: find.text('Beta'),
      ),
      findsOneWidget,
    );
  });
}

Tasmap50k _map({required String name}) {
  return Tasmap50k(
    series: name,
    name: name,
    parentSeries: '8211',
    mgrs100kIds: 'DM DN',
    eastingMin: 60000,
    eastingMax: 99999,
    northingMin: 80000,
    northingMax: 9999,
    mgrsMid: 'DM',
    eastingMid: 80000,
    northingMid: 95000,
    p1: 'DN6000009999',
    p2: 'DN9999909999',
    p3: 'DM6000080000',
    p4: 'DM9999980000',
  );
}

class RevisionOnlyTasmapNotifier extends TasmapNotifier {
  RevisionOnlyTasmapNotifier(this.repository);

  final TestTasmapRepository repository;

  @override
  TasmapState build() => const TasmapState();

  void bumpRevision() {
    state = state.copyWith(
      mapCount: repository.mapCount,
      tasmapRevision: state.tasmapRevision + 1,
    );
  }
}
