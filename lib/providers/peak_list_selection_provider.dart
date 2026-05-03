import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';

final filteredPeaksProvider = Provider<List<Peak>>((ref) {
  final mapState = ref.watch(mapProvider);
  return switch (mapState.peakListSelectionMode) {
    PeakListSelectionMode.none => const [],
    PeakListSelectionMode.allPeaks || PeakListSelectionMode.specificList =>
      mapState.peaks,
  };
});
