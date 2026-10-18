import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/time_chart_type_provider.dart';

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

class TimeChartTypeMenu extends ConsumerStatefulWidget {
  const TimeChartTypeMenu({
    super.key,
    required this.onOpen,
    required this.onChanged,
  });

  final VoidCallback onOpen;
  final VoidCallback onChanged;

  @override
  ConsumerState<TimeChartTypeMenu> createState() => _TimeChartTypeMenuState();
}

class _TimeChartTypeMenuState extends ConsumerState<TimeChartTypeMenu> {
  final _buttonFocus = FocusNode(debugLabel: 'Time Chart type');

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(timeChartTypeProvider);
    return MenuAnchor(
      childFocusNode: _buttonFocus,
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      menuChildren: [
        for (final type in TimeChartType.values)
          MenuItemButton(
            key: Key('time-chart-type-${type.name}'),
            autofocus: type == selected,
            leadingIcon: Icon(type.icon),
            trailingIcon: type == selected ? const Icon(Icons.check) : null,
            onPressed: () {
              // Material menus dispatch selection in a post-frame callback.
              if (!mounted) return;
              if (type == selected) return;
              // Invalidate pending pointer/page callbacks synchronously,
              // before a provider-driven frame changes the rendered type.
              widget.onChanged();
              ref.read(timeChartTypeProvider.notifier).select(type);
            },
            child: Semantics(
              selected: type == selected,
              child: Text(type.label),
            ),
          ),
      ],
      builder: (context, controller, child) => TooltipTheme(
        data: TooltipTheme.of(context).copyWith(excludeFromSemantics: true),
        child: FloatingActionButton.small(
          key: const Key('time-chart-type-button'),
          focusNode: _buttonFocus,
          tooltip: 'Chart type',
          mouseCursor: SystemMouseCursors.click,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              widget.onOpen();
              controller.open();
            }
          },
          child: Icon(selected.icon, semanticLabel: 'Chart type'),
        ),
      ),
    );
  }
}
