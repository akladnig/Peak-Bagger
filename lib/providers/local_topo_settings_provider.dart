import 'dart:async';
import 'dart:developer' as developer;
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/local_topo_overlay_outage_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

const localTopoValidationStatusPrefsKey = 'local_topo_validation_status_v1';
const defaultLocalTopoBaseUrlText = 'http://127.0.0.1:8090';

final localTopoSettingsPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final localTopoSettingsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
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
    this.isPending = false,
    this.needsClearRetry = false,
    this.storageConfirmed = true,
  });

  final String savedBaseUrlText;
  final LocalTopoValidationStatus validationStatus;
  final LocalTopoCapabilitySnapshot? activeSnapshot;
  final String? detailMessage;
  final bool isPending;
  final bool needsClearRetry;
  final bool storageConfirmed;

  String get validationStatusLabel => validationStatus.label;
  bool get isValidating =>
      isPending || validationStatus == LocalTopoValidationStatus.validating;
  bool get hasSavedBaseUrl => savedBaseUrlText.trim().isNotEmpty;
  bool get canRetry => !isValidating && storageConfirmed && hasSavedBaseUrl;
  bool get canClear =>
      !isValidating &&
      (needsClearRetry ||
          !storageConfirmed ||
          hasSavedBaseUrl ||
          activeSnapshot != null);

  LocalTopoSettingsState copyWith({
    String? savedBaseUrlText,
    LocalTopoValidationStatus? validationStatus,
    LocalTopoCapabilitySnapshot? activeSnapshot,
    bool clearActiveSnapshot = false,
    String? detailMessage,
    bool clearDetailMessage = false,
    bool? isPending,
    bool? needsClearRetry,
    bool? storageConfirmed,
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
      isPending: isPending ?? this.isPending,
      needsClearRetry: needsClearRetry ?? this.needsClearRetry,
      storageConfirmed: storageConfirmed ?? this.storageConfirmed,
    );
  }
}

class LocalTopoSettingsNotifier extends Notifier<LocalTopoSettingsState> {
  static const _validationTimeout = Duration(seconds: 15);

  int _validationRequestSerial = 0;
  bool _hasUserOverride = false;
  bool _attemptPending = false;

  @override
  LocalTopoSettingsState build() {
    final catalog = ref.watch(mappingCatalogProvider);
    registerLocalTopoRegionKeyValidator(
      (regionKey) => catalog.regionByKey(regionKey) != null,
    );
    final serial = ++_validationRequestSerial;
    _attemptPending = false;
    _hasUserOverride = false;
    unawaited(_hydrate(serial));
    return const LocalTopoSettingsState();
  }

  Future<void> saveAndValidate(String rawValue) async {
    if (_attemptPending) return;
    if (rawValue.trim().isEmpty) {
      await clearSetting();
      return;
    }
    _hasUserOverride = true;
    final trimmed = rawValue.trim();
    final baseUrl = parseLocalTileServerBaseUrl(trimmed);
    if (baseUrl == null) {
      state = state.copyWith(
        validationStatus: LocalTopoValidationStatus.invalidUrlSyntax,
        detailMessage: 'Enter a valid http or https base URL.',
      );
      return;
    }

    final previous = state;
    final previousBoundsSupport = _snapshotSupportsCurrentVisibleBounds(
      previous.activeSnapshot,
    );
    final loader = ref.read(localTopoSettingsPreferencesLoaderProvider);
    final requestSerial = ++_validationRequestSerial;
    _attemptPending = true;
    state = state.copyWith(isPending: true, clearDetailMessage: true);
    SharedPreferences? prefs;
    var validationStarted = false;
    try {
      prefs = await loader();
      if (!_isLatestRequest(requestSerial)) return;
      await localTopoRuntime.saveBaseUrl(
        baseUrl,
        loadPreferences: () async => prefs!,
        isCurrent: () => _isLatestRequest(requestSerial),
      );
      if (!_isLatestRequest(requestSerial)) return;
      validationStarted = true;
      if (previous.savedBaseUrlText != baseUrl.toString()) {
        _fallbackToTracestrackIfLocalTopoSelected();
      }
      await _persistValidationStatus(
        prefs,
        LocalTopoValidationStatus.validating,
      );
      if (!_isLatestRequest(requestSerial)) return;
      state = LocalTopoSettingsState(
        savedBaseUrlText: baseUrl.toString(),
        validationStatus: LocalTopoValidationStatus.validating,
        isPending: true,
        activeSnapshot: localTopoRuntime.capabilitySnapshot,
        detailMessage: 'Validating live capabilities from /capabilities.',
      );
      LocalTopoCapabilitySnapshot snapshot;
      try {
        snapshot = await _fetchValidatedSnapshot(baseUrl);
      } catch (error, stackTrace) {
        if (!_isLatestRequest(requestSerial)) return;
        _logFailure('capability validation', error, stackTrace);
        // Disable immediately, even if the following cleanup cannot persist.
        localTopoRuntime.deactivateSnapshot();
        _fallbackToTracestrackIfLocalTopoSelected();
        await localTopoRuntime.clearCapabilitySnapshot(
          loadPreferences: () async => prefs!,
          isCurrent: () => _isLatestRequest(requestSerial),
        );
        if (!_isLatestRequest(requestSerial)) return;
        await _persistValidationStatus(
          prefs,
          LocalTopoValidationStatus.validationFailed,
        );
        if (!_isLatestRequest(requestSerial)) return;
        state = LocalTopoSettingsState(
          savedBaseUrlText: baseUrl.toString(),
          validationStatus: LocalTopoValidationStatus.validationFailed,
          detailMessage:
              'Capability validation failed. Check the server, then use Retry for the saved URL.',
        );
        return;
      }
      if (!_isLatestRequest(requestSerial)) return;
      await localTopoRuntime.saveValidatedSnapshot(
        snapshot,
        loadPreferences: () async => prefs!,
        activate: false,
        persistBaseUrl: false,
        isCurrent: () => _isLatestRequest(requestSerial),
      );
      if (!_isLatestRequest(requestSerial)) return;
      await _persistValidationStatus(
        prefs,
        LocalTopoValidationStatus.liveValidated,
      );
      if (!_isLatestRequest(requestSerial)) return;
      localTopoRuntime.activateConfirmedSnapshot(snapshot);
      ref
          .read(localTopoOverlayOutageReporterProvider)
          .resetAfterCapabilityValidation();

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
    } catch (error, stackTrace) {
      if (!_isLatestRequest(requestSerial)) return;
      _logFailure('preference save', error, stackTrace);
      await _recoverPersistenceFailure(
        prefs,
        previous,
        requestSerial,
        allowPrevious: !validationStarted,
      );
    } finally {
      if (_isLatestRequest(requestSerial)) {
        _attemptPending = false;
        state = state.copyWith(isPending: false);
      }
    }
  }

  Future<void> retryValidation() async {
    if (!state.canRetry) {
      return;
    }

    await saveAndValidate(state.savedBaseUrlText);
  }

  /// Keeps the saved server and capabilities available for a later retry.
  /// Returns true only when this failure changes the active basemap.
  bool fallbackAfterTileFailure(Uri tileUri) {
    if (tileUri.origin != localTopoRuntime.savedBaseUrl?.origin ||
        ref.read(mapProvider).basemap != Basemap.localTopo) {
      return false;
    }
    _fallbackToTracestrackIfLocalTopoSelected();
    return true;
  }

  Future<void> clearSetting() async {
    if (_attemptPending) return;
    _hasUserOverride = true;
    final serial = ++_validationRequestSerial;
    final previous = state;
    final loader = ref.read(localTopoSettingsPreferencesLoaderProvider);
    _attemptPending = true;
    state = state.copyWith(isPending: true, clearDetailMessage: true);
    SharedPreferences? prefs;
    localTopoRuntime.deactivateSnapshot();
    _fallbackToTracestrackIfLocalTopoSelected();
    try {
      prefs = await loader();
      if (!_isLatestRequest(serial)) return;
      await localTopoRuntime.clear(
        loadPreferences: () async => prefs!,
        isCurrent: () => _isLatestRequest(serial),
      );
      if (!_isLatestRequest(serial)) return;
      if (!await prefs.remove(localTopoValidationStatusPrefsKey)) {
        throw StateError('Validation status removal was not accepted');
      }
      if (!_isLatestRequest(serial)) return;
      state = const LocalTopoSettingsState(
        detailMessage: 'No saved local tile server base URL.',
      );
    } catch (error, stackTrace) {
      if (!_isLatestRequest(serial)) return;
      _logFailure('preference clear', error, stackTrace);
      await _recoverPersistenceFailure(prefs, previous, serial, clearing: true);
    } finally {
      if (_isLatestRequest(serial)) {
        _attemptPending = false;
        state = state.copyWith(isPending: false);
      }
    }
  }

  Future<void> _recoverPersistenceFailure(
    SharedPreferences? prefs,
    LocalTopoSettingsState previous,
    int serial, {
    bool allowPrevious = false,
    bool clearing = false,
  }) async {
    var confirmed = true;
    var saved =
        localTopoRuntime.savedBaseUrl?.toString() ??
        (clearing && prefs != null ? '' : previous.savedBaseUrlText);
    var retainPrevious = allowPrevious && prefs == null;
    try {
      if (prefs != null) {
        // Failed SharedPreferences writes still update its cache. Read storage,
        // not that optimistic cache, before choosing Save versus Retry recovery.
        await prefs.reload();
        if (!_isLatestRequest(serial)) return;
        final rawSaved = prefs.getString(localTileServerBaseUrlPrefsKey) ?? '';
        saved = parseLocalTileServerBaseUrl(rawSaved)?.toString() ?? rawSaved;
        retainPrevious = allowPrevious && saved == previous.savedBaseUrlText;
        await localTopoRuntime.restore(
          loadPreferences: () async => prefs,
          allowSnapshot: false,
          isCurrent: () => _isLatestRequest(serial),
        );
        if (!_isLatestRequest(serial)) return;
        if (retainPrevious && previous.activeSnapshot != null) {
          final rawSnapshot = prefs.getString(
            localTopoCapabilitySnapshotPrefsKey,
          );
          retainPrevious =
              rawSnapshot != null &&
              jsonEncode(
                    LocalTopoCapabilitySnapshot.fromStoredJson(
                      jsonDecode(rawSnapshot),
                    ).toJson(),
                  ) ==
                  jsonEncode(previous.activeSnapshot!.toJson());
        }
        if (!retainPrevious) {
          // Best-effort durable quarantine; either failure must still leave the
          // current runtime unavailable and never report Live validated.
          try {
            await _persistValidationStatus(
              prefs,
              LocalTopoValidationStatus.validationFailed,
            );
          } catch (error, stackTrace) {
            _logFailure('recovery status', error, stackTrace);
          }
          if (!_isLatestRequest(serial)) return;
          try {
            await localTopoRuntime.clearCapabilitySnapshot(
              loadPreferences: () async => prefs,
              isCurrent: () => _isLatestRequest(serial),
            );
          } catch (error, stackTrace) {
            _logFailure('recovery snapshot cleanup', error, stackTrace);
          }
        }
      }
    } catch (error, stackTrace) {
      confirmed = false;
      retainPrevious = false;
      _logFailure('preference readback', error, stackTrace);
    }
    if (!_isLatestRequest(serial)) return;
    if (retainPrevious && !clearing) {
      if (previous.activeSnapshot case final snapshot?) {
        localTopoRuntime.activateConfirmedSnapshot(snapshot);
      }
      state = previous.copyWith(
        isPending: false,
        detailMessage:
            'The URL could not be saved. Your previous configuration is unchanged. Try Save again.',
      );
      return;
    }
    localTopoRuntime.deactivateSnapshot();
    _fallbackToTracestrackIfLocalTopoSelected();
    state = LocalTopoSettingsState(
      savedBaseUrlText: saved,
      validationStatus: LocalTopoValidationStatus.validationFailed,
      needsClearRetry: clearing,
      storageConfirmed: confirmed,
      detailMessage: !confirmed
          ? 'Storage could not be confirmed. Local Topo is unavailable. Try Save or Clear again.'
          : clearing
          ? 'Clear did not finish. Local Topo is unavailable. Try Clear again.'
          : 'Preferences could not be completed. Local Topo is unavailable. ${saved.isEmpty ? 'Try Save again.' : 'Use Retry for the saved URL.'}',
    );
  }

  Future<void> _hydrate(int serial) async {
    try {
      final prefsLoader = ref.read(localTopoSettingsPreferencesLoaderProvider);
      final prefs = await prefsLoader();
      if (!_isLatestRequest(serial) || _hasUserOverride) return;
      final savedBaseUrlText =
          prefs.getString(localTileServerBaseUrlPrefsKey) ?? '';
      final persistedStatus = _parseLocalTopoValidationStatus(
        prefs.getString(localTopoValidationStatusPrefsKey),
      );

      await localTopoRuntime.restore(
        loadPreferences: () async => prefs,
        isCurrent: () => _isLatestRequest(serial) && !_hasUserOverride,
      );
      if (!_isLatestRequest(serial) || _hasUserOverride) {
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
    } catch (error, stackTrace) {
      if (!_isLatestRequest(serial) || _hasUserOverride) return;
      _logFailure('preference loading', error, stackTrace);
      localTopoRuntime.deactivateSnapshot();
      _fallbackToTracestrackIfLocalTopoSelected();
      state = const LocalTopoSettingsState(
        validationStatus: LocalTopoValidationStatus.validationFailed,
        storageConfirmed: false,
        detailMessage:
            'Settings could not be loaded. Local Topo is unavailable. Try Save or Clear again.',
      );
    }
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
    SharedPreferences prefs,
    LocalTopoValidationStatus validationStatus,
  ) async {
    if (!await prefs.setString(
      localTopoValidationStatusPrefsKey,
      validationStatus.storageValue,
    )) {
      throw StateError('Validation status write was not accepted');
    }
  }

  void _logFailure(String phase, Object error, StackTrace stackTrace) {
    developer.log(
      'Local Topo $phase failed (${error.runtimeType}).',
      name: 'LocalTopoSettings',
      stackTrace: stackTrace,
    );
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
      catalog: ref.read(mappingCatalogProvider),
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
