import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/dashboard/my_ascents_card.dart';

void main() {
  group('MyAscentsCard', () {
    testWidgets('renders grouped rows and sort toggle', (tester) async {
      await _pumpCard(
        tester,
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _peak(10, 'Alpha', elevation: 1234),
            _peak(20, 'Beta', elevation: 987),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            _bagged(1, peakId: 10, date: DateTime.utc(2026, 5, 15)),
            _bagged(2, peakId: 20, date: DateTime.utc(2025, 5, 14)),
            _bagged(3, peakId: 10, date: null),
          ]),
        ),
      );

      expect(find.byKey(const Key('my-ascents-card')), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-table')), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-empty-state')), findsNothing);
      expect(find.byKey(const Key('my-ascents-sort-toggle')), findsOneWidget);
      expect(find.text('Peak Name'), findsOneWidget);
      expect(find.text('Elevation'), findsOneWidget);
      expect(find.text('Date Climbed'), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-year-2026')), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-year-2025')), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-row-1')), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-row-2')), findsOneWidget);
      expect(find.byKey(const Key('my-ascents-row-3')), findsNothing);
    });

    testWidgets('toggles sort order', (tester) async {
      await _pumpCard(
        tester,
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _peak(10, 'Alpha'),
            _peak(20, 'Beta'),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            _bagged(1, peakId: 10, date: DateTime.utc(2026, 5, 15)),
            _bagged(2, peakId: 20, date: DateTime.utc(2025, 5, 14)),
          ]),
        ),
      );

      final row1 = find.byKey(const Key('my-ascents-row-1'));
      final row2 = find.byKey(const Key('my-ascents-row-2'));
      expect(tester.getTopLeft(row1).dy, lessThan(tester.getTopLeft(row2).dy));

      await tester.tap(find.byKey(const Key('my-ascents-sort-toggle')));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(row1).dy, greaterThan(tester.getTopLeft(row2).dy));
    });

    testWidgets('shows empty state and scrolls the list', (tester) async {
      final rows = [
        for (var i = 1; i <= 8; i++) _bagged(i, peakId: i, date: DateTime.utc(2026, 5, i)),
      ];
      final peaks = [
        for (var i = 1; i <= 8; i++) _peak(i, 'Peak $i'),
      ];

      await _pumpCard(
        tester,
        peakRepository: PeakRepository.test(InMemoryPeakStorage(peaks)),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(rows),
        ),
        height: 260,
      );

      expect(find.byKey(const Key('my-ascents-empty-state')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('my-ascents-row-8')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('my-ascents-row-8')), findsOneWidget);

      await _pumpCard(
        tester,
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            _bagged(9, peakId: 9, date: null),
          ]),
        ),
      );

      expect(find.byKey(const Key('my-ascents-empty-state')), findsOneWidget);
    });
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required PeakRepository peakRepository,
  required PeaksBaggedRepository peaksBaggedRepository,
  double width = 420,
  double height = 320,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        peakRepositoryProvider.overrideWithValue(peakRepository),
        peaksBaggedRepositoryProvider.overrideWithValue(peaksBaggedRepository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: const MyAscentsCard(),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Peak _peak(
  int osmId,
  String name, {
  double? elevation,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: -41,
    longitude: 146,
  );
}

PeaksBagged _bagged(
  int baggedId, {
  required int peakId,
  required DateTime? date,
}) {
  return PeaksBagged(
    baggedId: baggedId,
    peakId: peakId,
    gpxId: 100 + baggedId,
    date: date,
  );
}
