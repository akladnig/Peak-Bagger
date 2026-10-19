import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gpx_track.dart';
import '../services/summary_card_service.dart';

/// Read on activation/refresh/interaction; deliberately no midnight timer.
final dashboardReferenceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum SummaryPageAction { first, last, adjacent, reconcile }

class SummaryPageSelection {
  const SummaryPageSelection({
    this.period = SummaryPeriodPreset.last12Months,
    this.pageStart,
    this.pageEndExclusive,
    this.referenceDate,
  });

  final SummaryPeriodPreset period;

  /// Null selects the current page; pixel offsets never identify calendar pages.
  final DateTime? pageStart;
  final DateTime? pageEndExclusive;
  final DateTime? referenceDate;

  /// Pure projection: refresh/activation can render the reconciled page in the
  /// same frame, before committing the new identity outside the build phase.
  SummaryPageNavigation? navigation({
    required List<GpxTrack> tracks,
    required SummaryMetricDefinition metric,
    required DateTime now,
  }) {
    const service = SummaryCardService();
    var day = pageStart;
    final previousReference = referenceDate;
    if (previousReference != null && pageEndExclusive != null) {
      final oldCurrent = service.calendarPage(
        period: period,
        day: previousReference,
        referenceDate: previousReference,
      );
      day = pageEndExclusive == oldCurrent.endExclusive
          ? null
          : DateTime(
              pageEndExclusive!.year,
              pageEndExclusive!.month,
              pageEndExclusive!.day - 1,
            );
    }
    return service.pageNavigation(
      tracks: tracks,
      metric: metric,
      period: period,
      now: now,
      selectedDay: day,
    );
  }
}

/// Each mounted card owns a distinct identity, preserved through reordering.
final summaryPageControllerProvider = NotifierProvider.autoDispose
    .family<SummaryPageController, SummaryPageSelection, Object>(
      SummaryPageController.new,
    );

class SummaryPageController extends Notifier<SummaryPageSelection> {
  SummaryPageController(this.cardIdentity);

  final Object cardIdentity;

  @override
  SummaryPageSelection build() => const SummaryPageSelection();

  void selectPeriod(SummaryPeriodPreset period) {
    if (period == state.period) return;
    state = SummaryPageSelection(period: period);
  }

  void selectPage(SummaryCalendarPage page, {DateTime? referenceDate}) {
    state = SummaryPageSelection(
      period: state.period,
      pageStart: page.start,
      pageEndExclusive: page.endExclusive,
      referenceDate: referenceDate,
    );
  }

  void navigate({
    required SummaryPageAction action,
    required List<GpxTrack> tracks,
    required SummaryMetricDefinition metric,
    required DateTime referenceDate,
    int pages = 1,
    DateTime? inputReference,
  }) {
    final navigation = state.navigation(
      tracks: tracks,
      metric: metric,
      now: referenceDate,
    );
    if (navigation == null) {
      reconcile(
        expected: state,
        navigation: null,
        referenceDate: referenceDate,
      );
      return;
    }
    var destination = navigation.selected;
    // Rollover supersedes direct input captured against a different reference.
    if (inputReference == null || inputReference == referenceDate) {
      destination = switch (action) {
        SummaryPageAction.first => navigation.first,
        SummaryPageAction.last => navigation.last,
        _ => destination,
      };
      for (
        var i = 0;
        action == SummaryPageAction.adjacent && i < pages.abs();
        i++
      ) {
        final next = SummaryPageNavigation(
          period: state.period,
          selected: destination,
          first: navigation.first,
          last: navigation.last,
          current: navigation.current,
        ).adjacent(pages > 0);
        if (next.start == destination.start) break;
        destination = next;
      }
    }
    selectPage(destination, referenceDate: referenceDate);
  }

  void reconcile({
    required SummaryPageSelection expected,
    required SummaryPageNavigation? navigation,
    required DateTime referenceDate,
  }) {
    // Navigation may already have superseded this frame's projection.
    if (!identical(state, expected)) return;
    final page = navigation?.selected;
    if (state.pageStart == page?.start &&
        state.pageEndExclusive == page?.endExclusive &&
        state.referenceDate == referenceDate) {
      return;
    }
    state = SummaryPageSelection(
      period: state.period,
      pageStart: page?.start,
      pageEndExclusive: page?.endExclusive,
      referenceDate: referenceDate,
    );
  }
}
