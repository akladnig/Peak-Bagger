import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

const localTopoValidationStatusPrefsKey = 'local_topo_validation_status_v1';
const defaultLocalTopoBaseUrlText = 'http://127.0.0.1:8090';

final localTopoSettingsPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final localTopoSettingsHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final localTopoSettingsProvider =
    NotifierProvider<LocalTopoSettingsNotifier, LocalTopoSettingsState>(
      LocalTopoSettingsNotifier.new,
    );

enum LocalTopoValidationStatus {
  empty,
  invalidUrlSyntax,
  validating,
  liveValidated,
  restoredSnapshot,
  validationFailed,
}

extension on LocalTopoValidationStatus {
  String get label {
    return switch (this) {
      LocalTopoValidationStatus.empty => 'Empty',
      LocalTopoValidationStatus.invalidUrlSyntax => 'Invalid URL syntax',
      LocalTopoValidationStatus.validating => 'Validating',
      LocalTopoValidationStatus.liveValidated => 'Live validated',
      LocalTopoValidationStatus.restoredSnapshot => 'Restored snapshot',
      LocalTopoValidationStatus.validationFailed => 'Validation failed',
    };
  }

  String get storageValue {
    return switch (this) {
      LocalTopoValidationStatus.empty => 'empty',
      LocalTopoValidationStatus.invalidUrlSyntax => 'invalid-url-syntax',
      LocalTopoValidationStatus.validating => 'validating',
      LocalTopoValidationStatus.liveValidated => 'live-validated',
      LocalTopoValidationStatus.restoredSnapshot => 'restored-snapshot',
      LocalTopoValidationStatus.validationFailed => 'validation-failed',
    };
  }
}

LocalTopoValidationStatus? _parseLocalTopoValidationStatus(String? value) {
  return switch (value) {
    'empty' => LocalTopoValidationStatus.empty,
    'invalid-url-syntax' => LocalTopoValidationStatus.invalidUrlSyntax,
    'validating' => LocalTopoValidationStatus.validating,
    'live-validated' => LocalTopoValidationStatus.liveValidated,
    'restored-snapshot' => LocalTopoValidationStatus.restoredSnapshot,
    'validation-failed' => LocalTopoValidationStatus.validationFailed,
    _ => null,
  };
}

class LocalTopoSettingsState {
  const LocalTopoSettingsState({
    this.savedBaseUrlText = '',
    this.validationStatus = LocalTopoValidationStatus.empty,
    this.activeSnapshot,
    this.detailMessage,
  });

  final String savedBaseUrlText;
  final LocalTopoValidationStatus validationStatus;
  final LocalTopoCapabilitySnapshot? activeSnapshot;
  final String? detailMessage;

  String get validationStatusLabel => validationStatus.label;
  bool get isValidating =>
      validationStatus == LocalTopoValidationStatus.validating;
  bool get hasSavedBaseUrl => savedBaseUrlText.trim().isNotEmpty;
  bool get canRetry => !isValidating && hasSavedBaseUrl;
  bool get canClear => hasSavedBaseUrl || activeSnapshot != null;

  LocalTopoSettingsState copyWith({
    String? savedBaseUrlText,
    LocalTopoValidationStatus? validationStatus,
    LocalTopoCapabilitySnapshot? activeSnapshot,
    bool clearActiveSnapshot = false,
    String? detailMessage,
    bool clearDetailMessage = false,
  }) {
    return LocalTopoSettingsState(
      savedBaseUrlText: savedBaseUrlText ?? this.savedBaseUrlText,
      validationStatus: validationStatus ?? this.validationStatus,
      activeSnapshot: clearActiveSnapshot
          ? null
          : (activeSnapshot ?? this.activeSnapshot),
      detailMessage: clearDetailMessage
          ? null
          : (detailMessage ?? this.detailMessage),
    );
  }
}

class LocalTopoSettingsNotifier extends Notifier<LocalTopoSettingsState> {
  static const _validationTimeout = Duration(seconds: 15);

  int _validationRequestSerial = 0;
  bool _hasUserOverride = false;

  @override
  LocalTopoSettingsState build() {
    registerLocalTopoRegionKeyValidator(
      (regionKey) => regionManifestCatalog.regionByKey(regionKey) != null,
    );
    unawaited(_hydrate());
    return const LocalTopoSettingsState();
  }

  Future<void> saveAndValidate(String rawValue) async {
    _hasUserOverride = true;
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      await clearSetting();
      return;
    }

    final baseUrl = parseLocalTileServerBaseUrl(trimmed);
    if (baseUrl == null) {
      state = state.copyWith(
        validationStatus: LocalTopoValidationStatus.invalidUrlSyntax,
        detailMessage: 'Enter a valid http or https base URL.',
      );
      return;
    }

    final normalizedBaseUrlText = baseUrl.toString();
    final prefsLoader = ref.read(localTopoSettingsPreferencesLoaderProvider);
    final previousSavedBaseUrlText =
        localTopoRuntime.savedBaseUrl?.toString() ?? '';
    final hadSnapshot = localTopoRuntime.hasCapabilitySnapshot;
    final isSameSavedBaseUrl =
        previousSavedBaseUrlText == normalizedBaseUrlText;
    final previousSnapshot = localTopoRuntime.capabilitySnapshot;
    final previousBoundsSupport = _snapshotSupportsCurrentVisibleBounds(
      previousSnapshot,
    );
    final retainedSnapshot = isSameSavedBaseUrl
        ? localTopoRuntime.capabilitySnapshot
        : null;

    if (!isSameSavedBaseUrl) {
      await localTopoRuntime.saveBaseUrl(baseUrl, loadPreferences: prefsLoader);
      if (hadSnapshot) {
        _fallbackToTracestrackIfLocalTopoSelected();
      }
    }

    final requestSerial = ++_validationRequestSerial;
    await _persistValidationStatus(LocalTopoValidationStatus.validating);
    state = LocalTopoSettingsState(
      savedBaseUrlText: normalizedBaseUrlText,
      validationStatus: LocalTopoValidationStatus.validating,
      activeSnapshot: retainedSnapshot,
      detailMessage: 'Validating live capabilities from /capabilities.',
    );

    try {
      final snapshot = await _fetchValidatedSnapshot(baseUrl);
      if (!_isLatestRequest(requestSerial)) {
        return;
      }

      await localTopoRuntime.saveValidatedSnapshot(
        snapshot,
        loadPreferences: prefsLoader,
      );
      await _persistValidationStatus(LocalTopoValidationStatus.liveValidated);

      state = LocalTopoSettingsState(
        savedBaseUrlText: snapshot.baseUrl.toString(),
        validationStatus: LocalTopoValidationStatus.liveValidated,
        activeSnapshot: snapshot,
        detailMessage: 'Live capabilities validated successfully.',
      );

      if (ref.read(mapProvider).basemap == Basemap.localTopo &&
          previousBoundsSupport &&
          !_snapshotSupportsCurrentVisibleBounds(snapshot)) {
        _fallbackToTracestrackIfLocalTopoSelected();
      }
    } catch (error) {
      if (!_isLatestRequest(requestSerial)) {
        return;
      }

      await localTopoRuntime.clearCapabilitySnapshot(
        loadPreferences: prefsLoader,
      );
      await _persistValidationStatus(
        LocalTopoValidationStatus.validationFailed,
      );
      _fallbackToTracestrackIfLocalTopoSelected();

      state = LocalTopoSettingsState(
        savedBaseUrlText: normalizedBaseUrlText,
        validationStatus: LocalTopoValidationStatus.validationFailed,
        detailMessage: '$error',
      );
    }
  }

  Future<void> retryValidation() async {
    if (!state.canRetry) {
      return;
    }

    await saveAndValidate(state.savedBaseUrlText);
  }

  Future<void> clearSetting() async {
    _hasUserOverride = true;
    _validationRequestSerial += 1;

    await localTopoRuntime.clear(
      loadPreferences: ref.read(localTopoSettingsPreferencesLoaderProvider),
    );
    await _clearPersistedValidationStatus();
    _fallbackToTracestrackIfLocalTopoSelected();

    state = const LocalTopoSettingsState(
      validationStatus: LocalTopoValidationStatus.empty,
      detailMessage: 'No saved local tile server base URL.',
    );
  }

  Future<void> _hydrate() async {
    final prefsLoader = ref.read(localTopoSettingsPreferencesLoaderProvider);
    final prefs = await prefsLoader();
    final savedBaseUrlText =
        prefs.getString(localTileServerBaseUrlPrefsKey) ?? '';
    final persistedStatus = _parseLocalTopoValidationStatus(
      prefs.getString(localTopoValidationStatusPrefsKey),
    );

    await localTopoRuntime.restore(loadPreferences: prefsLoader);
    if (!ref.mounted || _hasUserOverride) {
      return;
    }

    final snapshot = localTopoRuntime.capabilitySnapshot;
    if (snapshot != null) {
      state = LocalTopoSettingsState(
        savedBaseUrlText: snapshot.baseUrl.toString(),
        validationStatus: LocalTopoValidationStatus.restoredSnapshot,
        activeSnapshot: snapshot,
        detailMessage:
            'Using the last successful capability snapshot without probing the server.',
      );
      return;
    }

    if (savedBaseUrlText.trim().isEmpty) {
      state = const LocalTopoSettingsState(
        validationStatus: LocalTopoValidationStatus.empty,
        detailMessage: 'No saved local tile server base URL.',
      );
      return;
    }

    final parsedBaseUrl = parseLocalTileServerBaseUrl(savedBaseUrlText);
    if (parsedBaseUrl == null) {
      state = LocalTopoSettingsState(
        savedBaseUrlText: savedBaseUrlText,
        validationStatus: LocalTopoValidationStatus.invalidUrlSyntax,
        detailMessage: 'The saved URL is not a valid http or https base URL.',
      );
      return;
    }

    final validationStatus = switch (persistedStatus) {
      LocalTopoValidationStatus.liveValidated ||
      LocalTopoValidationStatus.restoredSnapshot ||
      LocalTopoValidationStatus.validating ||
      null => LocalTopoValidationStatus.validationFailed,
      final value => value,
    };

    state = LocalTopoSettingsState(
      savedBaseUrlText: parsedBaseUrl.toString(),
      validationStatus: validationStatus,
      detailMessage:
          validationStatus == LocalTopoValidationStatus.validationFailed
          ? 'The saved URL is not currently backed by a successful validation snapshot.'
          : 'Enter a valid http or https base URL.',
    );
  }

  Future<LocalTopoCapabilitySnapshot> _fetchValidatedSnapshot(
    Uri baseUrl,
  ) async {
    final client = ref.read(localTopoSettingsHttpClientProvider);
    final response = await client
        .get(baseUrl.resolve('/capabilities'))
        .timeout(_validationTimeout);

    if (response.statusCode != 200) {
      throw LocalTopoValidationException(
        'Capability request failed (${response.statusCode}).',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const LocalTopoValidationException(
        'Capability response was not valid JSON.',
      );
    }

    try {
      return LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
        baseUrl: baseUrl,
        decoded: decoded,
      );
    } on FormatException catch (error) {
      throw LocalTopoValidationException(error.message);
    }
  }

  Future<void> _persistValidationStatus(
    LocalTopoValidationStatus validationStatus,
  ) async {
    final prefs = await ref.read(localTopoSettingsPreferencesLoaderProvider)();
    await prefs.setString(
      localTopoValidationStatusPrefsKey,
      validationStatus.storageValue,
    );
  }

  Future<void> _clearPersistedValidationStatus() async {
    final prefs = await ref.read(localTopoSettingsPreferencesLoaderProvider)();
    await prefs.remove(localTopoValidationStatusPrefsKey);
  }

  void _fallbackToTracestrackIfLocalTopoSelected() {
    if (ref.read(mapProvider).basemap == Basemap.localTopo) {
      ref.read(mapProvider.notifier).setBasemap(Basemap.tracestrack);
    }
  }

  bool _isLatestRequest(int requestSerial) {
    return ref.mounted && requestSerial == _validationRequestSerial;
  }

  bool _snapshotSupportsCurrentVisibleBounds(
    LocalTopoCapabilitySnapshot? snapshot,
  ) {
    return isLocalTopoAvailableForBounds(
      ref.read(mapProvider).visibleBounds,
      snapshot: snapshot,
    );
  }
}

class LocalTopoValidationException implements Exception {
  const LocalTopoValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
