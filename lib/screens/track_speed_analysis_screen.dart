import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/providers/track_speed_analysis_provider.dart';
import 'package:peak_bagger/services/track_speed_analysis_service.dart';

class TrackSpeedAnalysisScreen extends ConsumerStatefulWidget {
  const TrackSpeedAnalysisScreen({super.key});

  @override
  ConsumerState<TrackSpeedAnalysisScreen> createState() =>
      _TrackSpeedAnalysisScreenState();
}

class _TrackSpeedAnalysisScreenState
    extends ConsumerState<TrackSpeedAnalysisScreen> {
  TrackSpeedAnalysisReport? _report;
  TrackSpeedAnalysisProgress? _progress;
  String? _errorSummary;
  bool _isRunning = true;
  int _activeRunId = 0;

  @override
  void initState() {
    super.initState();
    _runAnalysis(isRetry: false);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final isEmpty = report == null ? false : _isEmptyReport(report);

    return Scaffold(
      appBar: AppBar(title: const Text('Track Speed Analysis')),
      body: ListView(
        key: const Key('track-speed-analysis-screen'),
        padding: const EdgeInsets.all(16),
        children: [
          _TrackSpeedAnalysisActionHeader(
            isRunning: _isRunning,
            progress: _progress,
            onRefresh: _isRunning ? null : () => _runAnalysis(isRetry: false),
          ),
          const SizedBox(height: 12),
          if (_errorSummary != null && report == null)
            _TrackSpeedAnalysisErrorState(
              errorSummary: _errorSummary!,
              isRunning: _isRunning,
              onRetry: _isRunning ? null : () => _runAnalysis(isRetry: true),
            )
          else if (report == null)
            _TrackSpeedAnalysisLoadingState(progress: _progress)
          else ...[
            if (_errorSummary != null) ...[
              _TrackSpeedAnalysisInlineError(
                errorSummary: _errorSummary!,
                isRunning: _isRunning,
                onRetry: _isRunning ? null : () => _runAnalysis(isRetry: true),
              ),
              const SizedBox(height: 16),
            ],
            if (isEmpty)
              _TrackSpeedAnalysisEmptyState(
                onRefresh: _isRunning ? null : () => _runAnalysis(isRetry: false),
              )
            else
              _TrackSpeedAnalysisReportView(report: report),
          ],
          const SizedBox(height: 16),
          const Text(
            'Analysis uses the same filtered-track basis as current track statistics when available. Changing filter settings and running Recalculate Track Statistics can change report results.',
            key: Key('track-speed-analysis-filtered-track-note'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAnalysis({required bool isRetry}) async {
    if (_isRunning && _activeRunId != 0) {
      return;
    }

    final shouldKeepVisibleFailure = _report == null && _errorSummary != null;
    final runId = _activeRunId + 1;
    if (mounted) {
      setState(() {
        _activeRunId = runId;
        _isRunning = true;
        _progress = null;
        if (!shouldKeepVisibleFailure) {
          _errorSummary = null;
        }
      });
    } else {
      _activeRunId = runId;
      _isRunning = true;
      _progress = null;
    }

    try {
      final report = await ref.read(trackSpeedAnalysisRunnerProvider).analyze(
        onProgress: (progress) {
          if (!mounted || _activeRunId != runId) {
            return;
          }
          setState(() {
            _progress = progress;
          });
        },
      );
      if (!mounted || _activeRunId != runId) {
        return;
      }
      setState(() {
        _report = report;
        _progress = null;
        _errorSummary = null;
        _isRunning = false;
      });
    } catch (error) {
      if (!mounted || _activeRunId != runId) {
        return;
      }
      setState(() {
        _progress = null;
        _errorSummary = _summarizeError(error);
        _isRunning = false;
      });
    }
  }

  bool _isEmptyReport(TrackSpeedAnalysisReport report) {
    return report.sections.every((section) => section.rows.isEmpty);
  }

  String _summarizeError(Object error) {
    final message = '$error';
    const prefixes = ['Exception: ', 'Bad state: ', 'FormatException: '];
    for (final prefix in prefixes) {
      if (message.startsWith(prefix)) {
        return message.substring(prefix.length);
      }
    }
    return message;
  }
}

class _TrackSpeedAnalysisActionHeader extends StatelessWidget {
  const _TrackSpeedAnalysisActionHeader({
    required this.isRunning,
    required this.progress,
    required this.onRefresh,
  });

  final bool isRunning;
  final TrackSpeedAnalysisProgress? progress;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        TextButton(
          key: const Key('track-speed-analysis-refresh-action'),
          onPressed: onRefresh,
          child: const Text('Refresh Analysis'),
        ),
        if (isRunning)
          const SizedBox(
            key: Key('track-speed-analysis-refresh-progress'),
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (isRunning && progress != null)
          Text(
            progress!.label,
            key: const Key('track-speed-analysis-progress-text'),
          ),
      ],
    );
  }
}

class _TrackSpeedAnalysisLoadingState extends StatelessWidget {
  const _TrackSpeedAnalysisLoadingState({required this.progress});

  final TrackSpeedAnalysisProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          key: const Key('track-speed-analysis-loading'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Analysing tracks...'),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text(progress!.label),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackSpeedAnalysisEmptyState extends StatelessWidget {
  const _TrackSpeedAnalysisEmptyState({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          key: const Key('track-speed-analysis-empty-state'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No analysis data yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Import timestamped Tasmanian tracks and recalculate track statistics to build walking-speed analysis.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRefresh,
              child: const Text('Refresh Analysis'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSpeedAnalysisErrorState extends StatelessWidget {
  const _TrackSpeedAnalysisErrorState({
    required this.errorSummary,
    required this.isRunning,
    required this.onRetry,
  });

  final String errorSummary;
  final bool isRunning;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          key: const Key('track-speed-analysis-error-state'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Analysis failed',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(errorSummary, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('track-speed-analysis-retry-action'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSpeedAnalysisInlineError extends StatelessWidget {
  const _TrackSpeedAnalysisInlineError({
    required this.errorSummary,
    required this.isRunning,
    required this.onRetry,
  });

  final String errorSummary;
  final bool isRunning;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('track-speed-analysis-error-state'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis failed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(errorSummary),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('track-speed-analysis-retry-action'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSpeedAnalysisReportView extends StatelessWidget {
  const _TrackSpeedAnalysisReportView({required this.report});

  final TrackSpeedAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: report.sections
          .map((section) => _TrackSpeedAnalysisSectionCard(section: section))
          .toList(growable: false),
    );
  }
}

class _TrackSpeedAnalysisSectionCard extends StatelessWidget {
  const _TrackSpeedAnalysisSectionCard({required this.section});

  final TrackSpeedAnalysisSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key(_sectionKey(section.kind)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sectionTitle(section.kind),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Bucket')),
                  DataColumn(label: Text('Median speed')),
                  DataColumn(label: Text('Sample count')),
                  DataColumn(label: Text('Total moving distance')),
                  DataColumn(label: Text('Total moving time')),
                ],
                rows: section.rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.label)),
                          DataCell(Text(formatSpeedKmh(row.medianSpeedKmh))),
                          DataCell(Text(formatCount(row.sampleCount))),
                          DataCell(
                            Text(
                              formatDistance(
                                row.totalMovingDistanceMeters,
                                decimalPlaces: 1,
                              ),
                            ),
                          ),
                          DataCell(Text(_formatDuration(row.totalMovingTime))),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionTitle(TrackSpeedAnalysisSectionKind kind) {
    return switch (kind) {
      TrackSpeedAnalysisSectionKind.trackType => 'Speed by track type',
      TrackSpeedAnalysisSectionKind.hikingDifficulty =>
        'Speed by hiking difficulty',
      TrackSpeedAnalysisSectionKind.trackTypeAndHikingDifficulty =>
        'Speed by track type + hiking difficulty',
      TrackSpeedAnalysisSectionKind.gradientBand => 'Speed by gradient band',
    };
  }

  String _sectionKey(TrackSpeedAnalysisSectionKind kind) {
    return switch (kind) {
      TrackSpeedAnalysisSectionKind.trackType =>
        'track-speed-analysis-section-track-type',
      TrackSpeedAnalysisSectionKind.hikingDifficulty =>
        'track-speed-analysis-section-hiking-difficulty',
      TrackSpeedAnalysisSectionKind.trackTypeAndHikingDifficulty =>
        'track-speed-analysis-section-track-type-and-hiking-difficulty',
      TrackSpeedAnalysisSectionKind.gradientBand =>
        'track-speed-analysis-section-gradient-band',
    };
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}
