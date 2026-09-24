import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/services/natural_feature_admin_editor.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

void main() {
  final source = NaturalFeature(
    id: 7,
    name: 'Lake Example',
    tag: 'water',
    country: 'Australia',
    county: 'Tasmania',
    region: 'South',
    latitude: -42.68,
    longitude: 146.56,
    gridZoneDesignator: '55G',
    mgrs100kId: 'EN',
    easting: '41513',
    northing: '53653',
    osmId: 123,
    osmType: 'node',
  );

  NaturalFeatureAdminFormState form({
    String name = ' Lake Example ',
    String altName = ' Lake Alt ',
    String tag = ' water ',
    String country = ' Australia ',
    String county = ' Tasmania ',
    String region = ' South ',
    String latitude = '-42.68',
    String longitude = '146.56',
    String mgrs100kId = '',
    String easting = '',
    String northing = '',
    String sourceOfTruth = 'Manual',
  }) {
    return NaturalFeatureAdminFormState(
      name: name,
      altName: altName,
      tag: tag,
      country: country,
      county: county,
      region: region,
      latitude: latitude,
      longitude: longitude,
      gridZoneDesignator: source.gridZoneDesignator,
      mgrs100kId: mgrs100kId,
      easting: easting,
      northing: northing,
      sourceOfTruth: sourceOfTruth,
    );
  }

  test('normalizes and trims editable values while preserving identity', () {
    final result = NaturalFeatureAdminEditor.validateAndBuild(
      source: source,
      form: form(),
    );

    expect(result.isValid, isTrue);
    expect(result.naturalFeature?.id, 7);
    expect(result.naturalFeature?.osmType, 'node');
    expect(result.naturalFeature?.osmId, 123);
    expect(result.naturalFeature?.name, 'Lake Example');
    expect(result.naturalFeature?.altName, 'Lake Alt');
    expect(result.naturalFeature?.tag, 'water');
    expect(result.naturalFeature?.sourceOfTruth, 'Manual');
  });

  test('recalculates MGRS and derived grid zone from latitude longitude', () {
    const location = LatLng(46.8, 13.5);
    final result = NaturalFeatureAdminEditor.validateAndBuild(
      source: source,
      form: form(
        latitude: '${location.latitude}',
        longitude: '${location.longitude}',
      ),
      coordinateSource: NaturalFeatureAdminCoordinateSource.latLng,
    );
    final expected = PeakMgrsConverter.fromLatLng(location);

    expect(result.isValid, isTrue);
    expect(
      result.naturalFeature?.gridZoneDesignator,
      expected.gridZoneDesignator,
    );
    expect(result.naturalFeature?.gridZoneDesignator, isNot('55G'));
    expect(result.naturalFeature?.mgrs100kId, expected.mgrs100kId);
  });

  test('uses the stored non-55G grid zone for MGRS-only input', () {
    const location = LatLng(46.8, 13.5);
    final components = PeakMgrsConverter.fromLatLng(location);
    final non55Source = NaturalFeature(
      id: source.id,
      name: source.name,
      tag: source.tag,
      latitude: location.latitude,
      longitude: location.longitude,
      gridZoneDesignator: components.gridZoneDesignator,
      mgrs100kId: components.mgrs100kId,
      easting: components.easting,
      northing: components.northing,
      osmId: source.osmId,
      osmType: source.osmType,
    );
    final result = NaturalFeatureAdminEditor.validateAndBuild(
      source: non55Source,
      form: NaturalFeatureAdminFormState(
        name: 'Lake Example',
        tag: 'water',
        country: '',
        county: '',
        region: '',
        latitude: '',
        longitude: '',
        gridZoneDesignator: components.gridZoneDesignator,
        mgrs100kId: components.mgrs100kId,
        easting: components.easting,
        northing: components.northing,
        sourceOfTruth: 'OSM',
      ),
      coordinateSource: NaturalFeatureAdminCoordinateSource.mgrs,
    );
    final expected = mgrs.Mgrs.toPoint(
      '${components.gridZoneDesignator}${components.mgrs100kId}'
      '${components.easting}${components.northing}',
    );

    expect(result.isValid, isTrue);
    expect(
      result.naturalFeature?.gridZoneDesignator,
      components.gridZoneDesignator,
    );
    expect(result.naturalFeature?.latitude, closeTo(expected[1], 0.000001));
    expect(result.naturalFeature?.longitude, closeTo(expected[0], 0.000001));
  });

  test('rejects invalid editable values', () {
    final result = NaturalFeatureAdminEditor.validateAndBuild(
      source: source,
      form: form(altName: ' lake example ', tag: ' ', sourceOfTruth: 'HWC'),
    );

    expect(result.isValid, isFalse);
    expect(result.fieldErrors['altName'], isNotNull);
    expect(result.fieldErrors['tag'], isNotNull);
    expect(result.fieldErrors['sourceOfTruth'], isNotNull);
  });
}
