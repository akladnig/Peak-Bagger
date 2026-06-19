const webMercatorOriginShift = 20037508.342789244;

const fvgCoverageBounds = ProjectedBounds(
  minX: 1370000.0,
  minY: 5710000.0,
  maxX: 1555000.0,
  maxY: 5890000.0,
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
