import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/my_ascents_summary_service.dart';
import 'peak_list_provider.dart';
import 'peak_provider.dart';

final myAscentsSummaryProvider = Provider<MyAscentsDataset>((ref) {
  ref.watch(peakRevisionProvider);
  ref.watch(peaksBaggedRevisionProvider);

  try {
    final peakRepository = ref.watch(peakRepositoryProvider);
    final peaksBaggedRepository = ref.watch(peaksBaggedRepositoryProvider);
    return MyAscentsDataset(
      baggedRows: peaksBaggedRepository.getAll(),
      peaksByOsmId: {
        for (final peak in peakRepository.getAllPeaks()) peak.osmId: peak,
      },
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to load my ascents summary.',
      error: error,
      stackTrace: stackTrace,
      name: 'my_ascents_summary_provider',
    );
    return const MyAscentsDataset.empty();
  }
});
