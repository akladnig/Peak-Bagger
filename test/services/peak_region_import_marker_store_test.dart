import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loadFingerprints returns empty map by default', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PeakRegionImportMarkerStore();

    final fingerprints = await store.loadFingerprints();

    expect(fingerprints, isEmpty);
  });

  test('saveFingerprints persists and reloads sorted map', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PeakRegionImportMarkerStore();

    await store.saveFingerprints({'slovenia': 'bbb', 'tasmania': 'aaa'});

    final fingerprints = await store.loadFingerprints();

    expect(fingerprints, {'slovenia': 'bbb', 'tasmania': 'aaa'});
  });
}
