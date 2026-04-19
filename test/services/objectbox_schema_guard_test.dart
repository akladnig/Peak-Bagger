import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/objectbox_schema_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores the schema signature on first run', () async {
    SharedPreferences.setMockInitialValues({});

    final guard = ObjectBoxSchemaGuard(signatureLoader: () => 'schema-v1');

    await guard.verify();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('objectbox_schema_signature'), 'schema-v1');
  });

  test('updates the stored signature when the schema changes', () async {
    SharedPreferences.setMockInitialValues({
      'objectbox_schema_signature': 'schema-v1',
    });

    final guard = ObjectBoxSchemaGuard(signatureLoader: () => 'schema-v2');

    await guard.verify();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('objectbox_schema_signature'), 'schema-v2');
  });

  test('schema signature includes peak and peak list surface markers', () {
    final signature = ObjectBoxSchemaGuard.debugCurrentSchemaSignature();

    expect(signature, contains('Peak.sourceOfTruth:'));
    expect(signature, contains('PeakList.name:'));
    expect(signature, contains('PeakList.peakList:'));
  });
}
