import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

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

      final assetPaths =
          decoded
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
  final parseResult = parsePolygonText(contents);
  if (!parseResult.isSuccess) {
    return PolygonParseResult.failure(
      _assetErrorMessage(assetPath, parseResult.error!),
    );
  }

  return PolygonParseResult.success(
    MapPolygonAsset(
      assetPath: assetPath,
      name: parseResult.polygon!.name,
      points: parseResult.polygon!.vertices,
    ),
  );
}

String _assetErrorMessage(String assetPath, String error) {
  const prefix = 'Polygon text';
  if (error.startsWith(prefix)) {
    return 'Polygon asset $assetPath${error.substring(prefix.length)}';
  }

  return 'Polygon asset $assetPath: $error';
}
