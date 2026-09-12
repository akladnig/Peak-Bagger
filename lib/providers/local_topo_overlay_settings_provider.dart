import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const terrainReliefShadingOverlayKey = 'terrainReliefShading';
const contourLinesOverlayKey = 'contourLines';

const _terrainReliefShadingEnabledPrefsKey =
    'local_topo_terrain_relief_shading_enabled_v1';
const _contourLinesEnabledPrefsKey = 'local_topo_contour_lines_enabled_v1';
const _terrainReliefShadingOpacityPrefsKey =
    'local_topo_terrain_relief_shading_opacity_v1';
const _contourLinesOpacityPrefsKey = 'local_topo_contour_lines_opacity_v1';

final localTopoOverlaySettingsPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final localTopoOverlaySettingsProvider =
    NotifierProvider<
      LocalTopoOverlaySettingsNotifier,
      LocalTopoOverlaySettings
    >(LocalTopoOverlaySettingsNotifier.new);

class LocalTopoOverlaySettings {
  const LocalTopoOverlaySettings({
    this.terrainReliefShadingEnabled = false,
    this.contourLinesEnabled = false,
    this.terrainReliefShadingOpacity = 35,
    this.contourLinesOpacity = 70,
  });

  final bool terrainReliefShadingEnabled;
  final bool contourLinesEnabled;
  final int terrainReliefShadingOpacity;
  final int contourLinesOpacity;

  bool isEnabled(String key) => switch (key) {
    terrainReliefShadingOverlayKey => terrainReliefShadingEnabled,
    contourLinesOverlayKey => contourLinesEnabled,
    _ => false,
  };

  int opacityFor(String key) => switch (key) {
    terrainReliefShadingOverlayKey => terrainReliefShadingOpacity,
    contourLinesOverlayKey => contourLinesOpacity,
    _ => 0,
  };

  LocalTopoOverlaySettings copyWith({
    bool? terrainReliefShadingEnabled,
    bool? contourLinesEnabled,
    int? terrainReliefShadingOpacity,
    int? contourLinesOpacity,
  }) => LocalTopoOverlaySettings(
    terrainReliefShadingEnabled:
        terrainReliefShadingEnabled ?? this.terrainReliefShadingEnabled,
    contourLinesEnabled: contourLinesEnabled ?? this.contourLinesEnabled,
    terrainReliefShadingOpacity:
        terrainReliefShadingOpacity ?? this.terrainReliefShadingOpacity,
    contourLinesOpacity: contourLinesOpacity ?? this.contourLinesOpacity,
  );
}

class LocalTopoOverlaySettingsNotifier
    extends Notifier<LocalTopoOverlaySettings> {
  bool _hasUserOverride = false;

  @override
  LocalTopoOverlaySettings build() {
    unawaited(_hydrate());
    return const LocalTopoOverlaySettings();
  }

  Future<void> setEnabled(String key, bool value) => _persist(
    key: key,
    value: value,
    update: (settings) => switch (key) {
      terrainReliefShadingOverlayKey => settings.copyWith(
        terrainReliefShadingEnabled: value,
      ),
      contourLinesOverlayKey => settings.copyWith(contourLinesEnabled: value),
      _ => settings,
    },
  );

  Future<void> setOpacity(String key, int value) {
    if (value < 0 || value > 100) {
      return Future.value();
    }
    return _persist(
      key: key,
      value: value,
      update: (settings) => switch (key) {
        terrainReliefShadingOverlayKey => settings.copyWith(
          terrainReliefShadingOpacity: value,
        ),
        contourLinesOverlayKey => settings.copyWith(contourLinesOpacity: value),
        _ => settings,
      },
    );
  }

  Future<void> _persist({
    required String key,
    required Object value,
    required LocalTopoOverlaySettings Function(LocalTopoOverlaySettings) update,
  }) async {
    final previous = state;
    final updated = update(previous);
    if (identical(updated, previous)) {
      return;
    }
    _hasUserOverride = true;
    state = updated;
    try {
      final prefs = await ref.read(
        localTopoOverlaySettingsPreferencesLoaderProvider,
      )();
      if (value is bool) {
        await prefs.setBool(_prefsKeyFor(key, value: value), value);
      } else {
        await prefs.setInt(_prefsKeyFor(key, value: value), value as int);
      }
    } catch (_) {
      if (ref.mounted) {
        state = previous;
      }
    }
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(
        localTopoOverlaySettingsPreferencesLoaderProvider,
      )();
      if (!ref.mounted || _hasUserOverride) {
        return;
      }
      state = LocalTopoOverlaySettings(
        terrainReliefShadingEnabled:
            prefs.getBool(_terrainReliefShadingEnabledPrefsKey) ?? false,
        contourLinesEnabled:
            prefs.getBool(_contourLinesEnabledPrefsKey) ?? false,
        terrainReliefShadingOpacity: _validOpacity(
          prefs.getInt(_terrainReliefShadingOpacityPrefsKey),
          35,
        ),
        contourLinesOpacity: _validOpacity(
          prefs.getInt(_contourLinesOpacityPrefsKey),
          70,
        ),
      );
    } catch (_) {}
  }

  static int _validOpacity(int? value, int fallback) {
    return value != null && value >= 0 && value <= 100 ? value : fallback;
  }

  static String _prefsKeyFor(String key, {required Object value}) =>
      switch (key) {
        terrainReliefShadingOverlayKey when value is bool =>
          _terrainReliefShadingEnabledPrefsKey,
        contourLinesOverlayKey when value is bool =>
          _contourLinesEnabledPrefsKey,
        terrainReliefShadingOverlayKey => _terrainReliefShadingOpacityPrefsKey,
        contourLinesOverlayKey => _contourLinesOpacityPrefsKey,
        _ => throw ArgumentError.value(key, 'key'),
      };
}
