import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime lib code no longer references peak marker svg assets', () {
    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final offendingFiles = <String>[];
    for (final file in dartFiles) {
      final contents = file.readAsStringSync();
      if (contents.contains('assets/peak_marker.svg') ||
          contents.contains('assets/peak_marker_ticked.svg')) {
        offendingFiles.add(file.path);
      }
    }

    expect(offendingFiles, isEmpty, reason: offendingFiles.join('\n'));
  });

  test('pubspec no longer registers peak marker svg assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec.contains('assets/peak_marker.svg'), isFalse);
    expect(pubspec.contains('assets/peak_marker_ticked.svg'), isFalse);
  });
}
