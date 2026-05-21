import 'package:intl/intl.dart';

final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern('en_US');

String formatElevationMetres(int metres) => _wholeNumberFormat.format(metres);

String formatCount(double value) => _wholeNumberFormat.format(value.round());

String formatDistance(double value, {int decimalPlaces = 0}) {
  final roundedMeters = value.round();
  if (roundedMeters < 1000) {
    return '$roundedMeters m';
  }
  return '${(roundedMeters / 1000).toStringAsFixed(decimalPlaces)} km';
}

String formatElevation(double value) => '${value.round()} m';

String formatAscent(double? value) {
  if (value == null) {
    return 'Unknown';
  }
  return formatElevation(value);
}
