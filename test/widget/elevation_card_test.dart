import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/widgets/dashboard/elevation_card.dart';

void main() {
  group('ElevationCard', () {
    testWidgets('renders loading placeholder while tracks load', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: const [],
        isLoading: true,
        settle: false,
      );

      expect(find.byKey(const Key('elevation-loading-state')), findsOneWidget);
      expect(find.byKey(const Key('elevation-empty-state')), findsNothing);
    });

    testWidgets('renders empty state when no usable tracks exist', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: const [],
      );

      expect(find.byKey(const Key('elevation-empty-state')), findsOneWidget);
      expect(find.text('No elevation data yet'), findsOneWidget);
    });

    testWidgets('renders summary controls and anchored latest window', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 3, 1, 10), ascent: 100),
          _track(20, DateTime(2026, 4, 15, 10), ascent: 200),
          _track(30, DateTime(2026, 5, 15, 10), ascent: 300),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      expect(find.byKey(const Key('elevation-card')), findsOneWidget);
      expect(find.byKey(const Key('elevation-period-dropdown')), findsOneWidget);
      expect(find.byKey(const Key('elevation-prev-window')), findsOneWidget);
      expect(find.byKey(const Key('elevation-next-window')), findsOneWidget);
      expect(find.byKey(const Key('elevation-mode-fab')), findsOneWidget);
      expect(find.byKey(const Key('elevation-bucket-0')), findsOneWidget);
      expect(find.textContaining('Visible:'), findsOneWidget);
    });

    testWidgets('updates visible summary when period changes', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          for (var month = 8; month <= 12; month++)
            _track(month, DateTime(2025, month, 15, 10), ascent: month * 10),
          for (var month = 1; month <= 5; month++)
            _track(100 + month, DateTime(2026, month, 15, 10), ascent: month * 100),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      final initialSummary = tester.widget<Text>(find.textContaining('Visible:')).data;
      expect(initialSummary, isNotNull);

      await _selectPeriod(tester, 'Month');

      final updatedSummary = tester.widget<Text>(find.textContaining('Visible:')).data;
      expect(updatedSummary, isNotNull);
      expect(updatedSummary, isNot(initialSummary));
      expect(find.byKey(const Key('elevation-scroll-view')), findsOneWidget);
    });

    testWidgets('toggles display mode', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 5, 1, 10), ascent: 100),
          _track(20, DateTime(2026, 5, 15, 10), ascent: 300),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');

      expect(find.byIcon(Icons.show_chart), findsOneWidget);

      await tester.tap(find.byKey(const Key('elevation-mode-fab')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);

      await _hoverBucket(tester, 14);

      expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('15'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('300 m'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('preserves scroll position when the period changes', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          for (var day = 1; day <= 15; day++)
            _track(
              day,
              DateTime(2026, 5, day, 10),
              ascent: day * 10,
            ),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');
      await tester.drag(
        find.byKey(const Key('elevation-scroll-view')),
        const Offset(-144, 0),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byKey(const Key('elevation-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      final before = tester.state<ScrollableState>(scrollableFinder).position.pixels;

      await tester.drag(scrollableFinder, const Offset(300, 0));
      await tester.pumpAndSettle();

      final afterDrag = tester.state<ScrollableState>(scrollableFinder).position.pixels;
      expect(afterDrag, isNot(before));

      await _selectPeriod(tester, 'Last 3 Months');

      final after = tester.state<ScrollableState>(scrollableFinder).position.pixels;

      expect(after, closeTo(afterDrag, 16));
    });

    testWidgets('renders repeated month labels for 3 and 6 month views', (
      tester,
    ) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 3, 4, 10), ascent: 100),
          _track(20, DateTime(2026, 4, 15, 10), ascent: 200),
          _track(30, DateTime(2026, 5, 15, 10), ascent: 300),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Last 3 Months');
      expect(find.text('Mar'), findsWidgets);
      expect(find.text('Apr'), findsWidgets);
      expect(find.text('May'), findsWidgets);

      await _selectPeriod(tester, 'Last 6 Months');

      final scrollableFinder = find
          .descendant(
            of: find.byKey(const Key('elevation-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scrollableFinder, const Offset(800, 0));
      await tester.pumpAndSettle();

      expect(find.text('Apr'), findsWidgets);
      expect(find.text('May'), findsWidgets);
    });

    testWidgets('shows tooltip when tapped on touch devices', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 5, 15, 10), ascent: 300),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');

      await tester.tap(find.byKey(const Key('elevation-bucket-14')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('15'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('300 m'),
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpElevationCard(
  WidgetTester tester, {
  required List<GpxTrack> tracks,
  bool isLoading = false,
  DateTime? now,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 320,
          child: ElevationCard(
            tracks: tracks,
            isLoading: isLoading,
            now: now,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('elevation-period-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _hoverBucket(WidgetTester tester, int index) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);

  final bucket = find.byKey(Key('elevation-bucket-$index'));
  await mouse.addPointer(location: tester.getCenter(bucket));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(bucket));
  await tester.pump();
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  double? ascent,
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    ascent: ascent,
  );
}
