import 'package:intl/intl.dart';

final DateFormat _dateWithYear = DateFormat('EEE, d MMM y', 'en_US');
final DateFormat _dateWithoutYear = DateFormat('EEE, d MMM', 'en_US');
final DateFormat _dayMonth = DateFormat('d MMM', 'en_US');
const _trackDateWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _trackDateMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatSummaryDateRange(DateTime start, DateTime end) {
  final startText = start.year == end.year
      ? _dateWithoutYear.format(start)
      : _dateWithYear.format(start);
  final endText = _dateWithYear.format(end);
  return '$startText - $endText';
}

String formatSummaryDayMonth(DateTime date) => _dayMonth.format(date);

String formatTrackDate(DateTime? trackDate) {
  if (trackDate == null) {
    return 'Unknown';
  }

  return '${_trackDateWeekdays[trackDate.weekday - 1]}, ${trackDate.day} ${_trackDateMonths[trackDate.month - 1]} ${trackDate.year}';
}

String formatElevationDateRange(DateTime start, DateTime end) =>
    formatSummaryDateRange(start, end);

String formatElevationDayMonth(DateTime date) => formatSummaryDayMonth(date);
