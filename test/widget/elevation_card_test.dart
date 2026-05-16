import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/widgets/dashboard/elevation_card.dart';

void main() {
  group('ElevationCard', () {
    testWidgets('renders loading placeholder while tracks load', (
      tester,
    ) async {
      await _pumpElevationCard(
        tester,
        tracks: const [],
        isLoading: true,
        settle: false,
      );

      expect(find.byKey(const Key('elevation-loading-state')), findsOneWidget);
      expect(find.byKey(const Key('elevation-empty-state')), findsNothing);
    });

    testWidgets('renders empty state when no usable tracks exist', (
      tester,
    ) async {
      await _pumpElevationCard(tester, tracks: const []);

      expect(find.byKey(const Key('elevation-empty-state')), findsOneWidget);
      expect(find.text('No elevation data yet'), findsOneWidget);
    });

    testWidgets('renders summary controls and anchored latest window', (
      tester,
    ) async {
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
      expect(_cardControl('summary-period-dropdown'), findsOneWidget);
      expect(_cardControl('summary-prev-window'), findsOneWidget);
      expect(_cardControl('summary-next-window'), findsOneWidget);
      expect(_cardControl('summary-mode-fab'), findsOneWidget);
      expect(find.byKey(const Key('elevation-bucket-0')), findsOneWidget);
    });

    testWidgets('shows the visible date range under the dropdown', (
      tester,
    ) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          for (var day = 9; day <= 15; day++)
            _track(day, DateTime(2026, 5, day, 10), ascent: day * 10),
        ],
        now: DateTime(2026, 5, 15, 12),
        width: 520,
      );

      await _selectPeriod(tester, 'Week');

      expect(find.byKey(const Key('elevation-period-range')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('elevation-period-range')))
            .data,
        'Sat, 9 May - Fri, 15 May 2026',
      );
    });

    testWidgets('enables previous scrolling in week view', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          for (var day = 1; day <= 30; day++)
            _track(day, DateTime(2026, 5, day, 10), ascent: day * 10),
        ],
        now: DateTime(2026, 5, 30, 12),
        width: 420,
      );

      await _selectPeriod(tester, 'Week');

      expect(
        tester
            .widget<IconButton>(_cardControl('summary-prev-window'))
            .onPressed,
        isNotNull,
      );

      final scrollableFinder = find
          .descendant(
            of: find.byKey(const Key('elevation-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      final before = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .pixels;

      await tester.tap(_cardControl('summary-prev-window'));
      await tester.pumpAndSettle();

      final after = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .pixels;
      expect(after, lessThan(before));
    });

    testWidgets('enables previous scrolling in month view', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          for (var day = 1; day <= 30; day++)
            _track(day, DateTime(2026, 4, day, 10), ascent: day * 10),
          for (var day = 1; day <= 30; day++)
            _track(100 + day, DateTime(2026, 5, day, 10), ascent: day * 10),
        ],
        now: DateTime(2026, 5, 30, 12),
        width: 420,
      );

      await _selectPeriod(tester, 'Month');

      expect(
        tester
            .widget<IconButton>(_cardControl('summary-prev-window'))
            .onPressed,
        isNotNull,
      );

      final scrollableFinder = find
          .descendant(
            of: find.byKey(const Key('elevation-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      final before = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .pixels;

      await tester.tap(_cardControl('summary-prev-window'));
      await tester.pumpAndSettle();

      final after = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .pixels;
      expect(after, lessThan(before));
    });

    testWidgets('reports visible summary when period changes', (tester) async {
      ElevationVisibleSummary? summary;

      await _pumpElevationCard(
        tester,
        tracks: [
          for (var month = 8; month <= 12; month++)
            _track(month, DateTime(2025, month, 15, 10), ascent: month * 10),
          for (var month = 1; month <= 5; month++)
            _track(
              100 + month,
              DateTime(2026, month, 15, 10),
              ascent: month * 100,
            ),
        ],
        now: DateTime(2026, 5, 15, 12),
        onVisibleSummaryChanged: (value) => summary = value,
      );

      final initialSummary = summary;
      expect(initialSummary, isNotNull);

      await _selectPeriod(tester, 'Month');

      final updatedSummary = summary;
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
          _track(30, DateTime(2026, 5, 31, 10), ascent: 1234),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');

      expect(find.byIcon(Icons.show_chart), findsOneWidget);

      await tester.tap(_cardControl('summary-mode-fab'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);

      await _hoverBucket(tester, 30);

      expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('31 May'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('1,234 m'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reanchors to the latest range when the period changes', (
      tester,
    ) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          for (var day = 1; day <= 15; day++)
            _track(day, DateTime(2026, 4, day, 10), ascent: day * 10),
          for (var day = 1; day <= 15; day++)
            _track(100 + day, DateTime(2026, 5, day, 10), ascent: day * 10),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');
      await tester.drag(
        find.byKey(const Key('elevation-scroll-view')),
        const Offset(-144, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(_cardControl('summary-prev-window'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('elevation-period-range')))
            .data,
        isNot(contains('Thu, 30 Apr - Fri, 15 May 2026')),
      );

      await _selectPeriod(tester, 'Last 3 Months');

      expect(
        tester
            .widget<Text>(find.byKey(const Key('elevation-period-range')))
            .data,
        'Wed, 1 Apr - Wed, 13 May 2026',
      );
    });

    testWidgets('renders a single label per month for 3 and 6 month views', (
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
      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);

      await _selectPeriod(tester, 'Last 6 Months');

      final scrollableFinder = find
          .descendant(
            of: find.byKey(const Key('elevation-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scrollableFinder, const Offset(800, 0));
      await tester.pumpAndSettle();

      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);
    });

    testWidgets('shows tooltip when tapped on touch devices', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [_track(10, DateTime(2026, 5, 31, 10), ascent: 1234)],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');

      expect(find.byKey(const Key('elevation-bucket-30')), findsOneWidget);

      await tester.tap(find.byKey(const Key('elevation-bucket-30')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('31 May'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('1,234 m'),
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
  double width = 420,
  ValueChanged<ElevationVisibleSummary?>? onVisibleSummaryChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 320,
          child: ElevationCard(
            tracks: tracks,
            isLoading: isLoading,
            now: now,
            onVisibleSummaryChanged: onVisibleSummaryChanged,
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
  await tester.tap(_cardControl('summary-period-dropdown'));
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

GpxTrack _track(int id, DateTime? trackDate, {double? ascent}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    ascent: ascent,
  );
}

Finder _cardControl(String key) {
  return find.descendant(
    of: find.byKey(const Key('elevation-card')),
    matching: find.byKey(Key(key)),
  );
}
