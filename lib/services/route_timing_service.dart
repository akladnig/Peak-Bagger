import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';

final _distance = Distance();

const routeTimingDefaultWalkingSpeedKmh = 4.0;
const routeTimingMinWalkingSpeedKmh = 0.5;
const routeTimingMaxWalkingSpeedKmh = 9.9;
const routeTimingWalkingSpeedStepKmh = 0.1;

class RouteTimingSources {
  static const verifiedWalk = 'verified-walk';
  static const verifiedWalkPlusNaismith = 'verified-walk-plus-naismith';
  static const extendedRoute = 'extended-route';
  static const naismith = 'naismith';
}

class RouteTimingSegmentKinds {
  static const preserved = 'preserved';
  static const manualEstimated = 'manual-estimated';
}

class RouteTimingDisplayState {
  const RouteTimingDisplayState({
    required this.effectiveWalkingSpeedKmh,
    required this.walkingSpeedEnabled,
    required this.naismithDurationMillis,
    required this.scarfDurationMillis,
    this.limitationMessage,
    this.naismithUsesStoredMixedTotal = false,
  });

  final double effectiveWalkingSpeedKmh;
  final bool walkingSpeedEnabled;
  final int? naismithDurationMillis;
  final int? scarfDurationMillis;
  final String? limitationMessage;
  final bool naismithUsesStoredMixedTotal;
}

double scarfDistance({
  required double distanceMetres,
  required double ascentMetres,
}) {
  return distanceMetres + (RouteTimingConstants.naismithsNumber * ascentMetres);
}

int scarfTime({
  required double distanceMetres,
  required double ascentMetres,
  double speedMetresPerSecond =
      RouteTimingConstants.naismithSpeedMetresPerSecond,
}) {
  return ((scarfDistance(
            distanceMetres: distanceMetres,
            ascentMetres: ascentMetres,
          ) /
          speedMetresPerSecond))
      .round();
}

int naismithTime({
  required double distanceMetres,
  required double ascentMetres,
  required double descentMetres,
  double speedMetresPerSecond =
      RouteTimingConstants.naismithSpeedMetresPerSecond,
}) {
  return (distanceMetres / speedMetresPerSecond +
          ascentMetres * RouteTimingConstants.naismithAscentSecondsPerMetre +
          descentMetres * RouteTimingConstants.naismithDescentSecondsPerMetre)
      .round();
}

RouteTimingDisplayState resolveRouteTimingDisplay({
  required List<LatLng> points,
  required List<int?> elevations,
  required int? estimatedTimeMillis,
  required String? routeTimingSource,
  required String? routeTimingProfileJson,
  required String? routeTimingSegmentKindsJson,
  required double? walkingSpeedKmh,
}) {
  final effectiveWalkingSpeedKmh = normalizeWalkingSpeedKmh(walkingSpeedKmh);
  final segmentCount = points.length > 1 ? points.length - 1 : 0;
  if (segmentCount == 0) {
    return RouteTimingDisplayState(
      effectiveWalkingSpeedKmh: effectiveWalkingSpeedKmh,
      walkingSpeedEnabled: false,
      naismithDurationMillis: estimatedTimeMillis,
      scarfDurationMillis: estimatedTimeMillis,
    );
  }

  final profile = decodeRouteTimingProfile(routeTimingProfileJson);
  final profileSegmentSeconds = profile.length == points.length
      ? _profileSegmentSeconds(profile)
      : const <int>[];
  final segmentKinds = _resolveSegmentKinds(
    routeTimingSource: routeTimingSource,
    routeTimingSegmentKindsJson: routeTimingSegmentKindsJson,
    segmentCount: segmentCount,
  );

  if (segmentKinds == null && _isLegacyMixedRoute(routeTimingSource)) {
    return RouteTimingDisplayState(
      effectiveWalkingSpeedKmh: effectiveWalkingSpeedKmh,
      walkingSpeedEnabled: false,
      naismithDurationMillis: estimatedTimeMillis,
      scarfDurationMillis: null,
      limitationMessage:
          'Adjusted timing unavailable for this legacy mixed route because segment provenance was never stored.',
      naismithUsesStoredMixedTotal: true,
    );
  }

  if (segmentKinds == null) {
    return RouteTimingDisplayState(
      effectiveWalkingSpeedKmh: effectiveWalkingSpeedKmh,
      walkingSpeedEnabled: false,
      naismithDurationMillis: estimatedTimeMillis,
      scarfDurationMillis: estimatedTimeMillis,
    );
  }

  final speedMetresPerSecond = effectiveWalkingSpeedKmh / 3.6;
  var naismithSeconds = 0;
  var scarfSeconds = 0;
  for (var index = 0; index < segmentKinds.length; index++) {
    if (segmentKinds[index] == RouteTimingSegmentKinds.preserved) {
      if (profileSegmentSeconds.length != segmentCount) {
        return RouteTimingDisplayState(
          effectiveWalkingSpeedKmh: effectiveWalkingSpeedKmh,
          walkingSpeedEnabled: false,
          naismithDurationMillis: estimatedTimeMillis,
          scarfDurationMillis: estimatedTimeMillis,
        );
      }
      naismithSeconds += profileSegmentSeconds[index];
      scarfSeconds += profileSegmentSeconds[index];
      continue;
    }

    final start = points[index];
    final end = points[index + 1];
    final distanceMetres = _distance.as(LengthUnit.Meter, start, end);
    final ascentMetres = _positiveDelta(
      from: index < elevations.length ? elevations[index] : null,
      to: index + 1 < elevations.length ? elevations[index + 1] : null,
    );
    final descentMetres = _positiveDelta(
      from: index + 1 < elevations.length ? elevations[index + 1] : null,
      to: index < elevations.length ? elevations[index] : null,
    );
    naismithSeconds += naismithTime(
      distanceMetres: distanceMetres,
      ascentMetres: ascentMetres,
      descentMetres: descentMetres,
      speedMetresPerSecond: speedMetresPerSecond,
    );
    scarfSeconds += scarfTime(
      distanceMetres: distanceMetres,
      ascentMetres: ascentMetres,
      speedMetresPerSecond: speedMetresPerSecond,
    );
  }

  return RouteTimingDisplayState(
    effectiveWalkingSpeedKmh: effectiveWalkingSpeedKmh,
    walkingSpeedEnabled: true,
    naismithDurationMillis: naismithSeconds * Duration.millisecondsPerSecond,
    scarfDurationMillis: scarfSeconds * Duration.millisecondsPerSecond,
  );
}

List<int> buildProfileFromTimestamps(List<DateTime?> timestamps) {
  if (timestamps.length < 2 ||
      timestamps.any((timestamp) => timestamp == null)) {
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

int profileDurationSeconds(List<int> profile) =>
    profile.isEmpty ? 0 : profile.last;

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

List<String> decodeRouteTimingSegmentKinds(String? jsonString) {
  if (jsonString == null || jsonString.isEmpty) {
    return const [];
  }

  final decoded = jsonDecode(jsonString);
  if (decoded is! List) {
    return const [];
  }

  return [
    for (final entry in decoded)
      if (entry is String) entry,
  ];
}

String encodeRouteTimingSegmentKinds(List<String> kinds) {
  return jsonEncode(kinds);
}

List<String> buildRouteTimingSegmentKinds({
  required int segmentCount,
  required String kind,
}) {
  if (segmentCount <= 0) {
    return const [];
  }
  return List<String>.filled(segmentCount, kind, growable: false);
}

String buildRouteTimingSegmentKindsJson({
  required int segmentCount,
  required String kind,
}) {
  return encodeRouteTimingSegmentKinds(
    buildRouteTimingSegmentKinds(segmentCount: segmentCount, kind: kind),
  );
}

List<String>? resolveRouteTimingSegmentKinds({
  required int segmentCount,
  required String? routeTimingSource,
  required String? routeTimingSegmentKindsJson,
}) {
  return _resolveSegmentKinds(
    routeTimingSource: routeTimingSource,
    routeTimingSegmentKindsJson: routeTimingSegmentKindsJson,
    segmentCount: segmentCount,
  );
}

List<String>? extendRouteTimingSegmentKinds({
  required List<LatLng> sourcePoints,
  required List<String> sourceSegmentKinds,
  required List<LatLng> updatedPoints,
}) {
  if (sourcePoints.length < 2 ||
      sourceSegmentKinds.length != sourcePoints.length - 1 ||
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
    final appendedSegmentCount = updatedPoints.length - sourcePoints.length;
    return [
      ...sourceSegmentKinds,
      ...buildRouteTimingSegmentKinds(
        segmentCount: appendedSegmentCount,
        kind: RouteTimingSegmentKinds.manualEstimated,
      ),
    ];
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
  return [
    ...sourceSegmentKinds.take(leftAnchorIndex),
    ...buildRouteTimingSegmentKinds(
      segmentCount: insertedCount + 1,
      kind: RouteTimingSegmentKinds.manualEstimated,
    ),
    ...sourceSegmentKinds.skip(rightAnchorIndex),
  ];
}

double normalizeWalkingSpeedKmh(double? value) {
  if (value == null || !value.isFinite) {
    return routeTimingDefaultWalkingSpeedKmh;
  }
  return value
      .clamp(routeTimingMinWalkingSpeedKmh, routeTimingMaxWalkingSpeedKmh)
      .toDouble();
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
    insertedEnd < updatedElevations.length
        ? updatedElevations[insertedEnd]
        : null,
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
      return 'Estimated time has been derived from a verified walk plus manually added segments estimated using Naismith\'s rule using ${_formatKilometresPerHour(RouteTimingConstants.naismithSpeedMetresPerSecond)} km/h, ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithAscentSecondsPerMetre)} per 1000 m ascent and ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithDescentSecondsPerMetre)} per 1000 m descent';
    case RouteTimingSources.extendedRoute:
      return 'Estimated time has been derived from the original route plus manually added segments estimated using Naismith\'s rule using ${_formatKilometresPerHour(RouteTimingConstants.naismithSpeedMetresPerSecond)} km/h, ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithAscentSecondsPerMetre)} per 1000 m ascent and ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithDescentSecondsPerMetre)} per 1000 m descent';
    case RouteTimingSources.naismith:
      return 'Estimated time has been derived using Naismith\'s rule using ${_formatKilometresPerHour(RouteTimingConstants.naismithSpeedMetresPerSecond)} km/h, ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithAscentSecondsPerMetre)} per 1000 m ascent and ${_formatMinutesPer1000Metres(RouteTimingConstants.naismithDescentSecondsPerMetre)} per 1000 m descent';
    default:
      return null;
  }
}

List<DateTime> buildSyntheticRouteTimes(List<int> profile, {DateTime? anchor}) {
  final effectiveAnchor = anchor ?? DateTime.utc(2000, 1, 1);
  return [
    for (final seconds in profile)
      effectiveAnchor.add(Duration(seconds: seconds)),
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

List<int> _profileSegmentSeconds(List<int> profile) {
  if (profile.length < 2) {
    return const [];
  }

  return [
    for (var index = 1; index < profile.length; index++)
      profile[index] - profile[index - 1],
  ];
}

List<String>? _resolveSegmentKinds({
  required String? routeTimingSource,
  required String? routeTimingSegmentKindsJson,
  required int segmentCount,
}) {
  final decodedKinds = decodeRouteTimingSegmentKinds(
    routeTimingSegmentKindsJson,
  );
  if (decodedKinds.length == segmentCount) {
    return decodedKinds;
  }

  switch (routeTimingSource) {
    case RouteTimingSources.naismith:
      return List<String>.filled(
        segmentCount,
        RouteTimingSegmentKinds.manualEstimated,
      );
    case RouteTimingSources.verifiedWalk:
      return List<String>.filled(
        segmentCount,
        RouteTimingSegmentKinds.preserved,
      );
    default:
      return null;
  }
}

bool _isLegacyMixedRoute(String? routeTimingSource) {
  return routeTimingSource == RouteTimingSources.verifiedWalkPlusNaismith ||
      routeTimingSource == RouteTimingSources.extendedRoute;
}
