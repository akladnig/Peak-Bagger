import 'package:peak_bagger/core/constants.dart';
import 'package:intl/intl.dart';

final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern('en_US');
final NumberFormat _elevationNumberFormat = NumberFormat.decimalPattern(
  'en_US',
);

String formatCount(int value) => _wholeNumberFormat.format(value);

/// Recorded duration, not a calendar interval. Truncate only the final display.
String formatDurationMillis(double milliseconds) {
  final minutes = (milliseconds / Duration.millisecondsPerMinute).truncate();
  return '${minutes ~/ Duration.minutesPerDay}d '
      '${(minutes ~/ Duration.minutesPerHour) % Duration.hoursPerDay}h '
      '${minutes % Duration.minutesPerHour}m';
}

/// Compact chart days; retain distinguishable ticks even below one minute.
String formatDurationDaysAxis(double days) {
  if (days == 0) return '0d';
  final magnitude = days.abs();
  if (magnitude < 0.000001) return '${days.toStringAsPrecision(3)}d';
  final text = days.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  return '${text}d';
}

String formatDistance(double value, {int decimalPlaces = 0}) {
  final roundedMeters = value.round();
  if (roundedMeters < 1000) {
    return '$roundedMeters m';
  }
  return '${(roundedMeters / 1000).toStringAsFixed(decimalPlaces)} km';
}

String formatDistance2d3d(
  double distance2d,
  double distance3d, {
  int decimalPlaces = 1,
}) {
  return '${formatDistance(distance2d, decimalPlaces: decimalPlaces)} / ${formatDistance(distance3d, decimalPlaces: decimalPlaces)}';
}

String formatFileSizeKiB(double value, {int decimalPlaces = 1}) =>
    '${value.toStringAsFixed(decimalPlaces)} KiB';

String formatPercentage(double value, {int decimalPlaces = 1}) =>
    '${value.toStringAsFixed(decimalPlaces)}%';

String formatSpeedKmh(double? value, {int decimalPlaces = 1}) {
  if (value == null || !value.isFinite) {
    return 'Unknown';
  }
  return '${value.toStringAsFixed(decimalPlaces)} km/h';
}

String formatCoordinate(
  double value, {
  int decimalPlaces = GpxConstants.precision,
}) => value.toStringAsFixed(decimalPlaces);

String formatElevation(int value, {bool showUnits = true}) {
  final formatted = value.abs() < 10000
      ? value.toString()
      : _elevationNumberFormat.format(value);
  return showUnits ? '$formatted m' : formatted;
}

String formatCompactElevation(double value, {int decimalPlaces = 1}) {
  final formatted = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(decimalPlaces);
  return '${formatted}m';
}

String formatElevationWithThousandsSeparator(
  int value, {
  bool showUnits = true,
}) => formatElevation(value, showUnits: showUnits);

String formatCoordinatePair(double latitude, double longitude) =>
    '(${latitude.toStringAsFixed(GpxConstants.precision)}, ${longitude.toStringAsFixed(GpxConstants.precision)})';

String formatAscent(double? value) {
  if (value == null) {
    return 'Unknown';
  }
  return formatElevation(value.round());
}
