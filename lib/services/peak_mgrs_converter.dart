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

  @override
  String toString() {
    return 'PeakMgrsComponents(gridZoneDesignator: $gridZoneDesignator, mgrs100kId: $mgrs100kId, easting: $easting, northing: $northing)';
  }
}

class PeakMgrsConverter {
  static PeakMgrsComponents fromLatLng(LatLng location) {
    final forward = mgrs.Mgrs.forward([
      location.longitude,
      location.latitude,
    ], 5);
    return fromForwardString(forward);
  }

  static PeakMgrsComponents fromForwardString(String forward) {
    final cleaned = forward.replaceAll(RegExp(r'[\s\n]'), '');
    final match = RegExp(
      r'^(\d{1,2}[A-Z])([A-Z]{2})(\d{5})(\d{5})$',
    ).firstMatch(cleaned);
    if (match == null) {
      throw FormatException('Invalid MGRS value');
    }

    return PeakMgrsComponents(
      gridZoneDesignator: match.group(1)!,
      mgrs100kId: match.group(2)!,
      easting: match.group(3)!,
      northing: match.group(4)!,
    );
  }
}
