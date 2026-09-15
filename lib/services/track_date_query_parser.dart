enum TrackDateQueryKind { nonDateLike, invalidDateLike, valid }

class TrackCalendarDay implements Comparable<TrackCalendarDay> {
  const TrackCalendarDay(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  int compareTo(TrackCalendarDay other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) {
      return yearComparison;
    }
    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) {
      return monthComparison;
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackCalendarDay &&
        year == other.year &&
        month == other.month &&
        day == other.day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);
}

class TrackDateRange {
  const TrackDateRange({required this.start, required this.end});

  final TrackCalendarDay start;
  final TrackCalendarDay end;

  bool containsTrackDate(DateTime? trackDate) {
    if (trackDate == null) {
      return false;
    }
    final calendarDay = TrackCalendarDay(
      trackDate.year,
      trackDate.month,
      trackDate.day,
    );
    return calendarDay.compareTo(start) >= 0 && calendarDay.compareTo(end) <= 0;
  }
}

class TrackDateQueryParseResult {
  const TrackDateQueryParseResult._(this.kind, [this.range]);

  const TrackDateQueryParseResult.nonDateLike()
    : this._(TrackDateQueryKind.nonDateLike);

  const TrackDateQueryParseResult.invalidDateLike()
    : this._(TrackDateQueryKind.invalidDateLike);

  const TrackDateQueryParseResult.valid(TrackDateRange range)
    : this._(TrackDateQueryKind.valid, range);

  final TrackDateQueryKind kind;
  final TrackDateRange? range;
}

class TrackDateQueryParser {
  const TrackDateQueryParser();

  static final _numericDatePattern = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$',
  );
  static final _monthDatePattern = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{2}|\d{4})$',
  );
  static final _monthDateLikePattern = RegExp(r'^\d{1,2}\s*[A-Za-z]');
  static final _numericDateLikePattern = RegExp(r'^\d.*(?:/|\.{2}|-)');
  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  TrackDateQueryParseResult parseQuery(String value) {
    final trimmedValue = value.trim();
    if (!_isDateLike(trimmedValue)) {
      return const TrackDateQueryParseResult.nonDateLike();
    }

    final rangeParts = _splitRange(trimmedValue);
    if (rangeParts == null) {
      final day = _parseDay(trimmedValue);
      return day == null
          ? const TrackDateQueryParseResult.invalidDateLike()
          : TrackDateQueryParseResult.valid(
              TrackDateRange(start: day, end: day),
            );
    }

    final start = _parseDay(rangeParts.$1);
    final end = _parseDay(rangeParts.$2);
    if (start == null || end == null || start.compareTo(end) > 0) {
      return const TrackDateQueryParseResult.invalidDateLike();
    }
    return TrackDateQueryParseResult.valid(
      TrackDateRange(start: start, end: end),
    );
  }

  TrackDateQueryParseResult parseEndpoint(String value) {
    final trimmedValue = value.trim();
    if (!_isDateLike(trimmedValue)) {
      return const TrackDateQueryParseResult.nonDateLike();
    }
    if (_splitRange(trimmedValue) != null) {
      return const TrackDateQueryParseResult.invalidDateLike();
    }
    final day = _parseDay(trimmedValue);
    return day == null
        ? const TrackDateQueryParseResult.invalidDateLike()
        : TrackDateQueryParseResult.valid(TrackDateRange(start: day, end: day));
  }

  bool _isDateLike(String value) {
    return _numericDateLikePattern.hasMatch(value) ||
        _monthDateLikePattern.hasMatch(value);
  }

  (String, String)? _splitRange(String value) {
    final match = RegExp(r'^(.*?)\s*(?:\.\.|-)\s*(.*?)$').firstMatch(value);
    if (match == null) {
      return null;
    }
    return (match.group(1)!.trim(), match.group(2)!.trim());
  }

  TrackCalendarDay? _parseDay(String value) {
    final numericMatch = _numericDatePattern.firstMatch(value);
    if (numericMatch != null) {
      return _calendarDay(
        int.parse(numericMatch.group(3)!),
        int.parse(numericMatch.group(2)!),
        int.parse(numericMatch.group(1)!),
      );
    }
    final monthMatch = _monthDatePattern.firstMatch(value);
    if (monthMatch == null) {
      return null;
    }
    final month = _months[monthMatch.group(2)!.toLowerCase()];
    if (month == null) {
      return null;
    }
    return _calendarDay(
      int.parse(monthMatch.group(3)!),
      month,
      int.parse(monthMatch.group(1)!),
    );
  }

  TrackCalendarDay? _calendarDay(int parsedYear, int month, int day) {
    final year = parsedYear < 100
        ? (parsedYear <= 49 ? 2000 + parsedYear : 1900 + parsedYear)
        : parsedYear;
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return TrackCalendarDay(year, month, day);
  }
}
