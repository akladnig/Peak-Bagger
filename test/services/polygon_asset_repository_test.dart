import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

void main() {
  test('parsePolygonAsset reads a Tasmania fixture polygon', () {
    final result = parsePolygonAsset(
      _tasmaniaPolygon,
      assetPath: 'assets/polygons/tasmania.poly',
    );

    expect(result.isSuccess, isTrue);
    expect(result.asset!.assetPath, 'assets/polygons/tasmania.poly');
    expect(result.asset!.name, 'none');
    expect(result.asset!.points, hasLength(8));
    expect(result.asset!.points.first, const LatLng(-44.0, 148.8867));
  });

  test('parsePolygonAsset reads a Croatia fixture polygon', () {
    final result = parsePolygonAsset(
      _croatiaPolygon,
      assetPath: 'assets/polygons/croatia.poly',
    );

    expect(result.isSuccess, isTrue);
    expect(result.asset!.assetPath, 'assets/polygons/croatia.poly');
    expect(result.asset!.name, 'none');
    expect(result.asset!.points, isNotEmpty);
    expect(result.asset!.points.first, const LatLng(42.43746, 18.51463));
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
          'assets/polygons/tasmania.poly' => _tasmaniaPolygon,
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

const _tasmaniaPolygon = '''
none
1
148.8867 -44.0
143.4704 -44.0
143.4704 -39.1982
146.2510 -39.19759
146.6251 -39.19687
146.9203 -39.19721
147.1105 -39.19767
148.8867 -39.52946
END
END
''';

const _croatiaPolygon = '''
none
1
18.51463 42.43746
18.53434 42.42769
18.55029 42.38946
18.48013 42.24400
END
END
''';
