import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';
import 'package:peak_bagger/widgets/dashboard/elevation_card.dart';
import 'package:peak_bagger/widgets/dashboard/peaks_bagged_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';

void main() {
  for (final kind in ['elevation', 'distance', 'peaks-bagged']) {
    for (final mode in SummaryDisplayMode.values) {
      for (final period in ['Week', 'Month']) {
        testWidgets(
          '$kind ${mode.name} $period visits full history and empty gaps',
          (tester) async {
            SummaryVisibleSummary? summary;
            final tracks = [
              // Distance's non-null zero default remains qualifying activity.
              // Elevation/Peaks require an actual primary metric instead.
              if (kind != 'distance')
                GpxTrack(
                  gpxTrackId: 3,
                  contentHash: '3',
                  trackName: 'No metric',
                  trackDate: DateTime.utc(2010),
                ),
              _track(1, DateTime.utc(2020, 2, 29)),
              _track(2, DateTime.utc(2026, 8, 15)),
            ];
            await _pump(
              tester,
              kind: kind,
              tracks: tracks,
              onSummary: (s) => summary = s,
            );
            await _selectPeriod(tester, period);
            var chart = tester.widget<SummaryChart>(find.byType(SummaryChart));
            if (chart.mode != mode) {
              await tester.tap(find.byKey(const Key('summary-mode-fab')));
              await tester.pumpAndSettle();
            }
            final currentStart = period == 'Month'
                ? DateTime(2026, 10)
                : DateTime(2026, 10, 12);
            expect(_chart(tester).buckets.first.start, currentStart);
            expect(summary?.totalValue, 0);
            expect(summary?.averageValue, 0);
            expect(_button(tester, 'next').onPressed, isNull);
            expect(_button(tester, 'last').onPressed, isNotNull);
            final controls = ['first', 'prev', 'next', 'last'];
            expect(
              controls.map((c) => (_button(tester, c).icon as Icon).icon),
              [
                Icons.first_page,
                Icons.chevron_left,
                Icons.chevron_right,
                Icons.last_page,
              ],
            );
            expect(controls.map((c) => _button(tester, c).tooltip), [
              'first',
              'Previous $period',
              'Next $period',
              'last',
            ]);
            for (var i = 1; i < controls.length; i++) {
              expect(
                tester.getCenter(_control(controls[i])).dx,
                greaterThan(tester.getCenter(_control(controls[i - 1])).dx),
              );
              expect(
                tester.getCenter(_control(controls[i])).dy,
                tester.getCenter(_control(controls[0])).dy,
              );
            }

            await tester.tap(_control('last'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2026, 8) : DateTime(2026, 8, 10),
            );
            expect(
              summary?.totalValue,
              kind == 'elevation'
                  ? 70
                  : kind == 'distance'
                  ? 700
                  : 1,
            );
            expect(
              summary?.averageValue,
              kind == 'elevation'
                  ? (period == 'Week' ? 10 : 70 / 6)
                  : kind == 'distance'
                  ? (period == 'Week' ? 100 : 700 / 6)
                  : (period == 'Week' ? 1 / 7 : 1 / 6),
            );
            expect(_button(tester, 'last').onPressed, isNull);
            expect(
              _button(tester, 'last').mouseCursor,
              SystemMouseCursors.basic,
            );
            expect(
              _button(tester, 'next').mouseCursor,
              SystemMouseCursors.click,
            );
            // Repeated peaks are primary activity even without any new peaks.
            if (kind == 'peaks-bagged') {
              expect(
                _chart(
                  tester,
                ).secondaryBuckets!.fold<double>(0, (s, b) => s + b.value),
                0,
              );
            }
            if (kind == 'distance') {
              expect(
                _chart(tester).secondaryBuckets!.map((b) => b.start),
                _chart(tester).buckets.map((b) => b.start),
              );
              expect(
                _chart(tester).secondaryBuckets!.every((b) => b.value == 0),
                isTrue,
              );
            }
            await tester.tap(_control('next'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2026, 9) : DateTime(2026, 8, 17),
            );
            expect(summary?.totalValue, 0);
            expect(summary?.averageValue, 0);
            expect(find.textContaining('No '), findsNothing);
            if (period == 'Month') {
              await tester.tap(_control('next'));
              await tester.pumpAndSettle();
              expect(_chart(tester).buckets.first.start, currentStart);
              expect(_button(tester, 'next').onPressed, isNull);
            }
            await tester.tap(_control('first'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2020, 2) : DateTime(2020, 2, 24),
            );
            expect(
              _chart(tester).buckets,
              hasLength(period == 'Month' ? 29 : 7),
            );
            expect(_button(tester, 'first').onPressed, isNull);
            expect(_button(tester, 'prev').onPressed, isNull);
            expect(_button(tester, 'next').onPressed, isNotNull);
            final before = _chart(tester).buckets.first.start;
            await tester.tap(find.byKey(const Key('summary-mode-fab')));
            await tester.pumpAndSettle();
            expect(_chart(tester).buckets.first.start, before);
            await _selectPeriod(tester, period == 'Month' ? 'Week' : 'Month');
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2026, 10, 12) : DateTime(2026, 10),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets('$kind ${mode.name} Month hover and future-day cutoff', (
        tester,
      ) async {
        SummaryVisibleSummary? summary;
        await _pump(
          tester,
          kind: kind,
          tracks: [
            _track(1, DateTime.utc(2026, 10, 15))..distance3d = 770,
            _track(2, DateTime.utc(2026, 10, 16))..distance3d = 770,
          ],
          onSummary: (s) => summary = s,
        );
        await _selectPeriod(tester, 'Month');
        if (_chart(tester).mode != mode) {
          await tester.tap(find.byKey(const Key('summary-mode-fab')));
          await tester.pumpAndSettle();
        }
        expect(_chart(tester).buckets[14].trackCount, 1);
        expect(_chart(tester).buckets[15].trackCount, 0);
        expect(_chart(tester).buckets[15].value, 0);
        if (kind == 'distance') {
          expect(_chart(tester).secondaryBuckets![14].value, 770);
          expect(_chart(tester).secondaryBuckets![15].value, 0);
        }
        expect(_chart(tester).buckets, hasLength(31));
        expect(
          summary?.totalValue,
          kind == 'elevation'
              ? 70
              : kind == 'distance'
              ? 700
              : 1,
        );
        await tester.tap(find.byKey(Key('$kind-bucket-14')));
        await tester.pumpAndSettle();
        expect(find.text('Thu 15 Oct'), findsOneWidget);
        await _selectPeriod(tester, 'Week');
        expect(find.byKey(Key('$kind-tooltip')), findsNothing);
        expect(_chart(tester).buckets[4].value, 0);
      });
    }
  }

  for (final kind in ['elevation', 'distance', 'peaks-bagged']) {
    testWidgets('$kind future-only data retains the no-data state', (
      tester,
    ) async {
      await _pump(
        tester,
        kind: kind,
        tracks: [_track(1, DateTime.utc(2026, 10, 16))],
      );
      expect(find.byKey(Key('$kind-empty-state')), findsOneWidget);
      expect(find.byType(SummaryChart), findsNothing);
      expect(find.byKey(const Key('summary-first-window')), findsNothing);
    });
  }

  for (final theme in [MyTheme.light, MyTheme.dark]) {
    testWidgets(
      'single-row toolbar supports focus, semantics and enlarged text in ${theme.brightness.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(
          tester,
          kind: 'elevation',
          theme: theme,
          textScale: 1.5,
          tracks: [
            _track(1, DateTime.utc(2020)),
            _track(2, DateTime.utc(2026, 8)),
          ],
        );
        await _selectPeriod(tester, 'Month');
        final first = _control('first');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        final focus = Focus.of(
          tester.element(
            find.descendant(of: first, matching: find.byType(Icon)).first,
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(
          tester.getSemantics(first),
          matchesSemantics(
            label: 'first',
            tooltip: 'first',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            isFocused: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        final style = _button(tester, 'first').style!;
        expect(style.foregroundColor!.resolve({}), theme.colorScheme.onSurface);
        expect(
          style.foregroundColor!.resolve({WidgetState.disabled}),
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
        );
        expect(
          style.overlayColor!.resolve({WidgetState.focused}),
          isNot(style.overlayColor!.resolve({WidgetState.hovered})),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_chart(tester).buckets.first.start, DateTime(2020));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // Disabled first/previous are skipped; next is the following action.
        final nextFocus = Focus.of(
          tester.element(
            find
                .descendant(of: _control('next'), matching: find.byType(Icon))
                .first,
          ),
        );
        expect(nextFocus.hasFocus, isTrue);
        final y = tester.getCenter(_control('first')).dy;
        expect(tester.getCenter(_control('last')).dy, y);
        expect(MediaQuery.textScalerOf(tester.element(first)).scale(10), 15);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}

SummaryChart _chart(WidgetTester tester) =>
    tester.widget<SummaryChart>(find.byType(SummaryChart));
Finder _control(String action) => find.byKey(Key('summary-$action-window'));
IconButton _button(WidgetTester tester, String action) =>
    tester.widget<IconButton>(_control(action));

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('summary-period-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required String kind,
  required List<GpxTrack> tracks,
  ValueChanged<SummaryVisibleSummary?>? onSummary,
  ThemeData? theme,
  double textScale = 1,
  double width = 520,
}) async {
  final now = DateTime(2026, 10, 15, 12);
  final card = switch (kind) {
    'elevation' => ElevationCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
    'distance' => DistanceCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
    _ => PeaksBaggedCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
  };
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(width: width, height: 320, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
