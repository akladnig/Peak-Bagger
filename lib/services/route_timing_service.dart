import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';

final _distance = Distance();

class RouteTimingSources {
  static const verifiedWalk = 'verified-walk';
  static const verifiedWalkPlusNaismith = 'verified-walk-plus-naismith';
  static const extendedRoute = 'extended-route';
  static const naismith = 'naismith';
}

double scarfDistance({
  required double distanceMetres,
  required double ascentMetres,
}) {
  return distanceMetres +
      (RouteTimingConstants.naismithsNumber * ascentMetres);
}

int scarfTime({
  required double distanceMetres,
  required double ascentMetres,
}) {
  return ((scarfDistance(
        distanceMetres: distanceMetres,
        ascentMetres: ascentMetres,
      ) /
      RouteTimingConstants.naismithSpeedMetresPerSecond)
  ).round();
}

int naismithTime({
  required double distanceMetres,
  required double ascentMetres,
  required double descentMetres,
}) {
  return (
    distanceMetres / RouteTimingConstants.naismithSpeedMetresPerSecond +
    ascentMetres * RouteTimingConstants.naismithAscentSecondsPerMetre +
    descentMetres * RouteTimingConstants.naismithDescentSecondsPerMetre
  ).round();
}

List<int> buildProfileFromTimestamps(List<DateTime?> timestamps) {
  if (timestamps.length < 2 || timestamps.any((timestamp) => timestamp == null)) {
    return const [];
  }

  final firstTimestamp = timestamps.first!;
  final profile = <int>[0];
  var lastTimestamp = firstTimestamp;

  for (var index = 1; index < timestamps.length; index++) {
    final timestamp = timestamps[index]!;
    if (!timestamp.isAfter(lastTimestamp)) {
      return const [];
    }

    profile.add(timestamp.difference(firstTimestamp).inSeconds);
    lastTimestamp = timestamp;
  }

  return profile;
}

List<int> buildNaismithProfile({
  required List<LatLng> points,
  required List<int?> elevations,
}) {
  if (points.length < 2) {
    return points.isEmpty ? const [] : const [0];
  }

  final profile = <int>[0];
  var cumulativeSeconds = 0;

  for (var index = 1; index < points.length; index++) {
    final start = points[index - 1];
    final end = points[index];
    final distanceMetres = _distance.as(LengthUnit.Meter, start, end);
    final ascentMetres = _positiveDelta(
      from: index - 1 < elevations.length ? elevations[index - 1] : null,
      to: index < elevations.length ? elevations[index] : null,
    );
    final descentMetres = _positiveDelta(
      from: index < elevations.length ? elevations[index] : null,
      to: index - 1 < elevations.length ? elevations[index - 1] : null,
    );
    cumulativeSeconds += naismithTime(
      distanceMetres: distanceMetres,
      ascentMetres: ascentMetres,
      descentMetres: descentMetres,
    );
    profile.add(cumulativeSeconds);
  }

  return profile;
}

int profileDurationSeconds(List<int> profile) => profile.isEmpty ? 0 : profile.last;

String formatRouteTime(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

List<int> decodeRouteTimingProfile(String? jsonString) {
  if (jsonString == null || jsonString.isEmpty) {
    return const [];
  }

  final decoded = jsonDecode(jsonString);
  if (decoded is! List) {
    return const [];
  }

  return [
    for (final entry in decoded)
      if (entry is num) entry.round(),
  ];
}

String encodeRouteTimingProfile(List<int> profile) {
  return jsonEncode(profile);
}

List<int>? extendVerifiedWalkTimingProfile({
  required List<LatLng> sourcePoints,
  required List<int?> sourceElevations,
  required List<int> sourceProfile,
  required List<LatLng> updatedPoints,
  required List<int?> updatedElevations,
}) {
  if (sourcePoints.length < 2 ||
      sourceProfile.length != sourcePoints.length ||
      updatedPoints.length < sourcePoints.length) {
    return null;
  }

  var prefix = 0;
  while (prefix < sourcePoints.length &&
      prefix < updatedPoints.length &&
      _samePoint(sourcePoints[prefix], updatedPoints[prefix])) {
    prefix += 1;
  }

  var suffix = 0;
  while (suffix < sourcePoints.length - prefix &&
      suffix < updatedPoints.length - prefix &&
      _samePoint(
        sourcePoints[sourcePoints.length - 1 - suffix],
        updatedPoints[updatedPoints.length - 1 - suffix],
      )) {
    suffix += 1;
  }

  if (prefix == sourcePoints.length) {
    final extraPoints = [
      sourcePoints.last,
      ...updatedPoints.skip(sourcePoints.length),
    ];
    final extraElevations = <int?>[
      sourceElevations.isNotEmpty ? sourceElevations.last : null,
      ...updatedElevations.skip(sourcePoints.length),
    ];
    final extraProfile = buildNaismithProfile(
      points: extraPoints,
      elevations: extraElevations,
    );
    if (extraProfile.isEmpty) {
      return null;
    }

    final combined = List<int>.from(sourceProfile, growable: true);
    final baseSeconds = sourceProfile.last;
    for (final seconds in extraProfile.skip(1)) {
      combined.add(baseSeconds + seconds);
    }
    return combined;
  }

  if (prefix + suffix != sourcePoints.length || prefix == 0 || suffix == 0) {
    return null;
  }

  final insertedCount = updatedPoints.length - sourcePoints.length;
  if (insertedCount <= 0) {
    return null;
  }

  final leftAnchorIndex = prefix - 1;
  final rightAnchorIndex = prefix;
  final insertedStart = prefix;
  final insertedEnd = insertedStart + insertedCount;

  final replacementPoints = [
    updatedPoints[leftAnchorIndex],
    ...updatedPoints.sublist(insertedStart, insertedEnd),
    updatedPoints[insertedEnd],
  ];
  final replacementElevations = <int?>[
    leftAnchorIndex < updatedElevations.length
        ? updatedElevations[leftAnchorIndex]
        : null,
    ...updatedElevations.sublist(insertedStart, insertedEnd),
    insertedEnd < updatedElevations.length ? updatedElevations[insertedEnd] : null,
  ];
  final replacementProfile = buildNaismithProfile(
    points: replacementPoints,
    elevations: replacementElevations,
  );
  if (replacementProfile.isEmpty) {
    return null;
  }

  final originalSegmentSeconds =
      sourceProfile[rightAnchorIndex] - sourceProfile[leftAnchorIndex];
  final replacementSeconds = replacementProfile.last;
  final deltaSeconds = replacementSeconds - originalSegmentSeconds;
  final combined = <int>[
    ...sourceProfile.take(prefix),
    for (final seconds in replacementProfile.skip(1).take(insertedCount))
      sourceProfile[leftAnchorIndex] + seconds,
    for (final seconds in sourceProfile.skip(prefix)) seconds + deltaSeconds,
  ];
  return combined;
}

String? routeTimingExplanation({
  required int? estimatedTime,
  required String? routeTimingSource,
}) {
  if (estimatedTime == null) {
    return null;
  }

  switch (routeTimingSource) {
    case RouteTimingSources.verifiedWalk:
      return 'Estimated time has been derived from a verified walk';
    case RouteTimingSources.verifiedWalkPlusNaismith:
      return
          'Estimated time has been derived from a verified walk plus manually added segments estimated using Naismith\'s rule using ${_formatKilometresPerHour(RouteTimingConstants.naismithSpeedMetresPerSecond)} km/h, ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithAscentSecondsPerMetre)} per 1000 m ascent and ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithDescentSecondsPerMetre)} per 1000 m descent';
    case RouteTimingSources.extendedRoute:
      return
          'Estimated time has been derived from the original route plus manually added segments estimated using Naismith\'s rule using ${_formatKilometresPerHour(RouteTimingConstants.naismithSpeedMetresPerSecond)} km/h, ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithAscentSecondsPerMetre)} per 1000 m ascent and ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithDescentSecondsPerMetre)} per 1000 m descent';
    case RouteTimingSources.naismith:
      return
          'Estimated time has been derived using Naismith\'s rule using ${_formatKilometresPerHour(RouteTimingConstants.naismithSpeedMetresPerSecond)} km/h, ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithAscentSecondsPerMetre)} per 1000 m ascent and ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithDescentSecondsPerMetre)} per 1000 m descent';
    default:
      return null;
  }
}

List<DateTime> buildSyntheticRouteTimes(
  List<int> profile, {
  DateTime? anchor,
}) {
  final effectiveAnchor = anchor ?? DateTime.utc(2000, 1, 1);
  return [
    for (final seconds in profile) effectiveAnchor.add(Duration(seconds: seconds)),
  ];
}

double _positiveDelta({required num? from, required num? to}) {
  if (from == null || to == null) {
    return 0;
  }

  final delta = to.toDouble() - from.toDouble();
  return delta > 0 ? delta : 0;
}

String _formatKilometresPerHour(double metresPerSecond) {
  return (metresPerSecond * 3.6).toStringAsFixed(1);
}

String _formatMinutesPer1000Metres(double secondsPerMetre) {
  final minutes = (secondsPerMetre * 1000 / 60).round();
  return '$minutes:00m';
}

bool _samePoint(LatLng left, LatLng right) {
  return left.latitude == right.latitude && left.longitude == right.longitude;
}
