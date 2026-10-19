import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/track_date_migration_provider.dart';
import '../services/track_date_migration_repository.dart';
import '../services/track_date_migration_service.dart';

/// Startup writer barrier: the routed subtree (including startup backfills and
/// import/admin actions) is mounted only after durable date recalculation.
class TrackDateMigrationHost extends ConsumerStatefulWidget {
  const TrackDateMigrationHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<TrackDateMigrationHost> createState() =>
      _TrackDateMigrationHostState();
}

class _TrackDateMigrationHostState
    extends ConsumerState<TrackDateMigrationHost> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackDateMigrationProvider);
    if (state.isReady &&
        (_acknowledged ||
            state.result == null ||
            state.result!.alreadyCompleted)) {
      return widget.child;
    }
    return Scaffold(
      key: const Key('track-date-migration-status'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Walk date recalculation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  key: const Key('track-date-migration-details'),
                  children: [
                    if (state.status == TrackDateMigrationStatus.failed) ...[
                      Text(
                        'Walk dates could not be recalculated.',
                        key: const Key('track-date-migration-failure'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No recalculation changes were committed. Check available disk space and database access, then Retry. If data changed during preparation, Retry will use the latest records.',
                      ),
                    ] else if (!state.isReady) ...[
                      LinearProgressIndicator(
                        key: const Key('track-date-migration-progress'),
                        value:
                            state.progress?.phase ==
                                    TrackDateMigrationPhase.preparing &&
                                (state.progress?.total ?? 0) > 0
                            ? state.progress!.processed / state.progress!.total
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.progress?.phase ==
                                TrackDateMigrationPhase.committing
                            ? 'Committing walk and ascent dates…'
                            : 'Preparing walk dates: ${state.progress?.processed ?? 0} / ${state.progress?.total ?? 0}',
                      ),
                    ] else if (state.result case final result?) ...[
                      const Text('Walk date recalculation complete.'),
                      const SizedBox(height: 12),
                      Text(
                        'Updated: ${result.metadata.updatedCount}',
                        key: const Key('track-date-migration-updated'),
                      ),
                      Text(
                        'Unchanged: ${result.metadata.unchangedCount}',
                        key: const Key('track-date-migration-unchanged'),
                      ),
                      Text(
                        'Skipped: ${result.metadata.skippedCount}',
                        key: const Key('track-date-migration-skipped'),
                      ),
                      if (result.metadata.skippedCount > 0) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Skipped records retain their previous dates. Check their original GPX before reimporting.',
                        ),
                        for (final skip in TrackDateMigrationSkip.decode(
                          result.metadata.skippedRecordsJson,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SelectableText(
                              '${skip.trackName} (Track ${skip.trackId}): ${skip.message}',
                              key: ValueKey(
                                'track-date-migration-skip-${skip.trackId}',
                              ),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (state.status == TrackDateMigrationStatus.failed)
                      FilledButton(
                        key: const Key('track-date-migration-retry'),
                        onPressed: () => ref
                            .read(trackDateMigrationProvider.notifier)
                            .ensureCurrent(),
                        child: const Text('Retry'),
                      ),
                    if (state.isReady)
                      FilledButton(
                        key: const Key('track-date-migration-continue'),
                        onPressed: () => setState(() => _acknowledged = true),
                        child: const Text('Continue'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
