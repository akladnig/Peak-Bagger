import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_layout_provider.dart';
import '../../providers/time_chart_type_provider.dart';

/// Dashboard-scoped preference feedback, independent of lazy card construction.
/// One presentation owner keeps Time's queued warnings/keyboard Retry distinct
/// from active-surface order-save failures, without competing SnackBar owners.
class DashboardPreferenceFeedback extends ConsumerStatefulWidget {
  const DashboardPreferenceFeedback({required this.child, super.key});
  final Widget child;

  static void retryVisibleTimeWarning(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_TimePreferenceRetry>()?.retry();

  @override
  ConsumerState<DashboardPreferenceFeedback> createState() =>
      _DashboardPreferenceFeedbackState();
}

class _DashboardPreferenceFeedbackState
    extends ConsumerState<DashboardPreferenceFeedback>
    with WidgetsBindingObserver {
  final _retryFocus = FocusNode(
    debugLabel: 'Time preference Retry',
    skipTraversal: true,
  );
  final _orderRetryFocus = FocusNode(
    debugLabel: 'Dashboard order Retry',
    skipTraversal: true,
    canRequestFocus: false,
  );
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBar;
  AsyncValue<void>? _pendingOrderFailure;
  AsyncValue<void>? _shownOrderFailure;
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
    ref.listenManual(dashboardOrderSaveProvider, (_, next) {
      // Deliberately no app-scoped queue/replay policy for card-order warnings.
      _pendingOrderFailure = _active && next?.hasError == true ? next : null;
      _schedule();
    });
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
      final orderOutcome = ref.read(dashboardOrderSaveProvider);
      if (!_active) {
        _pendingOrderFailure = null;
        _removeShown();
        return;
      }
      if ((_shownId != null && warning?.id != _shownId) ||
          (_shownOrderFailure != null &&
              orderOutcome?.isLoading != true &&
              !identical(orderOutcome, _shownOrderFailure))) {
        _removeShown();
      }
      if (warning == null || warning.presented || _shownId != null) {
        if (_snackBar == null &&
            _pendingOrderFailure != null &&
            identical(orderOutcome, _pendingOrderFailure)) {
          _showOrderFailure(_pendingOrderFailure!);
        }
        return;
      }
      _pendingOrderFailure ??= _shownOrderFailure;
      _removeShown();
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
                onPressed: _retryVisible,
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
    if (_snackBar == null) return;
    _shownId = null;
    _shownOrderFailure = null;
    _snackBar = null;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    if (id != null) _controller.dismissWarning(id);
  }

  void _showOrderFailure(AsyncValue<void> failure) {
    _pendingOrderFailure = null;
    _shownOrderFailure = failure;
    _snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('dashboard-order-save-warning'),
        content: Consumer(
          builder: (context, ref, _) {
            final saving =
                ref.watch(dashboardOrderSaveProvider)?.isLoading == true;
            return Row(
              children: [
                const Expanded(
                  child: Text('Couldn’t save Dashboard card order.'),
                ),
                if (saving)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        key: const Key('dashboard-order-save-pending'),
                        color: Theme.of(context).colorScheme.inversePrimary,
                        strokeWidth: 2,
                        semanticsLabel: 'Saving Dashboard card order',
                      ),
                    ),
                  ),
                ExcludeFocus(
                  child: TextButton(
                    key: const Key('dashboard-order-retry'),
                    focusNode: _orderRetryFocus,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.inversePrimary,
                    ),
                    onPressed: saving
                        ? null
                        : () {
                            if (!_active ||
                                !identical(_shownOrderFailure, failure)) {
                              return;
                            }
                            unawaited(
                              ref
                                  .read(dashboardOrderSaveProvider.notifier)
                                  .retry(),
                            );
                          },
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    unawaited(
      _snackBar!.closed.then((_) {
        if (!mounted || !identical(_shownOrderFailure, failure)) return;
        _shownOrderFailure = null;
        _snackBar = null;
        _schedule();
      }),
    );
  }

  void _retryVisible() {
    final id = ref.read(timeChartTypeProvider).visibleWarningId;
    if (!_active || id == null || id != _shownId) return;
    unawaited(_controller.retryVisibleWarning());
    _snackBar?.close();
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
    _orderRetryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _TimePreferenceRetry(retry: _retryVisible, child: widget.child);
}

class _TimePreferenceRetry extends InheritedWidget {
  const _TimePreferenceRetry({required this.retry, required super.child});
  final VoidCallback retry;
  @override
  bool updateShouldNotify(_TimePreferenceRetry oldWidget) => false;
}
