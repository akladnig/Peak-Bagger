import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

class NaturalFeatureAdminFormState {
  const NaturalFeatureAdminFormState({
    required this.name,
    this.altName = '',
    required this.tag,
    required this.country,
    required this.county,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.gridZoneDesignator,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
    required this.sourceOfTruth,
  });

  final String name;
  final String altName;
  final String tag;
  final String country;
  final String county;
  final String region;
  final String latitude;
  final String longitude;
  final String gridZoneDesignator;
  final String mgrs100kId;
  final String easting;
  final String northing;
  final String sourceOfTruth;

  NaturalFeatureAdminFormState copyWith({
    String? name,
    String? altName,
    String? tag,
    String? country,
    String? county,
    String? region,
    String? latitude,
    String? longitude,
    String? gridZoneDesignator,
    String? mgrs100kId,
    String? easting,
    String? northing,
    String? sourceOfTruth,
  }) {
    return NaturalFeatureAdminFormState(
      name: name ?? this.name,
      altName: altName ?? this.altName,
      tag: tag ?? this.tag,
      country: country ?? this.country,
      county: county ?? this.county,
      region: region ?? this.region,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gridZoneDesignator: gridZoneDesignator ?? this.gridZoneDesignator,
      mgrs100kId: mgrs100kId ?? this.mgrs100kId,
      easting: easting ?? this.easting,
      northing: northing ?? this.northing,
      sourceOfTruth: sourceOfTruth ?? this.sourceOfTruth,
    );
  }
}

enum NaturalFeatureAdminCoordinateSource { latLng, mgrs }

class NaturalFeatureAdminValidationResult {
  const NaturalFeatureAdminValidationResult({
    required this.fieldErrors,
    this.coordinateError,
    this.naturalFeature,
  });

  final Map<String, String> fieldErrors;
  final String? coordinateError;
  final NaturalFeature? naturalFeature;

  bool get isValid => naturalFeature != null;
}

class NaturalFeatureAdminCalculationResult {
  const NaturalFeatureAdminCalculationResult({
    required this.fieldErrors,
    this.coordinateError,
    this.form,
  });

  final Map<String, String> fieldErrors;
  final String? coordinateError;
  final NaturalFeatureAdminFormState? form;

  bool get isValid => form != null;
}

class NaturalFeatureAdminEditor {
  static const nameRequiredError = 'A natural feature name is required';
  static const tagRequiredError = 'A natural feature tag is required';
  static const altNameDuplicateNameError =
      'Alt Name must be different from Name';
  static const sourceOfTruthError = 'Source of truth must be OSM or Manual';
  static const latitudeRangeError =
      'Latitude must be a number between -90.0 and 90.0';
  static const longitudeRangeError =
      'Longitude must be a number between -180.0 and 180.0';
  static const eastingError = 'easting must be a 1-5 digit number';
  static const northingError = 'northing must be a 1-5 digit number';
  static const mgrs100kIdError =
      'The MGRS 100km identifier must be exactly two letter';

  static NaturalFeatureAdminFormState normalize(NaturalFeature feature) {
    return NaturalFeatureAdminFormState(
      name: feature.name,
      altName: feature.altName,
      tag: feature.tag,
      country: feature.country,
      county: feature.county,
      region: feature.region,
      latitude: formatCoordinate(feature.latitude),
      longitude: formatCoordinate(feature.longitude),
      gridZoneDesignator: feature.gridZoneDesignator,
      mgrs100kId: feature.mgrs100kId,
      easting: feature.easting,
      northing: feature.northing,
      sourceOfTruth: feature.sourceOfTruth,
    );
  }

  static NaturalFeatureAdminValidationResult validateAndBuild({
    required NaturalFeature source,
    required NaturalFeatureAdminFormState form,
    NaturalFeatureAdminCoordinateSource? coordinateSource,
  }) {
    final fieldErrors = <String, String>{};
    final name = form.name.trim();
    final altName = form.altName.trim();
    final tag = form.tag.trim();
    final sourceOfTruth = form.sourceOfTruth.trim();
    if (name.isEmpty) {
      fieldErrors['name'] = nameRequiredError;
    }
    if (altName.isNotEmpty && altName.toLowerCase() == name.toLowerCase()) {
      fieldErrors['altName'] = altNameDuplicateNameError;
    }
    if (tag.isEmpty) {
      fieldErrors['tag'] = tagRequiredError;
    }
    if (sourceOfTruth != 'OSM' && sourceOfTruth != 'Manual') {
      fieldErrors['sourceOfTruth'] = sourceOfTruthError;
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
      return NaturalFeatureAdminValidationResult(
        fieldErrors: fieldErrors,
        coordinateError:
            'Enter either latitude/longitude or MGRS coordinates, not both.',
      );
    }
    if (!hasLatLng && !hasMgrs) {
      return NaturalFeatureAdminValidationResult(
        fieldErrors: fieldErrors,
        coordinateError: 'Enter either latitude/longitude or MGRS coordinates.',
      );
    }

    final useMgrs = switch (coordinateSource) {
      NaturalFeatureAdminCoordinateSource.latLng => false,
      NaturalFeatureAdminCoordinateSource.mgrs => true,
      null => mgrsComplete,
    };
    late double latitude;
    late double longitude;
    late PeakMgrsComponents components;
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
        return NaturalFeatureAdminValidationResult(fieldErrors: fieldErrors);
      }
      final forward =
          '${source.gridZoneDesignator.trim().toUpperCase()}'
          '${mgrsIdText.toUpperCase()}${_padMgrsComponent(eastingText)}'
          '${_padMgrsComponent(northingText)}';
      try {
        components = PeakMgrsConverter.fromForwardString(forward);
        final coordinates = mgrs.Mgrs.toPoint(forward);
        latitude = coordinates[1];
        longitude = coordinates[0];
      } catch (_) {
        return const NaturalFeatureAdminValidationResult(
          fieldErrors: {
            'mgrs100kId': mgrs100kIdError,
            'easting': eastingError,
            'northing': northingError,
          },
        );
      }
    } else {
      if (!latLngComplete) {
        return NaturalFeatureAdminValidationResult(
          fieldErrors: fieldErrors,
          coordinateError: 'Enter both latitude and longitude.',
        );
      }
      latitude = double.tryParse(latitudeText) ?? double.nan;
      longitude = double.tryParse(longitudeText) ?? double.nan;
      if (!latitude.isFinite || latitude < -90 || latitude > 90) {
        fieldErrors['latitude'] = latitudeRangeError;
      }
      if (!longitude.isFinite || longitude < -180 || longitude > 180) {
        fieldErrors['longitude'] = longitudeRangeError;
      }
      if (fieldErrors.isNotEmpty) {
        return NaturalFeatureAdminValidationResult(fieldErrors: fieldErrors);
      }
      components = PeakMgrsConverter.fromLatLng(LatLng(latitude, longitude));
    }

    if (fieldErrors.isNotEmpty) {
      return NaturalFeatureAdminValidationResult(fieldErrors: fieldErrors);
    }
    return NaturalFeatureAdminValidationResult(
      fieldErrors: const {},
      naturalFeature: NaturalFeature(
        id: source.id,
        name: name,
        altName: altName,
        tag: tag,
        country: form.country.trim(),
        county: form.county.trim(),
        region: form.region.trim(),
        latitude: latitude,
        longitude: longitude,
        gridZoneDesignator: components.gridZoneDesignator,
        mgrs100kId: components.mgrs100kId,
        easting: components.easting,
        northing: components.northing,
        osmId: source.osmId,
        osmType: source.osmType,
        sourceOfTruth: sourceOfTruth,
      ),
    );
  }

  static NaturalFeatureAdminCalculationResult calculateMissingCoordinates({
    required NaturalFeature source,
    required NaturalFeatureAdminCoordinateSource coordinateSource,
    required NaturalFeatureAdminFormState form,
  }) {
    final validation = validateAndBuild(
      source: source,
      form: form,
      coordinateSource: coordinateSource,
    );
    final feature = validation.naturalFeature;
    if (feature == null) {
      return NaturalFeatureAdminCalculationResult(
        fieldErrors: validation.fieldErrors,
        coordinateError: validation.coordinateError,
      );
    }
    return NaturalFeatureAdminCalculationResult(
      fieldErrors: const {},
      form: form.copyWith(
        latitude: formatCoordinate(feature.latitude),
        longitude: formatCoordinate(feature.longitude),
        gridZoneDesignator: feature.gridZoneDesignator,
        mgrs100kId: feature.mgrs100kId,
        easting: feature.easting,
        northing: feature.northing,
      ),
    );
  }

  static String _padMgrsComponent(String value) => value.padRight(5, '0');
}
