import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

const peakCorrelationDistanceKey = 'peak_correlation_distance_meters';
const peakCorrelationDefaultDistanceMeters = PeakCorrelationConstants.defaultDistanceMeters;
const peakCorrelationDistanceOptions = PeakCorrelationConstants.distanceOptions;

final peakCorrelationSettingsProvider =
    AsyncNotifierProvider<PeakCorrelationSettingsNotifier, int>(
      PeakCorrelationSettingsNotifier.new,
    );

class PeakCorrelationSettingsNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.getInt(peakCorrelationDistanceKey));
    } catch (_) {
      return peakCorrelationDefaultDistanceMeters;
    }
  }

  Future<void> setDistanceMeters(int value) async {
    final normalized = _normalize(value);
    state = AsyncData(normalized);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(peakCorrelationDistanceKey, normalized);
    } catch (_) {}
  }

  int _normalize(int? value) {
    if (value == null || !peakCorrelationDistanceOptions.contains(value)) {
      return peakCorrelationDefaultDistanceMeters;
    }
    return value;
  }
}
