import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const peakMarkerInfoKey = 'show_peak_info';

final peakMarkerInfoPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final peakMarkerInfoSettingsProvider =
    NotifierProvider<PeakMarkerInfoSettingsNotifier, bool>(
      PeakMarkerInfoSettingsNotifier.new,
    );

class PeakMarkerInfoSettingsNotifier extends Notifier<bool> {
  bool _hasUserOverride = false;

  @override
  bool build() {
    unawaited(_hydrate());
    return false;
  }

  Future<void> setShowPeakInfo(bool value) async {
    _hasUserOverride = true;
    state = value;
    try {
      final prefs = await ref.read(peakMarkerInfoPreferencesLoaderProvider)();
      await prefs.setBool(peakMarkerInfoKey, value);
    } catch (_) {}
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(peakMarkerInfoPreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getBool(peakMarkerInfoKey) ?? false;
      if (state != stored) {
        state = stored;
      }
    } catch (_) {}
  }
}
