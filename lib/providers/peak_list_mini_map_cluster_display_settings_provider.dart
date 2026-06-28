import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const peakListMiniMapClusterDisplayKey = 'show_peak_list_mini_map_clusters';

final peakListMiniMapClusterDisplayPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final peakListMiniMapClusterDisplaySettingsProvider =
    NotifierProvider<PeakListMiniMapClusterDisplaySettingsNotifier, bool>(
      PeakListMiniMapClusterDisplaySettingsNotifier.new,
    );

class PeakListMiniMapClusterDisplaySettingsNotifier extends Notifier<bool> {
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
        peakListMiniMapClusterDisplayPreferencesLoaderProvider,
      )();
      await prefs.setBool(peakListMiniMapClusterDisplayKey, value);
    } catch (_) {}
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(
        peakListMiniMapClusterDisplayPreferencesLoaderProvider,
      )();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getBool(peakListMiniMapClusterDisplayKey) ?? true;
      if (state != stored) {
        state = stored;
      }
    } catch (_) {}
  }
}
