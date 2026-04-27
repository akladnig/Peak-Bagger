import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';

void main() {
  group('GpxFilePicker', () {
    group('PlatformGpxFilePicker', () {
      test(
        'resolveImportRoot returns Bushwalking path when it exists',
        () async {
          final picker = PlatformGpxFilePicker();
          final home = Platform.environment['HOME'] ?? '';
          final bushwalkingPath = '$home/Documents/Bushwalking';

          if (Directory(bushwalkingPath).existsSync()) {
            expect(await picker.resolveImportRoot(), bushwalkingPath);
          }
        },
      );

      test(
        'resolveImportRoot falls back to home when Bushwalking does not exist',
        () async {
          final picker = PlatformGpxFilePicker();
          final home = Platform.environment['HOME'] ?? '';
          final bushwalkingPath = '$home/Documents/Bushwalking';

          if (Directory(bushwalkingPath).existsSync()) {
            return;
          }

          expect(await picker.resolveImportRoot(), home);
        },
      );
    });

    group('TestGpxFilePicker', () {
      test('returns provided files', () async {
        final picker = TestGpxFilePicker(
          filesToReturn: ['/tmp/track1.gpx', '/tmp/track2.gpx'],
        );

        final result = await picker.pickGpxFiles();

        expect(result, ['/tmp/track1.gpx', '/tmp/track2.gpx']);
        expect(picker.pickGpxFilesCalled, isTrue);
      });

      test('returns null when no files provided', () async {
        final picker = TestGpxFilePicker(filesToReturn: null);

        final result = await picker.pickGpxFiles();

        expect(result, isNull);
      });

      test('throws error when configured', () async {
        final picker = TestGpxFilePicker(errorToThrow: Exception('Test error'));

        expect(() => picker.pickGpxFiles(), throwsException);
      });

      test('resolveImportRoot returns configured path', () async {
        final picker = TestGpxFilePicker(importRoot: '/custom/test/path');

        expect(await picker.resolveImportRoot(), '/custom/test/path');
      });
    });
  });
}

class FakeGpxFilePicker implements GpxFilePicker {
  FakeGpxFilePicker({
    this.filesToReturn,
    this.importRoot = '/tmp',
    this.errorToThrow,
  });

  final List<String>? filesToReturn;
  final String importRoot;
  final Object? errorToThrow;
  bool pickGpxFilesCalled = false;

  @override
  Future<List<String>?> pickGpxFiles() async {
    pickGpxFilesCalled = true;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return filesToReturn;
  }

  @override
  Future<String> resolveImportRoot() async => importRoot;
}

class TestGpxFilePicker implements GpxFilePicker {
  TestGpxFilePicker({
    this.filesToReturn,
    this.importRoot = '/tmp',
    this.errorToThrow,
  });

  final List<String>? filesToReturn;
  final String importRoot;
  final Object? errorToThrow;
  bool pickGpxFilesCalled = false;

  @override
  Future<List<String>?> pickGpxFiles() async {
    pickGpxFilesCalled = true;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return filesToReturn;
  }

  @override
  Future<String> resolveImportRoot() async => importRoot;
}
