// Copyright 2011 Tomo Krajina
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math' as math;

// Generic geo related functions and classes.

// Latitude/longitude in GPX files is always in WGS84 datum.
// WGS84 defines the Earth semi-major axis as 6378.137 km.
const double earthRadius = 6378.137 * 1000;

// One degree in meters.
const double oneDegree = (2 * math.pi * earthRadius) / 360;

double _radians(double degrees) => degrees * math.pi / 180;

double _degrees(double radians) => radians * 180 / math.pi;

/// Haversine distance between two points, expressed in meters.
///
/// Implemented from http://www.movable-type.co.uk/scripts/latlong.html.
double haversineDistance(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  final dLon = _radians(longitude1 - longitude2);
  final lat1 = _radians(latitude1);
  final lat2 = _radians(latitude2);
  final dLat = lat1 - lat2;

  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.pow(math.sin(dLon / 2), 2) * math.cos(lat1) * math.cos(lat2);
  final c = 2 * math.asin(math.sqrt(a));
  return earthRadius * c;
}

/// The initial course from one point to another,
/// expressed in decimal degrees clockwise from true North
/// (not magnetic)
/// (0.0 <= value < 360.0).
///
/// Use the default loxodromic model in most cases
/// (except when visualizing the long routes of maritime transport and aeroplanes).
///
/// Implemented from http://www.movable-type.co.uk/scripts/latlong.html
/// (sections 'Bearing' and 'Rhumb lines').
double getCourse(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2, {
  bool loxodromic = true,
}) {
  // The initial course from one point to another, expressed in decimal degrees
  // clockwise from true North.
  final dLon = _radians(longitude2 - longitude1);
  final lat1 = _radians(latitude1);
  final lat2 = _radians(latitude2);

  double y;
  double x;

  if (!loxodromic) {
    y = math.sin(dLon) * math.cos(lat2);
    x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  } else {
    var adjustedDLon = dLon;
    const radianCircle = 2 * math.pi;

    if (adjustedDLon.abs() > math.pi) {
      adjustedDLon = adjustedDLon > 0
          ? -(radianCircle - adjustedDLon)
          : radianCircle + adjustedDLon;
    }

    y = adjustedDLon;
    const delta = math.pi / 4;
    x = math.log(math.tan(delta + 0.5 * lat2) / math.tan(delta + 0.5 * lat1));
  }

  final course = _degrees(math.atan2(y, x));
  return (course % 360 + 360) % 360;
}

/// Compute the total length between locations.
///
/// Parameters:
/// - `locations`: list with `Location` objects to calculate the length between.
/// - `use3d`: true uses the 3D distance with elevation.
///   false uses the 2D distance without elevation.
///
/// Returns the sum of the length between consecutive locations in meters.
double length(List<Location> locations, {bool use3d = false}) {
  if (locations.isEmpty) {
    return 0;
  }

  var total = 0.0;
  for (var i = 1; i < locations.length; i++) {
    final previousLocation = locations[i - 1];
    final location = locations[i];
    final d = use3d
        ? location.distance3d(previousLocation)
        : location.distance2d(previousLocation);
    if (d != null && d != 0) {
      total += d;
    }
  }
  return total;
}

/// 2-dimensional length (meters) of locations (only latitude and longitude,
/// no elevation).
double length2d(List<Location> locations) => length(locations, use3d: false);

/// 3-dimensional length (meters) of locations (it uses latitude, longitude,
/// and elevation).
double length3d(List<Location> locations) => length(locations, use3d: true);

/// Compute average distance and standard deviation for distance. Extremes
/// in distances are usually extremes in speeds, so we will ignore them,
/// here.
///
/// `speedsAndDistances` must be a list containing pairs of `(speed, distance)`
/// for every point in a track segment.
///
/// In many cases the top speeds are measurement errors. For that reason
/// extreme speeds can be removed with the `extreemesPercentile` (for example,
/// a value of `0.05` will remove top 5%).
double? calculateMaxSpeed(
  List<List<double>> speedsAndDistances,
  double extreemesPercentile,
  bool ignoreNonstandardDistances,
) {
  assert(speedsAndDistances.isNotEmpty);
  if (speedsAndDistances.isNotEmpty) {
    assert(speedsAndDistances.first.length == 2);
    assert(speedsAndDistances.last.length == 2);
  }

  if (!ignoreNonstandardDistances) {
    return speedsAndDistances.map((x) => x[0]).reduce(math.max);
  }

  final size = speedsAndDistances.length;
  if (size < 2) {
    return null;
  }

  final distances = speedsAndDistances.map((x) => x[1]).toList();
  final averageDistance = distances.reduce((a, b) => a + b) / size;
  final standardDistanceDeviation = math.sqrt(
    distances
            .map((distance) => math.pow(distance - averageDistance, 2))
            .reduce((a, b) => a + b) /
        size,
  );

  // Ignore items where the distance is too big.
  final filteredSpeedsAndDistances = speedsAndDistances
      .where(
        (x) =>
            (x[1] - averageDistance).abs() <= standardDistanceDeviation * 1.5,
      )
      .toList();

  // Sort by speed.
  final speeds = filteredSpeedsAndDistances.map((x) => x[0]).toList();
  if (speeds.isEmpty) {
    return null;
  }
  speeds.sort();

  // Even here there may be some extremes, so ignore the last 5%.
  var index = (speeds.length * (1 - extreemesPercentile)).toInt();
  if (index >= speeds.length) {
    index = speeds.length - 1;
  }

  return speeds[index];
}

/// Compute the total uphill and downhill elevation for a list of elevations.
/// Note that the result is smoothened.
///
/// Parameters:
/// - `elevations`: list of elevations to calculate the total up-/downhill
///   elevation between. If elevation is missing for a point, `null` can be used.
///
/// Returns a tuple of total `(uphill, downhill)` elevation. (smoothened)
({double uphill, double downhill}) calculateUphillDownhill(
  List<double?> elevations,
) {
  if (elevations.isEmpty) {
    return (uphill: 0, downhill: 0);
  }

  final filteredElevations = elevations.whereType<double>().toList();
  if (filteredElevations.isEmpty) {
    return (uphill: 0, downhill: 0);
  }

  final smoothedElevations = <double>[];
  for (var i = 0; i < filteredElevations.length; i++) {
    final currentEle = filteredElevations[i];
    if (i > 0 && i < filteredElevations.length - 1) {
      final previousEle = filteredElevations[i - 1];
      final nextEle = filteredElevations[i + 1];
      smoothedElevations.add(previousEle * .3 + currentEle * .4 + nextEle * .3);
    } else {
      smoothedElevations.add(currentEle);
    }
  }

  var uphill = 0.0;
  var downhill = 0.0;
  for (var i = 1; i < smoothedElevations.length; i++) {
    final d = smoothedElevations[i] - smoothedElevations[i - 1];
    if (d > 0) {
      uphill += d;
    } else {
      downhill -= d;
    }
  }

  return (uphill: uphill, downhill: downhill);
}

/// Distance between two points. If elevation is `null` compute a 2D distance.
///
/// If `haversine == true` - haversine will be used for every computation,
/// otherwise...
///
/// Haversine distance will be used for distant points where elevation makes a
/// small difference, so it is ignored. That's because haversine is 5-6 times
/// slower than the dummy distance algorithm (which is OK for most GPS tracks).
double distance(
  double latitude1,
  double longitude1,
  double? elevation1,
  double latitude2,
  double longitude2,
  double? elevation2, {
  bool haversine = false,
}) {
  // If points are too distant, compute haversine distance.
  if (haversine ||
      (latitude1 - latitude2).abs() > .2 ||
      (longitude1 - longitude2).abs() > .2) {
    return haversineDistance(latitude1, longitude1, latitude2, longitude2);
  }

  final coef = math.cos(_radians(latitude1));
  final x = latitude1 - latitude2;
  final y = (longitude1 - longitude2) * coef;

  final distance2d = math.sqrt(x * x + y * y) * oneDegree;

  if (elevation1 == null || elevation2 == null || elevation1 == elevation2) {
    return distance2d;
  }

  return math.sqrt(
    distance2d * distance2d + math.pow(elevation1 - elevation2, 2),
  );
}

/// Uphill/downhill angle between two locations.
double? _elevationAngle(
  Location location1,
  Location location2, {
  bool radians = false,
}) {
  if (location1.elevation == null || location2.elevation == null) {
    return null;
  }

  final b = location2.elevation! - location1.elevation!;
  final a = location2.distance2d(location1);
  if (a == null || a == 0) {
    return 0;
  }

  final angle = math.atan(b / a);
  return radians ? angle : _degrees(angle);
}

/// Uphill/downhill angle between two locations.
double? elevationAngle(
  Location location1,
  Location location2, {
  bool radians = false,
}) {
  return _elevationAngle(location1, location2, radians: radians);
}

/// Distance of point from a line given with two points.
double? distanceFromLine(
  Location point,
  Location linePoint1,
  Location linePoint2,
) {
  final a = linePoint1.distance2d(linePoint2);
  if (a == null || a == 0) {
    return linePoint1.distance2d(point);
  }

  final b = linePoint1.distance2d(point);
  final c = linePoint2.distance2d(point);

  if (b != null && c != null) {
    final s = (a + b + c) / 2;
    return 2 * math.sqrt((s * (s - a) * (s - b) * (s - c)).abs()) / a;
  }
  return null;
}

/// Distance of point from a finite line segment given with two points.
double? distanceFromSegment(
  Location point,
  Location linePoint1,
  Location linePoint2,
) {
  final latMean = _radians(
    (point.latitude + linePoint1.latitude + linePoint2.latitude) / 3,
  );

  double toX(Location location) {
    return location.longitude * math.cos(latMean) * oneDegree;
  }

  double toY(Location location) {
    return location.latitude * oneDegree;
  }

  final ax = toX(linePoint1);
  final ay = toY(linePoint1);
  final bx = toX(linePoint2);
  final by = toY(linePoint2);
  final px = toX(point);
  final py = toY(point);

  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
  }

  final projection = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
  final t = projection.clamp(0.0, 1.0);
  final closestX = ax + dx * t;
  final closestY = ay + dy * t;
  return math.sqrt(
    (px - closestX) * (px - closestX) + (py - closestY) * (py - closestY),
  );
}

/// Get line equation coefficients for:
///
///     latitude * a + longitude * b + c = 0
///
/// This is a normal cartesian line (not spherical!).
List<double> getLineEquationCoefficients(
  Location location1,
  Location location2,
) {
  // Latitude * a + longitude * b + c = 0.
  if (location1.longitude == location2.longitude) {
    return [0, 1, -location1.longitude];
  }

  final a =
      (location1.latitude - location2.latitude) /
      (location1.longitude - location2.longitude);
  final b = location1.latitude - location1.longitude * a;
  return [1, -a, -b];
}

/// Does Ramer-Douglas-Peucker algorithm for simplification of polyline.
List<Location> simplifyPolyline(List<Location> points, double? maxDistance) {
  final maxDistanceValue = maxDistance ?? 10;

  if (points.length < 3) {
    return points;
  }

  final begin = points.first;
  final end = points.last;

  // Use a "normal" line to detect the most distant point (not its real distance).
  // This is because this is faster to compute than calling distanceFromLine()
  // for every point.
  //
  // This is an approximation and may have some errors near the poles and if
  // the points are too distant, but it should be good enough for most use
  // cases...
  final coefficients = getLineEquationCoefficients(begin, end);
  final a = coefficients[0];
  final b = coefficients[1];
  final c = coefficients[2];

  // Initialize to safe values.
  var tmpMaxDistance = 0.0;
  var tmpMaxDistancePosition = 1;

  // Check distance of all points between begin and end, exclusive.
  for (var pointNo = 1; pointNo < points.length - 1; pointNo++) {
    final point = points[pointNo];
    final d = (a * point.latitude + b * point.longitude + c).abs();
    if (d > tmpMaxDistance) {
      tmpMaxDistance = d;
      tmpMaxDistancePosition = pointNo;
    }
  }

  // Now that we have the most distant point, compute its real distance.
  final realMaxDistance = distanceFromLine(
    points[tmpMaxDistancePosition],
    begin,
    end,
  );

  // If furthest point is less than maxDistance, remove all points between
  // begin and end.
  if (realMaxDistance != null && realMaxDistance < maxDistanceValue) {
    return [begin, end];
  }

  // If furthest point is more than maxDistance, use it as anchor and run
  // function again using (begin to anchor) and (anchor to end), remove extra
  // anchor.
  final left = simplifyPolyline(
    points.sublist(0, tmpMaxDistancePosition + 1),
    maxDistanceValue,
  );
  final right = simplifyPolyline(
    points.sublist(tmpMaxDistancePosition),
    maxDistanceValue,
  );
  return <Location>[...left, ...right.skip(1)];
}

/// Generic geographical location.
class Location {
  /// Creates a generic geographical location.
  Location(this.latitude, this.longitude, [this.elevation]);

  double latitude;
  double longitude;
  double? elevation;

  /// Returns if this location contains elevation data.
  bool hasElevation() => elevation != null;

  /// Remove the elevation data from this location.
  void removeElevation() {
    elevation = null;
  }

  /// Calculate the distance between self and location in meters.
  /// Does not take elevation into account.
  double? distance2d(Location? location) {
    if (location == null) {
      return null;
    }

    return distance(
      latitude,
      longitude,
      null,
      location.latitude,
      location.longitude,
      null,
    );
  }

  /// Calculate the distance between self and location in meters.
  /// Takes elevation into account.
  double? distance3d(Location? location) {
    if (location == null) {
      return null;
    }

    return distance(
      latitude,
      longitude,
      elevation,
      location.latitude,
      location.longitude,
      location.elevation,
    );
  }

  /// Computes the uphill/downhill angle towards a location.
  double? elevationAngle(Location location, {bool radians = false}) {
    return _elevationAngle(this, location, radians: radians);
  }

  /// Move this location with the given `LocationDelta`.
  void move(LocationDelta locationDelta) {
    final moved = locationDelta.move(this);
    latitude = moved.latitude;
    longitude = moved.longitude;
  }

  /// Return a new location moved by the given `LocationDelta`.
  Location operator +(LocationDelta locationDelta) {
    final moved = locationDelta.move(this);
    return Location(moved.latitude, moved.longitude);
  }

  @override
  String toString() => '[loc:$latitude,$longitude@$elevation]';
}

enum _LocationDeltaKind { distanceAngle, latLonDiff }

/// Intended to use similar to `timestamp.timedelta`, but for locations.
class LocationDelta {
  static const double north = 0;
  static const double east = 90;
  static const double south = 180;
  static const double west = 270;

  /// Create a location delta.
  ///
  /// Version 1:
  /// - Distance (in meters).
  /// - angle_from_north clockwise.
  /// - Both must be given.
  ///
  /// Version 2:
  /// - latitude_diff and longitude_diff.
  /// - Both must be given.
  factory LocationDelta({
    double? distance,
    double? angle,
    double? latitudeDiff,
    double? longitudeDiff,
  }) {
    final hasDistanceAngle = distance != null || angle != null;
    final hasLatLonDiff = latitudeDiff != null || longitudeDiff != null;

    if (hasDistanceAngle && hasLatLonDiff) {
      throw ArgumentError('No lat/lon diff if using distance and angle!');
    }

    if (distance != null && angle != null) {
      return LocationDelta._distanceAngle(distance, angle);
    }

    if (latitudeDiff != null && longitudeDiff != null) {
      return LocationDelta._latLonDiff(latitudeDiff, longitudeDiff);
    }

    throw ArgumentError(
      'Must provide either distance and angle or latitudeDiff and longitudeDiff.',
    );
  }

  const LocationDelta._distanceAngle(this.distance, this.angleFromNorth)
    : latitudeDiff = null,
      longitudeDiff = null,
      _kind = _LocationDeltaKind.distanceAngle;

  const LocationDelta._latLonDiff(this.latitudeDiff, this.longitudeDiff)
    : distance = null,
      angleFromNorth = null,
      _kind = _LocationDeltaKind.latLonDiff;

  final double? distance;
  final double? angleFromNorth;
  final double? latitudeDiff;
  final double? longitudeDiff;
  final _LocationDeltaKind _kind;

  /// Move location by this `LocationDelta`.
  ({double latitude, double longitude}) move(Location location) {
    switch (_kind) {
      case _LocationDeltaKind.distanceAngle:
        return moveByAngleAndDistance(location);
      case _LocationDeltaKind.latLonDiff:
        return moveByLatLonDiff(location);
    }
  }

  /// Move by distance and angle.
  ({double latitude, double longitude}) moveByAngleAndDistance(
    Location location,
  ) {
    final coef = math.cos(_radians(location.latitude));
    final verticalDistanceDiff =
        math.sin(_radians(90 - angleFromNorth!)) / oneDegree;
    final horizontalDistanceDiff =
        math.cos(_radians(90 - angleFromNorth!)) / oneDegree;
    final latDiff = distance! * verticalDistanceDiff;
    final lonDiff = distance! * horizontalDistanceDiff / coef;
    return (
      latitude: location.latitude + latDiff,
      longitude: location.longitude + lonDiff,
    );
  }

  /// Move by latitude/longitude difference.
  ({double latitude, double longitude}) moveByLatLonDiff(Location location) {
    return (
      latitude: location.latitude + latitudeDiff!,
      longitude: location.longitude + longitudeDiff!,
    );
  }

  @override
  String toString() {
    if (_kind == _LocationDeltaKind.distanceAngle) {
      return 'LocationDelta(distance=$distance, angle=$angleFromNorth)';
    }
    return 'LocationDelta(latitudeDiff=$latitudeDiff, longitudeDiff=$longitudeDiff)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LocationDelta &&
        distance == other.distance &&
        angleFromNorth == other.angleFromNorth &&
        latitudeDiff == other.latitudeDiff &&
        longitudeDiff == other.longitudeDiff;
  }

  @override
  int get hashCode =>
      Object.hash(distance, angleFromNorth, latitudeDiff, longitudeDiff);
}
