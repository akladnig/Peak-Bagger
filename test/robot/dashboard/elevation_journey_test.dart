import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../harness/mapping_catalog_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/summary_page_controller.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/dashboard/latest_walk_card.dart';
import '../../harness/fixture_tile_provider.dart';
import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'dashboard_robot.dart';

void main() {
  testWidgets(
    'elevation journey browses history, snaps, and reconciles routed activation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final robot = DashboardRobot(tester);
      var now = DateTime(2026, 10, 15, 12);
      final notifier = TestMapNotifier(
        const MapState(
          center: LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          dashboardReferenceClockProvider.overrideWithValue(() => now),
          latestWalkTileProviderFactoryProvider.overrideWithValue(
            FixtureTileProvider.new,
          ),
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          peaksBaggedRepositoryProvider.overrideWithValue(
            PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
          ),
          tasmapRepositoryProvider.overrideWithValue(
            await TestTasmapRepository.create(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await robot.pumpApp(container: container);
      await robot.openDashboard();

      notifier.setTracks([
        _track(1000, DateTime.utc(2020, 2, 29), ascent: 500),
        _track(1001, DateTime.utc(2026, 6, 15), ascent: 600),
        for (var day = 1; day <= 15; day++)
          _track(day, DateTime.utc(2026, 10, day), ascent: day * 1000),
      ]);
      await tester.pumpAndSettle();

      expect(now.timeZoneOffset, const Duration(hours: 11));
      await robot.selectSummaryPeriod('elevation', 'Month');
      robot.expectSummary(
        'elevation',
        range: 'Thu, 1 Oct - Sat, 31 Oct 2026',
        total: '120,000 m',
        average: '24,000 m',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('elevation-period-range')))
            .data,
        'Thu, 1 Oct - Sat, 31 Oct 2026',
      );

      final initialSummary = _summary(tester);
      expect(initialSummary.total, isNotEmpty);
      expect(initialSummary.average, isNotEmpty);
      expect(initialSummary.total, contains(','));
      expect(initialSummary.average, contains(','));

      await tester.tap(_summaryControl('summary-prev-window'));
      await tester.pumpAndSettle();

      final afterPrev = _summary(tester);
      expect(afterPrev.total, isNotEmpty);
      expect(afterPrev.average, isNotEmpty);
      robot.expectSummary(
        'elevation',
        range: 'Tue, 1 Sep - Wed, 30 Sep 2026',
        total: '0 m',
        average: '0 m',
      );

      await tester.tap(_summaryControl('summary-next-window'));
      await tester.pumpAndSettle();

      expect(_summary(tester).total, isNotEmpty);
      expect(_summary(tester).average, isNotEmpty);

      await robot.navigateSummary('elevation', 'first');
      robot.expectSummary(
        'elevation',
        range: 'Sat, 1 Feb - Sat, 29 Feb 2020',
        total: '500 m',
        average: '100 m',
      );

      expect(
        tester
            .widget<IconButton>(_summaryControl('summary-prev-window'))
            .onPressed,
        isNull,
      );

      await tester.tap(_summaryControl('summary-mode-fab'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);

      final mouse = await _hoverBucket(tester, 0);

      const firstBucketLabel = 'Sat 1 Feb';

      expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text(firstBucketLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('elevation-tooltip')),
          matching: find.text('0 m'),
        ),
        findsOneWidget,
      );
      await mouse.removePointer();
      await robot.navigateSummary('elevation', 'last');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('elevation-period-range')))
            .data,
        'Thu, 1 Oct - Sat, 31 Oct 2026',
      );
      await robot.scrollSummary('elevation', -160);
      robot.expectSummary(
        'elevation',
        range: 'Tue, 1 Sep - Wed, 30 Sep 2026',
        total: '0 m',
        average: '0 m',
      );
      await robot.navigateSummary('elevation', 'next');
      robot.expectSummary(
        'elevation',
        range: 'Thu, 1 Oct - Sat, 31 Oct 2026',
        total: '120,000 m',
        average: '24,000 m',
      );
      // The actual indexed-stack Dashboard is retained offstage. No data refresh
      // or changed clock-provider identity is used to force its activation build.
      await robot.selectSummaryPeriod('elevation', 'Last 3 Months');
      await robot.navigateSummary('elevation', 'prev');
      await robot.navigateSummary('elevation', 'next');
      await robot.openSettings();
      now = DateTime(2026, 11, 1, 12);
      await robot.openDashboard();
      robot.expectSummary(
        'elevation',
        range: 'Tue, 1 Sep - Mon, 30 Nov 2026',
        total: '120,000 m',
        average: '40,000 m',
      );
      await robot.navigateSummary('elevation', 'prev');
      robot.expectSummary(
        'elevation',
        range: 'Mon, 1 Jun - Mon, 31 Aug 2026',
        total: '600 m',
        average: '200 m',
      );
      // December remaps June–August to July–September (contains 31 August).
      await robot.openSettings();
      now = DateTime(2026, 12, 1, 12);
      await robot.openDashboard();
      robot.expectSummary(
        'elevation',
        range: 'Wed, 1 Jul - Wed, 30 Sep 2026',
        total: '0 m',
        average: '0 m',
      );
      expect(find.byKey(const Key('elevation-tooltip')), findsNothing);
      await robot.navigateSummary('elevation', 'last');
      robot.expectSummary(
        'elevation',
        range: 'Thu, 1 Oct - Thu, 31 Dec 2026',
        total: '120,000 m',
        average: '40,000 m',
      );
      // Future data updates last's destination without following a previous jump.
      notifier.setTracks([
        ...container.read(mapProvider).tracks,
        _track(1002, DateTime.utc(2026, 12, 15), ascent: 900),
      ]);
      now = DateTime(2026, 12, 15, 12);
      await tester.pumpAndSettle();
      robot.expectSummary(
        'elevation',
        range: 'Thu, 1 Oct - Thu, 31 Dec 2026',
        total: '120,900 m',
        average: '40,300 m',
      );
      await robot.selectSummaryPeriod('elevation', 'Week');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('elevation-period-range')))
            .data,
        'Mon, 14 Dec - Sun, 20 Dec 2026',
      );
    },
  );
}

Future<TestGesture> _hoverBucket(WidgetTester tester, int index) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);

  final bucket = find.byKey(Key('elevation-bucket-$index'));
  await mouse.addPointer(location: tester.getCenter(bucket));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(bucket));
  await tester.pump();
  return mouse;
}

({String total, String average}) _summary(WidgetTester tester) {
  final header = find.byKey(const Key('dashboard-card-elevation-drag-handle'));
  return (
    total:
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: header,
                    matching: find.byKey(
                      const Key('dashboard-card-summary-total-value'),
                    ),
                  )
                  .first,
            )
            .data ??
        '',
    average:
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: header,
                    matching: find.byKey(
                      const Key('dashboard-card-summary-average-value'),
                    ),
                  )
                  .first,
            )
            .data ??
        '',
  );
}

GpxTrack _track(int id, DateTime? trackDate, {double? ascent}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    trackDateStatus: TrackDateStatus.resolved,
    ascent: ascent,
  );
}

Finder _summaryControl(String key) {
  return find.descendant(
    of: find.byKey(const Key('dashboard-card-elevation')),
    matching: find.byKey(Key(key)),
  );
}
