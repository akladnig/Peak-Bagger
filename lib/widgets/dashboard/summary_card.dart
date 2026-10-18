import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/date_formatters.dart';
import '../../models/gpx_track.dart';
import '../../providers/summary_page_controller.dart';
import '../../services/summary_card_service.dart';
import '../../theme.dart';
import 'summary_chart.dart';
import 'summary_page_browser.dart';
import 'dashboard_card_keyboard.dart';
import 'dashboard_dropdown.dart';

class SummaryVisibleSummary {
  const SummaryVisibleSummary({
    required this.period,
    required this.totalValue,
    required this.averageValue,
  });

  final SummaryPeriodPreset period;
  final double totalValue;
  final double averageValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryVisibleSummary &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          totalValue == other.totalValue &&
          averageValue == other.averageValue;

  @override
  int get hashCode => Object.hash(period, totalValue, averageValue);
}

class SummaryCardMetricAdapter {
  const SummaryCardMetricAdapter({
    required this.keyPrefix,
    required this.emptyStateText,
    required this.metric,
    required this.tooltipValueTexts,
    this.tooltipValueTextColors,
    required this.headerValueText,
    required this.yAxisLabelText,
    this.chartMaxYFor = defaultChartMaxYFor,
    this.tooltipTitleText = defaultTooltipTitleText,
    this.averageLabelText = defaultAverageLabelText,
    this.secondaryMetric,
    this.secondarySeriesOnTop = false,
    this.barSeriesStyle = SummaryBarSeriesStyle.stacked,
    this.isEligible,
    this.chartValueScale = 1,
  });

  final String keyPrefix;
  final String emptyStateText;
  final SummaryMetricDefinition metric;
  final SummaryMetricDefinition? secondaryMetric;
  final List<String> Function(
    SummaryBucket bucket,
    SummaryBucket? secondaryBucket,
  )
  tooltipValueTexts;
  final List<Color> Function(
    BuildContext context,
    SummaryBucket bucket,
    SummaryBucket? secondaryBucket,
  )?
  tooltipValueTextColors;
  final String Function(double value) headerValueText;
  final String Function(double value) yAxisLabelText;
  final double Function(double maxValue) chartMaxYFor;
  final String Function(SummaryBucket bucket, SummaryPeriodPreset period)
  tooltipTitleText;
  final String Function(SummaryPeriodPreset period) averageLabelText;
  final bool secondarySeriesOnTop;
  final SummaryBarSeriesStyle barSeriesStyle;
  final bool Function(GpxTrack track)? isEligible;
  final double chartValueScale;
}

class SummaryCard extends ConsumerStatefulWidget {
  const SummaryCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    required this.adapter,
    this.initialMode = SummaryDisplayMode.columns,
    this.now,
    this.onVisibleSummaryChanged,
    this.displayMode,
    this.barSeriesStyle,
    this.chartTypeControlBuilder,
    this.enableKeyboardInspection = false,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final SummaryCardMetricAdapter adapter;
  final SummaryDisplayMode initialMode;
  final DateTime? now;
  final ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged;

  /// Explicit opt-in to externally owned chart selection and a menu control.
  /// Legacy adapters retain their binary control and local display default.
  final SummaryDisplayMode? displayMode;
  final SummaryBarSeriesStyle? barSeriesStyle;
  final Widget Function(VoidCallback onOpen, VoidCallback onChanged)?
  chartTypeControlBuilder;
  final bool enableKeyboardInspection;

  @override
  ConsumerState<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends ConsumerState<SummaryCard> {
  final SummaryCardService _service = const SummaryCardService();
  final ScrollController _scrollController = ScrollController();
  final Object _cardIdentity = Object();
  SummaryPeriodPreset get _period =>
      ref.read(summaryPageControllerProvider(_cardIdentity)).period;
  late SummaryDisplayMode _mode;
  SummaryDisplayMode get _displayMode => widget.displayMode ?? _mode;
  SummaryVisibleSummary? _lastVisibleSummary;
  bool _hasReportedSummary = false;
  int _revision = 0;
  int _inputRevision = 0;
  late List<GpxTrack> _tracks;
  DashboardCardKeyboardController? _keyboard;
  SummaryChartInspection? _inspection;
  Object? _inspectionIdentity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _clearInspection();
    final keyboard = DashboardCardKeyboard.maybeOf(context);
    if (_keyboard != keyboard) {
      _unregisterKeyboard();
      _keyboard = keyboard;
      for (final key in _pageKeys) {
        _keyboard?.actions[key] = _keyActions[key]!;
      }
      if (widget.chartTypeControlBuilder == null) {
        _keyboard?.actions[LogicalKeyboardKey.keyC] = _toggleMode;
      }
      if (widget.enableKeyboardInspection) {
        _keyboard?.focusEvents.addListener(_onKeyboardFocus);
        for (final entry in _inspectionActions.entries) {
          _keyboard?.actions[entry.key] = entry.value;
        }
      }
    }
  }

  static const _pageKeys = [
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
  ];
  late final _keyActions = <LogicalKeyboardKey, VoidCallback>{
    LogicalKeyboardKey.keyW: () =>
        _keyboardNavigate(SummaryPageAction.adjacent),
    LogicalKeyboardKey.keyB: () =>
        _keyboardNavigate(SummaryPageAction.adjacent, pages: -1),
    LogicalKeyboardKey.home: () => _keyboardNavigate(SummaryPageAction.first),
    LogicalKeyboardKey.end: () => _keyboardNavigate(SummaryPageAction.last),
  };

  late final _inspectionActions = <LogicalKeyboardKey, VoidCallback>{
    LogicalKeyboardKey.arrowLeft: () => _stepInspection(false),
    LogicalKeyboardKey.keyH: () => _stepInspection(false),
    LogicalKeyboardKey.arrowRight: () => _stepInspection(true),
    LogicalKeyboardKey.keyL: () => _stepInspection(true),
    LogicalKeyboardKey.escape: _clearKeyboardInspection,
  };

  void _clearKeyboardInspection() {
    if (!mounted) return;
    _inputRevision++;
    setState(_clearInspection);
  }

  void _clearInspection() {
    _inspection = null;
    _inspectionIdentity = null;
  }

  Object _chartIdentity(DateTime referenceDate, SummaryCalendarPage page) => (
    widget.tracks,
    referenceDate,
    _period,
    page.start,
    page.endExclusive,
    _revision,
    TickerMode.valuesOf(context).enabled,
  );

  // Read the current authoritative page for every key, including keys arriving
  // before the previous input has painted. Never navigate from a rendered cache.
  ({Object identity, List<SummaryBucket> buckets})? _inspectionPage() {
    if (widget.isLoading) return null;
    final reference = _referenceDate;
    final navigation = ref
        .read(summaryPageControllerProvider(_cardIdentity))
        .navigation(
          tracks: _tracks,
          metric: widget.adapter.metric,
          now: reference,
        );
    if (navigation == null) return null;
    return (
      identity: _chartIdentity(reference, navigation.selected),
      buckets: _service
          .buildTimeline(
            tracks: _tracks,
            period: _period,
            metric: widget.adapter.metric,
            now: reference,
            page: navigation.selected,
          )
          .buckets,
    );
  }

  void _initializeInspection({bool? boundaryForward}) {
    if (!mounted) return;
    _inputRevision++;
    final page = _inspectionPage();
    if (page == null || page.buckets.isEmpty) return;
    final latest = page.buckets.lastIndexWhere(
      (bucket) => bucket.trackCount > 0,
    );
    final index = boundaryForward == null
        ? math.max(0, latest)
        : boundaryForward
        ? 0
        : page.buckets.length - 1;
    setState(() {
      _inspectionIdentity = page.identity;
      _inspection = (index: index, pinned: true);
    });
  }

  void _onKeyboardFocus() {
    final keyboard = _keyboard;
    if (!mounted || keyboard == null || !keyboard.isActive()) return;
    switch (keyboard.focusEvents.value.$2) {
      case DashboardCardFocusReason.entry:
        // Repeated notifications while the same card owns focus are not entry.
        if (!keyboard.focusNode.hasPrimaryFocus) _initializeInspection();
      case DashboardCardFocusReason.menuChanged:
        setState(_clearInspection);
      case DashboardCardFocusReason.menuReturn:
        break;
    }
  }

  void _stepInspection(bool forward) {
    if (!mounted || widget.isLoading) return;
    _inputRevision++;
    final selection = ref.read(summaryPageControllerProvider(_cardIdentity));
    if (selection.referenceDate != _referenceDate) {
      _navigate(SummaryPageAction.reconcile);
      return;
    }
    final page = _inspectionPage();
    if (page == null) return;
    final index = _inspectionIdentity == page.identity
        ? _inspection?.index
        : null;
    if (index == null) {
      _initializeInspection();
      return;
    }
    final next = index + (forward ? 1 : -1);
    if (next >= 0 && next < page.buckets.length) {
      setState(() => _inspection = (index: next, pinned: true));
      return;
    }
    final navigation = selection.navigation(
      tracks: _tracks,
      metric: widget.adapter.metric,
      now: _referenceDate,
    )!;
    if (forward ? !navigation.canNext : !navigation.canPrevious) return;
    _navigate(SummaryPageAction.adjacent, pages: forward ? 1 : -1);
    _initializeInspection(boundaryForward: forward);
  }

  void _unregisterKeyboard() {
    _keyboard?.focusEvents.removeListener(_onKeyboardFocus);
    for (final entry in _inspectionActions.entries) {
      if (_keyboard?.actions[entry.key] == entry.value) {
        _keyboard?.actions.remove(entry.key);
      }
    }
    for (final key in _pageKeys) {
      if (_keyboard?.actions[key] == _keyActions[key]) {
        _keyboard?.actions.remove(key);
      }
    }
    if (_keyboard?.actions[LogicalKeyboardKey.keyC] == _toggleMode) {
      _keyboard?.actions.remove(LogicalKeyboardKey.keyC);
    }
  }

  void _keyboardNavigate(SummaryPageAction action, {int pages = 1}) {
    if (!mounted || widget.isLoading) return;
    final navigation = ref
        .read(summaryPageControllerProvider(_cardIdentity))
        .navigation(
          tracks: _tracks,
          metric: widget.adapter.metric,
          now: _referenceDate,
        );
    if (navigation == null) return;
    final enabled = switch (action) {
      SummaryPageAction.first => navigation.canFirst,
      SummaryPageAction.last => navigation.canLast,
      SummaryPageAction.adjacent =>
        pages < 0 ? navigation.canPrevious : navigation.canNext,
      SummaryPageAction.reconcile => true,
    };
    if (!enabled) {
      // A disabled toolbar action is a no-op. Only a changed reference day
      // requires reconciliation; do not clear valid inspection at a bound.
      _reconcileForChartMenu();
      return;
    }
    _navigate(action, pages: pages);
    if (widget.enableKeyboardInspection &&
        action == SummaryPageAction.adjacent) {
      _initializeInspection();
    }
  }

  void _filterTracks() {
    final isEligible = widget.adapter.isEligible;
    _tracks = isEligible == null
        ? widget.tracks
        : widget.tracks.where(isEligible).toList(growable: false);
  }

  DateTime get _referenceDate {
    final now = (widget.now ?? ref.read(dashboardReferenceClockProvider)())
        .toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void didUpdateWidget(covariant SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tracks, widget.tracks) ||
        oldWidget.adapter != widget.adapter) {
      _filterTracks();
    }
    if (!identical(oldWidget.tracks, widget.tracks) ||
        oldWidget.now != widget.now ||
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.displayMode != widget.displayMode ||
        oldWidget.barSeriesStyle != widget.barSeriesStyle) {
      _invalidate();
    }
  }

  void _invalidate() {
    _clearInspection();
    _revision++;
    _lastVisibleSummary = null;
    _hasReportedSummary = false;
  }

  void _navigate(
    SummaryPageAction action, {
    int pages = 1,
    DateTime? inputReference,
  }) {
    _invalidate();
    ref
        .read(summaryPageControllerProvider(_cardIdentity).notifier)
        .navigate(
          action: action,
          tracks: _tracks,
          metric: widget.adapter.metric,
          referenceDate: _referenceDate,
          pages: pages,
          inputReference: inputReference,
        );
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _filterTracks();
  }

  @override
  void dispose() {
    _unregisterKeyboard();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectPeriod(SummaryPeriodPreset? next) {
    if (next == null) {
      return;
    }
    if (next == _period) {
      _navigate(SummaryPageAction.reconcile);
      return;
    }
    _invalidate();
    setState(() {
      ref
          .read(summaryPageControllerProvider(_cardIdentity).notifier)
          .selectPeriod(next);
    });
  }

  void _toggleMode() {
    if (widget.isLoading) return;
    if (ref
            .read(summaryPageControllerProvider(_cardIdentity))
            .navigation(
              tracks: _tracks,
              metric: widget.adapter.metric,
              now: _referenceDate,
            ) ==
        null) {
      return;
    }
    _navigate(SummaryPageAction.reconcile);
    setState(() {
      _mode = switch (_mode) {
        SummaryDisplayMode.columns => SummaryDisplayMode.line,
        SummaryDisplayMode.line => SummaryDisplayMode.columns,
      };
    });
  }

  void _reconcileForChartMenu() {
    if (widget.enableKeyboardInspection) {
      // A menu takes temporary ownership from direct chart/page input, while
      // an unchanged menu must preserve the still-valid inspected bucket.
      setState(() => _inputRevision++);
    }
    // Opening/dismissing a menu or choosing the same type must not invalidate
    // still-valid inspection. A changed clock still uses the shared page owner.
    if (ref.read(summaryPageControllerProvider(_cardIdentity)).referenceDate !=
        _referenceDate) {
      _navigate(SummaryPageAction.reconcile);
    }
  }

  void _reportVisibleSummary(SummaryVisibleSummary? summary) {
    if (widget.onVisibleSummaryChanged == null ||
        (_hasReportedSummary && _lastVisibleSummary == summary)) {
      return;
    }

    _lastVisibleSummary = summary;
    _hasReportedSummary = true;
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == _revision && _lastVisibleSummary == summary) {
        widget.onVisibleSummaryChanged?.call(summary);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(summaryPageControllerProvider(_cardIdentity));
    ref.watch(dashboardReferenceClockProvider);
    // StatefulShellRoute retains Dashboard offstage. Activation changes this
    // dependency even when Tracks and the injected clock closure are unchanged.
    TickerMode.valuesOf(context);
    return widget.isLoading ? _buildLoadingState() : _buildContent();
  }

  Widget _buildLoadingState() {
    _reportVisibleSummary(null);
    return Center(
      key: Key('${widget.adapter.keyPrefix}-loading-state'),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildContent() {
    return _buildCalendarContent(_referenceDate);
  }

  Widget _buildCalendarContent(DateTime referenceDate) {
    final selection = ref.read(summaryPageControllerProvider(_cardIdentity));
    final navigation = selection.navigation(
      tracks: _tracks,
      metric: widget.adapter.metric,
      now: referenceDate,
    );
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _revision ||
          _referenceDate != referenceDate) {
        return;
      }
      ref
          .read(summaryPageControllerProvider(_cardIdentity).notifier)
          .reconcile(
            expected: selection,
            navigation: navigation,
            referenceDate: referenceDate,
          );
    });
    if (navigation == null) {
      _reportVisibleSummary(null);
      return Center(
        key: Key('${widget.adapter.keyPrefix}-empty-state'),
        child: Text(
          widget.adapter.emptyStateText,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final page = navigation.selected;
    // Discard, rather than merely hide, inspection invalidated by activation
    // or a reference-day projection (which need not increment _revision).
    if (_inspectionIdentity != null &&
        _inspectionIdentity != _chartIdentity(referenceDate, page)) {
      _clearInspection();
    }
    final timeline = _service.buildTimeline(
      tracks: _tracks,
      period: _period,
      metric: widget.adapter.metric,
      now: referenceDate,
      page: page,
    );
    final secondary = widget.adapter.secondaryMetric == null
        ? null
        : _service.buildTimeline(
            tracks: _tracks,
            period: _period,
            metric: widget.adapter.secondaryMetric!,
            now: referenceDate,
            page: page,
          );
    _reportVisibleSummary(
      SummaryVisibleSummary(
        period: _period,
        totalValue: timeline.totalValue,
        averageValue: _service.visibleAverageValueForPeriod(
          period: _period,
          buckets: timeline.buckets,
          referenceDate: referenceDate,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryHeader(
            keyPrefix: widget.adapter.keyPrefix,
            period: _period,
            mode: _displayMode,
            chartTypeControl: widget.chartTypeControlBuilder?.call(
              _reconcileForChartMenu,
              () => _navigate(SummaryPageAction.reconcile),
            ),
            visibleRangeText: formatSummaryDateRange(page.start, page.lastDay),
            onPeriodChanged: _selectPeriod,
            onOpenPeriod: _reconcileForChartMenu,
            onToggleMode: _toggleMode,
            onFirst: () => _navigate(SummaryPageAction.first),
            onPrevious: () => _navigate(SummaryPageAction.adjacent, pages: -1),
            onNext: () => _navigate(SummaryPageAction.adjacent),
            onLast: () => _navigate(SummaryPageAction.last),
            canMoveFirst: navigation.canFirst,
            canMovePrevious: navigation.canPrevious,
            canMoveNext: navigation.canNext,
            canMoveLast: navigation.canLast,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max<double>(
                  constraints.maxWidth - DashboardUI.yAxisLabelWidth,
                  1,
                );
                final identity = _chartIdentity(referenceDate, page);
                final inputRevision = _inputRevision;
                return SummaryPageBrowser(
                  key: Key('${widget.adapter.keyPrefix}-page-browser'),
                  revision: (identity, inputRevision),
                  enabled: navigation.canPrevious || navigation.canNext,
                  onPages: (pages) {
                    // Timers run before a queued frame's rebuild. Reject input
                    // synchronously superseded by a toolbar action as well as
                    // the cancellation performed by didUpdateWidget.
                    if (_revision != revision ||
                        _inputRevision != inputRevision ||
                        !TickerMode.valuesOf(context).enabled) {
                      return;
                    }
                    _navigate(
                      SummaryPageAction.adjacent,
                      pages: pages,
                      inputReference: referenceDate,
                    );
                  },
                  child: SummaryChart(
                    key: Key('${widget.adapter.keyPrefix}-scroll-view'),
                    keyPrefix: widget.adapter.keyPrefix,
                    controller: _scrollController,
                    buckets: timeline.buckets,
                    secondaryBuckets: secondary?.buckets,
                    mode: _displayMode,
                    barSeriesStyle:
                        widget.barSeriesStyle ?? widget.adapter.barSeriesStyle,
                    valueScale: widget.adapter.chartValueScale,
                    bucketExtent: width / timeline.buckets.length,
                    period: _period,
                    referenceDate: referenceDate,
                    chartMaxYFor: widget.adapter.chartMaxYFor,
                    tooltipValueTexts: widget.adapter.tooltipValueTexts,
                    tooltipValueTextColors:
                        widget.adapter.tooltipValueTextColors,
                    tooltipTitleText: widget.adapter.tooltipTitleText,
                    yAxisLabelText: widget.adapter.yAxisLabelText,
                    secondarySeriesOnTop: widget.adapter.secondarySeriesOnTop,
                    inspectionIdentity: identity,
                    inspection: _inspectionIdentity == identity
                        ? _inspection
                        : null,
                    onInspectionChanged: !widget.enableKeyboardInspection
                        ? null
                        : (inspection) {
                            if (_revision != revision ||
                                _referenceDate != referenceDate) {
                              return;
                            }
                            // A tap/key can pin before this frame's hover-exit
                            // callback has rebuilt with the new presentation.
                            if (inspection == null &&
                                _inspection?.pinned == true) {
                              return;
                            }
                            setState(() {
                              _inspectionIdentity = identity;
                              _inspection = inspection;
                            });
                          },
                    scrollable: false,
                    onInspect: () {
                      if (_revision != revision) return false;
                      if (_referenceDate == referenceDate) return true;
                      _navigate(SummaryPageAction.reconcile);
                      return false;
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  static const double _periodDropdownWidth = 160;

  const _SummaryHeader({
    required this.keyPrefix,
    required this.period,
    required this.mode,
    this.chartTypeControl,
    required this.visibleRangeText,
    required this.onPeriodChanged,
    required this.onOpenPeriod,
    required this.onToggleMode,
    required this.onPrevious,
    required this.onNext,
    required this.onFirst,
    required this.onLast,
    required this.canMoveFirst,
    required this.canMoveLast,
    required this.canMovePrevious,
    required this.canMoveNext,
  });

  final String keyPrefix;
  final SummaryPeriodPreset period;
  final SummaryDisplayMode mode;
  final Widget? chartTypeControl;
  final String visibleRangeText;
  final ValueChanged<SummaryPeriodPreset?> onPeriodChanged;
  final VoidCallback onOpenPeriod;
  final VoidCallback onToggleMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirst;
  final VoidCallback onLast;
  final bool canMoveFirst;
  final bool canMoveLast;
  final bool canMovePrevious;
  final bool canMoveNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _periodDropdownWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DashboardDropdown<SummaryPeriodPreset>(
                  selected: period,
                  shortcut: LogicalKeyboardKey.keyP,
                  minimumWidth: _periodDropdownWidth,
                  onOpen: onOpenPeriod,
                  onSelected: (value) {
                    if (value != period) onPeriodChanged(value);
                  },
                  choices: [
                    for (final value in SummaryPeriodPreset.values)
                      DashboardDropdownChoice(
                        key: Key('$keyPrefix-period-${value.name}'),
                        value: value,
                        label: value.label,
                      ),
                  ],
                  buttonBuilder: (focusNode, toggle) {
                    return InkWell(
                      key: const Key('summary-period-dropdown'),
                      focusNode: focusNode,
                      mouseCursor: SystemMouseCursors.click,
                      borderRadius: BorderRadius.circular(6),
                      onTap: toggle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                period.label,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Spacer(),
            _SummaryNavigationButton(
              buttonKey: const Key('summary-first-window'),
              label: 'First',
              enabled: canMoveFirst,
              onPressed: onFirst,
              icon: Icons.first_page,
            ),
            _SummaryNavigationButton(
              buttonKey: const Key('summary-prev-window'),
              label: period.previousTooltip,
              enabled: canMovePrevious,
              onPressed: onPrevious,
              icon: Icons.chevron_left,
            ),
            _SummaryNavigationButton(
              buttonKey: const Key('summary-next-window'),
              label: period.nextTooltip,
              enabled: canMoveNext,
              onPressed: onNext,
              icon: Icons.chevron_right,
            ),
            _SummaryNavigationButton(
              buttonKey: const Key('summary-last-window'),
              label: 'Last',
              enabled: canMoveLast,
              onPressed: onLast,
              icon: Icons.last_page,
            ),
            const SizedBox(width: 8),
            chartTypeControl ??
                FloatingActionButton.small(
                  key: const Key('summary-mode-fab'),
                  onPressed: onToggleMode,
                  mouseCursor: SystemMouseCursors.click,
                  tooltip: mode == SummaryDisplayMode.columns
                      ? 'Switch to line view'
                      : 'Switch to column view',
                  child: Icon(
                    mode == SummaryDisplayMode.columns
                        ? Icons.show_chart
                        : Icons.bar_chart,
                  ),
                ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          visibleRangeText,
          key: Key('$keyPrefix-period-range'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SummaryNavigationButton extends StatelessWidget {
  const _SummaryNavigationButton({
    required this.buttonKey,
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.icon,
  });

  final Key buttonKey;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => TooltipTheme(
    // The icon supplies the action name even when its visual tooltip is absent.
    data: TooltipTheme.of(context).copyWith(excludeFromSemantics: true),
    child: IconButton(
      key: buttonKey,
      style: dashboardNavigationButtonStyle(Theme.of(context).colorScheme),
      tooltip: enabled ? label : null,
      onPressed: enabled ? onPressed : null,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      icon: Icon(icon, semanticLabel: label),
    ),
  );
}

String defaultAverageLabelText(SummaryPeriodPreset period) =>
    period.averageLabel;

double defaultChartMaxYFor(double maxValue) {
  return math.max(4.0, (((maxValue.floor()) + 1 + 3) ~/ 4) * 4.0);
}

double roundedChartMaxYFor(double maxValue) {
  if (!maxValue.isFinite || maxValue <= 0) {
    return 4.0;
  }

  if (maxValue < 20) {
    return 20.0;
  }

  final place = _roundedChartPlace(maxValue.abs());
  final interval = ((maxValue / 4) / place).ceilToDouble() * place;
  return math.max(4.0, interval * 4);
}

double _roundedChartPlace(double value) {
  if (value < 100) {
    return 10.0;
  }

  final exponent = (math.log(value) / math.ln10).floor() - 1;
  return math.pow(10.0, exponent).toDouble();
}
