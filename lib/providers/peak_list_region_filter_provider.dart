import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/region_manifest_catalog.dart';

const peakListRegionFilterPreferenceKey = 'peak_lists_region_filter_keys';

final peakListRegionFilterPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final peakListRegionFilterOptionsProvider =
    Provider<List<RegionManifestRegionData>>((ref) {
      return regionManifestCatalog.peakListRegions();
    });

final peakListRegionFilterProvider =
    NotifierProvider<PeakListRegionFilterNotifier, Set<String>>(
      PeakListRegionFilterNotifier.new,
    );

class PeakListRegionFilterNotifier extends Notifier<Set<String>> {
  bool _hasUserOverride = false;

  @override
  Set<String> build() {
    final defaultSelection = _defaultSelection();
    unawaited(_hydrate());
    return defaultSelection;
  }

  Future<void> toggleRegion(String regionKey) async {
    _hasUserOverride = true;
    final nextSelection = Set<String>.from(state);
    if (!nextSelection.remove(regionKey)) {
      nextSelection.add(regionKey);
    }

    state = Set<String>.unmodifiable(nextSelection);
    await _persist(nextSelection);
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await ref.read(
        peakListRegionFilterPreferencesLoaderProvider,
      )();
      if (_hasUserOverride) {
        return;
      }

      final storedSelection = prefs.getStringList(
        peakListRegionFilterPreferenceKey,
      );
      if (storedSelection == null) {
        return;
      }

      final availableKeys = _availableRegionKeys();
      final restoredSelection = <String>{
        for (final key in storedSelection)
          if (availableKeys.contains(key)) key,
      };
      if (_setsEqual(state, restoredSelection)) {
        return;
      }

      await Future<void>.delayed(Duration.zero);
      if (!ref.mounted || _hasUserOverride) {
        return;
      }
      state = Set<String>.unmodifiable(restoredSelection);
    } catch (_) {}
  }

  Future<void> _persist(Set<String> selection) async {
    try {
      final prefs = await ref.read(
        peakListRegionFilterPreferencesLoaderProvider,
      )();
      await prefs.setStringList(
        peakListRegionFilterPreferenceKey,
        _orderedSelection(selection),
      );
    } catch (_) {}
  }

  Set<String> _defaultSelection() {
    return Set<String>.unmodifiable(_availableRegionKeys());
  }

  Set<String> _availableRegionKeys() {
    return {
      for (final region in ref.read(peakListRegionFilterOptionsProvider))
        region.key,
    };
  }

  List<String> _orderedSelection(Set<String> selection) {
    return [
      for (final region in ref.read(peakListRegionFilterOptionsProvider))
        if (selection.contains(region.key)) region.key,
    ];
  }

  bool _setsEqual(Set<String> left, Set<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }
    return true;
  }
}
