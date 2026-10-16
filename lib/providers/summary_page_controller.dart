import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/summary_card_service.dart';

/// Read on activation/refresh/interaction; deliberately no midnight timer.
final dashboardReferenceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class SummaryPageSelection {
  const SummaryPageSelection({
    this.period = SummaryPeriodPreset.last12Months,
    this.pageStart,
  });

  final SummaryPeriodPreset period;

  /// Null selects the current page; pixel offsets never identify calendar pages.
  final DateTime? pageStart;
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

  void selectPage(SummaryCalendarPage page) {
    state = SummaryPageSelection(period: state.period, pageStart: page.start);
  }
}
