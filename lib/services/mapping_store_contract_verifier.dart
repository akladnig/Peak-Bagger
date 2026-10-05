import 'dart:convert';

import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_manifest.dart';

class MappingStoreAllowedDifference {
  const MappingStoreAllowedDifference(this.path, this.expected, this.actual);
  final String path;
  final Object? expected;
  final Object? actual;

  @override
  String toString() =>
      '$path: ${jsonEncode(expected)} -> ${jsonEncode(actual)}';
}

/// The v1 fixture directory, not a manifest field, owns schema revision.
/// Both sides use the production parser. Every difference except an existing
/// regional fingerprint is a contract mismatch (including tool permissions).
List<MappingStoreAllowedDifference> verifyMappingStoreContract({
  required String fixtureRegion,
  required String fixturePolygons,
  required String fixtureTools,
  required String mountedRegion,
  required String mountedPolygons,
  required String mountedTools,
}) {
  final expectedRegion = jsonDecode(fixtureRegion);
  final expectedPolygons = jsonDecode(fixturePolygons);
  final actualRegion = jsonDecode(mountedRegion);
  final actualPolygons = jsonDecode(mountedPolygons);
  validateMappingManifestPair(expectedRegion, expectedPolygons);
  validateMappingManifestPair(actualRegion, actualPolygons);
  MappingToolManifest.parse(fixtureTools);
  MappingToolManifest.parse(mountedTools);
  final allowed = <MappingStoreAllowedDifference>[];
  final failures = <String>[];
  final fingerprintPointers = <String>{
    for (final entry in (expectedRegion as Map<String, dynamic>).entries)
      if (entry.value is Map && (entry.value as Map).containsKey('fingerprint'))
        '/${_escape(entry.key)}/fingerprint',
  };
  _compare(expectedRegion, actualRegion, '', (pointer, expected, actual) {
    final path = 'region_manifest.json#$pointer';
    if (fingerprintPointers.contains(pointer) &&
        expected is String &&
        actual is String) {
      allowed.add(MappingStoreAllowedDifference(path, expected, actual));
    } else {
      failures.add(path);
    }
  });
  _compare(
    expectedPolygons,
    actualPolygons,
    '',
    (pointer, _, _) => failures.add('Polygons/manifest.json#$pointer'),
  );
  _compare(
    jsonDecode(fixtureTools),
    jsonDecode(mountedTools),
    '',
    (pointer, _, _) => failures.add('tool_manifest.json#$pointer'),
  );
  if (failures.isNotEmpty) throw MappingStoreFailure(failures);
  allowed.sort((a, b) => a.path.compareTo(b.path));
  return List.unmodifiable(allowed);
}

String _escape(String key) => key.replaceAll('~', '~0').replaceAll('/', '~1');

void _compare(
  Object? expected,
  Object? actual,
  String pointer,
  void Function(String, Object?, Object?) difference,
) {
  if (expected is Map && actual is Map) {
    final keys = {...expected.keys, ...actual.keys}.cast<String>().toList()
      ..sort();
    for (final key in keys) {
      final child = '$pointer/${_escape(key)}';
      if (!expected.containsKey(key) || !actual.containsKey(key)) {
        difference(child, expected[key], actual[key]);
      } else {
        _compare(expected[key], actual[key], child, difference);
      }
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      difference(pointer, expected, actual);
    } else {
      for (var i = 0; i < expected.length; i++) {
        _compare(expected[i], actual[i], '$pointer/$i', difference);
      }
    }
  } else if (expected != actual) {
    difference(pointer, expected, actual);
  }
}
