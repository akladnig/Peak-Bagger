import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/summary_page_controller.dart';
import 'package:peak_bagger/services/summary_card_service.dart';

void main() {
  for (final fixture in [
    (
      SummaryPeriodPreset.week,
      DateTime(2026, 10, 12),
      DateTime(2026, 11, 2),
      DateTime(2020, 2, 24),
      DateTime(2020, 2, 24),
    ),
    (
      SummaryPeriodPreset.month,
      DateTime(2026, 10),
      DateTime(2026, 11),
      DateTime(2020, 2),
      DateTime(2020, 2),
    ),
    (
      SummaryPeriodPreset.last3Months,
      DateTime(2026, 8),
      DateTime(2026, 9),
      DateTime(2026, 5),
      DateTime(2026, 6),
    ),
    (
      SummaryPeriodPreset.last6Months,
      DateTime(2026, 5),
      DateTime(2026, 6),
      DateTime(2025, 11),
      DateTime(2025, 12),
    ),
    (
      SummaryPeriodPreset.last12Months,
      DateTime(2025, 11),
      DateTime(2025, 12),
      DateTime(2024, 11),
      DateTime(2024, 12),
    ),
    (
      SummaryPeriodPreset.allTime,
      DateTime(2015),
      DateTime(2016),
      DateTime(2003),
      DateTime(2004),
    ),
  ]) {
    test(
      '${fixture.$1.label} reconciles current/history using previous last included day',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = summaryPageControllerProvider('card');
        final sub = container.listen(provider, (_, _) {});
        addTearDown(sub.close);
        final controller = container.read(provider.notifier);
        controller.selectPeriod(fixture.$1);
        final oldReference = DateTime(2026, 10, 15);
        final nextReference = fixture.$1 == SummaryPeriodPreset.allTime
            ? DateTime(2027, 1, 1)
            : DateTime(2026, 11, 2);
        final tracks = [
          GpxTrack(
            gpxTrackId: 1,
            contentHash: '1',
            trackName: 'Old',
            trackDate: DateTime(1980),
            ascent: 1,
          ),
        ];
        final metric = SummaryMetricDefinition(
          valueOf: (track) => track.ascent,
        );
        for (final selected in [fixture.$2, fixture.$4]) {
          final page = const SummaryCardService().calendarPage(
            period: fixture.$1,
            day: selected,
            referenceDate: oldReference,
          );
          controller.selectPage(page, referenceDate: oldReference);
          final expected = container.read(provider);
          final nav = expected.navigation(
            tracks: tracks,
            metric: metric,
            now: nextReference,
          )!;
          expect(
            nav.selected.start,
            selected == fixture.$2 ? fixture.$3 : fixture.$5,
          );
          controller.reconcile(
            expected: expected,
            navigation: nav,
            referenceDate: nextReference,
          );
          expect(container.read(provider).pageStart, nav.selected.start);
          // An old frame cannot undo an interaction that followed it.
          controller.selectPage(nav.first, referenceDate: nextReference);
          controller.reconcile(
            expected: expected,
            navigation: nav,
            referenceDate: nextReference,
          );
          expect(container.read(provider).pageStart, nav.first.start);
        }
      },
    );
  }

  for (final period in SummaryPeriodPreset.values.skip(2)) {
    test(
      '${period.label} shares independent provider selection and current-page entry',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = summaryPageControllerProvider('elevation');
        final other = summaryPageControllerProvider('distance');
        final sub = container.listen(provider, (_, _) {});
        final otherSub = container.listen(other, (_, _) {});
        addTearDown(sub.close);
        addTearDown(otherSub.close);
        final controller = container.read(provider.notifier);
        controller.selectPeriod(period);
        expect(container.read(provider).pageStart, isNull);
        final page = const SummaryCardService().calendarPage(
          period: period,
          day: DateTime(2005, 6),
          referenceDate: DateTime(2026, 10, 15),
        );
        controller.selectPage(page);
        expect(container.read(provider).pageStart, page.start);
        expect(container.read(other).pageStart, isNull);
        controller.selectPeriod(period);
        expect(container.read(provider).pageStart, page.start);
        controller.selectPeriod(SummaryPeriodPreset.month);
        controller.selectPeriod(period);
        expect(container.read(provider).pageStart, isNull);
      },
    );
  }

  test(
    'cards select independent calendar pages and a different preset returns to current',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final elevation = summaryPageControllerProvider('elevation');
      final distance = summaryPageControllerProvider('distance');
      final sub1 = container.listen(elevation, (_, _) {});
      final sub2 = container.listen(distance, (_, _) {});
      addTearDown(sub1.close);
      addTearDown(sub2.close);
      expect(
        container.read(elevation).period,
        SummaryPeriodPreset.last12Months,
      );
      final controller = container.read(elevation.notifier);
      controller.selectPeriod(SummaryPeriodPreset.month);
      controller.selectPage(
        const SummaryCardService().calendarPage(
          period: SummaryPeriodPreset.month,
          day: DateTime(2020, 2, 29),
        ),
      );
      expect(container.read(elevation).pageStart, DateTime(2020, 2));
      expect(container.read(distance).pageStart, isNull);
      expect(container.read(distance).period, SummaryPeriodPreset.last12Months);
      controller.selectPeriod(SummaryPeriodPreset.month);
      expect(container.read(elevation).pageStart, DateTime(2020, 2));
      controller.selectPeriod(SummaryPeriodPreset.week);
      expect(container.read(elevation).pageStart, isNull);
    },
  );

  test(
    'advanceable clock supplies Mac-local reference and preserves explicit historical selection',
    () {
      var clock = DateTime(2026, 10, 15, 12);
      final container = ProviderContainer(
        overrides: [
          dashboardReferenceClockProvider.overrideWithValue(() => clock),
        ],
      );
      addTearDown(container.dispose);
      final provider = summaryPageControllerProvider('elevation');
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(provider.notifier);
      controller.selectPeriod(SummaryPeriodPreset.month);
      const service = SummaryCardService();
      final tracks = [
        GpxTrack(
          gpxTrackId: 1,
          contentHash: '1',
          trackName: 'Old',
          trackDate: DateTime(2020, 1, 1),
          ascent: 1,
        ),
      ];
      SummaryPageNavigation view() => service.pageNavigation(
        tracks: tracks,
        metric: SummaryMetricDefinition(valueOf: (t) => t.ascent),
        period: container.read(provider).period,
        selectedDay: container.read(provider).pageStart,
        now: container.read(dashboardReferenceClockProvider)(),
      )!;
      expect(view().selected.start, DateTime(2026, 10));
      clock = DateTime(2026, 11, 1);
      expect(view().selected.start, DateTime(2026, 11));
      controller.selectPage(
        service.calendarPage(
          period: SummaryPeriodPreset.month,
          day: DateTime(2020, 2, 29),
        ),
      );
      clock = DateTime(2027, 1, 1);
      expect(view().selected.start, DateTime(2020, 2));
      expect(view().current.start, DateTime(2027, 1));
    },
  );
}
