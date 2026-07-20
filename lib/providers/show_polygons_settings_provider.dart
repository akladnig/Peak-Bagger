import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const showPolygonsKey = 'show_polygons';

final showPolygonsPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final showPolygonsSettingsProvider =
    NotifierProvider<ShowPolygonsSettingsNotifier, bool>(
      ShowPolygonsSettingsNotifier.new,
    );

class ShowPolygonsSettingsNotifier extends Notifier<bool> {
  bool _hasUserOverride = false;

  @override
  bool build() {
    unawaited(_hydrate());
    return false;
  }

  Future<void> setShowPolygons(bool value) async {
    _hasUserOverride = true;
    state = value;
    try {
      final prefs = await ref.read(showPolygonsPreferencesLoaderProvider)();
      await prefs.setBool(showPolygonsKey, value);
    } catch (_) {}
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(showPolygonsPreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getBool(showPolygonsKey) ?? false;
      if (state != stored) {
        await Future<void>.delayed(Duration.zero);
        if (!ref.mounted || _hasUserOverride) {
          return;
        }
        state = stored;
      }
    } catch (_) {}
  }
}
