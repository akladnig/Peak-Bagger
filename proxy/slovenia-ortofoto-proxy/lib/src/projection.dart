import 'package:proj4dart/proj4dart.dart' as proj4;

const webMercatorOriginShift = 20037508.342789244;
const sloveniaProjectionCode = 'EPSG:3794';
const sloveniaProjectionDef =
    '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs';

final _webMercatorProjection = proj4.Projection.get('EPSG:3857')!;
final _sloveniaProjection =
    proj4.Projection.get(sloveniaProjectionCode) ??
    proj4.Projection.add(sloveniaProjectionCode, sloveniaProjectionDef);

const sloveniaCoverageBounds = ProjectedBounds(
  minX: 374000,
  minY: 28000,
  maxX: 626000,
  maxY: 196000,
);

class TileCoordinate {
  const TileCoordinate({required this.z, required this.x, required this.y});

  final int z;
  final int x;
  final int y;

  static TileCoordinate? tryParse(
    List<String> pathSegments, {
    required String routePrefix,
  }) {
    if (pathSegments.length != 4 || pathSegments.first != routePrefix) {
      return null;
    }

    final z = int.tryParse(pathSegments[1]);
    final x = int.tryParse(pathSegments[2]);
    final ySegment = pathSegments[3];
    if (!ySegment.endsWith('.png')) {
      return null;
    }
    final y = int.tryParse(ySegment.substring(0, ySegment.length - 4));

    if (z == null || x == null || y == null || z < 0 || x < 0 || y < 0) {
      return null;
    }

    final tileCount = 1 << z;
    if (x >= tileCount || y >= tileCount) {
      return null;
    }

    return TileCoordinate(z: z, x: x, y: y);
  }
}

class ProjectedBounds {
  const ProjectedBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  bool intersects(ProjectedBounds other) {
    return maxX > other.minX &&
        minX < other.maxX &&
        maxY > other.minY &&
        minY < other.maxY;
  }

  String toBboxString() {
    return '${_formatCoord(minX)},${_formatCoord(minY)},${_formatCoord(maxX)},${_formatCoord(maxY)}';
  }
}

String _formatCoord(double value) => value.toStringAsFixed(3);

ProjectedBounds tileBoundsInWebMercator(TileCoordinate coordinate) {
  final tileCount = 1 << coordinate.z;
  final fullExtent = webMercatorOriginShift * 2;
  final minX = coordinate.x / tileCount * fullExtent - webMercatorOriginShift;
  final maxX =
      (coordinate.x + 1) / tileCount * fullExtent - webMercatorOriginShift;
  final maxY = webMercatorOriginShift - coordinate.y / tileCount * fullExtent;
  final minY =
      webMercatorOriginShift - (coordinate.y + 1) / tileCount * fullExtent;
  return ProjectedBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

ProjectedBounds projectTileBoundsToSloveniaCrs(TileCoordinate coordinate) {
  final webBounds = tileBoundsInWebMercator(coordinate);
  final points = [
    proj4.Point(x: webBounds.minX, y: webBounds.minY),
    proj4.Point(x: webBounds.minX, y: webBounds.maxY),
    proj4.Point(x: webBounds.maxX, y: webBounds.minY),
    proj4.Point(x: webBounds.maxX, y: webBounds.maxY),
  ];

  final transformed = points
      .map((point) => _webMercatorProjection.transform(_sloveniaProjection, point))
      .toList(growable: false);

  final xs = transformed.map((point) => point.x);
  final ys = transformed.map((point) => point.y);
  return ProjectedBounds(
    minX: xs.reduce((left, right) => left < right ? left : right),
    minY: ys.reduce((left, right) => left < right ? left : right),
    maxX: xs.reduce((left, right) => left > right ? left : right),
    maxY: ys.reduce((left, right) => left > right ? left : right),
  );
}
