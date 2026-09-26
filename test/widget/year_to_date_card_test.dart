import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/widgets/dashboard/year_to_date_card.dart';

void main() {
  group('YearToDateCard', () {
    testWidgets('renders loading placeholder while tracks load', (
      tester,
    ) async {
      await _pumpYearToDateCard(
        tester,
        tracks: const [],
        peaksBagged: const [],
        isLoading: true,
        settle: false,
      );

      expect(
        find.byKey(const Key('year-to-date-loading-state')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('year-to-date-card')), findsOneWidget);
      expect(find.byKey(const Key('year-to-date-title')), findsNothing);
    });

    testWidgets('renders current year metrics and navigates years', (
      tester,
    ) async {
      await _pumpYearToDateCard(
        tester,
        tracks: [
          _track(
            10,
            DateTime.utc(2025, 6, 15, 12),
            distance2d: 2000,
            ascent: 30,
            peakIds: [1],
          ),
          _track(
            20,
            DateTime.utc(2026, 6, 15, 12),
            distance2d: 3000,
            ascent: 40,
            peakIds: [2, 2],
          ),
          _track(
            30,
            DateTime.utc(2027, 6, 15, 12),
            distance2d: 4000,
            ascent: 50,
            peakIds: [3],
          ),
        ],
        peaksBagged: [
          _bagged(1, peakId: 2, gpxId: 20, date: DateTime.utc(2026, 6, 15)),
          _bagged(2, peakId: 2, gpxId: 21, date: DateTime.utc(2026, 6, 16)),
          _bagged(3, peakId: 3, gpxId: 22, date: DateTime.utc(2026, 6, 17)),
          _bagged(4, peakId: 1, gpxId: 10, date: DateTime.utc(2025, 6, 15)),
          _bagged(5, peakId: 3, gpxId: 30, date: DateTime.utc(2027, 6, 15)),
          _bagged(6, peakId: 4, gpxId: 23, date: null),
        ],
        now: DateTime.utc(2026, 5, 15, 12),
      );

      expect(find.byKey(const Key('year-to-date-card')), findsOneWidget);
      expect(find.byKey(const Key('year-to-date-title')), findsOneWidget);
      expect(find.text('My Walks in 2026'), findsOneWidget);
      expect(
        find.byKey(const Key('year-to-date-distance-value')),
        findsOneWidget,
      );
      expect(find.text('3 km'), findsOneWidget);
      expect(
        find.byKey(const Key('year-to-date-ascent-value')),
        findsOneWidget,
      );
      expect(find.text('40'), findsOneWidget);
      expect(
        find.byKey(const Key('year-to-date-total-walks-value')),
        findsOneWidget,
      );
      expect(find.text('1'), findsWidgets);
      expect(
        find.byKey(const Key('year-to-date-peaks-climbed-value')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('year-to-date-peaks-climbed-value')),
            )
            .data,
        '3',
      );
      expect(
        find.byKey(const Key('year-to-date-new-peaks-climbed-value')),
        findsOneWidget,
      );
      for (final label in const [
        'Kilometers walked',
        'Metres climbed',
        'Total walks',
        'Peaks climbed',
        'New peaks climbed',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-prev-year')))
            .mouseCursor,
        SystemMouseCursors.click,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-next-year')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-next-year')))
            .tooltip,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-next-year')))
            .mouseCursor,
        SystemMouseCursors.basic,
      );

      await tester.tap(find.byKey(const Key('year-to-date-prev-year')));
      await tester.pumpAndSettle();

      expect(find.text('My Walks in 2025'), findsOneWidget);
      expect(
        find.byKey(const Key('year-to-date-distance-value')),
        findsOneWidget,
      );
      expect(find.text('2 km'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('year-to-date-card')),
          matching: find.byKey(const Key('year-to-date-title')),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-next-year')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-next-year')))
            .tooltip,
        'Next year',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('year-to-date-next-year')))
            .mouseCursor,
        SystemMouseCursors.click,
      );

      await tester.tap(find.byKey(const Key('year-to-date-next-year')));
      await tester.pumpAndSettle();

      expect(find.text('My Walks in 2026'), findsOneWidget);
      expect(find.text('3 km'), findsOneWidget);
    });

    testWidgets('renders zero values when the selected year has no walks', (
      tester,
    ) async {
      await _pumpYearToDateCard(
        tester,
        tracks: [
          _track(
            10,
            DateTime.utc(2026, 6, 15, 12),
            distance2d: 3000,
            ascent: 40,
            peakIds: [1],
          ),
        ],
        peaksBagged: [
          _bagged(1, peakId: 1, gpxId: 10, date: DateTime.utc(2026, 6, 15)),
        ],
        now: DateTime.utc(2024, 5, 15, 12),
      );

      expect(find.text('My Walks in 2024'), findsOneWidget);
      expect(find.text('0 m'), findsOneWidget);
      expect(
        find.byKey(const Key('year-to-date-ascent-value')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('year-to-date-card')),
          matching: find.text('0'),
        ),
        findsWidgets,
      );
    });
  });
}

Future<void> _pumpYearToDateCard(
  WidgetTester tester, {
  required List<GpxTrack> tracks,
  required List<PeaksBagged> peaksBagged,
  bool isLoading = false,
  DateTime? now,
  bool settle = true,
  double width = 440,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 320,
          child: YearToDateCard(
            tracks: tracks,
            peaksBagged: peaksBagged,
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

PeaksBagged _bagged(
  int baggedId, {
  required int peakId,
  required int gpxId,
  required DateTime? date,
}) {
  return PeaksBagged(
    baggedId: baggedId,
    peakId: peakId,
    gpxId: gpxId,
    date: date,
  );
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  required double distance2d,
  required List<int> peakIds,
  double? ascent,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    distance2d: distance2d,
    ascent: ascent,
  );
  track.peaks.addAll(
    peakIds.map(
      (peakId) => Peak(
        osmId: peakId,
        name: 'Peak $peakId',
        latitude: -42,
        longitude: 146,
      ),
    ),
  );
  return track;
}
