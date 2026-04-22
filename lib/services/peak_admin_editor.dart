import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/geo_areas.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

class PeakAdminFormState {
  const PeakAdminFormState({
    required this.name,
    required this.osmId,
    required this.elevation,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.gridZoneDesignator,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
    required this.sourceOfTruth,
  });

  final String name;
  final String osmId;
  final String elevation;
  final String latitude;
  final String longitude;
  final String area;
  final String gridZoneDesignator;
  final String mgrs100kId;
  final String easting;
  final String northing;
  final String sourceOfTruth;
}

class PeakAdminValidationResult {
  const PeakAdminValidationResult({
    required this.fieldErrors,
    this.coordinateError,
    this.peak,
  });

  final Map<String, String> fieldErrors;
  final String? coordinateError;
  final Peak? peak;

  bool get isValid => peak != null;
}

class PeakAdminEditor {
  static const String fixedGridZoneDesignator = '55G';

  static const String latitudeRangeError =
      'Latitude must be a number between -90.0 and 90.0';
  static const String longitudeRangeError =
      'Longitude must be a number between -180.0 and 180.0';
  static const String eastingError = 'easting must be a 1-5 digit number';
  static const String northingError = 'northing must be a 1-5 digit number';
  static const String mgrs100kIdError =
      'The MGRS 100km identifier must be exactly two letter';
  static const String nameRequiredError = 'A peak name is required';
  static const String osmIdError = 'osmId must be an integer';
  static const String elevationError = 'Elevation must be an integer';
  static const String tasmaniaError = 'Entered location is not with Tasmania.';

  static PeakAdminFormState normalize(Peak peak) {
    return PeakAdminFormState(
      name: peak.name,
      osmId: peak.osmId.toString(),
      elevation: _formatOptionalNumber(peak.elevation),
      latitude: peak.latitude.toString(),
      longitude: peak.longitude.toString(),
      area: peak.area ?? '',
      gridZoneDesignator: fixedGridZoneDesignator,
      mgrs100kId: peak.mgrs100kId,
      easting: peak.easting,
      northing: peak.northing,
      sourceOfTruth: peak.sourceOfTruth,
    );
  }

  static PeakAdminValidationResult validateAndBuild({
    required Peak source,
    required PeakAdminFormState form,
  }) {
    final fieldErrors = <String, String>{};

    final name = form.name.trim();
    if (name.isEmpty) {
      fieldErrors['name'] = nameRequiredError;
    }

    final osmId = int.tryParse(form.osmId.trim());
    if (osmId == null) {
      fieldErrors['osmId'] = osmIdError;
    }

    final elevationText = form.elevation.trim();
    double? elevation;
    if (elevationText.isNotEmpty) {
      final parsedElevation = int.tryParse(elevationText);
      if (parsedElevation == null) {
        fieldErrors['elevation'] = elevationError;
      } else {
        elevation = parsedElevation.toDouble();
      }
    }

    final latitudeText = form.latitude.trim();
    final longitudeText = form.longitude.trim();
    final mgrsIdText = form.mgrs100kId.trim();
    final eastingText = form.easting.trim();
    final northingText = form.northing.trim();

    final hasLatLng = latitudeText.isNotEmpty || longitudeText.isNotEmpty;
    final hasMgrs =
        mgrsIdText.isNotEmpty || eastingText.isNotEmpty || northingText.isNotEmpty;
    final latLngComplete = latitudeText.isNotEmpty && longitudeText.isNotEmpty;
    final mgrsComplete =
        mgrsIdText.isNotEmpty && eastingText.isNotEmpty && northingText.isNotEmpty;

    if (hasLatLng && hasMgrs && !(latLngComplete && mgrsComplete)) {
      return PeakAdminValidationResult(
        fieldErrors: fieldErrors,
        coordinateError:
            'Enter either latitude/longitude or MGRS coordinates, not both.',
      );
    }

    if (!hasLatLng && !hasMgrs) {
      return PeakAdminValidationResult(
        fieldErrors: fieldErrors,
        coordinateError: 'Enter either latitude/longitude or MGRS coordinates.',
      );
    }

    double latitude;
    double longitude;
    PeakMgrsComponents components;

    if (mgrsComplete) {
      if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(mgrsIdText)) {
        fieldErrors['mgrs100kId'] = mgrs100kIdError;
      }
      if (!RegExp(r'^\d{1,5}$').hasMatch(eastingText)) {
        fieldErrors['easting'] = eastingError;
      }
      if (!RegExp(r'^\d{1,5}$').hasMatch(northingText)) {
        fieldErrors['northing'] = northingError;
      }

      if (fieldErrors.isNotEmpty) {
        return PeakAdminValidationResult(fieldErrors: fieldErrors);
      }

      final forward =
          '$fixedGridZoneDesignator${mgrsIdText.toUpperCase()}$eastingText$northingText';
      components = PeakMgrsConverter.fromForwardString(forward);
      final coords = mgrs.Mgrs.toPoint(forward);
      final latLng = LatLng(coords[1], coords[0]);
      latitude = latLng.latitude;
      longitude = latLng.longitude;
    } else {
      if (!latLngComplete) {
        return PeakAdminValidationResult(
          fieldErrors: fieldErrors,
          coordinateError: 'Enter both latitude and longitude.',
        );
      }

      final parsedLatitude = double.tryParse(latitudeText);
      if (parsedLatitude == null ||
          parsedLatitude < -90.0 ||
          parsedLatitude > 90.0) {
        fieldErrors['latitude'] = latitudeRangeError;
      }

      final parsedLongitude = double.tryParse(longitudeText);
      if (parsedLongitude == null ||
          parsedLongitude < -180.0 ||
          parsedLongitude > 180.0) {
        fieldErrors['longitude'] = longitudeRangeError;
      }

      if (fieldErrors.isNotEmpty) {
        return PeakAdminValidationResult(fieldErrors: fieldErrors);
      }

      latitude = parsedLatitude!;
      longitude = parsedLongitude!;
      components = PeakMgrsConverter.fromLatLng(LatLng(latitude, longitude));
    }

    final isInsideTasmania = _isInsideTasmania(latitude, longitude);
    if (!isInsideTasmania) {
      return PeakAdminValidationResult(
        fieldErrors: fieldErrors,
        coordinateError: tasmaniaError,
      );
    }

    final area = form.area.trim();
    final peak = Peak(
      id: source.id,
      osmId: osmId!,
      name: name,
      elevation: elevation,
      latitude: latitude,
      longitude: longitude,
      area: area.isEmpty ? null : area,
      gridZoneDesignator: components.gridZoneDesignator,
      mgrs100kId: components.mgrs100kId,
      easting: components.easting,
      northing: components.northing,
      sourceOfTruth: Peak.sourceOfTruthHwc,
    );

    return PeakAdminValidationResult(fieldErrors: fieldErrors, peak: peak);
  }

  static String _formatOptionalNumber(double? value) {
    if (value == null) {
      return '';
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  static bool _isInsideTasmania(double latitude, double longitude) {
    final bounds = GeoAreas.tasmaniaBounds;
    return latitude >= bounds.southWest.latitude &&
        latitude <= bounds.northEast.latitude &&
        longitude >= bounds.southWest.longitude &&
        longitude <= bounds.northEast.longitude;
  }
}
