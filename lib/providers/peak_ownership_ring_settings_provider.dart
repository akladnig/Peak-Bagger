import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const peakOwnershipRingKey = 'show_peak_ownership_rings';

final peakOwnershipRingPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final peakOwnershipRingSettingsProvider =
    NotifierProvider<PeakOwnershipRingSettingsNotifier, bool>(
      PeakOwnershipRingSettingsNotifier.new,
    );

class PeakOwnershipRingSettingsNotifier extends Notifier<bool> {
  bool _hasUserOverride = false;

  @override
  bool build() {
    unawaited(_hydrate());
    return false;
  }

  Future<void> setShowPeakOwnershipRings(bool value) async {
    _hasUserOverride = true;
    state = value;
    try {
      final prefs = await ref.read(peakOwnershipRingPreferencesLoaderProvider)();
      await prefs.setBool(peakOwnershipRingKey, value);
    } catch (_) {}
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(peakOwnershipRingPreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getBool(peakOwnershipRingKey) ?? false;
      if (state != stored) {
        state = stored;
      }
    } catch (_) {}
  }
}
