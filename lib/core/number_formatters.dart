import 'package:peak_bagger/core/constants.dart';
import 'package:intl/intl.dart';

final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern('en_US');
final NumberFormat _elevationNumberFormat = NumberFormat.decimalPattern(
  'en_US',
);

String formatCount(int value) => _wholeNumberFormat.format(value);

String formatDistance(double value, {int decimalPlaces = 0}) {
  final roundedMeters = value.round();
  if (roundedMeters < 1000) {
    return '$roundedMeters m';
  }
  return '${(roundedMeters / 1000).toStringAsFixed(decimalPlaces)} km';
}

String formatFileSizeKiB(double value, {int decimalPlaces = 1}) =>
    '${value.toStringAsFixed(decimalPlaces)} KiB';

String formatPercentage(double value, {int decimalPlaces = 1}) =>
    '${value.toStringAsFixed(decimalPlaces)}%';

String formatCoordinate(double value, {int decimalPlaces = GpxConstants.precision}) =>
    value.toStringAsFixed(decimalPlaces);

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
