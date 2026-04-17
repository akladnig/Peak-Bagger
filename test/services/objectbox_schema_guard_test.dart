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

  test('throws when the schema signature changes', () async {
    SharedPreferences.setMockInitialValues({
      'objectbox_schema_signature': 'schema-v1',
    });

    final guard = ObjectBoxSchemaGuard(signatureLoader: () => 'schema-v2');

    await expectLater(guard.verify(), throwsStateError);
  });
}
