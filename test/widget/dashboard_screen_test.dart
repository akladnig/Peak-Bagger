import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';

import '../harness/test_map_notifier.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('renders six placeholder cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpDashboard(tester, const Size(1400, 1800));

    for (final card in dashboardCards) {
        expect(find.text(card.title), findsOneWidget);
        expect(find.byKey(Key('dashboard-card-${card.id}')), findsOneWidget);
        expect(
          find.byKey(Key('dashboard-card-${card.id}-drag-handle')),
          findsOneWidget,
        );
      }
    });

    testWidgets('scrolls when the viewport is short', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpDashboard(tester, const Size(1400, 520));

      await tester.scrollUntilVisible(
        find.byKey(const Key('dashboard-card-top-5-walks')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('dashboard-card-top-5-walks')), findsOneWidget);
    });

    testWidgets('uses the 3/2/1 column contract', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpDashboard(tester, const Size(1600, 1000));
    _expectGridContract(tester, 3);

      await _pumpDashboard(tester, const Size(1400, 1000));
      _expectGridContract(tester, 2);

      await _pumpDashboard(tester, const Size(700, 1000));
      _expectGridContract(tester, 1);
    });

    testWidgets('dragging a header reorders cards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('dashboard-card-distance-drag-handle'));
      final target = find.byKey(const Key('dashboard-card-peaks-bagged'));
      final gestureOffset = tester.getCenter(target) - tester.getCenter(handle);

      await tester.drag(handle, gestureOffset);
      await tester.pumpAndSettle();

      expect(
        container.read(dashboardLayoutProvider),
        <String>[
          'elevation',
          'latest-walk',
          'distance',
          'peaks-bagged',
          'top-5-highest',
          'top-5-walks',
        ],
      );
    });

    testWidgets('hovering a card updates its border', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpDashboard(tester, const Size(1400, 1000));

      final cardFinder = find
          .descendant(
            of: find.byKey(const Key('dashboard-card-elevation')),
            matching: find.byType(Card),
          )
          .first;

      final initialCard = tester.widget<Card>(cardFinder);
      final initialShape = initialCard.shape as RoundedRectangleBorder;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(cardFinder));
      await tester.pump();

      final hoveredCard = tester.widget<Card>(cardFinder);
      final hoveredShape = hoveredCard.shape as RoundedRectangleBorder;

      expect(hoveredShape.side.width, 2);
      expect(hoveredShape.side.color, isNot(initialShape.side.color));

      await mouse.moveTo(const Offset(10, 10));
      await tester.pump();

      final restoredCard = tester.widget<Card>(cardFinder);
      final restoredShape = restoredCard.shape as RoundedRectangleBorder;

      expect(restoredShape.side.width, 1);
      expect(restoredShape.side.color, initialShape.side.color);
    });

    testWidgets('dragging a header updates the card border', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpDashboard(tester, const Size(1400, 1000));

      final cardFinder = find
          .descendant(
            of: find.byKey(const Key('dashboard-card-distance')),
            matching: find.byType(Card),
          )
          .first;
      final initialCard = tester.widget<Card>(cardFinder);
      final initialShape = initialCard.shape as RoundedRectangleBorder;

      final handleFinder = find.byKey(
        const Key('dashboard-card-distance-drag-handle'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(handleFinder),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);

      await gesture.moveBy(const Offset(48, 0));
      await tester.pump();

      final draggingCard = tester.widget<Card>(cardFinder);
      final draggingShape = draggingCard.shape as RoundedRectangleBorder;

      expect(draggingShape.side.width, 2);
      expect(draggingShape.side.color, isNot(initialShape.side.color));
    });
  });
}

Future<void> _pumpDashboard(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void _expectGridContract(WidgetTester tester, int columns) {
  final grid = tester.widget<GridView>(find.byKey(const Key('dashboard-board')));
  final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

  expect(delegate.crossAxisCount, columns);
  expect(delegate.childAspectRatio, dashboardCardAspectRatio);
}
