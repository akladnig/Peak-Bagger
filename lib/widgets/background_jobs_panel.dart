import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/widgets/popup_shell.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';

class BackgroundJobsPanel extends StatelessWidget {
  const BackgroundJobsPanel({
    required this.jobs,
    required this.onClose,
    required this.onToggleExpanded,
    required this.onDismissJob,
    required this.onClearFinishedJobs,
    super.key,
  });

  final List<BackgroundJob> jobs;
  final VoidCallback onClose;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<String> onDismissJob;
  final VoidCallback onClearFinishedJobs;

  @override
  Widget build(BuildContext context) {
    final hasFinishedJobs = jobs.any((job) => job.isFinished);

    return SizedBox(
      key: const Key('background-jobs-panel'),
      width: UiConstants.preferredRightWidth,
      child: PopupShell(
        title: const Text('Background Jobs'),
        closeButtonKey: const Key('background-jobs-close'),
        onClose: onClose,
        bodyFlexible: true,
        headerActions: [
          if (hasFinishedJobs)
            TextButton(
              key: const Key('background-jobs-clear-finished'),
              onPressed: onClearFinishedJobs,
              child: const Text('Clear finished'),
            ),
        ],
        body: jobs.isEmpty
            ? const SizedBox.shrink()
            : ListView.separated(
                key: const Key('background-jobs-list'),
                shrinkWrap: true,
                itemCount: jobs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return _BackgroundJobCard(
                    job: job,
                    onToggleExpanded: () => onToggleExpanded(job.id),
                    onDismiss: job.isFinished
                        ? () => onDismissJob(job.id)
                        : null,
                  );
                },
              ),
      ),
    );
  }
}

class _BackgroundJobCard extends StatelessWidget {
  const _BackgroundJobCard({
    required this.job,
    required this.onToggleExpanded,
    this.onDismiss,
  });

  final BackgroundJob job;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = job.progress;
    final detailLines = <String>[
      ...?switch (job.summary) {
        null => null,
        final summary => <String>[summary],
      },
      ...job.detailLines,
    ];

    return Card(
      key: Key('background-jobs-row-${job.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.label,
                        key: Key('background-jobs-label-${job.id}'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _BackgroundJobStatusChip(job: job),
                          if (job.hasWarnings) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.warning_amber_rounded, size: 16),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    key: Key('background-jobs-dismiss-${job.id}'),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close),
                  ),
                IconButton(
                  key: Key('background-jobs-expand-${job.id}'),
                  onPressed: onToggleExpanded,
                  tooltip: job.isExpanded ? 'Collapse' : 'Expand',
                  icon: Icon(
                    job.isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text(progress.label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                progress.statusText,
                key: Key('background-jobs-progress-${job.id}'),
              ),
              if (progress.secondaryStatusText case final secondaryStatusText?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(secondaryStatusText),
                ),
              if (progress.currentFileName case final currentFileName?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    currentFileName,
                    key: Key('background-jobs-file-${job.id}'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (progress.percent case final percent?) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: percent),
              ],
            ],
            if (job.isExpanded && detailLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final detailLine in detailLines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(detailLine),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackgroundJobStatusChip extends StatelessWidget {
  const _BackgroundJobStatusChip({required this.job});

  final BackgroundJob job;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = switch (job.status) {
      BackgroundJobStatus.running => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
      BackgroundJobStatus.completed => (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
      BackgroundJobStatus.failed => (
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      ),
      BackgroundJobStatus.cancelled => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      key: Key('background-jobs-status-${job.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        job.statusLabel,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.foreground),
      ),
    );
  }
}
