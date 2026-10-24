import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One Time-only vertical viewport for its chrome, toolbar and chart. The grid
/// owns the outer size; content can exceed it without starving the plot.
class TimeCardViewport extends StatefulWidget {
  const TimeCardViewport({
    this.header,
    this.controls,
    required this.chart,
    this.minimumChartHeight = 0,
    super.key,
  });

  final Widget? header;
  final Widget? controls;
  final Widget chart;
  final double minimumChartHeight;

  @override
  State<TimeCardViewport> createState() => TimeCardViewportState();
}

class TimeCardViewportState extends State<TimeCardViewport> {
  final _scroll = ScrollController();

  /// The chart can be outside the sliver cache for an exceptionally tall header.
  /// Reveal its slot first; do not require an already-mounted chart RenderBox.
  void revealChart() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void scrollPage({required bool forward}) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.jumpTo(
      (position.pixels + (forward ? 1 : -1) * position.viewportDimension).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scroll,
    child: CustomScrollView(
      key: const Key('time-card-viewport'),
      controller: _scroll,
      primary: false,
      slivers: [
        if (widget.header case final header?) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (widget.controls case final controls?)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: controls,
                  ),
                ),
              SliverLayoutBuilder(
                builder: (context, constraints) => SliverToBoxAdapter(
                  child: SizedBox(
                    height: math.max(
                      widget.minimumChartHeight,
                      constraints.viewportMainAxisExtent -
                          constraints.precedingScrollExtent -
                          12,
                    ),
                    child: widget.chart,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
