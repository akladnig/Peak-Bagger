import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

class PeakRegionImportMarkerStore {
  static const fingerprintsKey = 'peak_region_import_fingerprints_v1';

  const PeakRegionImportMarkerStore({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _loadPreferences;

  Future<Map<String, String>> loadFingerprints() async {
    final preferences = await _loadPreferences();
    final raw = preferences.getString(fingerprintsKey);
    if (raw == null || raw.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const {};
      }
      return decoded.map<String, String>((key, value) {
        return MapEntry('$key', '$value');
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to decode stored peak region fingerprints.',
        error: error,
        stackTrace: stackTrace,
        name: 'PeakRegionImportMarkerStore',
      );
      return const {};
    }
  }

  Future<void> saveFingerprints(Map<String, String> fingerprints) async {
    final preferences = await _loadPreferences();
    final sorted = Map<String, String>.fromEntries(
      fingerprints.entries.toList(growable: false)
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
    await preferences.setString(fingerprintsKey, jsonEncode(sorted));
  }
}
