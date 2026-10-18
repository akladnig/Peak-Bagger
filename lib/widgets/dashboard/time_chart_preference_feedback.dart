import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/time_chart_type_provider.dart';

/// Dashboard-scoped delivery, independent of whether Time is built by the grid.
class TimeChartPreferenceFeedback extends ConsumerStatefulWidget {
  const TimeChartPreferenceFeedback({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<TimeChartPreferenceFeedback> createState() =>
      _TimeChartPreferenceFeedbackState();
}

class _TimeChartPreferenceFeedbackState
    extends ConsumerState<TimeChartPreferenceFeedback>
    with WidgetsBindingObserver {
  final _retryFocus = FocusNode(
    debugLabel: 'Time preference Retry',
    skipTraversal: true,
  );
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBar;
  int? _shownId;
  bool _scheduled = false;
  late final TimeChartTypeController _controller;

  bool get _active =>
      mounted &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(timeChartTypeProvider.notifier);
    ref.listenManual(timeChartTypeProvider, (_, _) => _schedule());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _schedule();

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final warning = ref.read(timeChartTypeProvider).warning;
      if (!_active || warning?.id != _shownId) _removeShown();
      if (!_active ||
          warning == null ||
          warning.presented ||
          _shownId != null) {
        return;
      }
      final controller = ref.read(timeChartTypeProvider.notifier);
      final id = warning.id;
      _shownId = id;
      final messenger = ScaffoldMessenger.of(context);
      _snackBar = messenger.showSnackBar(
        SnackBar(
          key: ValueKey('time-preference-warning-$id'),
          onVisible: () {
            // onVisible can run while the messenger is building. Consume only
            // after the visible frame and recheck activation/operation identity.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _active && _shownId == id) {
                controller.markWarningPresented(id);
              }
            });
          },
          content: Row(
            children: [
              Expanded(child: Text(warning.message)),
              TextButton(
                key: const Key('time-preference-retry'),
                focusNode: _retryFocus,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.inversePrimary,
                ),
                onPressed: () {
                  unawaited(controller.retryWarning(id));
                  _snackBar?.close();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
      unawaited(
        _snackBar!.closed.then((_) {
          if (!mounted) return;
          controller.dismissWarning(id);
          if (_shownId == id) {
            _snackBar = null;
            _shownId = null;
            _schedule();
          }
        }),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _removeShown() {
    final id = _shownId;
    if (id == null) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    _shownId = null;
    _snackBar = null;
    ref.read(timeChartTypeProvider.notifier).dismissWarning(id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The local messenger disposes its presentation. Clear keyboard identity
    // after the tree teardown without publishing feedback or consuming a queue.
    final id = _shownId;
    if (id != null) {
      scheduleMicrotask(() {
        _controller.dismissWarning(id);
      });
    }
    _retryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
