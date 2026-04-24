import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_admin_editor.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

void main() {
  group('PeakAdminEditor', () {
    test('normalizes a peak into read-only draft values', () {
      final draft = PeakAdminEditor.normalize(
        Peak(
          id: 7,
          osmId: 123,
          name: 'Cradle',
          elevation: 1545,
          latitude: -41.5,
          longitude: 146.5,
          area: '  Cradle Country  ',
          gridZoneDesignator: '54H',
          mgrs100kId: 'AB',
          easting: '12345',
          northing: '67890',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(draft.name, 'Cradle');
      expect(draft.osmId, '123');
      expect(draft.elevation, '1545');
      expect(draft.latitude, '-41.5');
      expect(draft.longitude, '146.5');
      expect(draft.area, '  Cradle Country  ');
      expect(draft.gridZoneDesignator, PeakAdminEditor.fixedGridZoneDesignator);
      expect(draft.sourceOfTruth, Peak.sourceOfTruthOsm);
    });

    test('builds a peak from latitude and longitude input', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '1545',
          latitude: '-41.5',
          longitude: '146.5',
          area: 'Central Highlands',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      final expectedComponents = PeakMgrsConverter.fromLatLng(
        const LatLng(-41.5, 146.5),
      );

      expect(result.isValid, isTrue);
      expect(result.coordinateError, isNull);
      expect(result.fieldErrors, isEmpty);
      expect(result.peak, isNotNull);
      expect(result.peak?.id, 0);
      expect(result.peak?.osmId, 123);
      expect(result.peak?.name, 'Cradle');
      expect(result.peak?.elevation, 1545);
      expect(result.peak?.latitude, -41.5);
      expect(result.peak?.longitude, 146.5);
      expect(result.peak?.area, 'Central Highlands');
      expect(
        result.peak?.gridZoneDesignator,
        expectedComponents.gridZoneDesignator,
      );
      expect(result.peak?.mgrs100kId, expectedComponents.mgrs100kId);
      expect(result.peak?.easting, expectedComponents.easting);
      expect(result.peak?.northing, expectedComponents.northing);
      expect(result.peak?.sourceOfTruth, Peak.sourceOfTruthHwc);
    });

    test('derives latitude and longitude from complete MGRS input', () {
      const forward = '55GEN4151353653';
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '1545',
          latitude: '',
          longitude: '',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '41513',
          northing: '53653',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      final expectedLatLng = mgrs.Mgrs.toPoint(forward);

      expect(result.isValid, isTrue);
      expect(result.coordinateError, isNull);
      expect(result.peak?.latitude, expectedLatLng[1]);
      expect(result.peak?.longitude, expectedLatLng[0]);
      expect(
        result.peak?.gridZoneDesignator,
        PeakAdminEditor.fixedGridZoneDesignator,
      );
    });

    test('prefers MGRS input when both coordinate forms are complete', () {
      final mgrsComponents = PeakMgrsConverter.fromLatLng(
        const LatLng(-41.85916, 145.97754),
      );
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '1545',
          latitude: '-42.0',
          longitude: '147.0',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: mgrsComponents.mgrs100kId,
          easting: mgrsComponents.easting,
          northing: mgrsComponents.northing,
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      final expectedForward =
          '55G${mgrsComponents.mgrs100kId}${mgrsComponents.easting}${mgrsComponents.northing}';
      final expectedLatLng = mgrs.Mgrs.toPoint(expectedForward);

      expect(result.isValid, isTrue);
      expect(result.peak?.latitude, expectedLatLng[1]);
      expect(result.peak?.longitude, expectedLatLng[0]);
      expect(result.peak?.mgrs100kId, mgrsComponents.mgrs100kId);
      expect(result.peak?.easting, mgrsComponents.easting);
      expect(result.peak?.northing, mgrsComponents.northing);
    });

    test('rejects partial mixed coordinate input', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '-41.5',
          longitude: '-42.0',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '',
          northing: '53653',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.peak, isNull);
      expect(
        result.coordinateError,
        'Enter either latitude/longitude or MGRS coordinates, not both.',
      );
    });

    test('rejects invalid latitude, longitude, and Tasmania bounds', () {
      final invalidLatitude = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '91',
          longitude: '146.5',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      final outsideTasmania = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '-35.0',
          longitude: '146.5',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(
        invalidLatitude.fieldErrors['latitude'],
        PeakAdminEditor.latitudeRangeError,
      );
      expect(outsideTasmania.coordinateError, PeakAdminEditor.tasmaniaError);
    });

    test('validates required and numeric fields inline', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: ' ',
          osmId: 'abc',
          elevation: '12.4',
          latitude: '',
          longitude: '',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'E',
          easting: '123456',
          northing: '12a',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.fieldErrors['name'], PeakAdminEditor.nameRequiredError);
      expect(result.fieldErrors['osmId'], PeakAdminEditor.osmIdError);
      expect(result.fieldErrors['elevation'], PeakAdminEditor.elevationError);
      expect(result.fieldErrors['mgrs100kId'], PeakAdminEditor.mgrs100kIdError);
      expect(result.fieldErrors['easting'], PeakAdminEditor.eastingError);
      expect(result.fieldErrors['northing'], PeakAdminEditor.northingError);
    });

    test('rejects invalid complete MGRS without throwing', () {
      expect(
        () => PeakAdminEditor.validateAndBuild(
          source: Peak(name: 'Old', latitude: -41, longitude: 146),
          form: const PeakAdminFormState(
            name: 'Cradle',
            osmId: '123',
            elevation: '',
            latitude: '',
            longitude: '',
            area: '',
            gridZoneDesignator: '55G',
            mgrs100kId: 'ZZ',
            easting: '12345',
            northing: '67890',
            sourceOfTruth: Peak.sourceOfTruthOsm,
          ),
        ),
        returnsNormally,
      );

      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '',
          longitude: '',
          area: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'ZZ',
          easting: '12345',
          northing: '67890',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.peak, isNull);
      expect(result.fieldErrors['mgrs100kId'], PeakAdminEditor.mgrs100kIdError);
    });
  });
}
