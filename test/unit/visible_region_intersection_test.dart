import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

void main() {
  test('regionsForBounds returns intersecting regions for mixed viewport', () {
    final regions = regionManifestCatalog.regionsForBounds(
      _bounds(south: -44.0, west: 143.0, north: -35.0, east: 149.0),
    );

    expect(
      regions.map((region) => region.key),
      containsAll(<String>['tasmania', 'new-south-wales']),
    );
  });

  test('mapSetForBounds unions supported sheet datasets across viewport', () {
    expect(
      regionManifestCatalog.mapSetForBounds(
        _bounds(south: -44.0, west: 143.0, north: -35.0, east: 149.0),
      ),
      {'tasmap50k'},
    );
    expect(
      regionManifestCatalog.mapSetForBounds(
        _bounds(south: 45.5, west: 13.5, north: 46.8, east: 16.5),
      ),
      isEmpty,
    );
  });
}

LatLngBounds _bounds({
  required double south,
  required double west,
  required double north,
  required double east,
}) {
  return LatLngBounds(LatLng(south, west), LatLng(north, east));
}
