import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';

void main() {
  group('DistanceCard', () {
    testWidgets('renders loading placeholder while tracks load', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: const [],
        isLoading: true,
        settle: false,
      );

      expect(find.byKey(const Key('distance-loading-state')), findsOneWidget);
      expect(find.byKey(const Key('distance-empty-state')), findsNothing);
    });

    testWidgets('renders empty state when no usable tracks exist', (
      tester,
    ) async {
      await _pumpDistanceCard(tester, tracks: const []);

      expect(find.byKey(const Key('distance-empty-state')), findsOneWidget);
      expect(find.text('No distance data yet'), findsOneWidget);
    });

    testWidgets('renders summary controls and anchored latest window', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 3, 1, 10), distance2d: 1000),
          _track(20, DateTime(2026, 4, 15, 10), distance2d: 2000),
          _track(30, DateTime(2026, 5, 15, 10), distance2d: 3000),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      expect(find.byKey(const Key('distance-card')), findsOneWidget);
      expect(_cardControl('summary-period-dropdown'), findsOneWidget);
      expect(_cardControl('summary-prev-window'), findsOneWidget);
      expect(_cardControl('summary-next-window'), findsOneWidget);
      expect(_cardControl('summary-mode-fab'), findsOneWidget);
      expect(find.byKey(const Key('distance-bucket-0')), findsOneWidget);
    });

    testWidgets('reports visible summary when period changes', (tester) async {
      SummaryVisibleSummary? summary;

      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(10, DateTime(2025, 12, 15, 10), distance2d: 1000),
          _track(20, DateTime(2026, 1, 15, 10), distance2d: 2000),
          _track(30, DateTime(2026, 5, 15, 10), distance2d: 3000),
        ],
        now: DateTime(2026, 5, 15, 12),
        onVisibleSummaryChanged: (value) => summary = value,
      );

      final initialSummary = summary;
      expect(initialSummary, isNotNull);

      await _selectPeriod(tester, 'Month');

      expect(summary, isNotNull);
      expect(summary, isNot(initialSummary));
      expect(summary?.totalValue.round(), 3000);
      expect(find.byKey(const Key('distance-scroll-view')), findsOneWidget);
    });

    testWidgets('toggles display mode and shows distance tooltip', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 5, 1, 10), distance2d: 100),
          _track(20, DateTime(2026, 5, 15, 10), distance2d: 300),
          _track(30, DateTime(2026, 5, 31, 10), distance2d: 12340),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      await _selectPeriod(tester, 'Month');
      await tester.tap(_cardControl('summary-mode-fab'));
      await tester.pumpAndSettle();

      await _hoverBucket(tester, 30);

      expect(find.byKey(const Key('distance-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('distance-tooltip')),
          matching: find.text('31 May'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('distance-tooltip')),
          matching: find.text('12.3 km'),
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpDistanceCard(
  WidgetTester tester, {
  required List<GpxTrack> tracks,
  bool isLoading = false,
  DateTime? now,
  bool settle = true,
  double width = 420,
  ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 320,
          child: DistanceCard(
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

  final bucket = find.byKey(Key('distance-bucket-$index'));
  await mouse.addPointer(location: tester.getCenter(bucket));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(bucket));
  await tester.pump();
}

Finder _cardControl(String key) {
  return find.descendant(
    of: find.byKey(const Key('distance-card')),
    matching: find.byKey(Key(key)),
  );
}

GpxTrack _track(int id, DateTime? trackDate, {required double distance2d}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    distance2d: distance2d,
  );
}
