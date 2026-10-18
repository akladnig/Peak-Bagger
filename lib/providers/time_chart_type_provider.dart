import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimeChartType { stackedColumn, line, clusteredColumn }

/// App-owned selection, independent of the card's transient menu and page.
/// Preference loading/saving will extend this owner in Work Item 03.
final timeChartTypeProvider =
    NotifierProvider<TimeChartTypeController, TimeChartType>(
      TimeChartTypeController.new,
    );

class TimeChartTypeController extends Notifier<TimeChartType> {
  @override
  TimeChartType build() => TimeChartType.stackedColumn;

  void select(TimeChartType type) {
    if (type == state) return;
    state = type;
  }
}
