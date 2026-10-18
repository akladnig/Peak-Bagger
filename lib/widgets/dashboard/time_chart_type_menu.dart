import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../providers/time_chart_type_provider.dart';
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
      selected: selected,
      shortcut: LogicalKeyboardKey.keyC,
      alignment: AlignmentDirectional.bottomEnd,
      onOpen: onOpen,
      onSelected: (type) {
        if (type == selected) return;
        onChanged();
        ref.read(timeChartTypeProvider.notifier).select(type);
      },
      choices: [
        for (final type in TimeChartType.values)
          DashboardDropdownChoice(
            key: Key('time-chart-type-${type.name}'),
            value: type,
            label: type.label,
            icon: type.icon,
          ),
      ],
      buttonBuilder: (focusNode, toggle) => TooltipTheme(
        data: TooltipTheme.of(context).copyWith(excludeFromSemantics: true),
        child: FloatingActionButton.small(
          key: const Key('time-chart-type-button'),
          focusNode: focusNode,
          tooltip: 'Chart type',
          mouseCursor: SystemMouseCursors.click,
          onPressed: toggle,
          child: Icon(selected.icon, semanticLabel: 'Chart type'),
        ),
      ),
    );
  }
}
