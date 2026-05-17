import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/widgets/dashboard/my_lists_card.dart';

import '../harness/test_map_notifier.dart';

void main() {
  group('MyListsCard', () {
    testWidgets('renders table rows in sorted order', (tester) async {
      await _pumpMyListsCard(
        tester,
        peakLists: [
          _peakList(10, 'Alpha', [1, 2]),
          _peakList(11, 'Alpha', [1, 3]),
          _peakList(12, 'Beta', [2, 4]),
          _peakList(13, 'Delta', [6]),
          _peakList(14, 'Gamma', [1, 5, 8]),
          _peakList(15, 'Epsilon', [9]),
        ],
        tracks: [_track(1, peakIds: [1, 2, 3, 4, 5, 6])],
        width: 360,
      );

      expect(find.byKey(const Key('my-lists-card')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-table')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-table-header')), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Total Peaks'), findsOneWidget);
      expect(find.text('Climbed'), findsOneWidget);
      expect(find.text('% Climbed'), findsOneWidget);
      expect(find.text('Unclimbed'), findsOneWidget);
      expect(find.byKey(const Key('my-lists-row-10')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-row-11')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-row-12')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-row-13')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-row-14')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-row-15')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('my-lists-row-10')),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('my-lists-row-14')),
          matching: find.text('67%'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders empty state when no usable lists exist', (
      tester,
    ) async {
      await _pumpMyListsCard(
        tester,
        peakLists: const [],
        tracks: const [],
      );

      expect(find.byKey(const Key('my-lists-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('my-lists-table')), findsNothing);
      expect(find.text('No peak lists yet'), findsOneWidget);
    });
  });
}

Future<void> _pumpMyListsCard(
  WidgetTester tester, {
  required List<PeakList> peakLists,
  required List<GpxTrack> tracks,
  double width = 420,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage(peakLists)),
        ),
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              tracks: tracks,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 320,
            child: const MyListsCard(),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

PeakList _peakList(
  int id,
  String name,
  List<int> peakIds,
) {
  return PeakList(
    peakListId: id,
    name: name,
    peakList: encodePeakListItems(
      peakIds
          .map((peakId) => PeakListItem(peakOsmId: peakId, points: 1))
          .toList(growable: false),
    ),
  );
}

GpxTrack _track(
  int id, {
  required List<int> peakIds,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: DateTime.utc(2026, 5, 15, 10),
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
