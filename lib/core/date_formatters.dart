import 'package:intl/intl.dart';

final DateFormat _dateWithYear = DateFormat('EEE, d MMM y', 'en_US');
final DateFormat _dateWithoutYear = DateFormat('EEE, d MMM', 'en_US');
final DateFormat _dayMonth = DateFormat('d MMM', 'en_US');

String formatElevationDateRange(DateTime start, DateTime end) {
  final startText = start.year == end.year
      ? _dateWithoutYear.format(start)
      : _dateWithYear.format(start);
  final endText = _dateWithYear.format(end);
  return '$startText - $endText';
}

String formatElevationDayMonth(DateTime date) => _dayMonth.format(date);
