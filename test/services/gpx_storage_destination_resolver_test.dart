import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/gpx_storage_destination_resolver.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

void main() {
  late GpxStorageDestinationResolver resolver;

  setUp(() {
    resolver = GpxStorageDestinationResolver(
      polygonAssetRepository: PolygonAssetRepository(
        assetLoader: (assetPath) async => File(assetPath).readAsString(),
      ),
    );
  });

  test('resolves Tasmania with region folder', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(-43.0, 147.0),
    );

    expect(destination, isNotNull);
    expect(destination!.country, 'Australia');
    expect(destination.region, 'Tasmania');
    expect(destination.relativeFolder, 'Australia/Tasmania');
  });

  test('resolves NSW with region folder', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(-36.5, 148.3),
    );

    expect(destination, isNotNull);
    expect(destination!.country, 'Australia');
    expect(destination.region, 'NSW');
    expect(destination.relativeFolder, 'Australia/NSW');
  });

  test('resolves Italy nord-est with region folder', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(45.7730, 13.6200),
    );

    expect(destination, isNotNull);
    expect(destination!.country, 'Italy');
    expect(destination.region, 'nord-est');
    expect(destination.relativeFolder, 'Italy/nord-est');
  });

  test('resolves Italy nord-ovest with region folder', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(45.0703, 7.6869),
    );

    expect(destination, isNotNull);
    expect(destination!.country, 'Italy');
    expect(destination.region, 'nord-ovest');
    expect(destination.relativeFolder, 'Italy/nord-ovest');
  });

  test('resolves Slovenia without region folder', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(46.0569, 14.5058),
    );

    expect(destination, isNotNull);
    expect(destination!.country, 'Slovenia');
    expect(destination.region, isNull);
    expect(destination.relativeFolder, 'Slovenia');
    expect(
      destination.trackFolderPath(bushwalkingRoot: '/tmp/Bushwalking'),
      p.join('/tmp/Bushwalking', 'Tracks', 'Slovenia'),
    );
    expect(
      destination.routeFolderPath(bushwalkingRoot: '/tmp/Bushwalking'),
      p.join('/tmp/Bushwalking', 'Routes', 'Slovenia'),
    );
  });

  test('resolves Croatia without region folder', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(45.8150, 15.9819),
    );

    expect(destination, isNotNull);
    expect(destination!.country, 'Croatia');
    expect(destination.region, isNull);
    expect(destination.relativeFolder, 'Croatia');
  });

  test('returns null for unsupported points', () async {
    final destination = await resolver.resolveForPoint(
      const LatLng(-37.8136, 144.9631),
    );

    expect(destination, isNull);
  });
}
