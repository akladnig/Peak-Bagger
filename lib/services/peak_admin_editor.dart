import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/geo_areas.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

class PeakAdminFormState {
  const PeakAdminFormState({
    required this.name,
    this.altName = '',
    required this.osmId,
    this.peakbaggerPid = '',
    required this.elevation,
    this.prominence = '',
    this.country = '',
    this.county = '',
    this.range = '',
    this.rating = '',
    this.durationLabel = '',
    this.difficulty = '',
    this.viaFerrata = '',
    this.notes = '',
    required this.latitude,
    required this.longitude,
    required this.region,
    required this.gridZoneDesignator,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
    this.verified = false,
    required this.sourceOfTruth,
  });

  final String name;
  final String altName;
  final String osmId;
  final String peakbaggerPid;
  final String elevation;
  final String prominence;
  final String country;
  final String county;
  final String range;
  final String rating;
  final String durationLabel;
  final String difficulty;
  final String viaFerrata;
  final String notes;
  final String latitude;
  final String longitude;
  final String region;
  final String gridZoneDesignator;
  final String mgrs100kId;
  final String easting;
  final String northing;
  final bool verified;
  final String sourceOfTruth;

  PeakAdminFormState copyWith({
    String? name,
    String? altName,
    String? osmId,
    String? peakbaggerPid,
    String? elevation,
    String? prominence,
    String? country,
    String? county,
    String? range,
    String? rating,
    String? durationLabel,
    String? difficulty,
    String? viaFerrata,
    String? notes,
    String? latitude,
    String? longitude,
    String? region,
    String? gridZoneDesignator,
    String? mgrs100kId,
    String? easting,
    String? northing,
    bool? verified,
    String? sourceOfTruth,
  }) {
    return PeakAdminFormState(
      name: name ?? this.name,
      altName: altName ?? this.altName,
      osmId: osmId ?? this.osmId,
      peakbaggerPid: peakbaggerPid ?? this.peakbaggerPid,
      elevation: elevation ?? this.elevation,
      prominence: prominence ?? this.prominence,
      country: country ?? this.country,
      county: county ?? this.county,
      range: range ?? this.range,
      rating: rating ?? this.rating,
      durationLabel: durationLabel ?? this.durationLabel,
      difficulty: difficulty ?? this.difficulty,
      viaFerrata: viaFerrata ?? this.viaFerrata,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      region: region ?? this.region,
      gridZoneDesignator: gridZoneDesignator ?? this.gridZoneDesignator,
      mgrs100kId: mgrs100kId ?? this.mgrs100kId,
      easting: easting ?? this.easting,
      northing: northing ?? this.northing,
      verified: verified ?? this.verified,
      sourceOfTruth: sourceOfTruth ?? this.sourceOfTruth,
    );
  }
}

enum PeakAdminCoordinateSource { latLng, mgrs }

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

class PeakAdminCalculationResult {
  const PeakAdminCalculationResult({
    required this.fieldErrors,
    this.coordinateError,
    this.form,
  });

  final Map<String, String> fieldErrors;
  final String? coordinateError;
  final PeakAdminFormState? form;

  bool get isValid => form != null;
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
  static const String altNameDuplicateNameError =
      'Alt Name must be different from Name';
  static const String osmIdError = 'osmId must be an integer';
  static const String peakbaggerPidError =
      'PeakBagger PID must be a positive integer';
  static const String elevationError = 'Elevation must be an integer';
  static const String prominenceError = 'Prominence must be a number';
  static const String ratingError =
      'Rating must be a number between 0.0 and 5.0';
  static const String tasmaniaError = 'Entered location is not with Tasmania.';
  static const String latLngConversionError =
      'Failed to derive coordinates from marker.';

  static PeakAdminFormState normalize(Peak peak) {
    return PeakAdminFormState(
      name: peak.name,
      altName: peak.altName,
      osmId: peak.osmId.toString(),
      peakbaggerPid: peak.peakbaggerPid?.toString() ?? '',
      elevation: _formatOptionalNumber(peak.elevation),
      prominence: _formatOptionalNumber(peak.prominence),
      country: peak.country,
      county: peak.county,
      range: peak.range,
      rating: _formatOptionalNumber(peak.rating),
      durationLabel: peakDurationDisplayLabel(peak),
      difficulty: peak.difficulty,
      viaFerrata: peak.viaFerrata,
      notes: peak.notes,
      latitude: formatCoordinate(peak.latitude),
      longitude: formatCoordinate(peak.longitude),
      region: peak.region ?? Peak.defaultRegion,
      gridZoneDesignator: fixedGridZoneDesignator,
      mgrs100kId: peak.mgrs100kId,
      easting: peak.easting,
      northing: peak.northing,
      verified: peak.verified,
      sourceOfTruth: peak.sourceOfTruth,
    );
  }

  static PeakAdminValidationResult validateAndBuild({
    required Peak source,
    required PeakAdminFormState form,
    PeakAdminCoordinateSource? coordinateSource,
  }) {
    final fieldErrors = <String, String>{};

    final name = form.name.trim();
    if (name.isEmpty) {
      fieldErrors['name'] = nameRequiredError;
    }
    final altName = form.altName.trim();
    if (altName.isNotEmpty && altName.toLowerCase() == name.toLowerCase()) {
      fieldErrors['altName'] = altNameDuplicateNameError;
    }

    final osmId = int.tryParse(form.osmId.trim());
    if (osmId == null) {
      fieldErrors['osmId'] = osmIdError;
    }

    final peakbaggerPidText = form.peakbaggerPid.trim();
    final peakbaggerPid = peakbaggerPidText.isEmpty
        ? null
        : int.tryParse(peakbaggerPidText);
    if (peakbaggerPidText.isNotEmpty &&
        (peakbaggerPid == null || peakbaggerPid <= 0)) {
      fieldErrors['peakbaggerPid'] = peakbaggerPidError;
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

    final prominenceText = form.prominence.trim();
    final prominence = prominenceText.isEmpty
        ? null
        : double.tryParse(prominenceText);
    if (prominenceText.isNotEmpty &&
        (prominence == null || !prominence.isFinite)) {
      fieldErrors['prominence'] = prominenceError;
    }

    final ratingText = form.rating.trim();
    final rating = ratingText.isEmpty ? null : double.tryParse(ratingText);
    if (ratingText.isNotEmpty &&
        (rating == null || !rating.isFinite || rating < 0.0 || rating > 5.0)) {
      fieldErrors['rating'] = ratingError;
    }

    final durationText = form.durationLabel.trim();
    ParsedPeakDuration? parsedDuration;
    try {
      parsedDuration = parsePeakDuration(durationText);
    } on FormatException catch (error) {
      fieldErrors['durationLabel'] = error.message;
    }

    final latitudeText = form.latitude.trim();
    final longitudeText = form.longitude.trim();
    final mgrsIdText = form.mgrs100kId.trim();
    final eastingText = form.easting.trim();
    final northingText = form.northing.trim();

    final hasLatLng = latitudeText.isNotEmpty || longitudeText.isNotEmpty;
    final hasMgrs =
        mgrsIdText.isNotEmpty ||
        eastingText.isNotEmpty ||
        northingText.isNotEmpty;
    final latLngComplete = latitudeText.isNotEmpty && longitudeText.isNotEmpty;
    final mgrsComplete =
        mgrsIdText.isNotEmpty &&
        eastingText.isNotEmpty &&
        northingText.isNotEmpty;

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

    final useMgrs = switch (coordinateSource) {
      PeakAdminCoordinateSource.latLng => false,
      PeakAdminCoordinateSource.mgrs => true,
      null => mgrsComplete,
    };

    if (useMgrs) {
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

      final normalizedEasting = _padMgrsComponent(eastingText);
      final normalizedNorthing = _padMgrsComponent(northingText);
      final forward =
          '$fixedGridZoneDesignator${mgrsIdText.toUpperCase()}$normalizedEasting$normalizedNorthing';
      try {
        components = PeakMgrsConverter.fromForwardString(forward);
        final coords = mgrs.Mgrs.toPoint(forward);
        final latLng = LatLng(coords[1], coords[0]);
        latitude = latLng.latitude;
        longitude = latLng.longitude;
      } catch (_) {
        return PeakAdminValidationResult(
          fieldErrors: {
            ...fieldErrors,
            'mgrs100kId': mgrs100kIdError,
            'easting': eastingError,
            'northing': northingError,
          },
        );
      }
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

    if (fieldErrors.isNotEmpty) {
      return PeakAdminValidationResult(fieldErrors: fieldErrors);
    }

    final region = form.region.trim();
    final peak = Peak(
      id: source.id,
      osmId: osmId!,
      peakbaggerPid: peakbaggerPid,
      name: name,
      altName: altName,
      elevation: elevation,
      prominence: prominence,
      country: form.country.trim(),
      county: form.county.trim(),
      range: form.range.trim(),
      rating: rating == null ? null : (rating * 10).round() / 10,
      durationMinutes: parsedDuration?.durationMinutes,
      durationLabel: parsedDuration?.durationLabel ?? '',
      difficulty: form.difficulty.trim(),
      viaFerrata: form.viaFerrata.trim(),
      notes: form.notes.trim(),
      latitude: latitude,
      longitude: longitude,
      region: region.isEmpty ? Peak.defaultRegion : region,
      gridZoneDesignator: components.gridZoneDesignator,
      mgrs100kId: components.mgrs100kId,
      easting: components.easting,
      northing: components.northing,
      verified: form.verified,
      sourceOfTruth: Peak.sourceOfTruthHwc,
    );

    return PeakAdminValidationResult(fieldErrors: fieldErrors, peak: peak);
  }

  static PeakAdminCalculationResult calculateMissingCoordinates({
    required PeakAdminCoordinateSource source,
    required PeakAdminFormState form,
  }) {
    final validation = validateAndBuild(
      source: Peak(name: form.name, latitude: 0, longitude: 0),
      form: form,
      coordinateSource: source,
    );
    final peak = validation.peak;
    if (peak == null) {
      return PeakAdminCalculationResult(
        fieldErrors: validation.fieldErrors,
        coordinateError: validation.coordinateError,
      );
    }

    return PeakAdminCalculationResult(
      fieldErrors: const {},
      form: form.copyWith(
        latitude: formatCoordinate(peak.latitude),
        longitude: formatCoordinate(peak.longitude),
        gridZoneDesignator: peak.gridZoneDesignator,
        mgrs100kId: peak.mgrs100kId,
        easting: peak.easting,
        northing: peak.northing,
      ),
    );
  }

  static PeakAdminValidationResult updatePeakFromLatLng({
    required Peak source,
    required LatLng location,
  }) {
    try {
      final components = PeakMgrsConverter.fromLatLng(location);
      if (!_isInsideTasmania(location.latitude, location.longitude)) {
        return const PeakAdminValidationResult(
          fieldErrors: {},
          coordinateError: tasmaniaError,
        );
      }
      return PeakAdminValidationResult(
        fieldErrors: const {},
        peak: source.copyWith(
          latitude: location.latitude,
          longitude: location.longitude,
          gridZoneDesignator: components.gridZoneDesignator,
          mgrs100kId: components.mgrs100kId,
          easting: components.easting,
          northing: components.northing,
        ),
      );
    } catch (_) {
      return const PeakAdminValidationResult(
        fieldErrors: {},
        coordinateError: latLngConversionError,
      );
    }
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

  static String _padMgrsComponent(String value) {
    return value.padRight(5, '0');
  }

  static bool _isInsideTasmania(double latitude, double longitude) {
    final bounds = GeoAreas.tasmaniaBounds;
    return latitude >= bounds.southWest.latitude &&
        latitude <= bounds.northEast.latitude &&
        longitude >= bounds.southWest.longitude &&
        longitude <= bounds.northEast.longitude;
  }
}
