import 'package:intl/intl.dart';

final DateFormat _dateWithYear = DateFormat('EEE, d MMM y', 'en_US');
final DateFormat _dateWithoutYear = DateFormat('EEE, d MMM', 'en_US');
final DateFormat _dayMonth = DateFormat('d MMM', 'en_US');
final DateFormat _weekdayDayMonth = DateFormat('EEE d MMM', 'en_US');
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
const _trackDateShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatSummaryDateRange(DateTime start, DateTime end) {
  final startText = start.year == end.year
      ? _dateWithoutYear.format(start)
      : _dateWithYear.format(start);
  final endText = _dateWithYear.format(end);
  return '$startText - $endText';
}

/// Compact chart range using included calendar days, without zone conversion.
String formatSummaryWeeklyRange(DateTime start, DateTime end) {
  final startMonth = _trackDateShortMonths[start.month - 1];
  final endMonth = _trackDateShortMonths[end.month - 1];
  if (start.year != end.year) {
    return '${start.day} $startMonth ${start.year} – ${end.day} $endMonth ${end.year}';
  }
  if (start.month != end.month) {
    return '${start.day} $startMonth – ${end.day} $endMonth ${end.year}';
  }
  final days = start.day == end.day
      ? '${start.day}'
      : '${start.day}-${end.day}';
  return '$days $endMonth ${end.year}';
}

String formatSummaryDayMonth(DateTime date) => _dayMonth.format(date);
String formatSummaryWeekdayDayMonth(DateTime date) =>
    _weekdayDayMonth.format(date);

String formatCompactDate(DateTime date) {
  return formatCompactCalendarDate(date.toLocal());
}

String formatCompactCalendarDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';

String formatTrackDate(DateTime? trackDate) {
  if (trackDate == null) {
    return 'Unknown';
  }

  return '${_trackDateWeekdays[trackDate.weekday - 1]}, ${trackDate.day} ${_trackDateMonths[trackDate.month - 1]} ${trackDate.year}';
}

String formatTrackDateShortMonth(DateTime? trackDate) {
  if (trackDate == null) {
    return 'Unknown';
  }

  return '${_trackDateWeekdays[trackDate.weekday - 1]}, ${trackDate.day} ${_trackDateShortMonths[trackDate.month - 1]} ${trackDate.year}';
}

String formatElevationDateRange(DateTime start, DateTime end) =>
    formatSummaryDateRange(start, end);

String formatElevationDayMonth(DateTime date) => formatSummaryDayMonth(date);
