import 'dart:async';
import 'dart:developer' as developer;

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
  bool _saving = false;
  int _generation = 0;

  bool get isSaving => _saving;

  @override
  String build() {
    final generation = ++_generation;
    _saving = false;
    _hasUserOverride = false;
    unawaited(_hydrate(generation));
    return defaultOpenRouteServiceApiKey;
  }

  Future<bool> setApiKey(String value) async {
    if (_saving) return false;
    _saving = true;
    final generation = _generation;
    _hasUserOverride = true;
    try {
      final prefs = await ref.read(
        openRouteServiceApiKeyPreferencesLoaderProvider,
      )();
      if (!ref.mounted || generation != _generation) return false;
      if (!await prefs.setString(
        openRouteServiceApiKeyPrefsKey,
        value.trim(),
      )) {
        throw StateError('Preference write was not accepted');
      }
      if (!ref.mounted || generation != _generation) return false;
      state = value.trim();
      return true;
    } catch (error, stackTrace) {
      // Preference exceptions can include their arguments. Never log the payload.
      developer.log(
        'API key persistence failed (${error.runtimeType}).',
        name: 'OpenRouteServiceApiKey',
        stackTrace: stackTrace,
      );
      throw const OpenRouteServiceApiKeySaveException();
    } finally {
      if (generation == _generation) _saving = false;
    }
  }

  Future<void> _hydrate(int generation) async {
    try {
      final prefs = await ref.read(
        openRouteServiceApiKeyPreferencesLoaderProvider,
      )();
      if (!ref.mounted || generation != _generation || _hasUserOverride) {
        return;
      }

      final stored =
          prefs.getString(openRouteServiceApiKeyPrefsKey) ??
          defaultOpenRouteServiceApiKey;
      if (state != stored) {
        await Future<void>.delayed(Duration.zero);
        if (!ref.mounted || generation != _generation || _hasUserOverride) {
          return;
        }
        state = stored;
      }
    } catch (error, stackTrace) {
      developer.log(
        'API key preference loading failed (${error.runtimeType}).',
        name: 'OpenRouteServiceApiKey',
        stackTrace: stackTrace,
      );
    }
  }
}

class OpenRouteServiceApiKeySaveException implements Exception {
  const OpenRouteServiceApiKeySaveException();

  @override
  String toString() => 'Could not save the API key. Try Save again, or Cancel.';
}
