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
          peakbaggerPid: 456,
          name: 'Cradle',
          altName: 'Cradle Mountain',
          elevation: 1545,
          prominence: 312.5,
          country: 'Australia',
          county: 'Kentish',
          range: 'Central Highlands',
          rating: 4.5,
          durationMinutes: 255,
          durationLabel: '4:15',
          difficulty: 'T3',
          viaFerrata: 'None',
          notes: 'Summit plateau',
          latitude: -41.5,
          longitude: 146.5,
          region: '  Cradle Country  ',
          gridZoneDesignator: '54H',
          mgrs100kId: 'AB',
          easting: '12345',
          northing: '67890',
          verified: true,
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(draft.name, 'Cradle');
      expect(draft.altName, 'Cradle Mountain');
      expect(draft.osmId, '123');
      expect(draft.peakbaggerPid, '456');
      expect(draft.elevation, '1545');
      expect(draft.prominence, '312.5');
      expect(draft.country, 'Australia');
      expect(draft.county, 'Kentish');
      expect(draft.range, 'Central Highlands');
      expect(draft.rating, '4.5');
      expect(draft.durationLabel, '4:15');
      expect(draft.difficulty, 'T3');
      expect(draft.viaFerrata, 'None');
      expect(draft.notes, 'Summit plateau');
      expect(draft.latitude, '-41.500000');
      expect(draft.longitude, '146.500000');
      expect(draft.region, '  Cradle Country  ');
      expect(draft.gridZoneDesignator, PeakAdminEditor.fixedGridZoneDesignator);
      expect(draft.verified, isTrue);
      expect(draft.sourceOfTruth, Peak.sourceOfTruthOsm);
    });

    test('builds a peak from latitude and longitude input', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '1545',
          durationLabel: '4:15',
          latitude: '-41.5',
          longitude: '146.5',
          region: 'Central Highlands',
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
      expect(result.peak?.durationMinutes, 255);
      expect(result.peak?.durationLabel, '4:15');
      expect(result.peak?.latitude, -41.5);
      expect(result.peak?.longitude, 146.5);
      expect(result.peak?.region, 'Central Highlands');
      expect(
        result.peak?.gridZoneDesignator,
        expectedComponents.gridZoneDesignator,
      );
      expect(result.peak?.mgrs100kId, expectedComponents.mgrs100kId);
      expect(result.peak?.easting, expectedComponents.easting);
      expect(result.peak?.northing, expectedComponents.northing);
      expect(result.peak?.sourceOfTruth, Peak.sourceOfTruthHwc);
    });

    test('persists validated metadata and clears optional values', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(
          name: 'Old',
          peakbaggerPid: 1,
          prominence: 2,
          country: 'Old country',
          county: 'Old county',
          range: 'Old range',
          rating: 1,
          difficulty: 'Old difficulty',
          viaFerrata: 'Old via ferrata',
          notes: 'Old notes',
          latitude: -41,
          longitude: 146,
        ),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          peakbaggerPid: '456',
          elevation: '',
          prominence: '312.5',
          country: 'Australia',
          county: 'Kentish',
          range: 'Central Highlands',
          rating: '4.26',
          difficulty: 'T3',
          viaFerrata: 'None',
          notes: 'First line\nSecond line',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.peak?.peakbaggerPid, 456);
      expect(result.peak?.prominence, 312.5);
      expect(result.peak?.country, 'Australia');
      expect(result.peak?.county, 'Kentish');
      expect(result.peak?.range, 'Central Highlands');
      expect(result.peak?.rating, 4.3);
      expect(result.peak?.difficulty, 'T3');
      expect(result.peak?.viaFerrata, 'None');
      expect(result.peak?.notes, 'First line\nSecond line');

      final cleared = PeakAdminEditor.validateAndBuild(
        source: result.peak!,
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(cleared.isValid, isTrue);
      expect(cleared.peak?.peakbaggerPid, isNull);
      expect(cleared.peak?.prominence, isNull);
      expect(cleared.peak?.rating, isNull);
      expect(cleared.peak?.country, isEmpty);
      expect(cleared.peak?.county, isEmpty);
      expect(cleared.peak?.range, isEmpty);
      expect(cleared.peak?.difficulty, isEmpty);
      expect(cleared.peak?.viaFerrata, isEmpty);
      expect(cleared.peak?.notes, isEmpty);
    });

    test('rejects invalid PeakBagger PID, prominence, and rating', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          peakbaggerPid: '0',
          elevation: '',
          prominence: 'unknown',
          rating: '5.1',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.fieldErrors['peakbaggerPid'],
        PeakAdminEditor.peakbaggerPidError,
      );
      expect(result.fieldErrors['prominence'], PeakAdminEditor.prominenceError);
      expect(result.fieldErrors['rating'], PeakAdminEditor.ratingError);
    });

    test('calculates MGRS fields from latitude and longitude input', () {
      final result = PeakAdminEditor.calculateMissingCoordinates(
        source: PeakAdminCoordinateSource.latLng,
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
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
      expect(result.form?.mgrs100kId, expectedComponents.mgrs100kId);
      expect(result.form?.easting, expectedComponents.easting);
      expect(result.form?.northing, expectedComponents.northing);
      expect(result.form?.latitude, '-41.500000');
      expect(result.form?.longitude, '146.500000');
    });

    test('trims alternate name and round-trips verified metadata', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          altName: '  Cradle Mountain  ',
          osmId: '123',
          elevation: '',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          verified: true,
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.peak?.altName, 'Cradle Mountain');
      expect(result.peak?.verified, isTrue);
      expect(result.peak?.region, Peak.defaultRegion);
      expect(result.peak?.durationMinutes, isNull);
      expect(result.peak?.durationLabel, '');
    });

    test('accepts valid range durations in the dedicated editor', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          durationLabel: '4-5 hours',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.peak?.durationMinutes, 300);
      expect(result.peak?.durationLabel, '4-5 hours');
    });

    test('accepts exact day durations in the dedicated editor', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          durationLabel: '2 days',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.peak?.durationMinutes, 2880);
      expect(result.peak?.durationLabel, '2 days');
    });

    test('rejects unsupported duration text clearly', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          durationLabel: 'soon',
          latitude: '-41.5',
          longitude: '146.5',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.fieldErrors['durationLabel'],
        'Invalid peak duration "soon". Expected H:MM, <int>-<int> hour(s), <int>-<int> day(s), 1 day, or <int> days.',
      );
      expect(result.peak, isNull);
    });

    test(
      'rejects alternate name matching canonical name before coordinates',
      () {
        final result = PeakAdminEditor.validateAndBuild(
          source: Peak(name: 'Old', latitude: -41, longitude: 146),
          form: const PeakAdminFormState(
            name: 'Cradle',
            altName: ' cradle ',
            osmId: '123',
            elevation: '',
            latitude: '',
            longitude: '',
            region: '',
            gridZoneDesignator: '55G',
            mgrs100kId: '',
            easting: '',
            northing: '',
            sourceOfTruth: Peak.sourceOfTruthOsm,
          ),
        );

        expect(
          result.fieldErrors['altName'],
          PeakAdminEditor.altNameDuplicateNameError,
        );
        expect(result.coordinateError, isNotNull);
        expect(result.peak, isNull);
      },
    );

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
          region: '',
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

    test('calculates latitude and longitude from MGRS input', () {
      const forward = '55GEN4151353653';
      final result = PeakAdminEditor.calculateMissingCoordinates(
        source: PeakAdminCoordinateSource.mgrs,
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '',
          longitude: '',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '41513',
          northing: '53653',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      final expectedLatLng = mgrs.Mgrs.toPoint(forward);

      expect(result.isValid, isTrue);
      expect(result.form?.latitude, expectedLatLng[1].toStringAsFixed(6));
      expect(result.form?.longitude, expectedLatLng[0].toStringAsFixed(6));
      expect(result.form?.easting, '41513');
      expect(result.form?.northing, '53653');
    });

    test('right-pads MGRS easting and northing for calculate and save', () {
      const forward = '55GEN4150053600';
      final calculated = PeakAdminEditor.calculateMissingCoordinates(
        source: PeakAdminCoordinateSource.mgrs,
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '',
          longitude: '',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '415',
          northing: '536',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );
      final saved = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        coordinateSource: PeakAdminCoordinateSource.mgrs,
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '',
          longitude: '',
          region: '',
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '415',
          northing: '536',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        ),
      );

      final expectedLatLng = mgrs.Mgrs.toPoint(forward);

      expect(calculated.isValid, isTrue);
      expect(calculated.form?.easting, '41500');
      expect(calculated.form?.northing, '53600');
      expect(calculated.form?.latitude, expectedLatLng[1].toStringAsFixed(6));
      expect(calculated.form?.longitude, expectedLatLng[0].toStringAsFixed(6));
      expect(saved.isValid, isTrue);
      expect(saved.peak?.easting, '41500');
      expect(saved.peak?.northing, '53600');
    });

    test(
      'returns validation errors for incomplete or invalid source input',
      () {
        final missingLongitude = PeakAdminEditor.calculateMissingCoordinates(
          source: PeakAdminCoordinateSource.latLng,
          form: const PeakAdminFormState(
            name: 'Cradle',
            osmId: '123',
            elevation: '',
            latitude: '-41.5',
            longitude: '',
            region: '',
            gridZoneDesignator: '55G',
            mgrs100kId: '',
            easting: '',
            northing: '',
            sourceOfTruth: Peak.sourceOfTruthOsm,
          ),
        );
        final invalidMgrs = PeakAdminEditor.calculateMissingCoordinates(
          source: PeakAdminCoordinateSource.mgrs,
          form: const PeakAdminFormState(
            name: 'Cradle',
            osmId: '123',
            elevation: '',
            latitude: '',
            longitude: '',
            region: '',
            gridZoneDesignator: '55G',
            mgrs100kId: 'E',
            easting: '123456',
            northing: '12a',
            sourceOfTruth: Peak.sourceOfTruthOsm,
          ),
        );

        expect(missingLongitude.isValid, isFalse);
        expect(
          missingLongitude.coordinateError,
          'Enter both latitude and longitude.',
        );
        expect(invalidMgrs.isValid, isFalse);
        expect(
          invalidMgrs.fieldErrors['mgrs100kId'],
          PeakAdminEditor.mgrs100kIdError,
        );
        expect(
          invalidMgrs.fieldErrors['easting'],
          PeakAdminEditor.eastingError,
        );
        expect(
          invalidMgrs.fieldErrors['northing'],
          PeakAdminEditor.northingError,
        );
      },
    );

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
          region: '',
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

    test(
      'uses explicit latitude and longitude source when both are complete',
      () {
        final enteredLatLngComponents = PeakMgrsConverter.fromLatLng(
          const LatLng(-42, 147),
        );
        final mgrsComponents = PeakMgrsConverter.fromLatLng(
          const LatLng(-41.85916, 145.97754),
        );
        final result = PeakAdminEditor.validateAndBuild(
          source: Peak(name: 'Old', latitude: -41, longitude: 146),
          coordinateSource: PeakAdminCoordinateSource.latLng,
          form: PeakAdminFormState(
            name: 'Cradle',
            osmId: '123',
            elevation: '1545',
            latitude: '-42.0',
            longitude: '147.0',
            region: '',
            gridZoneDesignator: '55G',
            mgrs100kId: mgrsComponents.mgrs100kId,
            easting: mgrsComponents.easting,
            northing: mgrsComponents.northing,
            sourceOfTruth: Peak.sourceOfTruthOsm,
          ),
        );

        expect(result.isValid, isTrue);
        expect(result.peak?.latitude, -42.0);
        expect(result.peak?.longitude, 147.0);
        expect(result.peak?.mgrs100kId, enteredLatLngComponents.mgrs100kId);
        expect(result.peak?.easting, enteredLatLngComponents.easting);
        expect(result.peak?.northing, enteredLatLngComponents.northing);
      },
    );

    test('rejects partial mixed coordinate input', () {
      final result = PeakAdminEditor.validateAndBuild(
        source: Peak(name: 'Old', latitude: -41, longitude: 146),
        form: const PeakAdminFormState(
          name: 'Cradle',
          osmId: '123',
          elevation: '',
          latitude: '-41.5',
          longitude: '-42.0',
          region: '',
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
          region: '',
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
          region: '',
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
          region: '',
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
            region: '',
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
          region: '',
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

    test('updates a peak from persisted marker coordinates', () {
      final location = const LatLng(-41.6, 146.5);
      final result = PeakAdminEditor.updatePeakFromLatLng(
        source: Peak(
          id: 7,
          osmId: 123,
          name: 'Cradle',
          latitude: -41.5,
          longitude: 146.6,
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '12345',
          northing: '67890',
        ),
        location: location,
      );

      final expected = PeakMgrsConverter.fromLatLng(location);
      expect(result.isValid, isTrue);
      expect(result.coordinateError, isNull);
      expect(result.peak?.latitude, location.latitude);
      expect(result.peak?.longitude, location.longitude);
      expect(result.peak?.gridZoneDesignator, expected.gridZoneDesignator);
      expect(result.peak?.mgrs100kId, expected.mgrs100kId);
      expect(result.peak?.easting, expected.easting);
      expect(result.peak?.northing, expected.northing);
    });

    test('rejects marker coordinates outside Tasmania', () {
      final result = PeakAdminEditor.updatePeakFromLatLng(
        source: Peak(name: 'Cradle', latitude: -41.5, longitude: 146.5),
        location: const LatLng(-35.0, 146.5),
      );

      expect(result.isValid, isFalse);
      expect(result.coordinateError, PeakAdminEditor.tasmaniaError);
      expect(result.peak, isNull);
    });

    test('fails closed when marker coordinate conversion breaks', () {
      final result = PeakAdminEditor.updatePeakFromLatLng(
        source: Peak(name: 'Cradle', latitude: -41.5, longitude: 146.5),
        location: const LatLng(double.nan, 146.5),
      );

      expect(result.isValid, isFalse);
      expect(result.coordinateError, PeakAdminEditor.latLngConversionError);
      expect(result.peak, isNull);
    });
  });
}
