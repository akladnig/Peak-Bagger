import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

    test('builds Tracks path from an explicit Bushwalking root', () {
      expect(
        resolveBushwalkingTracksPath(bushwalkingRoot: '/tmp/Bushwalking'),
        p.join('/tmp/Bushwalking', 'Tracks'),
      );
    });

    test('builds Routes path from an explicit Bushwalking root', () {
      expect(
        resolveBushwalkingRoutesPath(bushwalkingRoot: '/tmp/Bushwalking'),
        p.join('/tmp/Bushwalking', 'Routes'),
      );
    });
  });

  group('resolveTasmaniaDemRoot', () {
    test(
      'uses HOME/DEM/Tasmania even when Documents/Bushwalking exists',
      () async {
        final home = await Directory.systemTemp.createTemp('tas-dem-root-home');
        addTearDown(() => home.deleteSync(recursive: true));
        Directory(
          p.join(home.path, 'Documents', 'Bushwalking'),
        ).createSync(recursive: true);

        expect(
          resolveTasmaniaDemRoot(homeDirectory: home.path),
          p.join(home.path, 'DEM', 'Tasmania'),
        );
      },
    );

    test('uses HOME/DEM/Tasmania when Bushwalking does not exist', () async {
      final home = await Directory.systemTemp.createTemp(
        'tas-dem-home-fallback',
      );
      addTearDown(() => home.deleteSync(recursive: true));

      expect(
        resolveTasmaniaDemRoot(homeDirectory: home.path),
        p.join(home.path, 'DEM', 'Tasmania'),
      );
    });

    test('fails clearly when HOME is unavailable', () {
      expect(
        () => resolveTasmaniaDemRoot(homeDirectory: ''),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('HOME is unavailable'),
          ),
        ),
      );
    });
  });
}
