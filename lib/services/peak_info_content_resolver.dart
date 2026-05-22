import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

final DateFormat _ascentDateFormat = DateFormat('dd MMM yyyy', 'en_US');
final RegExp _trackNameDateSuffix = RegExp(r'\s*\(\d{1,2}\/\d{1,2}\/\d{4}\)$');

class PeakInfoAscentRow {
  const PeakInfoAscentRow({
    required this.gpxId,
    required this.trackLabel,
    required this.dateText,
  });

  final int gpxId;
  final String trackLabel;
  final String dateText;
}

class PeakInfoContent {
  const PeakInfoContent({
    required this.peak,
    required this.mapName,
    required this.listNames,
    required this.ascentRows,
  });

  final Peak peak;
  final String mapName;
  final List<String> listNames;
  final List<PeakInfoAscentRow> ascentRows;
}

PeakInfoContent resolvePeakInfoContent({
  required Peak peak,
  required PeakListRepository peakListRepository,
  required TasmapRepository tasmapRepository,
  required PeaksBaggedRepository peaksBaggedRepository,
  required GpxTrackRepository gpxTrackRepository,
}) {
  return PeakInfoContent(
    peak: peak,
    mapName: _resolvePeakMapName(peak, tasmapRepository),
    listNames: _resolvePeakListNames(peak.osmId, peakListRepository),
    ascentRows: _resolvePeakAscentRows(
      peakOsmId: peak.osmId,
      peaksBaggedRepository: peaksBaggedRepository,
      gpxTrackRepository: gpxTrackRepository,
    ),
  );
}

String _resolvePeakMapName(Peak peak, TasmapRepository tasmapRepository) {
  try {
    final gridZoneDesignator = peak.gridZoneDesignator.trim();
    final mgrs100kId = peak.mgrs100kId.trim();
    final easting = peak.easting.trim();
    final northing = peak.northing.trim();
    final hasCompleteMgrs =
        gridZoneDesignator.isNotEmpty &&
        mgrs100kId.isNotEmpty &&
        easting.isNotEmpty &&
        northing.isNotEmpty;
    final mgrsString = hasCompleteMgrs
        ? '$gridZoneDesignator$mgrs100kId$easting$northing'
        : _convertToMgrs(LatLng(peak.latitude, peak.longitude));
    return tasmapRepository.findByMgrsCodeAndCoordinates(mgrsString)?.name ??
        'Unknown';
  } catch (_) {
    return 'Unknown';
  }
}

List<String> _resolvePeakListNames(
  int peakOsmId,
  PeakListRepository peakListRepository,
) {
  try {
    return peakListRepository.findPeakListNamesForPeak(peakOsmId);
  } catch (_) {
    return const [];
  }
}

List<PeakInfoAscentRow> _resolvePeakAscentRows({
  required int peakOsmId,
  required PeaksBaggedRepository peaksBaggedRepository,
  required GpxTrackRepository gpxTrackRepository,
}) {
  try {
    final resolvedRows = <_ResolvedPeakInfoAscentRow>[];
    for (final ascent in peaksBaggedRepository.ascentsForPeakId(peakOsmId)) {
      resolvedRows.add(
        _ResolvedPeakInfoAscentRow(
          gpxId: ascent.gpxId,
          date: ascent.date,
          trackLabel: _resolveTrackLabel(
            ascent.gpxId,
            gpxTrackRepository,
          ),
        ),
      );
    }
    resolvedRows.sort((left, right) {
      final dateCompare = _compareDatesDescending(left.date, right.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final labelCompare = left.trackLabel.compareTo(right.trackLabel);
      if (labelCompare != 0) {
        return labelCompare;
      }
      return left.gpxId.compareTo(right.gpxId);
    });
    return resolvedRows
        .map(
          (row) => PeakInfoAscentRow(
            gpxId: row.gpxId,
            trackLabel: row.trackLabel,
            dateText: row.date == null
                ? 'Unknown'
                : _ascentDateFormat.format(row.date!.toLocal()),
          ),
        )
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

String _resolveTrackLabel(
  int gpxId,
  GpxTrackRepository gpxTrackRepository,
) {
  try {
    final trackName = gpxTrackRepository.findById(gpxId)?.trackName.trim() ?? '';
    if (trackName.isNotEmpty) {
      final cleanedTrackName = trackName.replaceFirst(_trackNameDateSuffix, '').trim();
      if (cleanedTrackName.isNotEmpty) {
        return cleanedTrackName;
      }
    }
  } catch (_) {
    // Fall through to the safe fallback label.
  }
  return 'Track #$gpxId';
}

int _compareDatesDescending(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
}

class _ResolvedPeakInfoAscentRow {
  const _ResolvedPeakInfoAscentRow({
    required this.gpxId,
    required this.date,
    required this.trackLabel,
  });

  final int gpxId;
  final DateTime? date;
  final String trackLabel;
}

String _convertToMgrs(LatLng location) {
  final components = PeakMgrsConverter.fromLatLng(location);
  return '${components.gridZoneDesignator} ${components.mgrs100kId} ${components.easting} ${components.northing}';
}
