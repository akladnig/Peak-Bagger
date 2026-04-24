import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hampelWindowKey = 'gpx_filter_hampel_window';
const _outlierFilterKey = 'gpx_filter_outlier_filter';
const _elevationSmootherKey = 'gpx_filter_elevation_smoother';
const _elevationWindowKey = 'gpx_filter_elevation_window';
const _positionSmootherKey = 'gpx_filter_position_smoother';
const _positionWindowKey = 'gpx_filter_position_window';

enum GpxTrackOutlierFilter { none, hampel }

enum GpxTrackElevationSmoother { none, median, savitzkyGolay }

enum GpxTrackPositionSmoother { none, movingAverage, kalman }

class GpxFilterConfig {
  const GpxFilterConfig({
    required this.hampelWindow,
    required this.outlierFilter,
    required this.elevationSmoother,
    required this.elevationWindow,
    required this.positionSmoother,
    required this.positionWindow,
  });

  static const defaults = GpxFilterConfig(
    hampelWindow: 7,
    outlierFilter: GpxTrackOutlierFilter.hampel,
    elevationSmoother: GpxTrackElevationSmoother.median,
    elevationWindow: 5,
    positionSmoother: GpxTrackPositionSmoother.movingAverage,
    positionWindow: 5,
  );

  final int hampelWindow;
  final GpxTrackOutlierFilter outlierFilter;
  final GpxTrackElevationSmoother elevationSmoother;
  final int elevationWindow;
  final GpxTrackPositionSmoother positionSmoother;
  final int positionWindow;

  GpxFilterConfig copyWith({
    int? hampelWindow,
    GpxTrackOutlierFilter? outlierFilter,
    GpxTrackElevationSmoother? elevationSmoother,
    int? elevationWindow,
    GpxTrackPositionSmoother? positionSmoother,
    int? positionWindow,
  }) {
    return GpxFilterConfig(
      hampelWindow: hampelWindow ?? this.hampelWindow,
      outlierFilter: outlierFilter ?? this.outlierFilter,
      elevationSmoother: elevationSmoother ?? this.elevationSmoother,
      elevationWindow: elevationWindow ?? this.elevationWindow,
      positionSmoother: positionSmoother ?? this.positionSmoother,
      positionWindow: positionWindow ?? this.positionWindow,
    ).normalized();
  }

  GpxFilterConfig normalized() {
    return GpxFilterConfig(
      hampelWindow: _normalizeOdd(hampelWindow, min: 5, max: 11),
      outlierFilter: outlierFilter,
      elevationSmoother: elevationSmoother,
      elevationWindow: _normalizeOdd(elevationWindow, min: 5, max: 9),
      positionSmoother: positionSmoother,
      positionWindow: _normalizeOdd(positionWindow, min: 3, max: 7),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setInt(_hampelWindowKey, hampelWindow);
    await prefs.setString(_outlierFilterKey, outlierFilter.name);
    await prefs.setString(_elevationSmootherKey, elevationSmoother.name);
    await prefs.setInt(_elevationWindowKey, elevationWindow);
    await prefs.setString(_positionSmootherKey, positionSmoother.name);
    await prefs.setInt(_positionWindowKey, positionWindow);
  }

  static GpxFilterConfig fromPreferences(SharedPreferences prefs) {
    return GpxFilterConfig(
      hampelWindow: prefs.getInt(_hampelWindowKey) ?? defaults.hampelWindow,
      outlierFilter: _parseOutlierFilter(prefs.getString(_outlierFilterKey)),
      elevationSmoother: _parseElevationSmoother(
        prefs.getString(_elevationSmootherKey),
      ),
      elevationWindow:
          prefs.getInt(_elevationWindowKey) ?? defaults.elevationWindow,
      positionSmoother: _parsePositionSmoother(
        prefs.getString(_positionSmootherKey),
      ),
      positionWindow:
          prefs.getInt(_positionWindowKey) ?? defaults.positionWindow,
    ).normalized();
  }

  static GpxTrackOutlierFilter _parseOutlierFilter(String? value) {
    return switch (value) {
      'hampel' => GpxTrackOutlierFilter.hampel,
      'none' => GpxTrackOutlierFilter.none,
      _ => defaults.outlierFilter,
    };
  }

  static GpxTrackElevationSmoother _parseElevationSmoother(String? value) {
    return switch (value) {
      'none' => GpxTrackElevationSmoother.none,
      'savitzkyGolay' => GpxTrackElevationSmoother.savitzkyGolay,
      'median' => GpxTrackElevationSmoother.median,
      _ => defaults.elevationSmoother,
    };
  }

  static GpxTrackPositionSmoother _parsePositionSmoother(String? value) {
    return switch (value) {
      'none' => GpxTrackPositionSmoother.none,
      'movingAverage' => GpxTrackPositionSmoother.movingAverage,
      'kalman' => GpxTrackPositionSmoother.kalman,
      _ => defaults.positionSmoother,
    };
  }
}

final gpxFilterSettingsProvider =
    AsyncNotifierProvider<GpxFilterSettingsNotifier, GpxFilterConfig>(
      GpxFilterSettingsNotifier.new,
    );

class GpxFilterSettingsNotifier extends AsyncNotifier<GpxFilterConfig> {
  @override
  Future<GpxFilterConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    return GpxFilterConfig.fromPreferences(prefs);
  }

  Future<void> updateConfig(GpxFilterConfig config) async {
    final next = config.normalized();
    state = AsyncData(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await next.save(prefs);
    } catch (_) {}
  }

  Future<void> setHampelWindow(int value) async {
    await _update((config) => config.copyWith(hampelWindow: value));
  }

  Future<void> setOutlierFilter(GpxTrackOutlierFilter value) async {
    await _update((config) => config.copyWith(outlierFilter: value));
  }

  Future<void> setElevationSmoother(GpxTrackElevationSmoother value) async {
    await _update((config) => config.copyWith(elevationSmoother: value));
  }

  Future<void> setElevationWindow(int value) async {
    await _update((config) => config.copyWith(elevationWindow: value));
  }

  Future<void> setPositionSmoother(GpxTrackPositionSmoother value) async {
    await _update((config) => config.copyWith(positionSmoother: value));
  }

  Future<void> setPositionWindow(int value) async {
    await _update((config) => config.copyWith(positionWindow: value));
  }

  Future<void> _update(
    GpxFilterConfig Function(GpxFilterConfig) transform,
  ) async {
    final current = state.maybeWhen(
      data: (value) => value,
      orElse: () => GpxFilterConfig.defaults,
    );
    await updateConfig(transform(current));
  }
}

int _normalizeOdd(int value, {required int min, required int max}) {
  final clamped = value.clamp(min, max).toInt();
  if (clamped.isOdd) {
    return clamped;
  }
  final next = clamped + 1;
  if (next <= max) {
    return next;
  }
  return clamped - 1;
}
