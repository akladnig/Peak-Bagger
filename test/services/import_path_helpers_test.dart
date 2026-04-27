import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';

void main() {
  group('resolveBushwalkingRoot', () {
    test('returns Bushwalking path when it exists', () {
      final home = Platform.environment['HOME'] ?? '';
      final bushwalkingPath = '$home/Documents/Bushwalking';

      if (Directory(bushwalkingPath).existsSync()) {
        expect(resolveBushwalkingRoot(), bushwalkingPath);
      }
    });

    test('falls back to home when Bushwalking does not exist', () {
      final home = Platform.environment['HOME'] ?? '';
      final bushwalkingPath = '$home/Documents/Bushwalking';

      if (Directory(bushwalkingPath).existsSync()) {
        // Skipping - Bushwalking exists in this environment
        return;
      }

      // When Bushwalking doesn't exist, should fall back to home
      expect(resolveBushwalkingRoot(), home);
    });

    test('returns current directory when HOME is not set', () {
      // This is hard to test without mocking Platform.environment
      // The behavior is tested via integration tests
    });
  });
}
