import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/my_ascents_summary_service.dart';
import '../services/performance_measurement.dart';
import 'peak_list_provider.dart';
import 'peak_provider.dart';
import 'local_data_load_outcome_provider.dart';

final myAscentsSummaryProvider = Provider<MyAscentsDataset>((ref) {
  return ref.watch(myAscentsSummaryReadProvider).value ??
      const MyAscentsDataset.empty();
});

final myAscentsSummaryReadProvider = Provider<AsyncValue<MyAscentsDataset>>((
  ref,
) {
  ref.watch(peakRevisionProvider);
  ref.watch(peaksBaggedRevisionProvider);
  ref.watch(mapDashboardLoadProvider);

  try {
    final peaksBaggedRepository = ref.watch(peaksBaggedRepositoryProvider);
    return AsyncData(
      performanceMeasurement.phaseSync(
        'dashboard.my-ascents',
        () => MyAscentsDataset(
          baggedRows: peaksBaggedRepository.getAll(),
          peaksByOsmId: ref.watch(peaksByOsmIdProvider),
        ),
      ),
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to load my ascents summary.',
      error: error,
      stackTrace: stackTrace,
      name: 'my_ascents_summary_provider',
    );
    return AsyncError(error, stackTrace);
  }
});
