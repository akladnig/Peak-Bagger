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

final peakMarkerInfoReadProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(peakMarkerInfoPreferencesLoaderProvider)();
  return prefs.getBool(peakMarkerInfoKey) ?? false;
});

/// Completes after the read is applied, or a newer user toggle is retained.
final peakMarkerInfoHydrationProvider = FutureProvider<void>((ref) {
  return ref.watch(peakMarkerInfoSettingsProvider.notifier).load();
});

class PeakMarkerInfoSettingsNotifier extends Notifier<bool> {
  bool _hasUserOverride = false;
  Future<void>? _loadFuture;

  @override
  bool build() {
    unawaited(load().catchError((Object _) {}));
    return false;
  }

  Future<void> load() => _loadFuture ??= _hydrate();

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
      final stored = await ref.read(peakMarkerInfoReadProvider.future);
      if (!ref.mounted) return;
      if (_hasUserOverride) {
        return;
      }

      if (state != stored) {
        await Future<void>.delayed(Duration.zero);
        if (!ref.mounted || _hasUserOverride) {
          return;
        }
        state = stored;
      }
    } catch (_) {
      // The UI keeps its fallback; the hydration observer retains failure.
      rethrow;
    }
  }
}
