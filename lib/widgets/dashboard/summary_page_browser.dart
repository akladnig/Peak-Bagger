import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Transient input ownership only. Calendar selection belongs to Riverpod.
/// Direct input commits whole pages, so neither pixels nor an animation's
/// completion can restore an obsolete calendar selection.
class SummaryPageBrowser extends StatefulWidget {
  const SummaryPageBrowser({
    super.key,
    required this.revision,
    required this.enabled,
    required this.onPages,
    required this.child,
  });

  final Object revision;
  final bool enabled;
  final ValueChanged<int> onPages;
  final Widget child;

  @override
  State<SummaryPageBrowser> createState() => _SummaryPageBrowserState();
}

class _SummaryPageBrowserState extends State<SummaryPageBrowser> {
  Timer? _scrollEnd;
  double _delta = 0;
  Object? _dragRevision;

  void _cancel() {
    _scrollEnd?.cancel();
    _scrollEnd = null;
    _delta = 0;
    _dragRevision = null;
  }

  @override
  void didUpdateWidget(covariant SummaryPageBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision || !widget.enabled) _cancel();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _settle(double width) {
    final delta = _delta;
    _cancel();
    if (delta.abs() < 24 || !widget.enabled) return;
    widget.onPages(
      delta.sign.toInt() * math.max(1, (delta.abs() / width).round()),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Listener(
      onPointerSignal: (event) {
        if (!widget.enabled ||
            event is! PointerScrollEvent ||
            event.scrollDelta.dx == 0 ||
            event.scrollDelta.dx.abs() < event.scrollDelta.dy.abs()) {
          return;
        }
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          _delta += event.scrollDelta.dx;
          _scrollEnd?.cancel();
          _scrollEnd = Timer(const Duration(milliseconds: 100), () {
            _settle(constraints.maxWidth);
          });
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: widget.enabled
            ? (_) {
                _cancel();
                _dragRevision = widget.revision;
              }
            : null,
        onHorizontalDragUpdate: widget.enabled
            ? (event) {
                if (_dragRevision == widget.revision) _delta -= event.delta.dx;
              }
            : null,
        onHorizontalDragEnd: widget.enabled
            ? (_) {
                if (_dragRevision == widget.revision) {
                  _settle(constraints.maxWidth);
                }
              }
            : null,
        onHorizontalDragCancel: _cancel,
        child: widget.child,
      ),
    ),
  );
}
