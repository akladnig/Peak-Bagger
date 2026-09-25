import 'package:flutter/material.dart';

import '../core/number_formatters.dart';
import '../models/peak.dart';
import '../theme.dart';

class PeakMultiSelectResultsList extends StatelessWidget {
  const PeakMultiSelectResultsList({
    required this.searchResults,
    required this.searchQuery,
    required this.selectedPeakIds,
    this.readOnlySelectedPeakIds = const {},
    required this.onSelectionChanged,
    required this.mapNameForPeak,
    super.key,
  });

  final List<Peak> searchResults;
  final String searchQuery;
  final Set<int> selectedPeakIds;
  final Set<int> readOnlySelectedPeakIds;
  final ValueChanged<Set<int>> onSelectionChanged;
  final String Function(Peak peak) mapNameForPeak;

  @override
  Widget build(BuildContext context) {
    final sortedResults = List<Peak>.from(searchResults)
      ..sort((left, right) {
        final nameComparison = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        if (nameComparison != 0) {
          return nameComparison;
        }
        return left.osmId.compareTo(right.osmId);
      });
    final selectionLimitReached = selectedPeakIds.length >= 50;
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);

    if (sortedResults.isEmpty) {
      if (searchQuery.isNotEmpty) {
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('No peaks found'),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectionLimitReached)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Maximum 50 peaks per save',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Expanded(
          child: ListView.separated(
            key: const Key('peak-multi-select-scrollable'),
            itemCount: sortedResults.length,
            separatorBuilder: (context, index) => Divider(
              key: Key('peak-multi-select-divider-$index'),
              height: dataGridTheme.dividerThickness,
              thickness: dataGridTheme.dividerThickness,
              color: dataGridTheme.dividerColor,
            ),
            itemBuilder: (context, index) {
              final peak = sortedResults[index];
              final readOnlySelected = readOnlySelectedPeakIds.contains(
                peak.osmId,
              );
              final selected =
                  selectedPeakIds.contains(peak.osmId) || readOnlySelected;
              final canSelect =
                  !readOnlySelected && (selected || !selectionLimitReached);
              return _PeakSearchResultRow(
                key: Key('peak-multi-select-row-${peak.osmId}'),
                peak: peak,
                selectedPeakIds: selectedPeakIds,
                selected: selected,
                readOnlySelected: readOnlySelected,
                canToggleSelection: canSelect,
                mapName: mapNameForPeak(peak),
                onSelectionChanged: onSelectionChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeakSearchResultRow extends StatefulWidget {
  const _PeakSearchResultRow({
    super.key,
    required this.peak,
    required this.selectedPeakIds,
    required this.selected,
    required this.readOnlySelected,
    required this.canToggleSelection,
    required this.mapName,
    required this.onSelectionChanged,
  });

  final Peak peak;
  final Set<int> selectedPeakIds;
  final bool selected;
  final bool readOnlySelected;
  final bool canToggleSelection;
  final String mapName;
  final ValueChanged<Set<int>> onSelectionChanged;

  @override
  State<_PeakSearchResultRow> createState() => _PeakSearchResultRowState();
}

class _PeakSearchResultRowState extends State<_PeakSearchResultRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);
    final checkboxKey = Key('peak-multi-select-checkbox-${widget.peak.osmId}');
    final rowTextStyle = widget.readOnlySelected
        ? dataGridTheme.rowTextStyle.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : dataGridTheme.rowTextStyle;
    final rowDecoration = _rowDecoration(dataGridTheme);

    return MouseRegion(
      cursor: widget.canToggleSelection
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: widget.canToggleSelection
            ? (_) => _setPressed(true)
            : null,
        onPointerUp: widget.canToggleSelection
            ? (_) => _setPressed(false)
            : null,
        onPointerCancel: widget.canToggleSelection
            ? (_) => _setPressed(false)
            : null,
        child: Container(
          decoration: rowDecoration,
          padding: dataGridTheme.rowPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: checkboxKey,
                value: widget.selected,
                activeColor: Colors.green,
                checkColor: Colors.white,
                onChanged: widget.canToggleSelection ? _toggleSelection : null,
              ),
              SizedBox(width: dataGridTheme.columnGap),
              Expanded(
                flex: 3,
                child: Text(
                  widget.peak.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rowTextStyle,
                ),
              ),
              SizedBox(width: dataGridTheme.columnGap),
              Expanded(
                flex: 1,
                child: Text(
                  _heightLabel(widget.peak.elevation),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rowTextStyle,
                ),
              ),
              SizedBox(width: dataGridTheme.columnGap),
              Expanded(
                flex: 2,
                child: Text(
                  widget.mapName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rowTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration? _rowDecoration(DataGridTheme dataGridTheme) {
    if (widget.selected) {
      return BoxDecoration(
        color: dataGridTheme.selectedRowColor,
        border: Border.symmetric(
          horizontal: BorderSide(color: dataGridTheme.selectedRowBorderColor),
        ),
      );
    }
    if (_isPressed) {
      return BoxDecoration(color: dataGridTheme.pressedRowColor);
    }
    if (_isHovered) {
      return BoxDecoration(color: dataGridTheme.hoverColor);
    }
    return null;
  }

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }
    setState(() {
      _isHovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  void _toggleSelection(bool? value) {
    final next = <int>{...widget.selectedPeakIds};
    if (value ?? false) {
      next.add(widget.peak.osmId);
    } else {
      next.remove(widget.peak.osmId);
    }
    widget.onSelectionChanged(next);
  }

  String _heightLabel(double? elevation) {
    if (elevation == null) {
      return '—';
    }
    return formatCompactElevation(elevation);
  }
}
