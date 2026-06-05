import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/map_polygon_asset.dart';

typedef PolygonAssetLoader = Future<String> Function(String assetPath);

class PolygonParseResult {
  const PolygonParseResult.success(this.asset) : error = null;

  const PolygonParseResult.failure(this.error) : asset = null;

  final MapPolygonAsset? asset;
  final String? error;

  bool get isSuccess => asset != null;
}

class PolygonAssetRepository {
  PolygonAssetRepository({PolygonAssetLoader? assetLoader})
    : _assetLoader = assetLoader ?? rootBundle.loadString;

  static const _manifestAssetPath = 'assets/polygons/manifest.json';

  final PolygonAssetLoader _assetLoader;

  Future<List<MapPolygonAsset>> loadPolygons() async {
    try {
      final manifestText = await _assetLoader(_manifestAssetPath);
      final decoded = jsonDecode(manifestText);
      if (decoded is! List) {
        developer.log(
          'Polygon manifest must be a JSON list of asset paths.',
          name: 'PolygonAssetRepository',
        );
        return const [];
      }

      final assetPaths = decoded
          .whereType<String>()
          .where((path) => path.toLowerCase().endsWith('.poly'))
          .toList(growable: false)
        ..sort();

      final polygons = <MapPolygonAsset>[];
      for (final assetPath in assetPaths) {
        try {
          final contents = await _assetLoader(assetPath);
          final parseResult = parsePolygonAsset(contents, assetPath: assetPath);
          if (parseResult.isSuccess) {
            polygons.add(parseResult.asset!);
          } else if (parseResult.error != null) {
            developer.log(
              'Skipping polygon asset $assetPath: ${parseResult.error}',
              name: 'PolygonAssetRepository',
            );
          }
        } catch (error) {
          developer.log(
            'Failed to load polygon asset $assetPath: $error',
            name: 'PolygonAssetRepository',
          );
        }
      }

      return polygons;
    } catch (error) {
      developer.log(
        'Failed to load polygon assets: $error',
        name: 'PolygonAssetRepository',
      );
      return const [];
    }
  }
}

PolygonParseResult parsePolygonAsset(
  String contents, {
  required String assetPath,
}) {
  final lines = const LineSplitter()
      .convert(contents)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  if (lines.length < 4) {
    return PolygonParseResult.failure(
      'Polygon asset $assetPath does not contain a complete ring.',
    );
  }

  final name = lines.first;
  final points = <LatLng>[];

  var index = 2;
  for (; index < lines.length; index++) {
    final line = lines[index];
    if (line == 'END') {
      break;
    }

    final parts = line.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      return PolygonParseResult.failure(
        'Polygon asset $assetPath has an invalid coordinate line: $line',
      );
    }

    final longitude = double.tryParse(parts[0]);
    final latitude = double.tryParse(parts[1]);
    if (longitude == null || latitude == null) {
      return PolygonParseResult.failure(
        'Polygon asset $assetPath has an invalid coordinate line: $line',
      );
    }

    points.add(LatLng(latitude, longitude));
  }

  if (index >= lines.length || lines[index] != 'END') {
    return PolygonParseResult.failure(
      'Polygon asset $assetPath is missing the end of the first ring.',
    );
  }

  if (points.length >= 2 && _samePoint(points.first, points.last)) {
    points.removeLast();
  }

  final distinctPoints = <String>{
    for (final point in points) '${point.latitude},${point.longitude}',
  };
  if (distinctPoints.length < 3) {
    return PolygonParseResult.failure(
      'Polygon asset $assetPath needs at least 3 distinct vertices.',
    );
  }

  for (final line in lines.skip(index + 1)) {
    if (line != 'END') {
      return PolygonParseResult.failure(
        'Polygon asset $assetPath contains unsupported additional rings.',
      );
    }
  }

  return PolygonParseResult.success(
    MapPolygonAsset(
      assetPath: assetPath,
      name: name,
      points: List.unmodifiable(points),
    ),
  );
}

bool _samePoint(LatLng left, LatLng right) {
  return left.latitude == right.latitude && left.longitude == right.longitude;
}
