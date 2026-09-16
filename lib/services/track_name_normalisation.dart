final RegExp _trackNameDateSuffix = RegExp(
  r'^(.*?)[\s_-]*(?:\((\d{2})([-/])(\d{2})\3(\d{4})\)|(\d{2})([-/])(\d{2})\7(\d{4}))\s*$',
);

String normaliseTrackName(String trackName) {
  final match = _trackNameDateSuffix.firstMatch(trackName);
  if (match == null) {
    return trackName;
  }

  final day = int.parse(match.group(2) ?? match.group(6)!);
  final month = int.parse(match.group(4) ?? match.group(8)!);
  final year = int.parse(match.group(5) ?? match.group(9)!);
  final date = DateTime(year, month, day);
  final normalisedName = match.group(1)!.trim();
  if (normalisedName.isEmpty ||
      date.year != year ||
      date.month != month ||
      date.day != day) {
    return trackName;
  }

  return normalisedName;
}
