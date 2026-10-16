import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/summary_page_controller.dart';
import 'package:peak_bagger/services/summary_card_service.dart';

void main() {
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
