import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

/// Shared app-owned CSV contract usable by the app and standalone Dart tools.
class PeakListCsvFormat {
  static const csvHeaders = [
    'name',
    'altName',
    'elevation',
    'prominence',
    'rating',
    'difficulty',
    'duration',
    'viaFerrata',
    'gridZoneDesignator',
    'mgrs100kId',
    'easting',
    'northing',
    'points',
    'osmId',
    'peakbaggerPid',
    'country',
    'region',
    'county',
    'range',
    'notes',
    'verified',
    'sourceOfTruth',
  ];

  static PeakMgrsComponents resolveMgrsComponents(Peak peak) {
    final storedForward =
        '${peak.gridZoneDesignator.trim().toUpperCase()}'
        '${peak.mgrs100kId.trim().toUpperCase()}${peak.easting.trim()}${peak.northing.trim()}';
    try {
      return PeakMgrsConverter.fromForwardString(storedForward);
    } on FormatException {
      return PeakMgrsConverter.fromLatLng(
        LatLng(peak.latitude, peak.longitude),
      );
    }
  }

  static String formatDuration(Peak peak) =>
      peak.durationLabel.trim().isNotEmpty
      ? peak.durationLabel
      : formatPeakDurationMinutes(peak.durationMinutes);
  static String formatOptionalNumber(double? value) => value?.toString() ?? '';
  static String formatOptionalRating(double? rating) =>
      rating == null ? '' : rating.toStringAsFixed(1);

  static int comparePeaksForCsv(Peak left, Peak right) {
    final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    return name == 0 ? left.osmId.compareTo(right.osmId) : name;
  }

  static List<dynamic> csvRowForPeak(Peak peak, {required int points}) {
    final mgrs = resolveMgrsComponents(peak);
    return [
      peak.name,
      peak.altName,
      formatOptionalNumber(peak.elevation),
      formatOptionalNumber(peak.prominence),
      formatOptionalRating(peak.rating),
      peak.difficulty,
      formatDuration(peak),
      peak.viaFerrata,
      mgrs.gridZoneDesignator,
      mgrs.mgrs100kId,
      mgrs.easting,
      mgrs.northing,
      points,
      peak.osmId,
      peak.peakbaggerPid?.toString() ?? '',
      peak.country,
      peak.region ?? '',
      peak.county,
      peak.range,
      peak.notes,
      peak.verified.toString(),
      peak.sourceOfTruth,
    ];
  }
}
