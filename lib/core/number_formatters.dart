import 'package:intl/intl.dart';

final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern('en_US');
final NumberFormat _elevationNumberFormat = NumberFormat.decimalPattern('en_US');

String formatCount(int value) => _wholeNumberFormat.format(value);

String formatDistance(double value, {int decimalPlaces = 0}) {
  final roundedMeters = value.round();
  if (roundedMeters < 1000) {
    return '$roundedMeters m';
  }
  return '${(roundedMeters / 1000).toStringAsFixed(decimalPlaces)} km';
}

String formatElevation(int value, {bool showUnits = true}) {
  final formatted = value.abs() < 10000
      ? value.toString()
      : _elevationNumberFormat.format(value);
  return showUnits ? '$formatted m' : formatted;
}

String formatElevationWithThousandsSeparator(
  int value, {
  bool showUnits = true,
}) =>
    formatElevation(value, showUnits: showUnits);

String formatAscent(double? value) {
  if (value == null) {
    return 'Unknown';
  }
  return formatElevation(value.round());
}
