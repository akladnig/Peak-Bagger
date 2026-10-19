import 'dart:collection';

import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls physical completion independently of visible order/provider state.
class ControlledDashboardOrderWriter {
  final steps = Queue<Future<bool> Function()>();
  final writes = <List<String>>[];

  Future<bool> call(List<String> order) async {
    writes.add(List.of(order));
    final success = steps.isEmpty ? true : await steps.removeFirst()();
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(dashboardCardOrderStorageKey, order);
    }
    return success;
  }
}
