import 'package:intl/intl.dart';

final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern('en_US');

String formatCount(int value) => _wholeNumberFormat.format(value);

String formatDistance(double value, {int decimalPlaces = 0}) {
  final roundedMeters = value.round();
  if (roundedMeters < 1000) {
    return '$roundedMeters m';
  }
  return '${(roundedMeters / 1000).toStringAsFixed(decimalPlaces)} km';
}

String formatElevation(int value, {bool showUnits = true}) =>
    showUnits ? '$value m' : '$value';

String formatAscent(double? value) {
  if (value == null) {
    return 'Unknown';
  }
  return formatElevation(value.round());
}
