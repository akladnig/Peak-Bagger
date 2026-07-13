import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const openRouteServiceApiKeyPrefsKey = 'open_route_service_api_key';
const defaultOpenRouteServiceApiKey =
    'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjdjOTZhNmU1MjUzNTRhYTdiM2YxZGZkMzc1NGQ3ZDk1IiwiaCI6Im11cm11cjY0In0=';

final openRouteServiceApiKeyPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final openRouteServiceApiKeyProvider =
    NotifierProvider<OpenRouteServiceApiKeyNotifier, String>(
      OpenRouteServiceApiKeyNotifier.new,
    );

class OpenRouteServiceApiKeyNotifier extends Notifier<String> {
  bool _hasUserOverride = false;

  @override
  String build() {
    unawaited(_hydrate());
    return defaultOpenRouteServiceApiKey;
  }

  Future<void> setApiKey(String value) async {
    _hasUserOverride = true;
    state = value;
    try {
      final prefs = await ref.read(
        openRouteServiceApiKeyPreferencesLoaderProvider,
      )();
      await prefs.setString(openRouteServiceApiKeyPrefsKey, value);
    } catch (_) {}
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(
        openRouteServiceApiKeyPreferencesLoaderProvider,
      )();
      if (_hasUserOverride) {
        return;
      }

      final stored =
          prefs.getString(openRouteServiceApiKeyPrefsKey) ??
          defaultOpenRouteServiceApiKey;
      if (state != stored) {
        state = stored;
      }
    } catch (_) {}
  }
}
