import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const peakMapClusterDisplayKey = 'show_map_peak_clusters';

final peakMapClusterDisplayPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final peakMapClusterDisplaySettingsProvider =
    NotifierProvider<PeakMapClusterDisplaySettingsNotifier, bool>(
      PeakMapClusterDisplaySettingsNotifier.new,
    );

class PeakMapClusterDisplaySettingsNotifier extends Notifier<bool> {
  bool _hasUserOverride = false;

  @override
  bool build() {
    unawaited(_hydrate());
    return true;
  }

  Future<void> setShowPeakClusters(bool value) async {
    _hasUserOverride = true;
    state = value;
    try {
      final prefs = await ref.read(
        peakMapClusterDisplayPreferencesLoaderProvider,
      )();
      await prefs.setBool(peakMapClusterDisplayKey, value);
    } catch (_) {}
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(
        peakMapClusterDisplayPreferencesLoaderProvider,
      )();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getBool(peakMapClusterDisplayKey) ?? true;
      if (state != stored) {
        state = stored;
      }
    } catch (_) {}
  }
}
