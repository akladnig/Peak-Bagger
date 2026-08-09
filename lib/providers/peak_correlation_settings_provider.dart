import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

const peakCorrelationDistanceKey = 'peak_correlation_distance_meters';
const peakCorrelationElevationKey = 'peak_correlation_elevation_meters';
const peakCorrelationDefaultDistanceMeters =
    PeakCorrelationConstants.defaultDistanceMeters;
const peakCorrelationDistanceOptions = PeakCorrelationConstants.distanceOptions;
const peakCorrelationDefaultElevationMeters =
    PeakCorrelationConstants.defaultElevationMeters;
const peakCorrelationElevationOptions =
    PeakCorrelationConstants.elevationOptions;

class PeakCorrelationSettings {
  const PeakCorrelationSettings({
    required this.distanceMeters,
    required this.elevationMeters,
  });

  static const defaults = PeakCorrelationSettings(
    distanceMeters: peakCorrelationDefaultDistanceMeters,
    elevationMeters: peakCorrelationDefaultElevationMeters,
  );

  final int distanceMeters;
  final int elevationMeters;

  PeakCorrelationSettings copyWith({
    int? distanceMeters,
    int? elevationMeters,
  }) {
    return PeakCorrelationSettings(
      distanceMeters: _normalizeDistance(distanceMeters ?? this.distanceMeters),
      elevationMeters: _normalizeElevation(
        elevationMeters ?? this.elevationMeters,
      ),
    );
  }

  static PeakCorrelationSettings fromPreferences(SharedPreferences prefs) {
    return PeakCorrelationSettings(
      distanceMeters: _normalizeDistance(
        prefs.getInt(peakCorrelationDistanceKey),
      ),
      elevationMeters: _normalizeElevation(
        prefs.getInt(peakCorrelationElevationKey),
      ),
    );
  }
}

final peakCorrelationSettingsProvider =
    AsyncNotifierProvider<
      PeakCorrelationSettingsNotifier,
      PeakCorrelationSettings
    >(PeakCorrelationSettingsNotifier.new);

class PeakCorrelationSettingsNotifier
    extends AsyncNotifier<PeakCorrelationSettings> {
  @override
  Future<PeakCorrelationSettings> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PeakCorrelationSettings.fromPreferences(prefs);
    } catch (_) {
      return PeakCorrelationSettings.defaults;
    }
  }

  Future<void> setDistanceMeters(int value) async {
    final normalized = _normalizeDistance(value);
    state = AsyncData(
      (state.asData?.value ?? PeakCorrelationSettings.defaults).copyWith(
        distanceMeters: normalized,
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(peakCorrelationDistanceKey, normalized);
    } catch (_) {}
  }

  Future<void> setElevationMeters(int value) async {
    final normalized = _normalizeElevation(value);
    state = AsyncData(
      (state.asData?.value ?? PeakCorrelationSettings.defaults).copyWith(
        elevationMeters: normalized,
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(peakCorrelationElevationKey, normalized);
    } catch (_) {}
  }
}

int _normalizeDistance(int? value) {
  if (value == null || !peakCorrelationDistanceOptions.contains(value)) {
    return peakCorrelationDefaultDistanceMeters;
  }
  return value;
}

int _normalizeElevation(int? value) {
  if (value == null || !peakCorrelationElevationOptions.contains(value)) {
    return peakCorrelationDefaultElevationMeters;
  }
  return value;
}
