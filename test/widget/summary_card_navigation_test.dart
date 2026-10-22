import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/providers/summary_page_controller.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';
import 'package:peak_bagger/widgets/dashboard/elevation_card.dart';
import 'package:peak_bagger/widgets/dashboard/peaks_bagged_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/time_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/summary_chart_controls.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['elevation', 'distance', 'peaks-bagged', 'time']) {
    for (final view in summaryTestViews(kind)) {
      testWidgets(
        '$kind ${view.name} yearly gaps, refresh, rollover and superseded input agree',
        (tester) async {
          final h = _Harness(tester, kind);
          h.tracks = [
            _track(1, DateTime.utc(2020, 2, 29)),
            _track(2, DateTime.utc(2024, 12, 31)),
          ];
          await h.pump();
          await h.view(view);
          await h.period(SummaryPeriodPreset.yearToDate);
          h.expectPage(DateTime(2026), total: 0, average: 0);
          expect(h.chart.buckets, hasLength(12));
          await h.tap('last');
          h.expectPage(DateTime(2024), total: h.unit, average: h.unit / 12);
          expect(h.button('last').onPressed, isNull);
          expect(h.button('next').onPressed, isNotNull);
          await h.tap('next');
          h.expectPage(DateTime(2025), total: 0, average: 0);
          expect(h.chart.buckets, hasLength(12));
          expect(find.byKey(Key('$kind-empty-state')), findsNothing);
          await h.scroll(160);
          h.expectPage(DateTime(2026), total: 0);
          await h.tap('first');
          h.expectPage(DateTime(2020), total: h.unit, average: h.unit / 12);
          await h.pin();
          await h.scroll(160, settle: false);
          h.tracks = [_track(3, DateTime.utc(2019)), ...h.tracks];
          await h.pump();
          h.expectPage(DateTime(2020), total: h.unit);
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
          expect(h.button('first').onPressed, isNotNull);
          await h.tap('last');
          h.tracks = [...h.tracks, _track(4, DateTime.utc(2025))];
          await h.pump();
          h.expectPage(DateTime(2024), total: h.unit);
          expect(h.button('last').onPressed, isNotNull);
          await h.tap('first');
          h.tracks = h.tracks.where((t) => t.trackDate!.year >= 2024).toList();
          await h.pump();
          h.expectPage(DateTime(2024), total: h.unit);
          await toggleSummaryMode(tester, kind);
          await h.finish();
          h.expectPage(DateTime(2024), total: h.unit);
          h.now = DateTime(2027, 1, 1, 12);
          await h.pump();
          h.expectPage(DateTime(2024), total: h.unit);
          // Preset re-entry opens current, then a queued gesture spans rollover.
          await h.period(SummaryPeriodPreset.month);
          await h.period(SummaryPeriodPreset.yearToDate);
          h.expectPage(DateTime(2027), total: 0);
          await h.scroll(-160, settle: false);
          h.now = DateTime(2028, 1, 1, 12);
          await h.finish();
          h.expectPage(DateTime(2028), total: 0);
          await h.scroll(-160, settle: false);
          await h.tap('first', settle: false);
          await h.finish();
          h.expectPage(DateTime(2024), total: h.unit);
          await h.scroll(160, settle: false);
          await h.period(SummaryPeriodPreset.month, settle: false);
          await h.finish();
          h.expectPage(DateTime(2028, 1), total: 0);
          await h.period(SummaryPeriodPreset.yearToDate);
          h.loading = true;
          h.tracks = [];
          await h.pump(settle: false);
          expect(find.byKey(Key('$kind-loading-state')), findsOneWidget);
          expect(find.byKey(Key('$kind-empty-state')), findsNothing);
          h.loading = false;
          await h.pump();
          expect(find.byKey(Key('$kind-empty-state')), findsOneWidget);
          expect(h.summary, isNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$kind ${view.name} direct input shares every preset and bound',
        (tester) async {
          final h = _Harness(tester, kind);
          await h.pump();
          await h.view(view);
          for (final fixture in [
            (
              SummaryPeriodPreset.week,
              DateTime(2026, 10, 12),
              DateTime(2026, 10, 5),
            ),
            (SummaryPeriodPreset.month, DateTime(2026, 10), DateTime(2026, 9)),
            (
              SummaryPeriodPreset.last3Months,
              DateTime(2026, 8),
              DateTime(2026, 5),
            ),
            (
              SummaryPeriodPreset.last6Months,
              DateTime(2026, 5),
              DateTime(2025, 11),
            ),
            (
              SummaryPeriodPreset.last12Months,
              DateTime(2025, 11),
              DateTime(2024, 11),
            ),
            (SummaryPeriodPreset.allTime, DateTime(2015), DateTime(2003)),
            (SummaryPeriodPreset.yearToDate, DateTime(2026), DateTime(2025)),
          ]) {
            await h.period(fixture.$1);
            await h.scroll(-160);
            h.expectPage(fixture.$3);
            final previous = h.chart.buckets
                .map((b) => (b.start, b.endExclusive, b.value))
                .toList();
            await h.scroll(160);
            h.expectPage(fixture.$2);
            // No resting partial page, including when attempting to pass today.
            await h.scroll(160);
            h.expectPage(fixture.$2);
            await h.tap('prev');
            expect(
              h.chart.buckets.map((b) => (b.start, b.endExclusive, b.value)),
              previous,
            );
            // Real pan/zoom events exercise macOS trackpad gesture recognition.
            final pan = await tester.createGesture(
              kind: PointerDeviceKind.trackpad,
            );
            await pan.addPointer(location: tester.getCenter(h.browser));
            await pan.panZoomStart(tester.getCenter(h.browser));
            await pan.panZoomUpdate(
              tester.getCenter(h.browser),
              pan: const Offset(-160, 0),
            );
            await pan.panZoomEnd();
            await pan.removePointer();
            await h.finish();
            h.expectPage(fixture.$2);
            await h.tap('first');
            final first = h.chart.buckets.first.start;
            await h.scroll(-160);
            h.expectPage(first);
            expect(h.button('first').onPressed, isNull);
            expect(h.button('prev').onPressed, isNull);
            expect(h.button('next').onPressed, isNotNull);
            // The chart is one complete viewport, not an offset into a timeline.
            expect(h.chart.controller.offset, 0);
          }
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$kind ${view.name} overlapping navigation and preset cancel obsolete input',
        (tester) async {
          final h = _Harness(tester, kind);
          await h.pump();
          await h.view(view);
          await h.period(SummaryPeriodPreset.month);
          // Queue scroll settlement, then navigate repeatedly while chart value
          // animations and post-frame header callbacks are still pending.
          await h.scroll(-160, settle: false);
          await h.tap('prev', settle: false);
          await tester.pump(const Duration(milliseconds: 16));
          await h.tap('prev', settle: false);
          await h.tap('next', settle: false);
          await h.finish();
          h.expectPage(DateTime(2026, 9), total: 0, average: 0);
          expect(h.button('next').onPressed, isNotNull);
          await h.scroll(-160, settle: false);
          await h.period(SummaryPeriodPreset.last3Months, settle: false);
          await h.finish();
          h.expectPage(DateTime(2026, 8), total: h.unit, average: h.unit / 3);
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
          await h.tap('prev', settle: false);
          await tester.pump(const Duration(milliseconds: 20));
          await toggleSummaryMode(tester, kind);
          await h.finish();
          h.expectPage(DateTime(2026, 5), total: h.unit, average: h.unit / 3);
          expect(
            h.chart.mode,
            view.mode == SummaryDisplayMode.columns
                ? SummaryDisplayMode.line
                : SummaryDisplayMode.columns,
          );
        },
      );

      testWidgets(
        '$kind ${view.name} refresh preserves jumps, clears inspection and commits clamps',
        (tester) async {
          final h = _Harness(tester, kind);
          await h.pump();
          await h.view(view);
          await h.period(SummaryPeriodPreset.month);
          await h.tap('first');
          h.expectPage(DateTime(1989, 2), total: h.unit);
          await h.pin();
          await h.scroll(160, settle: false);
          h.tracks = [
            _track(10, DateTime.utc(1988)),
            ...h.tracks,
            _track(11, DateTime.utc(2026, 10, 15)),
          ];
          await h.pump(settle: false);
          await h.finish();
          h.expectPage(DateTime(1989, 2), total: h.unit);
          expect(h.button('first').onPressed, isNotNull);
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
          await h.tap('last');
          h.expectPage(DateTime(2026, 10), total: h.unit * 2);
          await h.pin();
          // Same bucket boundaries, changed values: old pinned data must vanish.
          await h.scroll(-160, settle: false);
          h.tracks = [...h.tracks, _track(12, DateTime.utc(2026, 10, 14))];
          await h.pump(settle: false);
          await h.finish();
          h.expectPage(DateTime(2026, 10), total: h.unit * 3);
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
          await h.tap('first');
          await h.scroll(160, settle: false);
          h.tracks = [_track(20, DateTime.utc(2020, 2, 29))];
          await h.pump(settle: false);
          await h.finish();
          h.expectPage(DateTime(2020, 2), total: h.unit);
          expect(h.button('first').onPressed, isNull);
          expect(h.button('last').onPressed, isNull);
          // Restoring earlier history cannot resurrect the pre-clamp selection.
          h.tracks = [_track(21, DateTime.utc(1989)), ...h.tracks];
          await h.pump();
          h.expectPage(DateTime(2020, 2), total: h.unit);
          h.loading = true;
          h.tracks = [];
          await h.pump(settle: false);
          expect(find.byKey(Key('$kind-loading-state')), findsOneWidget);
          expect(find.byKey(Key('$kind-empty-state')), findsNothing);
          expect(h.summary, isNull);
          h.loading = false;
          await h.pump();
          expect(find.byKey(Key('$kind-empty-state')), findsOneWidget);
          expect(h.summary, isNull);
          h.tracks = [_track(40, DateTime.utc(2026, 6, 15))];
          await h.pump();
          await h.tap('last');
          h.expectPage(DateTime(2026, 6), total: h.unit);
          h.tracks = [...h.tracks, _track(41, DateTime.utc(2026, 8, 15))];
          await h.pump();
          h.expectPage(DateTime(2026, 6), total: h.unit);
          expect(h.button('last').onPressed, isNotNull);
          expect(h.button('next').onPressed, isNotNull);
          await h.tap('last');
          h.expectPage(DateTime(2026, 8), total: h.unit);
          expect(h.button('last').onPressed, isNull);
          expect(h.button('next').onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$kind ${view.name} refreshed canonical and skipped days retain their decoding',
        (tester) async {
          final h = _Harness(tester, kind);
          await h.pump();
          await h.view(view);
          await h.period(SummaryPeriodPreset.month);
          h.tracks = [
            _track(50, DateTime.utc(2026, 10, 15)),
            _track(51, DateTime.utc(2026, 10, 14, 13, 30))
              ..trackDateStatus = TrackDateStatus.legacySkipped,
            _track(52, DateTime.utc(2026, 10, 16)),
          ];
          await h.pump();
          h.expectPage(DateTime(2026, 10), total: h.unit * 2);
          expect(h.chart.buckets[14].trackCount, 2);
          expect(h.chart.buckets[13].trackCount, 0);
          h.now = DateTime(2026, 10, 16, 12);
          // Inspection is also a timeline interaction, not just toolbar input.
          await tester.tap(find.byKey(Key('$kind-bucket-14')));
          await h.finish();
          h.expectPage(DateTime(2026, 10), total: h.unit * 3);
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
        },
      );

      testWidgets(
        '$kind ${view.name} rollover supersedes movement and remaps history by last day',
        (tester) async {
          final h = _Harness(tester, kind);
          expect(h.now.timeZoneOffset, const Duration(hours: 11));
          await h.pump();
          await h.view(view);
          await h.period(SummaryPeriodPreset.last3Months);
          // Explicitly select current using prev/next, rather than relying on an
          // uninitialised null page or a sticky "last" flag.
          await h.tap('prev');
          await h.tap('next');
          await h.scroll(-160, settle: false);
          h.now = DateTime(2026, 11, 1, 12);
          await h.finish();
          h.expectPage(DateTime(2026, 9), total: h.unit, average: h.unit / 3);
          await h.tap('prev');
          h.expectPage(DateTime(2026, 6), total: h.unit);
          // Reset to October's May–July then cross the boundary mid-drag.
          h.now = DateTime(2026, 10, 15, 12);
          await h.pump();
          await h.period(SummaryPeriodPreset.month);
          await h.period(SummaryPeriodPreset.last3Months);
          await h.tap('prev');
          h.expectPage(DateTime(2026, 5));
          final gesture = await tester.startGesture(
            tester.getCenter(h.browser),
          );
          await gesture.moveBy(const Offset(-100, 0));
          await tester.pump(const Duration(milliseconds: 16));
          h.now = DateTime(2026, 11, 1, 12);
          // Data refresh and reference change supersede the active gesture.
          h.tracks = [...h.tracks];
          await h.pump(settle: false);
          await gesture.up();
          await h.finish();
          h.expectPage(DateTime(2026, 6), total: h.unit, average: h.unit / 3);
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
          expect(h.button('last').onPressed, isNotNull);
          // Reference-day eligibility changes without changing month alignment.
          await h.period(SummaryPeriodPreset.month);
          h.now = DateTime(2026, 10, 15, 12);
          h.tracks = [
            _track(30, DateTime.utc(2026, 10, 15)),
            _track(31, DateTime.utc(2026, 10, 16)),
          ];
          await h.pump();
          h.expectPage(DateTime(2026, 10), total: h.unit);
          h.now = DateTime(2026, 10, 16, 12);
          await toggleSummaryMode(tester, kind);
          await h.finish();
          h.expectPage(DateTime(2026, 10), total: h.unit * 2);
          expect(h.tracks.last.trackDate, DateTime.utc(2026, 10, 16));
        },
      );
    }
  }

  testWidgets(
    'hover refresh and disposal during pending direct movement are safe',
    (tester) async {
      final h = _Harness(tester, 'elevation');
      await h.pump();
      await h.period(SummaryPeriodPreset.month);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(
          find.byKey(const Key('elevation-bucket-13')),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
      h.tracks = [...h.tracks, _track(60, DateTime.utc(2026, 10, 14))];
      await h.pump();
      h.expectPage(DateTime(2026, 10), total: 140);
      expect(find.byKey(const Key('elevation-tooltip')), findsNothing);
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump();
      expect(find.byKey(const Key('elevation-tooltip')), findsNothing);
      await h.scroll(-160, settle: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      await h.pump();
      final gesture = await tester.startGesture(tester.getCenter(h.browser));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(this.tester, this.kind);
  final WidgetTester tester;
  final String kind;
  DateTime now = DateTime(2026, 10, 15, 12);
  DateTime clock() => now;
  List<GpxTrack> tracks = [
    _track(1, DateTime.utc(1989, 2, 28)),
    _track(2, DateTime.utc(2005, 6, 15)),
    _track(3, DateTime.utc(2026, 6, 15)),
    _track(4, DateTime.utc(2026, 10, 14)),
  ];
  bool loading = false;
  SummaryVisibleSummary? summary;
  double get unit => kind == 'elevation'
      ? 70
      : kind == 'distance'
      ? 700
      : kind == 'time'
      ? 18000000
      : 1;
  Finder get card => find.byKey(Key('$kind-card'));
  Finder get browser => find.descendant(
    of: card,
    matching: find.byKey(Key('$kind-page-browser')),
  );
  Finder control(String key) =>
      find.descendant(of: card, matching: find.byKey(Key(key)));
  SummaryChart get chart => tester.widget<SummaryChart>(
    find.descendant(of: card, matching: find.byType(SummaryChart)),
  );
  IconButton button(String action) =>
      tester.widget<IconButton>(control('summary-$action-window'));

  Future<void> pump({bool settle = true}) async {
    Widget body = switch (kind) {
      'elevation' => ElevationCard(
        tracks: tracks,
        isLoading: loading,
        onVisibleSummaryChanged: (value) => summary = value,
      ),
      'distance' => DistanceCard(
        tracks: tracks,
        isLoading: loading,
        onVisibleSummaryChanged: (value) => summary = value,
      ),
      'time' => TimeCard(
        tracks: tracks,
        isLoading: loading,
        onVisibleSummaryChanged: (value) => summary = value,
      ),
      _ => PeaksBaggedCard(
        tracks: tracks,
        isLoading: loading,
        onVisibleSummaryChanged: (value) => summary = value,
      ),
    };
    // Existing card-sized regression fixture, not a supported window minimum.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardReferenceClockProvider.overrideWithValue(clock)],
        child: MaterialApp(
          theme: MyTheme.dark,
          home: Scaffold(body: SizedBox(width: 700, height: 400, child: body)),
        ),
      ),
    );
    if (settle) await finish();
  }

  Future<void> finish() async {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> view(SummaryTestView value) async {
    await selectSummaryView(tester, kind, value);
    await finish();
  }

  Future<void> period(SummaryPeriodPreset value, {bool settle = true}) async {
    await tester.tap(control('summary-period-dropdown'));
    await tester.pump();
    await tester.tap(find.text(value.label).last);
    await tester.pump();
    if (settle) await finish();
  }

  Future<void> tap(String action, {bool settle = true}) async {
    await tester.tap(control('summary-$action-window'));
    await tester.pump();
    if (settle) await finish();
  }

  Future<void> scroll(double delta, {bool settle = true}) async {
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(browser),
        scrollDelta: Offset(delta, 0),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (settle) await finish();
  }

  Future<void> pin() async {
    await tester.tap(find.byKey(Key('$kind-bucket-0')));
    await tester.pump();
    expect(find.byKey(Key('$kind-tooltip')), findsOneWidget);
  }

  void expectPage(DateTime start, {double? total, double? average}) {
    expect(chart.buckets.first.start, start);
    expect(
      find.text(
        formatSummaryDateRange(
          start,
          chart.buckets.last.endExclusive.subtract(const Duration(hours: 1)),
        ),
      ),
      findsOneWidget,
    );
    final actual = chart.buckets.fold<double>(
      0,
      (sum, bucket) => sum + bucket.value,
    );
    expect(summary?.totalValue, actual);
    final end = chart.buckets.last.endExclusive;
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final divisor = switch (chart.period) {
      SummaryPeriodPreset.week => 7,
      SummaryPeriodPreset.month => ((days + start.weekday - 1) / 7).ceil(),
      SummaryPeriodPreset.last3Months => 3,
      SummaryPeriodPreset.last6Months => 6,
      SummaryPeriodPreset.last12Months => 12,
      SummaryPeriodPreset.yearToDate => start.year == now.year ? now.month : 12,
      SummaryPeriodPreset.allTime => chart.buckets.length,
    };
    expect(summary?.averageValue, closeTo(actual / divisor, 1e-9));
    if (total != null) expect(actual, total);
    if (average != null) expect(summary?.averageValue, closeTo(average, 1e-9));
    expect(chart.controller.offset, 0);
    if (chart.secondaryBuckets != null) {
      expect(
        chart.secondaryBuckets!.map((b) => (b.start, b.endExclusive)),
        chart.buckets.map((b) => (b.start, b.endExclusive)),
      );
    }
  }
}

GpxTrack _track(int id, DateTime day) =>
    GpxTrack(
        gpxTrackId: id,
        contentHash: '$id',
        trackName: 'Track $id',
        trackDate: day,
        trackDateStatus: TrackDateStatus.resolved,
        ascent: 70,
        distance2d: 700,
        distance3d: 770,
        totalTimeMillis: 18000000,
        movingTime: 14400000,
      )
      ..peaks.add(
        Peak(
          osmId: 11,
          name: 'Peak',
          latitude: -42,
          longitude: 147,
          elevation: 100,
        ),
      );
