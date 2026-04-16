import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;

class PeakMgrsComponents {
  const PeakMgrsComponents({
    required this.gridZoneDesignator,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
  });

  final String gridZoneDesignator;
  final String mgrs100kId;
  final String easting;
  final String northing;
}

class PeakMgrsConverter {
  static const String gridZoneDesignator = '55G';

  static PeakMgrsComponents fromLatLng(LatLng location) {
    final forward = mgrs.Mgrs.forward([
      location.longitude,
      location.latitude,
    ], 5);
    return fromForwardString(forward);
  }

  static PeakMgrsComponents fromForwardString(String forward) {
    final cleaned = forward.replaceAll(RegExp(r'[\s\n]'), '');
    if (cleaned.length < 15) {
      throw FormatException('Invalid MGRS value');
    }

    return PeakMgrsComponents(
      gridZoneDesignator: gridZoneDesignator,
      mgrs100kId: cleaned.substring(3, 5),
      easting: cleaned.substring(5, 10),
      northing: cleaned.substring(10, 15),
    );
  }
}
