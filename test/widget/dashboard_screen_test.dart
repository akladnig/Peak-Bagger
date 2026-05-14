import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('renders six placeholder cards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpDashboard(tester, const Size(1400, 1000));

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
      await _pumpDashboard(tester, const Size(1400, 1000));
      _expectGridContract(tester, 3);

      await _pumpDashboard(tester, const Size(1000, 1000));
      _expectGridContract(tester, 2);

      await _pumpDashboard(tester, const Size(700, 1000));
      _expectGridContract(tester, 1);
    });

    testWidgets('dragging a header reorders cards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1400, 1000));
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
  });
}

Future<void> _pumpDashboard(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
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
