import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/core/constants.dart';

import '../core/number_formatters.dart';
import '../providers/dashboard_layout_provider.dart';
import '../providers/dashboard_readiness_provider.dart';
import '../providers/summary_page_controller.dart';
import '../providers/time_chart_type_provider.dart';
import '../providers/map_provider.dart';
import '../providers/peak_marker_info_settings_provider.dart';
import '../providers/peak_list_provider.dart';
import '../router.dart';
import '../services/latest_walk_summary.dart';
import '../services/performance_frame.dart';
import '../services/summary_card_service.dart';
import '../widgets/dashboard/distance_card.dart';
import '../widgets/dashboard/time_card.dart';
import '../widgets/dashboard/time_chart_preference_feedback.dart';
import '../widgets/dashboard/elevation_card.dart';
import '../widgets/dashboard/latest_walk_card.dart';
import '../widgets/dashboard/my_ascents_card.dart';
import '../widgets/dashboard/my_lists_card.dart';
import '../widgets/dashboard/peaks_bagged_card.dart';
import '../widgets/dashboard/year_to_date_card.dart';
import '../widgets/dashboard/summary_card.dart';
import '../widgets/dashboard/dashboard_card_keyboard.dart';
import '../widgets/shell_destination_keyboard.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  SummaryVisibleSummary? _elevationSummary;
  SummaryVisibleSummary? _distanceSummary;
  SummaryVisibleSummary? _timeSummary;
  SummaryVisibleSummary? _peaksBaggedSummary;
  bool _readyMarkerEmitted = false;
  bool _readyFrameScheduled = false;
  final Set<String> _failedDependencies = {};
  VoidCallback? _cancelFrameMeasurement;
  int _headerRevision = 0;
  int _paintedHeaderRevision = 0;
  Map<String, AsyncValue<Object?>>? _paintedReadiness;
  List<String>? _paintedOrder;
  Object? _paintedTracks;
  bool? _paintedPeakInfo;
  final _boardScroll = ScrollController();
  final _boardFocus = FocusNode(debugLabel: 'Dashboard traversal');
  final Map<String, DashboardCardKeyboardController> _cardKeyboards = {};
  String? _focusTarget;
  int _focusRevision = 0;
  int _columns = 1;
  double _gridWidth = 0;

  bool get _active =>
      mounted &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  DashboardCardKeyboardController _keyboardFor(DashboardCardDefinition card) =>
      _cardKeyboards.putIfAbsent(
        card.id,
        () => DashboardCardKeyboardController(
          title: card.title,
          traverse: (forward) => _traverse(forward, from: card.id),
        )..isActive = () => _active,
      );

  void _traverse(bool forward, {String? from}) {
    if (!_active) return;
    final order = ref.read(dashboardLayoutProvider);
    final focused =
        _focusTarget ??
        from ??
        _cardKeyboards.entries
            .where((entry) => entry.value.focusNode.hasFocus)
            .map((entry) => entry.key)
            .firstOrNull;
    final index = order.indexOf(focused ?? '');
    final next = index < 0
        ? (forward ? 0 : order.length - 1)
        : (index + (forward ? 1 : -1)) % order.length;
    _revealAndFocus(order[next]);
  }

  void _revealAndFocus(
    String id, [
    DashboardCardFocusReason reason = DashboardCardFocusReason.entry,
  ]) {
    _focusTarget = id;
    final revision = ++_focusRevision;
    // Keep ownership while the lazy grid constructs an unmounted target.
    _boardFocus.requestFocus();
    void reveal(Duration _) {
      if (!_active || revision != _focusRevision) return;
      final index = ref.read(dashboardLayoutProvider).indexOf(id);
      if (index < 0 || !_boardScroll.hasClients) return;
      final rowHeight =
          ((_gridWidth - 16 * (_columns - 1)) / _columns) /
          dashboardCardAspectRatio;
      final top = (index ~/ _columns) * (rowHeight + 16);
      final position = _boardScroll.position;
      final bottom = top + rowHeight;
      final offset =
          rowHeight >= position.viewportDimension || top < position.pixels
          ? top
          : bottom > position.pixels + position.viewportDimension
          ? bottom - position.viewportDimension
          : position.pixels;
      final target = offset.clamp(0.0, position.maxScrollExtent);
      if ((target - position.pixels).abs() > 0.5) {
        _boardScroll.jumpTo(target);
        WidgetsBinding.instance.addPostFrameCallback(reveal);
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      final keyboard = _cardKeyboards[id];
      if (keyboard?.focusNode.context == null) {
        WidgetsBinding.instance.addPostFrameCallback(reveal);
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      _focusTarget = null;
      keyboard!.focus(reason);
    }

    WidgetsBinding.instance.addPostFrameCallback(reveal);
    WidgetsBinding.instance.scheduleFrame();
  }

  KeyEventResult _boardKey(FocusNode node, KeyEvent event) {
    if (!_active ||
        dashboardHasCommandModifier ||
        dashboardIsEditing ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final focused = _cardKeyboards.values
        .where((c) => c.focusNode.hasFocus)
        .firstOrNull;
    if (focused?.menuOwnsFocus == true) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _traverse(!HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (focused == null || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.f6) {
      final id = _cardKeyboards.entries
          .firstWhere((e) => identical(e.value, focused))
          .key;
      final shell = ShellDestinationKeyboard.maybeOf(context);
      if (shell == null) return KeyEventResult.ignored;
      shell.enter((forward) {
        if (!_active) return;
        if (forward == null) {
          _revealAndFocus(id, DashboardCardFocusReason.menuReturn);
        } else {
          _traverse(forward, from: id);
        }
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyR) {
      // Feedback owns actual presentation and the identical pointer/R action.
      TimeChartPreferenceFeedback.retryVisible(focused.focusNode.context!);
      return KeyEventResult.handled;
    }
    final action = focused.actions[event.logicalKey];
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(dashboardLayoutProvider.notifier).load());
    ref.listenManual(
      dashboardReadinessProvider,
      (_, next) => _observeReadiness(next),
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_active) {
      _focusRevision++;
      _focusTarget = null;
    }
    if (TickerMode.valuesOf(context).enabled) {
      _observeReadiness(ref.read(dashboardReadinessProvider));
    }
  }

  void _observeReadiness(Map<String, AsyncValue<Object?>> next) {
    final measurement = ref.read(performanceMeasurementProvider);
    for (final entry in next.entries) {
      if (entry.value.hasError && _failedDependencies.add(entry.key)) {
        measurement.event('dashboard.dependency.failed', {
          'dependency': entry.key,
          'error': '${entry.value.error}',
        });
      }
    }
    if (!dashboardDependenciesLoaded(next) ||
        _readyMarkerEmitted ||
        _readyFrameScheduled) {
      return;
    }
    _readyFrameScheduled = true;
    // Flush every post-frame summary callback before judging this frame. Only
    // defer if newer local data or header content still awaits a build/paint.
    // Empty data with no pending header update qualifies on this first frame.
    unawaited(
      WidgetsBinding.instance.endOfFrame.then((_) {
        _readyFrameScheduled = false;
        if (!mounted ||
            _readyMarkerEmitted ||
            !dashboardDependenciesLoaded(
              ref.read(dashboardReadinessProvider),
            )) {
          return;
        }
        // A dashboard retained offstage by navigation is not a shown endpoint.
        if (!TickerMode.valuesOf(context).enabled ||
            !(ModalRoute.of(context)?.isCurrent ?? true)) {
          return;
        }
        if (_paintedHeaderRevision != _headerRevision ||
            !identical(
              _paintedReadiness,
              ref.read(dashboardReadinessProvider),
            ) ||
            !identical(_paintedOrder, ref.read(dashboardLayoutProvider)) ||
            !identical(_paintedTracks, ref.read(mapProvider).tracks) ||
            _paintedPeakInfo != ref.read(peakMarkerInfoSettingsProvider)) {
          _observeReadiness(ref.read(dashboardReadinessProvider));
          return;
        }
        _readyMarkerEmitted = true;
        final fields = <String, Object?>{
          'endpoint': 'framework-frame-complete',
          'window_width': MediaQuery.sizeOf(context).width,
          'window_height': MediaQuery.sizeOf(context).height,
          'text_scale': MediaQuery.textScalerOf(context).scale(1),
          'dashboard_order': ref.read(dashboardLayoutProvider),
          'track_count': ref.read(mapProvider).tracks.length,
        };
        measurement.event('dashboard.local_data_ready.frame', fields);
        _cancelFrameMeasurement = recordRasterizedPerformanceFrame(
          measurement,
          'dashboard.local_data_ready.frame',
          fields,
        );
      }),
    );
  }

  void _handleElevationSummaryChanged(SummaryVisibleSummary? summary) {
    if (_elevationSummary == summary) {
      return;
    }

    setState(() {
      _elevationSummary = summary;
      _headerRevision++;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusRevision++;
    _boardScroll.dispose();
    _boardFocus.dispose();
    for (final keyboard in _cardKeyboards.values) {
      keyboard.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _cancelFrameMeasurement?.call();
    super.dispose();
  }

  void _handleDistanceSummaryChanged(SummaryVisibleSummary? summary) {
    if (_distanceSummary == summary) {
      return;
    }

    setState(() {
      _distanceSummary = summary;
      _headerRevision++;
    });
  }

  void _handlePeaksBaggedSummaryChanged(SummaryVisibleSummary? summary) {
    if (_peaksBaggedSummary == summary) {
      return;
    }

    setState(() {
      _peaksBaggedSummary = summary;
      _headerRevision++;
    });
  }

  void _handleTimeSummaryChanged(SummaryVisibleSummary? summary) {
    if (_timeSummary == summary) return;
    setState(() {
      _timeSummary = summary;
      _headerRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? ref.watch(dashboardReferenceClockProvider)();
    _paintedReadiness = ref.watch(dashboardReadinessProvider);
    _paintedHeaderRevision = _headerRevision;
    final order = ref.watch(dashboardLayoutProvider);
    final tracks = ref.watch(mapProvider.select((state) => state.tracks));
    final peaksBagged = ref.watch(peaksBaggedRepositoryProvider).getAll();
    final latestWalkTrackId = LatestWalkSummary.selectLatestTrack(
      tracks,
    )?.gpxTrackId;
    final showPeakInfo = ref.watch(peakMarkerInfoSettingsProvider);
    _paintedOrder = order;
    _paintedTracks = tracks;
    _paintedPeakInfo = showPeakInfo;
    final isLoadingTracks = ref.watch(
      mapProvider.select((state) => state.isLoadingTracks),
    );
    final isLoadingTimePreference = ref.watch(
      timeChartTypeProvider.select((state) => state.isHydrating),
    );

    return ScaffoldMessenger(
      child: Scaffold(
        body: TimeChartPreferenceFeedback(
          child: Focus(
            focusNode: _boardFocus,
            autofocus: true,
            skipTraversal: true,
            onKeyEvent: _boardKey,
            onFocusChange: (focused) {
              if (!focused) {
                _focusRevision++;
                _focusTarget = null;
              }
            },
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _resolveColumnCount(constraints.maxWidth);
                    _columns = columns;
                    _gridWidth = constraints.maxWidth;
                    return GridView.builder(
                      key: const Key('dashboard-board'),
                      controller: _boardScroll,
                      findChildIndexCallback: (key) {
                        final valueKey = key is ValueKey<String>
                            ? key.value
                            : null;
                        if (valueKey == null ||
                            !valueKey.startsWith('dashboard-card-')) {
                          return null;
                        }

                        final cardId = valueKey.substring(
                          'dashboard-card-'.length,
                        );
                        return order.indexOf(cardId);
                      },
                      itemCount: order.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: dashboardCardAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final definition = dashboardCards.firstWhere(
                          (card) => card.id == order[index],
                        );
                        final body = switch (definition.id) {
                          'distance' => DistanceCard(
                            tracks: tracks,
                            isLoading: isLoadingTracks,
                            now: widget.now,
                            onVisibleSummaryChanged:
                                _handleDistanceSummaryChanged,
                          ),
                          'time' => TimeCard(
                            tracks: tracks,
                            isLoading: isLoadingTracks,
                            now: widget.now,
                            onVisibleSummaryChanged: _handleTimeSummaryChanged,
                          ),
                          'latest-walk' => LatestWalkCard(
                            key: ValueKey(
                              'latest-walk-card-${latestWalkTrackId ?? 'empty'}',
                            ),
                            tracks: tracks,
                            showPeakInfo: showPeakInfo,
                            onOpenTrack: (trackId) {
                              ref.read(mapProvider.notifier).showTrack(trackId);
                              router.go('/map');
                            },
                          ),
                          'elevation' => ElevationCard(
                            tracks: tracks,
                            isLoading: isLoadingTracks,
                            now: widget.now,
                            onVisibleSummaryChanged:
                                _handleElevationSummaryChanged,
                          ),
                          'my-ascents' => const MyAscentsCard(),
                          'my-lists' => const MyListsCard(),
                          'peaks-bagged' => PeaksBaggedCard(
                            tracks: tracks,
                            isLoading: isLoadingTracks,
                            now: widget.now,
                            onVisibleSummaryChanged:
                                _handlePeaksBaggedSummaryChanged,
                          ),
                          'year-to-date' => YearToDateCard(
                            tracks: tracks,
                            peaksBagged: peaksBagged,
                            isLoading: isLoadingTracks,
                            now: now,
                          ),
                          _ => const _DashboardCardBody(),
                        };
                        return _DashboardCard(
                          key: ValueKey('dashboard-card-${definition.id}'),
                          definition: definition,
                          keyboard: _keyboardFor(definition),
                          headerTrailing: switch (definition.id) {
                            'elevation' when _elevationSummary != null =>
                              _DashboardCardHeaderMetrics(
                                summary: _elevationSummary!,
                                valueFormatter:
                                    ElevationCard.adapter.headerValueText,
                                averageLabelText:
                                    ElevationCard.adapter.averageLabelText,
                              ),
                            'distance' when _distanceSummary != null =>
                              _DashboardCardHeaderMetrics(
                                summary: _distanceSummary!,
                                valueFormatter:
                                    DistanceCard.adapter.headerValueText,
                                averageLabelText:
                                    DistanceCard.adapter.averageLabelText,
                              ),
                            'time'
                                when _timeSummary != null &&
                                    !isLoadingTracks &&
                                    !isLoadingTimePreference =>
                              _DashboardCardHeaderMetrics(
                                summary: _timeSummary!,
                                valueFormatter:
                                    TimeCard.adapter.headerValueText,
                                averageLabelText:
                                    TimeCard.adapter.averageLabelText,
                                wrap: true,
                              ),
                            'peaks-bagged' when _peaksBaggedSummary != null =>
                              _DashboardCardHeaderMetrics(
                                summary: _peaksBaggedSummary!,
                                valueFormatter: _formatCountValue,
                                averageLabelText: defaultAverageLabelText,
                              ),
                            _ => null,
                          },
                          body: body,
                          onMove: (draggedId, targetId) {
                            unawaited(
                              ref
                                  .read(dashboardLayoutProvider.notifier)
                                  .moveCard(draggedId, targetId),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _resolveColumnCount(double width) {
    if (width >= dashboardDesktopWideBreakpoint) {
      return 3;
    }
    if (width >= dashboardDesktopMediumBreakpoint) {
      return 2;
    }
    return 1;
  }
}

class _DashboardCard extends StatefulWidget {
  const _DashboardCard({
    super.key,
    required this.definition,
    required this.keyboard,
    required this.headerTrailing,
    required this.body,
    required this.onMove,
  });

  final DashboardCardDefinition definition;
  final DashboardCardKeyboardController keyboard;
  final Widget? headerTrailing;
  final Widget body;
  final void Function(String draggedId, String targetId) onMove;

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard>
    with AutomaticKeepAliveClientMixin {
  bool _isPointerHovered = false;
  bool _isDragging = false;
  bool _focused = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return DashboardCardKeyboard(
      controller: widget.keyboard,
      child: Focus(
        key: Key('dashboard-card-${widget.definition.id}-focus'),
        focusNode: widget.keyboard.focusNode,
        includeSemantics: false,
        descendantsAreTraversable: false,
        onFocusChange: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        child: Semantics(
          container: true,
          label: widget.definition.title,
          focusable: true,
          focused: _focused,
          onFocus: widget.keyboard.focus,
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) =>
                details.data != widget.definition.id,
            onAcceptWithDetails: (details) {
              widget.onMove(details.data, widget.definition.id);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered =
                  _isPointerHovered || _isDragging || candidateData.isNotEmpty;
              return MouseRegion(
                onEnter: (_) {
                  if (!_isPointerHovered) {
                    setState(() => _isPointerHovered = true);
                  }
                },
                onExit: (_) {
                  if (_isPointerHovered) {
                    setState(() => _isPointerHovered = false);
                  }
                },
                child: Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: DashboardUI.cardBorderRadius,
                    side: BorderSide(
                      color: _focused
                          ? theme.colorScheme.primary
                          : isHovered
                          ? theme.colorScheme.outlineVariant
                          : theme.colorScheme.outline,
                      width: _focused
                          ? 3
                          : isHovered
                          ? 2
                          : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardCardHeader(
                        definition: widget.definition,
                        headerTrailing: widget.headerTrailing,
                        onDragStarted: () {
                          if (!_isDragging) {
                            setState(() => _isDragging = true);
                          }
                        },
                        onDragEnded: () {
                          if (_isDragging) {
                            setState(() => _isDragging = false);
                          }
                        },
                      ),
                      Expanded(child: widget.body),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardCardHeader extends StatelessWidget {
  const _DashboardCardHeader({
    required this.definition,
    required this.headerTrailing,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final DashboardCardDefinition definition;
  final Widget? headerTrailing;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<String>(
        data: definition.id,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragEnded(),
        feedback: _DashboardCardDragFeedback(
          definition: definition,
          headerTrailing: headerTrailing,
        ),
        childWhenDragging: const Opacity(
          opacity: 0.35,
          child: _DashboardCardHeaderBodyPlaceholder(),
        ),
        child: Container(
          key: Key('dashboard-card-${definition.id}-drag-handle'),
          color: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _DashboardCardHeaderRow(
            title: definition.title,
            headerTrailing: headerTrailing,
            titleStyle: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

class _DashboardCardBody extends StatelessWidget {
  const _DashboardCardBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Placeholder'));
  }
}

class _DashboardCardDragFeedback extends StatelessWidget {
  const _DashboardCardDragFeedback({
    required this.definition,
    required this.headerTrailing,
  });

  final DashboardCardDefinition definition;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 280,
        height: 280 / dashboardCardAspectRatio,
        child: Card(
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: DashboardUI.cardBorderRadius,
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _DashboardCardHeaderRow(
                  title: definition.title,
                  headerTrailing: headerTrailing,
                  titleStyle: theme.textTheme.titleMedium,
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCardHeaderRow extends StatelessWidget {
  const _DashboardCardHeaderRow({
    required this.title,
    required this.headerTrailing,
    required this.titleStyle,
  });

  final String title;
  final Widget? headerTrailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    if (headerTrailing == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.drag_indicator, size: 18),
        ],
      );
    }

    final textDirection = Directionality.of(context);
    final titleWidth = _measureSingleLineTextWidth(
      text: title,
      style: titleStyle,
      textDirection: textDirection,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingMaxWidth =
            (constraints.maxWidth -
                    titleWidth.clamp(0.0, constraints.maxWidth).toDouble() -
                    42)
                .clamp(0.0, constraints.maxWidth)
                .toDouble();

        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: trailingMaxWidth),
              child: Align(
                alignment: Alignment.centerRight,
                child: headerTrailing!,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.drag_indicator, size: 18),
          ],
        );
      },
    );
  }
}

double _measureSingleLineTextWidth({
  required String text,
  required TextStyle? style,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: textDirection,
  )..layout();
  return painter.width;
}

class _DashboardCardHeaderMetrics extends StatelessWidget {
  const _DashboardCardHeaderMetrics({
    required this.summary,
    required this.valueFormatter,
    required this.averageLabelText,
    this.wrap = false,
  });

  final SummaryVisibleSummary summary;
  final String Function(double value) valueFormatter;
  final String Function(SummaryPeriodPreset period) averageLabelText;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(
        key: const Key('time-header-summaries'),
        alignment: WrapAlignment.end,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            'Total: ${valueFormatter(summary.totalValue)}',
            key: const Key('dashboard-card-summary-total-value'),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '${averageLabelText(summary.period)} ${valueFormatter(summary.averageValue)}',
            key: const Key('dashboard-card-summary-average-value'),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _DashboardCardHeaderMetricPill(
            label: 'Total:',
            value: valueFormatter(summary.totalValue),
            metricKey: const Key('dashboard-card-summary-total-value'),
          ),
          const SizedBox(width: 20),
          _DashboardCardHeaderMetricPill(
            label: averageLabelText(summary.period),
            value: valueFormatter(summary.averageValue),
            metricKey: const Key('dashboard-card-summary-average-value'),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardHeaderMetricPill extends StatelessWidget {
  const _DashboardCardHeaderMetricPill({
    required this.label,
    required this.value,
    this.metricKey,
  });

  final String label;
  final String value;
  final Key? metricKey;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      key: metricKey,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    );
  }
}

class _DashboardCardHeaderBodyPlaceholder extends StatelessWidget {
  const _DashboardCardHeaderBodyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

String _formatCountValue(double value) => formatCount(value.round());
