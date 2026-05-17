import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dashboardCardOrderStorageKey = 'dashboard_card_order';

const dashboardCardAspectRatio = 4 / 3;
const dashboardDesktopWideBreakpoint = 1500.0;
const dashboardDesktopMediumBreakpoint = 800.0;

class DashboardCardDefinition {
  const DashboardCardDefinition({required this.id, required this.title});

  final String id;
  final String title;
}

const myListsCardId = 'my-lists';
const myAscentsCardId = 'my-ascents';
const _legacyTopFiveHighestCardId = 'top-5-highest';
const _legacyTopFiveWalksCardId = 'top-5-walks';

const dashboardCards = <DashboardCardDefinition>[
  DashboardCardDefinition(id: 'elevation', title: 'Elevation'),
  DashboardCardDefinition(id: 'distance', title: 'Distance'),
  DashboardCardDefinition(id: 'latest-walk', title: 'Latest Walk'),
  DashboardCardDefinition(id: 'peaks-bagged', title: 'Peaks Bagged'),
  DashboardCardDefinition(id: 'year-to-date', title: 'My Year to Date'),
  DashboardCardDefinition(id: myListsCardId, title: 'My Lists'),
  DashboardCardDefinition(id: myAscentsCardId, title: 'My Ascents'),
];

const dashboardDefaultCardOrder = <String>[
  'elevation',
  'distance',
  'latest-walk',
  'peaks-bagged',
  'year-to-date',
  myListsCardId,
  myAscentsCardId,
];

final dashboardPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, List<String>>(
      DashboardLayoutNotifier.new,
    );

class DashboardLayoutNotifier extends Notifier<List<String>> {
  bool _loaded = false;

  @override
  List<String> build() => dashboardDefaultCardOrder;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final initialState = state;

    try {
      final prefs = await ref.read(dashboardPreferencesLoaderProvider)();
      final storedOrder = prefs.getStringList(dashboardCardOrderStorageKey);
      if (storedOrder != null && listEquals(state, initialState)) {
        state = _sanitizeOrder(storedOrder);
      }
    } catch (_) {
      // Keep the in-memory default order.
    }
  }

  Future<void> setOrder(List<String> order) async {
    final next = _sanitizeOrder(order);
    state = next;

    try {
      final prefs = await ref.read(dashboardPreferencesLoaderProvider)();
      await prefs.setStringList(dashboardCardOrderStorageKey, next);
    } catch (_) {
      // Keep the in-memory order even if persistence fails.
    }
  }

  Future<void> moveCard(String draggedId, String targetId) async {
    final next = _moveCard(state, draggedId, targetId);
    if (listEquals(next, state)) {
      return;
    }

    await setOrder(next);
  }

  List<String> _sanitizeOrder(List<String> order) {
    final seen = <String>{};
    final next = <String>[];

    for (final rawId in order) {
      final id = _normalizeCardId(rawId);
      if (!dashboardDefaultCardOrder.contains(id) || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      next.add(id);
    }

    for (final id in dashboardDefaultCardOrder) {
      if (seen.add(id)) {
        next.add(id);
      }
    }

    return next;
  }

  String _normalizeCardId(String id) {
    return switch (id) {
      _legacyTopFiveHighestCardId => myListsCardId,
      _legacyTopFiveWalksCardId => myAscentsCardId,
      _ => id,
    };
  }

  List<String> _moveCard(
    List<String> order,
    String draggedId,
    String targetId,
  ) {
    final draggedIndex = order.indexOf(draggedId);
    final targetIndex = order.indexOf(targetId);
    if (draggedIndex < 0 || targetIndex < 0 || draggedIndex == targetIndex) {
      return order;
    }

    final next = [...order];
    final dragged = next.removeAt(draggedIndex);
    final adjustedTargetIndex = draggedIndex < targetIndex
        ? targetIndex - 1
        : targetIndex;
    next.insert(adjustedTargetIndex, dragged);
    return next;
  }
}
