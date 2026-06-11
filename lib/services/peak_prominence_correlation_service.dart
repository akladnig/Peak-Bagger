import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/peak_prominence_csv_service.dart';

class PeakProminenceCorrelationResult {
  const PeakProminenceCorrelationResult({
    required this.row,
    required this.peak,
    required this.action,
    required this.detail,
    required this.skippedDuplicatePeaks,
  });

  final PeakProminenceCsvRow row;
  final Peak? peak;
  final String action;
  final String detail;
  final List<Peak> skippedDuplicatePeaks;

  bool get isMatched => peak != null;
}

class PeakProminenceCorrelationService {
  const PeakProminenceCorrelationService({
    this.spatialThresholdMeters = 150,
    this.elevationThresholdMeters = 100,
  });

  final int spatialThresholdMeters;
  final int elevationThresholdMeters;

  PeakProminenceCorrelationResult correlate({
    required PeakProminenceCsvRow row,
    required List<Peak> peaks,
  }) {
    final candidates = <Peak>[
      for (final peak in peaks)
        if (_matches(row: row, peak: peak)) peak,
    ]..sort((left, right) => left.id.compareTo(right.id));

    if (candidates.isEmpty) {
      return PeakProminenceCorrelationResult(
        row: row,
        peak: null,
        action: 'unresolved',
        detail:
            'no peak found within ${spatialThresholdMeters}m/${elevationThresholdMeters}m window',
        skippedDuplicatePeaks: const [],
      );
    }

    final selectedPeak = candidates.first;
    final skippedDuplicatePeaks = candidates.skip(1).toList(growable: false);
    final action = skippedDuplicatePeaks.isEmpty
        ? 'spatial-match'
        : 'closest-location-tie-break';
    final detail = skippedDuplicatePeaks.isEmpty
        ? 'matched within ${spatialThresholdMeters}m/${elevationThresholdMeters}m window'
        : 'selected Peak ${selectedPeak.id} after sorting ${candidates.length} qualifying candidates by id';

    return PeakProminenceCorrelationResult(
      row: row,
      peak: selectedPeak,
      action: action,
      detail: detail,
      skippedDuplicatePeaks: skippedDuplicatePeaks,
    );
  }

  bool _matches({required PeakProminenceCsvRow row, required Peak peak}) {
    final distanceMeters = haversineDistance(
      row.latitude,
      row.longitude,
      peak.latitude,
      peak.longitude,
    );
    if (distanceMeters > spatialThresholdMeters) {
      return false;
    }

    final peakElevation = peak.elevation;
    if (peakElevation == null) {
      return true;
    }

    final elevationDifference = (row.elevation - peakElevation).abs();
    return elevationDifference <= elevationThresholdMeters;
  }
}
