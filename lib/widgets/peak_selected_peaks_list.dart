import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/peak.dart';

class PeakSelectedPeaksList extends StatelessWidget {
  const PeakSelectedPeaksList({
    required this.selectedPeaks,
    required this.selectedPeakIds,
    required this.pointsByPeakId,
    required this.onSelectionChanged,
    required this.onPointsChanged,
    required this.mapNameForPeak,
    super.key,
  });

  final List<Peak> selectedPeaks;
  final Set<int> selectedPeakIds;
  final Map<int, int> pointsByPeakId;
  final ValueChanged<Set<int>> onSelectionChanged;
  final void Function(int peakId, int points) onPointsChanged;
  final String Function(Peak peak) mapNameForPeak;

  @override
  Widget build(BuildContext context) {
    final sortedSelectedPeaks = List<Peak>.from(selectedPeaks)
      ..sort((left, right) {
        final nameComparison = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        if (nameComparison != 0) {
          return nameComparison;
        }
        return left.osmId.compareTo(right.osmId);
      });

    if (sortedSelectedPeaks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            key: const Key('peak-selected-scrollable'),
            itemCount: sortedSelectedPeaks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final peak = sortedSelectedPeaks[index];
              final selected = selectedPeakIds.contains(peak.osmId);
              return _PeakSelectedRow(
                key: Key('peak-selected-row-${peak.osmId}'),
                peak: peak,
                selectedPeakIds: selectedPeakIds,
                selected: selected,
                points: pointsByPeakId[peak.osmId] ?? 1,
                mapName: mapNameForPeak(peak),
                onSelectionChanged: onSelectionChanged,
                onPointsChanged: onPointsChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeakSelectedRow extends StatefulWidget {
  const _PeakSelectedRow({
    super.key,
    required this.peak,
    required this.selectedPeakIds,
    required this.selected,
    required this.points,
    required this.mapName,
    required this.onSelectionChanged,
    required this.onPointsChanged,
  });

  final Peak peak;
  final Set<int> selectedPeakIds;
  final bool selected;
  final int points;
  final String mapName;
  final ValueChanged<Set<int>> onSelectionChanged;
  final void Function(int peakId, int points) onPointsChanged;

  @override
  State<_PeakSelectedRow> createState() => _PeakSelectedRowState();
}

class _PeakSelectedRowState extends State<_PeakSelectedRow> {
  late final TextEditingController _pointsController;
  late final FocusNode _focusNode;
  bool _syncingText = false;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController(text: widget.points.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _PeakSelectedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.points.toString();
    if (!_focusNode.hasFocus && _pointsController.text != nextText) {
      _setControllerText(nextText);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Colors.green.withValues(alpha: 0.12);
    final checkboxKey = Key('peak-selected-checkbox-${widget.peak.osmId}');
    final pointsKey = Key('peak-selected-points-${widget.peak.osmId}');

    return Container(
      color: widget.selected ? selectedColor : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              key: checkboxKey,
              value: widget.selected,
              activeColor: Colors.green,
              checkColor: Colors.white,
              onChanged: _toggleSelection,
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.peak.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Text(
                _heightLabel(widget.peak.elevation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                widget.mapName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: _PointsControl(
                fieldKey: pointsKey,
                controller: _pointsController,
                focusNode: _focusNode,
                onChanged: _onPointsChanged,
                onIncrement: () => _adjustPoints(1),
                onDecrement: () => _adjustPoints(-1),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _pointsController.text.isEmpty) {
      _commitPoints(1);
    }
  }

  void _adjustPoints(int delta) {
    final current = int.tryParse(_pointsController.text) ?? widget.points;
    _commitPoints((current + delta).clamp(0, 10).toInt());
  }

  void _onPointsChanged(String value) {
    if (_syncingText) {
      return;
    }
    if (value.isEmpty) {
      return;
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return;
    }
    _commitPoints(parsed.clamp(0, 10).toInt());
  }

  void _commitPoints(int value) {
    final clamped = value.clamp(0, 10).toInt();
    final nextText = clamped.toString();
    _setControllerText(nextText);
    widget.onPointsChanged(widget.peak.osmId, clamped);
  }

  void _setControllerText(String value) {
    _syncingText = true;
    _pointsController.text = value;
    _pointsController.selection = TextSelection.collapsed(
      offset: _pointsController.text.length,
    );
    _syncingText = false;
  }

  String _heightLabel(double? elevation) {
    if (elevation == null) {
      return '—';
    }
    return '${elevation.round()}m';
  }
}

class _PointsControl extends StatelessWidget {
  const _PointsControl({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(20, 20),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('peak-selected-points-down'),
          style: buttonStyle,
          onPressed: onDecrement,
          iconSize: 16,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 38,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          key: const Key('peak-selected-points-up'),
          style: buttonStyle,
          onPressed: onIncrement,
          iconSize: 16,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
