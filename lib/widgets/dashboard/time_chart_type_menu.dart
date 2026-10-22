import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../providers/time_chart_type_provider.dart';
import '../shared_dropdown.dart';
import 'dashboard_dropdown.dart';

extension TimeChartTypePresentation on TimeChartType {
  String get label => switch (this) {
    TimeChartType.stackedColumn => 'Stacked column view',
    TimeChartType.line => 'Line view',
    TimeChartType.clusteredColumn => 'Clustered column view',
  };

  IconData get icon => switch (this) {
    TimeChartType.stackedColumn => Icons.stacked_bar_chart,
    TimeChartType.line => Icons.show_chart,
    TimeChartType.clusteredColumn => Icons.bar_chart,
  };
}

class TimeChartTypeMenu extends ConsumerWidget {
  const TimeChartTypeMenu({
    super.key,
    required this.onOpen,
    required this.onChanged,
  });

  final VoidCallback onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(timeChartTypeProvider.select((s) => s.selected));
    return DashboardDropdown<TimeChartType>(
      key: const Key('time-chart-type-button'),
      label: 'Chart type',
      selected: selected,
      shortcut: LogicalKeyboardKey.keyC,
      trigger: SharedDropdownTrigger.iconOnly,
      rows: SharedDropdownRows.iconAndLabel,
      icon: selected.icon,
      onOpen: onOpen,
      onSelected: (type) {
        if (type == selected) return;
        onChanged();
        ref.read(timeChartTypeProvider.notifier).select(type);
      },
      choices: [
        for (final type in TimeChartType.values)
          SharedDropdownChoice(
            key: Key('time-chart-type-${type.name}'),
            value: type,
            label: type.label,
            icon: type.icon,
          ),
      ],
    );
  }
}
