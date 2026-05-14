import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

class PeakInfoContent {
  const PeakInfoContent({
    required this.peak,
    required this.mapName,
    required this.listNames,
  });

  final Peak peak;
  final String mapName;
  final List<String> listNames;
}

PeakInfoContent resolvePeakInfoContent({
  required Peak peak,
  required PeakListRepository peakListRepository,
  required TasmapRepository tasmapRepository,
}) {
  return PeakInfoContent(
    peak: peak,
    mapName: _resolvePeakMapName(peak, tasmapRepository),
    listNames: _resolvePeakListNames(peak.osmId, peakListRepository),
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

String _convertToMgrs(LatLng location) {
  final components = PeakMgrsConverter.fromLatLng(location);
  return '${components.gridZoneDesignator} ${components.mgrs100kId} ${components.easting} ${components.northing}';
}
