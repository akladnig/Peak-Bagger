import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

void main() {
  test('parsePolygonAsset reads the bundled tasmania polygon', () async {
    final contents = await File('assets/polygons/tasmania.poly').readAsString();
    final result = parsePolygonAsset(
      contents,
      assetPath: 'assets/polygons/tasmania.poly',
    );

    expect(result.isSuccess, isTrue);
    expect(result.asset!.assetPath, 'assets/polygons/tasmania.poly');
    expect(result.asset!.name, 'none');
    expect(result.asset!.points, hasLength(9));
    expect(result.asset!.points.first, const LatLng(-56.86236, 152.8587));
  });

  test('parsePolygonAsset rejects malformed coordinates', () {
    final result = parsePolygonAsset(
      'none\n1\ninvalid line\nEND\nEND\n',
      assetPath: 'assets/polygons/broken.poly',
    );

    expect(result.isSuccess, isFalse);
    expect(result.error, contains('assets/polygons/broken.poly'));
    expect(result.error, contains('invalid coordinate line'));
  });

  test('loadPolygons filters asset manifest polygon paths', () async {
    final tasmania = await File('assets/polygons/tasmania.poly').readAsString();
    final repository = PolygonAssetRepository(
      assetLoader: (assetPath) async {
        return switch (assetPath) {
          'assets/polygons/manifest.json' => jsonEncode([
            'assets/polygons/alpha.poly',
            'assets/polygons/tasmania.poly',
            'assets/peak_marker.svg',
          ]),
          'assets/polygons/alpha.poly' =>
            'none\n1\n0 0\n1 0\n1 1\n0 0\nEND\nEND\n',
          'assets/polygons/tasmania.poly' => tasmania,
          _ => throw StateError('Unexpected asset: $assetPath'),
        };
      },
    );

    final polygons = await repository.loadPolygons();

    expect(polygons, hasLength(2));
    expect(polygons.first.assetPath, 'assets/polygons/alpha.poly');
    expect(polygons.last.assetPath, 'assets/polygons/tasmania.poly');
    expect(polygons.first.points, hasLength(3));
  });
}
