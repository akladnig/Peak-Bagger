import 'dart:convert';

import 'package:peak_bagger/core/constants.dart';

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
