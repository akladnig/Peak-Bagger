import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/my_ascents_summary_service.dart';
import 'my_ascents_summary_provider.dart';
import 'my_lists_summary_provider.dart';

/// Screen state only; none of these selections is a preference.
final dashboardTrackSelectionProvider = NotifierProvider.autoDispose
    .family<DashboardIntegerSelection, int?, Object>(
      DashboardIntegerSelection.new,
    );
final dashboardYearSelectionProvider = NotifierProvider.autoDispose
    .family<DashboardIntegerSelection, int?, Object>(
      DashboardIntegerSelection.new,
    );

class DashboardIntegerSelection extends Notifier<int?> {
  DashboardIntegerSelection(this.identity);
  final Object identity;
  @override
  int? build() => null;
  void select(int value) => state = value;
}

final myAscentsAscendingProvider =
    NotifierProvider.autoDispose<MyAscentsSort, bool>(MyAscentsSort.new);

class MyAscentsSort extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final sortedMyAscentsProvider = Provider.autoDispose<MyAscentsSummary>((ref) {
  return const MyAscentsSummaryService().build(
    ref.watch(myAscentsSummaryProvider),
    ascending: ref.watch(myAscentsAscendingProvider),
  );
});

class DashboardRowSelection {
  const DashboardRowSelection(this.ids, this.selectedId);
  final List<int> ids;
  final int? selectedId;
}

final dashboardRowSelectionProvider = NotifierProvider.autoDispose
    .family<DashboardRowSelectionController, DashboardRowSelection, String>(
      DashboardRowSelectionController.new,
    );

class DashboardRowSelectionController extends Notifier<DashboardRowSelection> {
  DashboardRowSelectionController(this.cardId);
  final String cardId;
  int? _selectedId;
  bool _entered = false;

  @override
  DashboardRowSelection build() {
    final ids = cardId == 'my-lists'
        ? ref
              .watch(myListsSummaryProvider)
              .map((r) => r.peakList.peakListId)
              .toList()
        : ref
              .watch(sortedMyAscentsProvider)
              .sections
              .expand((s) => s.rows.map((r) => r.baggedId))
              .toList();
    if (!ids.contains(_selectedId)) {
      _selectedId = _entered ? ids.firstOrNull : null;
    }
    return DashboardRowSelection(ids, _selectedId);
  }

  void enter() {
    _entered = true;
    _select(state.ids.firstOrNull);
  }

  void move(bool forward) {
    if (state.ids.isEmpty) return;
    final index = state.ids.indexOf(state.selectedId ?? -1);
    _select(
      state.ids[(index + (forward ? 1 : -1)).clamp(0, state.ids.length - 1)],
    );
  }

  void _select(int? id) {
    _selectedId = id;
    state = DashboardRowSelection(state.ids, id);
  }
}
