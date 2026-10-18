import 'dart:async';

import 'package:flutter/material.dart';
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = _resolveColumnCount(constraints.maxWidth);
                  return GridView.builder(
                    key: const Key('dashboard-board'),
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
                              valueFormatter: TimeCard.adapter.headerValueText,
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
    required this.headerTrailing,
    required this.body,
    required this.onMove,
  });

  final DashboardCardDefinition definition;
  final Widget? headerTrailing;
  final Widget body;
  final void Function(String draggedId, String targetId) onMove;

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isPointerHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<String>(
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
                color: isHovered
                    ? theme.colorScheme.outlineVariant
                    : theme.colorScheme.outline,
                width: isHovered ? 2 : 1,
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
