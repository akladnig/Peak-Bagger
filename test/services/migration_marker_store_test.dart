import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MigrationMarkerStore', () {
    test('marks track migration as complete', () async {
      SharedPreferences.setMockInitialValues({});
      const store = MigrationMarkerStore();

      expect(await store.isMarked(), isFalse);

      await store.markComplete();

      expect(await store.isMarked(), isTrue);
    });

    test('marks peaks bagged backfill as complete', () async {
      SharedPreferences.setMockInitialValues({});
      const store = MigrationMarkerStore();

      expect(await store.isPeaksBaggedBackfillMarked(), isFalse);

      await store.markPeaksBaggedBackfillComplete();

      expect(await store.isPeaksBaggedBackfillMarked(), isTrue);
    });
  });
}
