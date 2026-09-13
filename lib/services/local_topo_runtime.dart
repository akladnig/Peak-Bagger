import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const localTileServerBaseUrlPrefsKey = 'local_tile_server_base_url';
const localTopoCapabilitySnapshotPrefsKey = 'local_topo_capability_snapshot_v1';
const localTopoPlaceholderTileUrl =
    'https://local-topo.invalid/{z}/{x}/{y}.png';

final localTopoRuntime = LocalTopoRuntime();

typedef LocalTopoRegionKeyValidator = bool Function(String regionKey);

LocalTopoRegionKeyValidator _localTopoRegionKeyValidator = (_) => false;

void registerLocalTopoRegionKeyValidator(
  LocalTopoRegionKeyValidator validator,
) {
  _localTopoRegionKeyValidator = validator;
}

Uri? parseLocalTileServerBaseUrl(String? rawValue) {
  final trimmed = rawValue?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }

  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    return null;
  }

  if (uri.path.isNotEmpty && uri.path != '/') {
    return null;
  }

  return uri.hasPort
      ? Uri(scheme: scheme, host: uri.host, port: uri.port)
      : Uri(scheme: scheme, host: uri.host);
}

class LocalTopoRegionCapability {
  const LocalTopoRegionCapability({
    required this.regionKey,
    required this.tilePathTemplate,
  });

  final String regionKey;
  final String tilePathTemplate;

  String resolveTileUrlTemplate(Uri baseUrl) {
    final normalizedPath = tilePathTemplate.startsWith('/')
        ? tilePathTemplate
        : '/$tilePathTemplate';
    return '${baseUrl.toString()}$normalizedPath';
  }

  Map<String, dynamic> toJson() {
    return {'regionKey': regionKey, 'tilePathTemplate': tilePathTemplate};
  }

  static LocalTopoRegionCapability? tryParse(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final regionKey = value['regionKey'];
    final tilePathTemplate = value['tilePathTemplate'];
    if (regionKey is! String || tilePathTemplate is! String) {
      return null;
    }

    if (!_localTopoRegionKeyValidator(regionKey) ||
        !_isAcceptedTilePathTemplate(tilePathTemplate)) {
      return null;
    }

    return LocalTopoRegionCapability(
      regionKey: regionKey,
      tilePathTemplate: tilePathTemplate,
    );
  }

  static bool _isAcceptedTilePathTemplate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        !trimmed.contains('{z}') ||
        !trimmed.contains('{x}') ||
        !trimmed.contains('{y}')) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return false;
    }

    return !uri.hasQuery && !uri.hasFragment;
  }
}

class LocalTopoOverlayCapability {
  const LocalTopoOverlayCapability({
    required this.key,
    required this.label,
    required this.regions,
  });

  final String key;
  final String label;
  final List<LocalTopoRegionCapability> regions;

  LocalTopoRegionCapability? resolveRegion(String regionKey) {
    for (final region in regions) {
      if (region.regionKey == regionKey) {
        return region;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'regions': [for (final region in regions) region.toJson()],
  };

  static LocalTopoOverlayCapability? tryParse(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final key = value['key'];
    final label = value['label'];
    if (key is! String ||
        label is! String ||
        !_hasAcceptedKeyAndLabel(key, label) ||
        value['regions'] is! List) {
      return null;
    }

    final regions = <LocalTopoRegionCapability>[];
    final seenRegionKeys = <String>{};
    for (final region in value['regions'] as List) {
      final parsed = LocalTopoRegionCapability.tryParse(region);
      if (parsed == null || !seenRegionKeys.add(parsed.regionKey)) {
        return null;
      }
      regions.add(parsed);
    }
    if (regions.isEmpty) {
      return null;
    }
    regions.sort((left, right) => left.regionKey.compareTo(right.regionKey));
    return LocalTopoOverlayCapability(
      key: key,
      label: label,
      regions: List.unmodifiable(regions),
    );
  }

  static bool _hasAcceptedKeyAndLabel(String key, String label) {
    return (key == 'terrainReliefShading' &&
            label == 'Terrain relief shading') ||
        (key == 'contourLines' && label == 'Contour lines');
  }
}

class LocalTopoCapabilitySnapshot {
  const LocalTopoCapabilitySnapshot({
    required this.baseUrl,
    required this.regions,
    this.overlays,
  });

  final Uri baseUrl;
  final List<LocalTopoRegionCapability> regions;
  // Null retains the stored v1 shape; an empty list is a validated v2 response.
  final List<LocalTopoOverlayCapability>? overlays;

  List<LocalTopoOverlayCapability> get overlayCapabilities =>
      overlays ?? const [];

  Set<String> get supportedRegionKeys => {
    for (final region in regions) region.regionKey,
  };

  factory LocalTopoCapabilitySnapshot.fromCapabilitiesResponse({
    required Uri baseUrl,
    required Object? decoded,
  }) {
    if (decoded is! Map) {
      throw const FormatException(
        'Local topo capabilities response must be a JSON object.',
      );
    }

    final service = decoded['service'];
    if (service != 'peak-bagger-local-topo') {
      throw const FormatException(
        'Local topo capabilities service must be peak-bagger-local-topo.',
      );
    }

    final version = decoded['version'];
    if (version is! int || (version != 1 && version != 2)) {
      throw const FormatException(
        'Local topo capabilities version must be 1 or 2.',
      );
    }

    final basemaps = decoded['basemaps'];
    if (basemaps is! List) {
      throw const FormatException(
        'Local topo capabilities basemaps must be a list.',
      );
    }

    Map<dynamic, dynamic>? localTopoBasemap;
    for (final basemap in basemaps) {
      if (basemap is! Map) {
        continue;
      }
      if (basemap['key'] == 'localTopo') {
        localTopoBasemap = basemap;
        break;
      }
    }

    if (localTopoBasemap == null) {
      throw const FormatException(
        'Local topo capabilities must include a localTopo basemap.',
      );
    }

    if (localTopoBasemap['label'] != 'Local Topo') {
      throw const FormatException(
        'Local topo capabilities localTopo basemap must use label Local Topo.',
      );
    }

    final regions = localTopoBasemap['regions'];
    if (regions is! List) {
      throw const FormatException(
        'Local topo capabilities regions must be a list.',
      );
    }

    final acceptedRegions = <LocalTopoRegionCapability>[];
    final seenRegionKeys = <String>{};
    for (final region in regions) {
      final parsedRegion = LocalTopoRegionCapability.tryParse(region);
      if (parsedRegion == null || !seenRegionKeys.add(parsedRegion.regionKey)) {
        continue;
      }
      acceptedRegions.add(parsedRegion);
    }

    if (acceptedRegions.isEmpty) {
      throw const FormatException(
        'Local topo capabilities did not include any accepted regions.',
      );
    }

    acceptedRegions.sort(
      (left, right) => left.regionKey.compareTo(right.regionKey),
    );

    final overlays = version == 2 ? _parseOverlays(decoded['overlays']) : null;

    return LocalTopoCapabilitySnapshot(
      baseUrl: baseUrl,
      regions: List.unmodifiable(acceptedRegions),
      overlays: overlays,
    );
  }

  factory LocalTopoCapabilitySnapshot.fromStoredJson(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException(
        'Stored local topo snapshot must be a JSON object.',
      );
    }

    final baseUrlValue = decoded['baseUrl'];
    final baseUrl = parseLocalTileServerBaseUrl(
      baseUrlValue is String ? baseUrlValue : null,
    );
    if (baseUrl == null) {
      throw const FormatException(
        'Stored local topo snapshot base URL is invalid.',
      );
    }

    final regions = decoded['regions'];
    if (regions is! List) {
      throw const FormatException(
        'Stored local topo snapshot regions must be a list.',
      );
    }

    final acceptedRegions = <LocalTopoRegionCapability>[];
    final seenRegionKeys = <String>{};
    for (final region in regions) {
      final parsedRegion = LocalTopoRegionCapability.tryParse(region);
      if (parsedRegion == null || !seenRegionKeys.add(parsedRegion.regionKey)) {
        continue;
      }
      acceptedRegions.add(parsedRegion);
    }

    if (acceptedRegions.isEmpty) {
      throw const FormatException(
        'Stored local topo snapshot did not include any accepted regions.',
      );
    }

    acceptedRegions.sort(
      (left, right) => left.regionKey.compareTo(right.regionKey),
    );

    final overlaysValue = decoded['overlays'];
    if (overlaysValue != null && overlaysValue is! List) {
      throw const FormatException(
        'Stored local topo snapshot overlays must be a list.',
      );
    }

    return LocalTopoCapabilitySnapshot(
      baseUrl: baseUrl,
      regions: List.unmodifiable(acceptedRegions),
      overlays: overlaysValue == null ? null : _parseOverlays(overlaysValue),
    );
  }

  static List<LocalTopoOverlayCapability> _parseOverlays(dynamic value) {
    if (value is! List) {
      throw const FormatException(
        'Local topo capabilities overlays must be a list.',
      );
    }

    final parsedByKey = <String, LocalTopoOverlayCapability>{};
    final invalidKeys = <String>{};
    for (final declaration in value) {
      final parsed = LocalTopoOverlayCapability.tryParse(declaration);
      if (parsed == null || invalidKeys.contains(parsed.key)) {
        continue;
      }
      if (parsedByKey.containsKey(parsed.key)) {
        parsedByKey.remove(parsed.key);
        invalidKeys.add(parsed.key);
        continue;
      }
      parsedByKey[parsed.key] = parsed;
    }
    final overlays = parsedByKey.values.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(overlays);
  }

  String? resolvedTileUrlTemplate({String? regionKey}) {
    final resolvedRegion = resolveRegion(regionKey: regionKey);
    if (resolvedRegion == null) {
      return null;
    }

    return resolvedRegion.resolveTileUrlTemplate(baseUrl);
  }

  LocalTopoRegionCapability? resolveRegion({String? regionKey}) {
    if (regionKey == null || regionKey.isEmpty) {
      return regions.length == 1 ? regions.single : null;
    }

    for (final region in regions) {
      if (region.regionKey == regionKey) {
        return region;
      }
    }

    return null;
  }

  bool supportsRegionKey(String regionKey) {
    for (final region in regions) {
      if (region.regionKey == regionKey) {
        return true;
      }
    }

    return false;
  }

  LocalTopoOverlayCapability? overlayByKey(String key) {
    for (final overlay in overlayCapabilities) {
      if (overlay.key == key) {
        return overlay;
      }
    }
    return null;
  }

  String? resolvedOverlayTileUrlTemplate({
    required String key,
    required String regionKey,
  }) {
    return overlayByKey(
      key,
    )?.resolveRegion(regionKey)?.resolveTileUrlTemplate(baseUrl);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'baseUrl': baseUrl.toString(),
      'regions': [for (final region in regions) region.toJson()],
    };
    if (overlays != null) {
      json['overlays'] = [for (final overlay in overlays!) overlay.toJson()];
    }
    return json;
  }
}

class LocalTopoPersistedState {
  const LocalTopoPersistedState({this.savedBaseUrl, this.capabilitySnapshot});

  final Uri? savedBaseUrl;
  final LocalTopoCapabilitySnapshot? capabilitySnapshot;

  bool get hasCapabilitySnapshot => capabilitySnapshot != null;
}

class LocalTopoRuntime {
  LocalTopoPersistedState _state = const LocalTopoPersistedState();

  LocalTopoPersistedState get state => _state;
  Uri? get savedBaseUrl => _state.savedBaseUrl;
  LocalTopoCapabilitySnapshot? get capabilitySnapshot =>
      _state.capabilitySnapshot;
  bool get hasCapabilitySnapshot => _state.hasCapabilitySnapshot;

  String? resolvedTileUrlTemplate({String? regionKey}) {
    return capabilitySnapshot?.resolvedTileUrlTemplate(regionKey: regionKey);
  }

  Future<void> restore({
    Future<SharedPreferences> Function()? loadPreferences,
  }) async {
    final preferences =
        await (loadPreferences ?? SharedPreferences.getInstance)();
    final savedBaseUrl = parseLocalTileServerBaseUrl(
      preferences.getString(localTileServerBaseUrlPrefsKey),
    );

    LocalTopoCapabilitySnapshot? capabilitySnapshot;
    final rawSnapshot = preferences.getString(
      localTopoCapabilitySnapshotPrefsKey,
    );
    if (savedBaseUrl != null && rawSnapshot != null && rawSnapshot.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSnapshot);
        final parsedSnapshot = LocalTopoCapabilitySnapshot.fromStoredJson(
          decoded,
        );
        if (parsedSnapshot.baseUrl.toString() == savedBaseUrl.toString()) {
          capabilitySnapshot = parsedSnapshot;
        }
      } catch (error, stackTrace) {
        developer.log(
          'Failed to decode stored local topo snapshot.',
          error: error,
          stackTrace: stackTrace,
          name: 'LocalTopoRuntime',
        );
      }
    }

    _state = LocalTopoPersistedState(
      savedBaseUrl: savedBaseUrl,
      capabilitySnapshot: capabilitySnapshot,
    );
  }

  Future<void> saveBaseUrl(
    Uri? baseUrl, {
    Future<SharedPreferences> Function()? loadPreferences,
  }) async {
    final preferences =
        await (loadPreferences ?? SharedPreferences.getInstance)();
    if (baseUrl == null) {
      await preferences.remove(localTileServerBaseUrlPrefsKey);
      await preferences.remove(localTopoCapabilitySnapshotPrefsKey);
      _state = const LocalTopoPersistedState();
      return;
    }

    await preferences.setString(
      localTileServerBaseUrlPrefsKey,
      baseUrl.toString(),
    );

    final existingSnapshot = capabilitySnapshot;
    if (existingSnapshot != null &&
        existingSnapshot.baseUrl.toString() != baseUrl.toString()) {
      await preferences.remove(localTopoCapabilitySnapshotPrefsKey);
      _state = LocalTopoPersistedState(savedBaseUrl: baseUrl);
      return;
    }

    _state = LocalTopoPersistedState(
      savedBaseUrl: baseUrl,
      capabilitySnapshot: existingSnapshot,
    );
  }

  Future<void> saveValidatedSnapshot(
    LocalTopoCapabilitySnapshot snapshot, {
    Future<SharedPreferences> Function()? loadPreferences,
  }) async {
    final preferences =
        await (loadPreferences ?? SharedPreferences.getInstance)();
    await preferences.setString(
      localTileServerBaseUrlPrefsKey,
      snapshot.baseUrl.toString(),
    );
    await preferences.setString(
      localTopoCapabilitySnapshotPrefsKey,
      jsonEncode(snapshot.toJson()),
    );

    _state = LocalTopoPersistedState(
      savedBaseUrl: snapshot.baseUrl,
      capabilitySnapshot: snapshot,
    );
  }

  Future<void> clearCapabilitySnapshot({
    Future<SharedPreferences> Function()? loadPreferences,
  }) async {
    final preferences =
        await (loadPreferences ?? SharedPreferences.getInstance)();
    await preferences.remove(localTopoCapabilitySnapshotPrefsKey);

    _state = LocalTopoPersistedState(savedBaseUrl: savedBaseUrl);
  }

  Future<void> clear({
    Future<SharedPreferences> Function()? loadPreferences,
  }) async {
    await saveBaseUrl(null, loadPreferences: loadPreferences);
  }

  @visibleForTesting
  void resetForTesting() {
    _state = const LocalTopoPersistedState();
  }
}
