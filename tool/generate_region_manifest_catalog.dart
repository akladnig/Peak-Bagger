import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

const _manifestPath = 'assets/region_manifest.json';
const _outputPath = 'lib/generated/region_manifest_catalog.g.dart';
const _baselineBasemapOrder = <String>[
  'tasmapTopo',
  'tasmap50k',
  'tasmap25k',
  'tracestrack',
  'openstreetmap',
  'mapyCz',
];

const _postBaselineBasemapOrder = <String>[
  'nswImagery',
  'nswBasemap',
  'nswTopo',
  'sloveniaTopo',
  'fvgTopo',
  'localTopo',
];

const _appOwnedBasemaps = <_BasemapDefinition>[
  _BasemapDefinition(
    key: 'localTopo',
    name: 'Local Topo',
    tileUrl: 'https://local-topo.invalid/{z}/{x}/{y}.png',
    attribution: 'OpenStreetMap contributors and State of Tasmania',
    maxZoom: 16,
    coveragePolygons: [],
  ),
];

void main(List<String> args) {
  final manifestFile = File(_manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Missing manifest: $_manifestPath');
    exitCode = 1;
    return;
  }

  final manifest = jsonDecode(manifestFile.readAsStringSync());
  if (manifest is! Map<String, dynamic>) {
    stderr.writeln('Manifest must be a JSON object.');
    exitCode = 1;
    return;
  }

  final seenBasemapOrder = <String>[];
  final basemapDefinitions = <String, _BasemapDefinition>{};
  final seenDisplayNames = <String, String>{};
  final seenPeakListFilterIdentifiers = <String, String>{};
  final regions = <_RegionDefinition>[];

  for (final entry in manifest.entries) {
    final regionKey = entry.key;
    final regionValue = entry.value;
    if (regionValue is! Map<String, dynamic>) {
      stderr.writeln('Region $regionKey must be a JSON object.');
      exitCode = 1;
      return;
    }

    final polygons = <List<LatLng>>[];
    final polygonPaths = _readStringList(
      regionValue['poly'],
      'poly',
      regionKey,
    );
    for (final polygonPath in polygonPaths) {
      final polygonFile = File(polygonPath);
      if (!polygonFile.existsSync()) {
        stderr.writeln('Missing polygon asset for $regionKey: $polygonPath');
        exitCode = 1;
        return;
      }

      final parseResult = parsePolygonText(polygonFile.readAsStringSync());
      if (!parseResult.isSuccess || parseResult.polygon == null) {
        stderr.writeln(
          'Invalid polygon asset for $regionKey: $polygonPath (${parseResult.error})',
        );
        exitCode = 1;
        return;
      }

      polygons.add(parseResult.polygon!.vertices);
    }

    final mapKeys = <String>[];
    final mapSet = _readStringList(regionValue['mapSet'], 'mapSet', regionKey);
    final maps = _readList(regionValue['maps'], 'maps', regionKey);
    for (final mapEntry in maps) {
      if (mapEntry is! Map<String, dynamic>) {
        stderr.writeln('Map entry for $regionKey must be an object.');
        exitCode = 1;
        return;
      }

      final definition = _BasemapDefinition.fromJson(mapEntry, regionKey);
      final existing = basemapDefinitions[definition.key];
      if (existing == null) {
        basemapDefinitions[definition.key] = definition;
        seenBasemapOrder.add(definition.key);
      } else if (!existing.isCompatibleWith(definition)) {
        stderr.writeln(
          'Basemap key conflict for ${definition.key} in $regionKey',
        );
        exitCode = 1;
        return;
      }

      if (!mapKeys.contains(definition.key)) {
        mapKeys.add(definition.key);
      }
    }

    final peakListFilterAliases = _readPeakListFilterAliases(
      regionValue,
      regionKey,
    );
    final name = _readRegionName(regionValue, regionKey);
    _registerDisplayName(
      seenDisplayNames,
      displayName: name,
      regionKey: regionKey,
    );
    _registerPeakListFilterIdentifiers(
      seenPeakListFilterIdentifiers,
      regionKey: regionKey,
      peakListFilterAliases: peakListFilterAliases,
    );

    regions.add(
      _RegionDefinition(
        key: regionKey,
        name: name,
        shortName: _readRegionShortName(regionValue, regionKey),
        priority: _readRegionPriority(regionValue, regionKey),
        showInPeakList: _readRegionShowInPeakList(regionValue, regionKey),
        peakListFilterAliases: peakListFilterAliases,
        polygons: polygons,
        basemapKeys: mapKeys,
        mapSet: mapSet,
      ),
    );
  }

  final mergedBasemapDefinitions = _mergeAppOwnedBasemaps(basemapDefinitions);

  final orderedBasemapKeys = <String>[
    for (final key in _baselineBasemapOrder)
      if (mergedBasemapDefinitions.containsKey(key)) key,
    for (final key in _postBaselineBasemapOrder)
      if (mergedBasemapDefinitions.containsKey(key)) key,
    for (final key in seenBasemapOrder)
      if (!_baselineBasemapOrder.contains(key) &&
          !_postBaselineBasemapOrder.contains(key))
        key,
    for (final basemap in _appOwnedBasemaps)
      if (!_baselineBasemapOrder.contains(basemap.key) &&
          !_postBaselineBasemapOrder.contains(basemap.key) &&
          !seenBasemapOrder.contains(basemap.key))
        basemap.key,
  ];

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln(
      '// ignore_for_file: constant_identifier_names, unnecessary_const',
    )
    ..writeln()
    ..writeln(
      "part of 'package:peak_bagger/services/region_manifest_catalog.dart';",
    )
    ..writeln()
    ..writeln('enum Basemap {')
    ..writeln(orderedBasemapKeys.map((key) => '  $key,').join('\n'))
    ..writeln('}')
    ..writeln()
    ..writeln('const regionManifestCatalogData = RegionManifestCatalogData(')
    ..writeln('  basemaps: [');

  for (final key in orderedBasemapKeys) {
    final basemap = mergedBasemapDefinitions[key]!;
    buffer
      ..writeln('    RegionManifestBasemapData(')
      ..writeln('      key: ${_stringLiteral(basemap.key)},')
      ..writeln('      name: ${_stringLiteral(basemap.name)},')
      ..writeln('      tileUrl: ${_stringLiteral(basemap.tileUrl)},')
      ..writeln('      attribution: ${_stringLiteral(basemap.attribution)},');
    if (basemap.maxZoom != null) {
      buffer.writeln('      maxZoom: ${basemap.maxZoom},');
    }
    buffer.writeln('      coveragePolygons: [');
    for (final polygon in basemap.coveragePolygons) {
      buffer.writeln('        [');
      for (final point in polygon) {
        buffer.writeln(
          '          const LatLng(${_doubleLiteral(point.latitude)}, ${_doubleLiteral(point.longitude)}),',
        );
      }
      buffer.writeln('        ],');
    }
    buffer.writeln('      ],');
    buffer.writeln('    ),');
  }

  buffer.writeln('  ],');
  buffer.writeln('  regions: [');

  for (final region in regions) {
    buffer
      ..writeln('    RegionManifestRegionData(')
      ..writeln('      key: ${_stringLiteral(region.key)},')
      ..writeln('      name: ${_stringLiteral(region.name)},')
      ..writeln('      shortName: ${_stringLiteral(region.shortName)},')
      ..writeln(
        '      priority: const ManifestPriority([${region.priority.segments.join(', ')}]),',
      )
      ..writeln('      showInPeakList: ${region.showInPeakList},')
      ..writeln('      peakListFilterAliases: [');
    for (final alias in region.peakListFilterAliases) {
      buffer.writeln('        ${_stringLiteral(alias)},');
    }
    buffer.writeln('      ],');
    buffer.writeln('      polygons: [');

    for (final polygon in region.polygons) {
      buffer.writeln('        [');
      for (final point in polygon) {
        buffer.writeln(
          '          const LatLng(${_doubleLiteral(point.latitude)}, ${_doubleLiteral(point.longitude)}),',
        );
      }
      buffer.writeln('        ],');
    }

    buffer
      ..writeln('      ],')
      ..writeln('      mapSet: [');
    for (final key in region.mapSet) {
      buffer.writeln('        ${_stringLiteral(key)},');
    }
    buffer
      ..writeln('      ],')
      ..writeln('      basemapKeys: [');
    for (final key in region.basemapKeys) {
      buffer.writeln('        ${_stringLiteral(key)},');
    }
    buffer
      ..writeln('      ],')
      ..writeln('    ),');
  }

  buffer
    ..writeln('  ],')
    ..writeln(');');

  final outputFile = File(_outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(buffer.toString());
}

Map<String, _BasemapDefinition> _mergeAppOwnedBasemaps(
  Map<String, _BasemapDefinition> basemapDefinitions,
) {
  final merged = <String, _BasemapDefinition>{...basemapDefinitions};
  for (final basemap in _appOwnedBasemaps) {
    final existing = merged[basemap.key];
    if (existing == null) {
      merged[basemap.key] = basemap;
      continue;
    }

    if (!existing.isCompatibleWith(basemap)) {
      throw StateError('App-owned basemap key conflict for ${basemap.key}');
    }
  }
  return merged;
}

List<dynamic> _readList(dynamic value, String field, String regionKey) {
  if (value is! List<dynamic>) {
    stderr.writeln('Region $regionKey must define a list for $field.');
    exitCode = 1;
    return const [];
  }
  return value;
}

List<String> _readStringList(dynamic value, String field, String regionKey) {
  final items = _readList(value, field, regionKey);
  return items.cast<String>();
}

String _readRegionName(Map<String, dynamic> regionValue, String regionKey) {
  final name = regionValue['name'];
  if (name is! String || name.trim().isEmpty) {
    stderr.writeln(
      'Region $regionKey must define a non-empty string for name.',
    );
    exitCode = 1;
    return regionKey;
  }
  return name;
}

ManifestPriority _readRegionPriority(
  Map<String, dynamic> regionValue,
  String regionKey,
) {
  final priority = regionValue['priority'];
  if (priority is! String) {
    stderr.writeln(
      'Region $regionKey must define a non-empty string for priority.',
    );
    exitCode = 1;
    return const ManifestPriority([0]);
  }

  try {
    return ManifestPriority.parse(priority, regionKey: regionKey);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
    return const ManifestPriority([0]);
  }
}

String _readRegionShortName(
  Map<String, dynamic> regionValue,
  String regionKey,
) {
  final shortName = regionValue['shortName'];
  if (shortName == null) {
    return _readRegionName(regionValue, regionKey);
  }
  if (shortName is! String || shortName.trim().isEmpty) {
    stderr.writeln(
      'Region $regionKey must define a non-empty string for shortName when present.',
    );
    exitCode = 1;
    return _readRegionName(regionValue, regionKey);
  }
  return shortName;
}

bool? _readRegionShowInPeakList(
  Map<String, dynamic> regionValue,
  String regionKey,
) {
  final showInPeakList = regionValue['showInPeakList'];
  if (showInPeakList == null) {
    return null;
  }
  if (showInPeakList is bool) {
    return showInPeakList;
  }
  if (showInPeakList is String) {
    return switch (showInPeakList.trim().toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => _invalidShowInPeakListValue(regionKey),
    };
  }

  return _invalidShowInPeakListValue(regionKey);
}

bool? _invalidShowInPeakListValue(String regionKey) {
  stderr.writeln(
    'Region $regionKey must define showInPeakList as true, false, or omit the field.',
  );
  exitCode = 1;
  return null;
}

List<String> _readPeakListFilterAliases(
  Map<String, dynamic> regionValue,
  String regionKey,
) {
  final aliases = _readOptionalStringList(
    regionValue['peakListFilterAliases'],
    'peakListFilterAliases',
    regionKey,
  );

  return [
    for (final alias in aliases)
      _normalizePeakListFilterIdentifier(alias, regionKey),
  ];
}

void _registerPeakListFilterIdentifiers(
  Map<String, String> seenPeakListFilterIdentifiers, {
  required String regionKey,
  required List<String> peakListFilterAliases,
}) {
  for (final alias in peakListFilterAliases) {
    _registerPeakListFilterIdentifier(
      seenPeakListFilterIdentifiers,
      identifier: alias,
      ownerRegionKey: regionKey,
    );
  }
}

void _registerDisplayName(
  Map<String, String> seenDisplayNames, {
  required String displayName,
  required String regionKey,
}) {
  final normalized = displayName.trim();
  final previousOwner = seenDisplayNames[normalized];
  if (previousOwner != null) {
    stderr.writeln(
      'Duplicate manifest display name "$normalized" for $regionKey and $previousOwner.',
    );
    exitCode = 1;
    return;
  }

  seenDisplayNames[normalized] = regionKey;
}

void _registerPeakListFilterIdentifier(
  Map<String, String> seenPeakListFilterIdentifiers, {
  required String identifier,
  required String ownerRegionKey,
}) {
  final previousOwner = seenPeakListFilterIdentifiers[identifier];
  if (previousOwner != null) {
    stderr.writeln(
      'Duplicate peak-list filter alias "$identifier" for $ownerRegionKey and $previousOwner.',
    );
    exitCode = 1;
    return;
  }
  seenPeakListFilterIdentifiers[identifier] = ownerRegionKey;
}

String _normalizePeakListFilterIdentifier(String value, String regionKey) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    stderr.writeln(
      'Region $regionKey must not contain empty peak-list filter aliases.',
    );
    exitCode = 1;
  }
  return normalized;
}

String _stringLiteral(String value) =>
    "'${value.replaceAll("\\", "\\\\").replaceAll("'", "\\'")}'";

String _doubleLiteral(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(1);
  }
  return value.toString();
}

List<String> _readOptionalStringList(
  dynamic value,
  String field,
  String regionKey,
) {
  if (value == null) {
    return const [];
  }

  return _readStringList(value, field, regionKey);
}

List<List<LatLng>> _loadPolygonVertices(
  List<String> polygonPaths,
  String context,
  String ownerKey,
) {
  final polygons = <List<LatLng>>[];
  for (final polygonPath in polygonPaths) {
    final polygonFile = File(polygonPath);
    if (!polygonFile.existsSync()) {
      stderr.writeln('Missing polygon asset for $ownerKey: $polygonPath');
      exitCode = 1;
      return const [];
    }

    final parseResult = parsePolygonText(polygonFile.readAsStringSync());
    if (!parseResult.isSuccess || parseResult.polygon == null) {
      stderr.writeln(
        'Invalid polygon asset for $ownerKey $context: $polygonPath (${parseResult.error})',
      );
      exitCode = 1;
      return const [];
    }

    polygons.add(parseResult.polygon!.vertices);
  }

  return polygons;
}

bool _polygonsEqual(List<List<LatLng>> left, List<List<LatLng>> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var polygonIndex = 0; polygonIndex < left.length; polygonIndex++) {
    final leftPolygon = left[polygonIndex];
    final rightPolygon = right[polygonIndex];
    if (leftPolygon.length != rightPolygon.length) {
      return false;
    }

    for (var pointIndex = 0; pointIndex < leftPolygon.length; pointIndex++) {
      final leftPoint = leftPolygon[pointIndex];
      final rightPoint = rightPolygon[pointIndex];
      if (leftPoint.latitude != rightPoint.latitude ||
          leftPoint.longitude != rightPoint.longitude) {
        return false;
      }
    }
  }

  return true;
}

class _BasemapDefinition {
  const _BasemapDefinition({
    required this.key,
    required this.name,
    required this.tileUrl,
    required this.attribution,
    required this.maxZoom,
    required this.coveragePolygons,
  });

  factory _BasemapDefinition.fromJson(
    Map<String, dynamic> json,
    String regionKey,
  ) {
    final key = json['key'];
    final name = json['name'];
    final tileUrl = json['tileUrl'];
    final attribution = json['attribution'];
    if (key is! String ||
        name is! String ||
        tileUrl is! String ||
        attribution is! String) {
      throw StateError('Invalid basemap entry in $regionKey');
    }

    final maxZoom = json['maxZoom'];
    if (maxZoom != null && maxZoom is! num) {
      throw StateError('Invalid maxZoom for $key in $regionKey');
    }

    final coveragePaths = _readOptionalStringList(
      json['coveragePoly'],
      'coveragePoly',
      regionKey,
    );
    final coveragePolygons = _loadPolygonVertices(
      coveragePaths,
      'coveragePoly',
      regionKey,
    );

    return _BasemapDefinition(
      key: key,
      name: name,
      tileUrl: tileUrl,
      attribution: attribution,
      maxZoom: maxZoom?.toInt(),
      coveragePolygons: coveragePolygons,
    );
  }

  final String key;
  final String name;
  final String tileUrl;
  final String attribution;
  final int? maxZoom;
  final List<List<LatLng>> coveragePolygons;

  bool isCompatibleWith(_BasemapDefinition other) {
    return key == other.key &&
        name == other.name &&
        tileUrl == other.tileUrl &&
        attribution == other.attribution &&
        maxZoom == other.maxZoom &&
        _polygonsEqual(coveragePolygons, other.coveragePolygons);
  }
}

class _RegionDefinition {
  const _RegionDefinition({
    required this.key,
    required this.name,
    required this.shortName,
    required this.priority,
    required this.showInPeakList,
    required this.peakListFilterAliases,
    required this.polygons,
    required this.basemapKeys,
    required this.mapSet,
  });

  final String key;
  final String name;
  final String shortName;
  final ManifestPriority priority;
  final bool? showInPeakList;
  final List<String> peakListFilterAliases;
  final List<List<LatLng>> polygons;
  final List<String> basemapKeys;
  final List<String> mapSet;
}
