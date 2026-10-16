import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/performance_measurement.dart';
import 'dashboard_layout_provider.dart';
import 'local_data_load_outcome_provider.dart';
import 'map_provider.dart';
import 'mapping_store_operation_provider.dart';
import 'my_ascents_summary_provider.dart';
import 'my_lists_summary_provider.dart';
import 'peak_list_selection_provider.dart';
import 'peak_marker_info_settings_provider.dart';
import 'track_date_migration_provider.dart';

export 'local_data_load_outcome_provider.dart';

final performanceMeasurementProvider = Provider<PerformanceMeasurement>(
  (ref) => performanceMeasurement,
);

/// Watching these providers loads data for off-screen cards, not their widgets.
/// The outcomes come from the actual read boundaries used by the visible UI.
final dashboardReadinessProvider = Provider<Map<String, AsyncValue<Object?>>>((
  ref,
) {
  final lists = ref.watch(peakListsLoadProvider);
  final listRows = ref.watch(myListsSummaryReadProvider);
  ref.watch(mappingStoreOperationRevisionProvider);
  final dates = ref.watch(trackDateMigrationProvider);
  return {
    'track-calendar-dates': dates.isReady
        ? const AsyncData(null)
        : dates.error != null
        ? AsyncError(dates.error!, StackTrace.current)
        : const AsyncLoading(),
    'main-navigation':
        ref.watch(mappingStoreOperationCoordinatorProvider).activeFailure ==
            null
        ? const AsyncData(null)
        : const AsyncLoading(),
    'dashboard-layout': ref.watch(dashboardLayoutReadProvider),
    'peak-info-settings': ref.watch(peakMarkerInfoReadProvider),
    'peak-info-hydration': ref.watch(peakMarkerInfoHydrationProvider),
    'tracks-migrations-settings': ref.watch(mapDashboardLoadProvider),
    'track-presentation':
        ref.watch(mapProvider.select((s) => s.isLoadingTracks))
        ? const AsyncLoading()
        : const AsyncData(null),
    'peak-lists': lists.failed
        ? AsyncError(StateError('Peak list read failed'), StackTrace.current)
        : AsyncData(lists.peakLists),
    'my-lists': listRows,
    'list-ascent-dates': ref.watch(myListsAscentDatesReadProvider),
    'my-ascents': ref.watch(myAscentsSummaryReadProvider),
  };
});

bool dashboardDependenciesLoaded(Map<String, AsyncValue<Object?>> outcomes) =>
    outcomes.values.every(
      (value) => !value.isLoading && !value.hasError && value.hasValue,
    );
