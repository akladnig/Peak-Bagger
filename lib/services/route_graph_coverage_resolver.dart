import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/models/route_graph_coverage.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

typedef RouteGraphCoverageAssetLoader =
    Future<String> Function(String assetPath);

class RouteGraphCoverageResolver {
  RouteGraphCoverageResolver({
    RouteGraphCoverageAssetLoader? assetLoader,
    this.manifestAssetPath = defaultManifestAssetPath,
  }) : _assetLoader = assetLoader ?? rootBundle.loadString;

  static const defaultManifestAssetPath = 'assets/region_manifest.json';
  static const routingCoveragesKey = 'routingCoverages';

  final RouteGraphCoverageAssetLoader _assetLoader;
  final String manifestAssetPath;

  Future<List<RouteGraphCoverageImportInput>> resolve() async {
    final manifest = _decodeManifest(await _assetLoader(manifestAssetPath));
    final definitions = _readDefinitions(manifest);
    final sourcesByCoverage = <String, List<_SourceRegion>>{
      for (final definition in definitions) definition.key: [],
    };

    for (final entry in manifest.entries) {
      if (entry.key == routingCoveragesKey) {
        continue;
      }
      final region = _readRegion(entry.key, entry.value);
      if (region.routingCoverage == null) {
        continue;
      }
      final sources = sourcesByCoverage[region.routingCoverage];
      if (sources == null) {
        throw FormatException(
          'Region ${region.key} references unknown routing coverage '
          '${region.routingCoverage}.',
        );
      }
      sources.add(region);
    }

    final inputs = <RouteGraphCoverageImportInput>[];
    for (final definition in definitions) {
      final sourceRegions = sourcesByCoverage[definition.key]!;
      if (sourceRegions.isEmpty) {
        throw FormatException(
          'Routing coverage ${definition.key} has no source regions.',
        );
      }
      sourceRegions.sort(
        (left, right) => left.priority.compareTo(right.priority),
      );
      for (var index = 1; index < sourceRegions.length; index++) {
        if (_samePriority(
          sourceRegions[index - 1].priority,
          sourceRegions[index].priority,
        )) {
          throw FormatException(
            'Routing coverage ${definition.key} has duplicate priority '
            '${sourceRegions[index].priority}.',
          );
        }
      }

      final resolvedSources = <RouteGraphCoverageSourceRegion>[];
      final hashSourceRegions = <Object?>[];
      final mergedElements = <Object?>[];
      final identities = <String, String>{};
      final unavailableFootprint = <RouteGraphFootprintBound>[];

      for (final sourceRegion in sourceRegions) {
        final sourcePaths = List<String>.from(sourceRegion.highwayPaths)
          ..sort((left, right) => left.compareTo(right));
        final sourceAssets = <RouteGraphCoverageSourceAsset>[];
        final hashSourceAssets = <Object?>[];
        for (final sourcePath in sourcePaths) {
          final overpass = _decodeOverpass(
            sourcePath,
            await _assetLoader(sourcePath),
          );
          sourceAssets.add(
            RouteGraphCoverageSourceAsset(path: sourcePath, overpass: overpass),
          );
          final bound = _nodeCoordinateBound(overpass['elements']! as List);
          if (bound != null) {
            unavailableFootprint.add(bound);
          }
          hashSourceAssets.add({'path': sourcePath, 'overpass': overpass});

          for (final element in overpass['elements']! as List<Object?>) {
            final canonicalElement = canonicalJsonValue(element);
            final identity = _osmIdentity(canonicalElement);
            if (identity != null) {
              final encoded = canonicalJsonEncode(canonicalElement);
              final existing = identities[identity];
              if (existing != null) {
                if (existing != encoded) {
                  throw FormatException(
                    'Routing coverage ${definition.key} has conflicting '
                    'OSM element $identity.',
                  );
                }
                continue;
              }
              identities[identity] = encoded;
            }
            mergedElements.add(canonicalElement);
          }
        }
        resolvedSources.add(
          RouteGraphCoverageSourceRegion(
            key: sourceRegion.key,
            priority: sourceRegion.priority,
            sourceAssets: List.unmodifiable(sourceAssets),
          ),
        );
        hashSourceRegions.add({
          'key': sourceRegion.key,
          'prioritySegments': sourceRegion.priority.segments,
          'sourceAssets': hashSourceAssets,
        });
      }

      final resolvedDefinition = RouteGraphCoverageDefinition(
        key: definition.key,
        displayName: definition.displayName,
        sourceRegions: List.unmodifiable(resolvedSources),
      );
      final hashPayload = <String, Object?>{
        'routingCoverageKey': definition.key,
        'sourceRegions': hashSourceRegions,
      };
      final nodeById = _validNodesById(mergedElements);
      if (unavailableFootprint.isEmpty) {
        for (final sourceRegion in sourceRegions) {
          for (final polygonPath in sourceRegion.polygonPaths) {
            final parsed = parsePolygonText(await _assetLoader(polygonPath));
            if (!parsed.isSuccess) {
              throw FormatException(
                'Routing coverage ${definition.key} has invalid coverage '
                'polygon $polygonPath.',
              );
            }
            final points = parsed.polygon!.vertices;
            unavailableFootprint.add(
              RouteGraphFootprintBound(
                minLat: points.map((point) => point.latitude).reduce(_min),
                minLon: points.map((point) => point.longitude).reduce(_min),
                maxLat: points.map((point) => point.latitude).reduce(_max),
                maxLon: points.map((point) => point.longitude).reduce(_max),
              ),
            );
          }
        }
      }
      inputs.add(
        RouteGraphCoverageImportInput(
          definition: resolvedDefinition,
          sourceHash: sha256
              .convert(utf8.encode(canonicalJsonEncode(hashPayload)))
              .toString(),
          mergedOverpass: {'elements': List.unmodifiable(mergedElements)},
          acceptedWayCount: mergedElements
              .where(
                (element) =>
                    isAcceptedRouteGraphWay(element, nodeById: nodeById),
              )
              .length,
          unavailableFootprint: List.unmodifiable(unavailableFootprint),
        ),
      );
    }
    return List.unmodifiable(inputs);
  }

  Map<String, Object?> _decodeManifest(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException(
        'Route graph manifest must be a JSON object.',
      );
    }
    return _stringKeyedMap(decoded, 'Route graph manifest');
  }

  List<_CoverageDefinition> _readDefinitions(Map<String, Object?> manifest) {
    final rawDefinitions = manifest[routingCoveragesKey];
    if (rawDefinitions is! Map) {
      throw const FormatException(
        'Route graph manifest must define routingCoverages.',
      );
    }
    final definitions = <_CoverageDefinition>[];
    for (final entry in rawDefinitions.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException(
          'Each routing coverage must be an object keyed by a non-empty string.',
        );
      }
      final key = entry.key;
      final value = _stringKeyedMap(
        entry.value as Map,
        'Routing coverage $key',
      );
      final displayName = value['displayName'];
      if (key.isEmpty || displayName is! String || displayName.trim().isEmpty) {
        throw FormatException(
          'Routing coverage $key must define a non-empty displayName.',
        );
      }
      definitions.add(_CoverageDefinition(key: key, displayName: displayName));
    }
    return definitions;
  }

  _SourceRegion _readRegion(String key, Object? rawRegion) {
    if (rawRegion is! Map) {
      throw FormatException('Region $key must be a JSON object.');
    }
    final region = _stringKeyedMap(rawRegion, 'Region $key');
    final routingCoverage = region['routingCoverage'];
    if (routingCoverage != null && routingCoverage is! String) {
      throw FormatException('Region $key routingCoverage must be a string.');
    }
    if (region['composite'] == true || routingCoverage == null) {
      return _SourceRegion.excluded(key: key);
    }
    final priority = region['priority'];
    if (priority is! String) {
      throw FormatException('Region $key has no priority.');
    }
    final highways = region['highways'];
    if (highways is! List || highways.isEmpty) {
      throw FormatException('Region $key must define non-empty highways.');
    }
    final paths = <String>[];
    for (final rawPath in highways) {
      if (rawPath is! String || !_isCanonicalAssetPath(rawPath)) {
        throw FormatException(
          'Region $key has non-canonical highway asset $rawPath.',
        );
      }
      paths.add(rawPath);
    }
    final polygonPaths = <String>[];
    final polygons = region['poly'];
    if (polygons is List) {
      for (final polygon in polygons) {
        if (polygon is! String || !_isCanonicalAssetPath(polygon)) {
          throw FormatException(
            'Region $key has non-canonical polygon $polygon.',
          );
        }
        polygonPaths.add(polygon);
      }
    }
    return _SourceRegion(
      key: key,
      routingCoverage: routingCoverage as String,
      priority: ManifestPriority.parse(priority, regionKey: key),
      highwayPaths: paths,
      polygonPaths: polygonPaths,
    );
  }

  Map<String, Object?> _decodeOverpass(String path, String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw FormatException('Highway asset $path must be a JSON object.');
    }
    final overpass = canonicalJsonValue(decoded);
    if (overpass is! Map<String, Object?> || overpass['elements'] is! List) {
      throw FormatException(
        'Highway asset $path must contain an elements array.',
      );
    }
    return overpass;
  }
}

double _min(double left, double right) => left < right ? left : right;
double _max(double left, double right) => left > right ? left : right;

RouteGraphFootprintBound? _nodeCoordinateBound(List elements) {
  double? minLat;
  double? minLon;
  double? maxLat;
  double? maxLon;
  for (final element in elements) {
    if (element is! Map || element['type'] != 'node') continue;
    final lat = element['lat'];
    final lon = element['lon'];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite) {
      continue;
    }
    final latitude = lat.toDouble();
    final longitude = lon.toDouble();
    minLat = minLat == null || latitude < minLat ? latitude : minLat;
    maxLat = maxLat == null || latitude > maxLat ? latitude : maxLat;
    minLon = minLon == null || longitude < minLon ? longitude : minLon;
    maxLon = maxLon == null || longitude > maxLon ? longitude : maxLon;
  }
  if (minLat == null || minLon == null || maxLat == null || maxLon == null) {
    return null;
  }
  return RouteGraphFootprintBound(
    minLat: minLat,
    minLon: minLon,
    maxLat: maxLat,
    maxLon: maxLon,
  );
}

bool isAcceptedRouteGraphWay(
  Object? element, {
  Map<int, Map<String, Object?>> nodeById = const {},
}) {
  if (element is! Map || element['type'] != 'way' || element['id'] is! int) {
    return false;
  }
  final tags = element['tags'];
  final nodes = element['nodes'];
  if (tags is! Map ||
      tags['highway'] == null ||
      tags['area'] == 'yes' ||
      tags['place'] == 'square' ||
      nodes is! List ||
      nodes.length < 2) {
    return false;
  }
  return nodes.every((nodeId) => nodeId is int && nodeById.containsKey(nodeId));
}

Map<int, Map<String, Object?>> _validNodesById(List<Object?> elements) {
  final nodes = <int, Map<String, Object?>>{};
  for (final element in elements) {
    if (element is! Map || element['type'] != 'node') {
      continue;
    }
    final id = element['id'];
    final lat = element['lat'];
    final lon = element['lon'];
    if (id is! int || lat is! num || lon is! num) {
      continue;
    }
    if (!lat.isFinite || !lon.isFinite) {
      continue;
    }
    nodes[id] = Map<String, Object?>.from(element);
  }
  return nodes;
}

String canonicalJsonEncode(Object? value) =>
    jsonEncode(canonicalJsonValue(value));

Object? canonicalJsonValue(Object? value) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const FormatException('Canonical JSON numbers must be finite.');
    }
    return value == value.roundToDouble() ? value.toInt() : value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(canonicalJsonValue));
  }
  if (value is Map) {
    final map = _stringKeyedMap(value, 'Canonical JSON object');
    final keys = map.keys.toList()
      ..sort((left, right) => left.compareTo(right));
    return Map<String, Object?>.unmodifiable({
      for (final key in keys) key: canonicalJsonValue(map[key]),
    });
  }
  throw FormatException(
    'Unsupported canonical JSON value: ${value.runtimeType}.',
  );
}

Map<String, Object?> _stringKeyedMap(
  Map<Object?, Object?> value,
  String context,
) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$context must use string keys.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

bool _isCanonicalAssetPath(String path) {
  if (!path.startsWith('assets/') ||
      path.startsWith('/') ||
      path.endsWith('/')) {
    return false;
  }
  final segments = path.split('/');
  return !path.contains('\\') &&
      segments.every(
        (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
      );
}

String? _osmIdentity(Object? element) {
  if (element is! Map) {
    return null;
  }
  final type = element['type'];
  final id = element['id'];
  return type is String && id is int ? '$type:$id' : null;
}

bool _samePriority(ManifestPriority left, ManifestPriority right) {
  if (left.segments.length != right.segments.length) {
    return false;
  }
  for (var index = 0; index < left.segments.length; index++) {
    if (left.segments[index] != right.segments[index]) {
      return false;
    }
  }
  return true;
}

class _CoverageDefinition {
  const _CoverageDefinition({required this.key, required this.displayName});

  final String key;
  final String displayName;
}

class _SourceRegion {
  const _SourceRegion({
    required this.key,
    required this.routingCoverage,
    required this.priority,
    required this.highwayPaths,
    required this.polygonPaths,
  });

  _SourceRegion.excluded({required this.key})
    : routingCoverage = null,
      priority = const ManifestPriority([]),
      highwayPaths = const [],
      polygonPaths = const [];

  final String key;
  final String? routingCoverage;
  final ManifestPriority priority;
  final List<String> highwayPaths;
  final List<String> polygonPaths;
}
