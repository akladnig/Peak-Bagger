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

    testWidgets('updates visible summary when scrolled', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 4, 1, 10), ascent: 10),
          _track(20, DateTime(2026, 4, 15, 10), ascent: 20),
          _track(30, DateTime(2026, 5, 15, 10), ascent: 300),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      final initialSummary = tester.widget<Text>(find.textContaining('Visible:')).data;
      expect(initialSummary, isNotNull);

      await tester.drag(
        find.byKey(const Key('elevation-scroll-view')),
        const Offset(-360, 0),
      );
      await tester.pumpAndSettle();

      final updatedSummary = tester.widget<Text>(find.textContaining('Visible:')).data;
      expect(updatedSummary, isNotNull);
      expect(updatedSummary, isNot(initialSummary));
      expect(find.byKey(const Key('elevation-scroll-view')), findsOneWidget);
    });

    testWidgets('toggles display mode', (tester) async {
      await _pumpElevationCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 5, 15, 10), ascent: 300),
        ],
        now: DateTime(2026, 5, 15, 12),
      );

      expect(find.byIcon(Icons.show_chart), findsOneWidget);

      await tester.tap(find.byKey(const Key('elevation-mode-fab')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
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
