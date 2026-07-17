import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';
import 'package:peak_bagger/services/slovenia_peak_correlation_service.dart';

void main() {
  const baseLatitude = 46.37832;
  const baseLongitude = 13.83648;

  SloveniaHribiSourcePeakListRow row({
    String name = 'Triglav',
    String altitude = '2864',
    String latitude = '46.37832',
    String longitude = '13.83648',
    String country = 'Slovenia',
    String mountainRange = 'Julian Alps',
    String popularity = '100',
    String sourceOfTruth = 'HRIBI',
  }) {
    return SloveniaHribiSourcePeakListRow(
      name: name,
      altName: '',
      country: country,
      sourceOfTruth: sourceOfTruth,
      mountainRange: mountainRange,
      altitude: altitude,
      latitude: latitude,
      longitude: longitude,
      popularity: popularity,
      rangeOrder: 1,
      sourceOrder: 1,
      rangeUrl: 'https://example.com/range',
      hribiDetailUrl: 'https://example.com/hribi',
      montiDetailUrl: 'https://example.com/monti',
    );
  }

  Peak peak({
    required int id,
    required int osmId,
    required String name,
    required double distanceMeters,
    String altName = '',
    double? elevation = 2800,
    double? prominence = 1800,
    String country = 'Stored Country',
    String range = 'Stored Range',
    String county = 'Stored County',
    String difficulty = 'T4',
    String viaFerrata = 'A/B',
    String notes = 'Stored notes',
  }) {
    final moved = LocationDelta(
      distance: distanceMeters,
      angle: LocationDelta.north,
    ).move(Location(baseLatitude, baseLongitude));
    return Peak(
      id: id,
      osmId: osmId,
      name: name,
      altName: altName,
      elevation: elevation,
      prominence: prominence,
      country: country,
      range: range,
      county: county,
      difficulty: difficulty,
      viaFerrata: viaFerrata,
      notes: notes,
      latitude: moved.latitude,
      longitude: moved.longitude,
    );
  }

  SloveniaPeakCorrelationService service(
    List<Peak> peaks, {
    SloveniaCanonicalRegionResolver canonicalRegionResolver =
        const SloveniaCanonicalRegionResolver(),
  }) {
    return SloveniaPeakCorrelationService(
      peakSource: InMemoryPeakSource(peaks),
      canonicalRegionResolver: canonicalRegionResolver,
    );
  }

  group('SloveniaPeakCorrelationService', () {
    test(
      'matches the nearest peak and backfills canonical fields from Peak',
      () {
        final result =
            service([
              peak(
                id: 1,
                osmId: 9001,
                name: 'Triglav',
                distanceMeters: 30,
                elevation: 2864,
                prominence: 2048,
                country: 'Slovenia',
                range: 'Julian Alps',
                county: 'Upper Carniola',
                difficulty: 'T5',
                viaFerrata: 'B',
                notes: 'Snow early season',
              ),
              peak(
                id: 2,
                osmId: 9002,
                name: 'Triglav North',
                distanceMeters: 45,
              ),
            ]).correlate(
              rows: [
                row(
                  altitude: '',
                  country: '',
                  mountainRange: '',
                  popularity: '83',
                ),
              ],
            );

        expect(result.reviewRows, isEmpty);
        expect(result.canonicalRows.single.toCsvRow(), [
          'Triglav',
          '9001',
          '4.2',
          '2864',
          '2048',
          '46.37832',
          '13.83648',
          'Slovenia',
          'Slovenia',
          'Julian Alps',
          'Upper Carniola',
          'T5',
          'B',
          'Snow early season',
          'HRIBI',
        ]);
      },
    );

    test(
      'requires normalized exact name confirmation beyond 50m via altName',
      () {
        final result =
            service([
              peak(
                id: 1,
                osmId: 7001,
                name: 'Montaz',
                altName: 'Jôf di Montasio',
                distanceMeters: 80,
                elevation: 2600,
                prominence: 900,
                country: 'Italy',
                range: 'Stored Range',
              ),
            ]).correlate(
              rows: [
                row(
                  name: 'Jof di Montasio',
                  altitude: '2753',
                  country: 'Italy, Slovenia',
                  mountainRange: 'Julian Alps',
                  popularity: '95',
                ),
              ],
            );

        expect(result.reviewRows, isEmpty);
        expect(result.canonicalRows.single.toCsvRow(), [
          'Jof di Montasio',
          '7001',
          '4.8',
          '2753',
          '900',
          '46.37832',
          '13.83648',
          'Slovenia',
          'Slovenia',
          'Julian Alps',
          'Stored County',
          'T4',
          'A/B',
          'Stored notes; Border peak with Italy',
          'HRIBI',
        ]);
      },
    );

    test(
      'canonicalizes border peaks onto the Italy administrative side when that region wins',
      () {
        final resolver = _FakeCanonicalRegionResolver(
          candidateRegions: const [
            RegionManifestRegionData(
              key: 'fvg',
              name: 'Friuli Venezia Giulia',
              shortName: 'FVG',
              priority: ManifestPriority([2, 1, 1]),
              showInPeakList: false,
              polygons: [],
              basemapKeys: [],
              mapSet: [],
            ),
          ],
        );

        final result =
            service([
              peak(
                id: 1,
                osmId: 7001,
                name: 'Montaz',
                altName: 'Jôf di Montasio',
                distanceMeters: 30,
              ),
            ], canonicalRegionResolver: resolver).correlate(
              rows: [row(name: 'Jof di Montasio', country: 'Italy, Slovenia')],
            );

        expect(result.reviewRows, isEmpty);
        expect(result.canonicalRows.single.country, 'Italy');
        expect(result.canonicalRows.single.region, 'Friuli Venezia Giulia');
        expect(
          result.canonicalRows.single.notes,
          'Stored notes; Border peak with Slovenia',
        );
      },
    );

    test(
      'falls back to review when the nearest beyond-50m candidate lacks a name match',
      () {
        final result =
            service([
              peak(
                id: 1,
                osmId: 8001,
                name: 'Batognica',
                distanceMeters: 80,
                prominence: 123,
                county: 'Should stay hidden',
              ),
            ]).correlate(
              rows: [row(name: 'Krn', popularity: '80')],
            );

        expect(result.canonicalRows, isEmpty);
        expect(result.reviewRows.single.toCsvRow(), [
          'Krn',
          '0',
          '4.0',
          '2864',
          '',
          '46.37832',
          '13.83648',
          'Slovenia',
          'Slovenia',
          'Julian Alps',
          '',
          '',
          '',
          '',
          'HRIBI',
          'name_mismatch_beyond_50m',
        ]);
      },
    );

    test('uses tieWindowMeters only for tie handling and supports zero', () {
      final peaks = [
        peak(id: 1, osmId: 8101, name: 'Near 1', distanceMeters: 30),
        peak(id: 2, osmId: 8102, name: 'Near 2', distanceMeters: 35),
      ];

      final tiedResult = service(
        peaks,
      ).correlate(rows: [row(name: 'Any Name')], tieWindowMeters: 10);
      final untiedResult = service(
        peaks,
      ).correlate(rows: [row(name: 'Any Name')], tieWindowMeters: 0);

      expect(tiedResult.canonicalRows, isEmpty);
      expect(
        tiedResult.reviewRows.single.correlationReason,
        'multiple_tied_candidates',
      );
      expect(untiedResult.reviewRows, isEmpty);
      expect(untiedResult.canonicalRows.single.osmId, '8101');
    });

    test(
      'reviews rows when multiple beyond-50m candidates are name confirmed',
      () {
        final result = service([
          peak(id: 1, osmId: 8201, name: 'Triglav', distanceMeters: 70),
          peak(
            id: 2,
            osmId: 8202,
            name: 'Stored Name',
            altName: 'Triglav',
            distanceMeters: 130,
          ),
        ]).correlate(rows: [row(name: 'Triglav')]);

        expect(result.canonicalRows, isEmpty);
        expect(
          result.reviewRows.single.correlationReason,
          'multiple_name_confirmed_candidates',
        );
      },
    );

    test('reviews rows when no candidate is within 150m', () {
      final result = service([
        peak(id: 1, osmId: 8301, name: 'Far Peak', distanceMeters: 180),
      ]).correlate(rows: [row(name: 'Triglav')]);

      expect(result.canonicalRows, isEmpty);
      expect(
        result.reviewRows.single.correlationReason,
        'no_candidate_within_150m',
      );
    });

    test('reviews rows with missing coordinates', () {
      final result =
          service([
            peak(id: 1, osmId: 8401, name: 'Triglav', distanceMeters: 20),
          ]).correlate(
            rows: [row(latitude: '', longitude: '')],
          );

      expect(result.canonicalRows, isEmpty);
      expect(
        result.reviewRows.single.correlationReason,
        'missing_hribi_coordinates',
      );
    });

    test('reviews rows with insufficient source data before correlation', () {
      final result = service([
        peak(id: 1, osmId: 8501, name: 'Triglav', distanceMeters: 20),
      ]).correlate(rows: [row(name: '')]);

      expect(result.canonicalRows, isEmpty);
      expect(
        result.reviewRows.single.correlationReason,
        'insufficient_source_data_for_correlation',
      );
    });

    test('exposes only the approved deterministic review reason codes', () {
      expect(sloveniaCorrelationReviewCsvHeader, [
        ...sloveniaRankedPeakListCsvHeader,
        'correlationReason',
      ]);
      expect(sloveniaPeakCorrelationReasonCodes, {
        'missing_hribi_coordinates',
        'no_candidate_within_150m',
        'name_mismatch_beyond_50m',
        'multiple_tied_candidates',
        'multiple_name_confirmed_candidates',
        'insufficient_source_data_for_correlation',
        'no_canonical_region_match',
        'tied_canonical_region_priorities',
      });
    });

    test('canonical region resolution uses numeric manifest priorities', () {
      expect(
        ManifestPriority.parse('2.10').compareTo(ManifestPriority.parse('2.2')),
        greaterThan(0),
      );
      expect(
        ManifestPriority.parse(
          '2.1.1',
        ).compareTo(ManifestPriority.parse('2.1')),
        greaterThan(0),
      );
      expect(
        ManifestPriority.parse('2.1').compareTo(ManifestPriority.parse('2')),
        greaterThan(0),
      );
    });

    test(
      'tied canonical region priorities fall into deterministic review output',
      () {
        final resolver = _FakeCanonicalRegionResolver(
          candidateRegions: const [
            RegionManifestRegionData(
              key: 'fvg',
              name: 'Friuli Venezia Giulia',
              shortName: 'FVG',
              priority: ManifestPriority([2, 1, 1]),
              showInPeakList: false,
              polygons: [],
              basemapKeys: [],
              mapSet: [],
            ),
            RegionManifestRegionData(
              key: 'slovenia',
              name: 'Slovenia',
              shortName: 'Slovenia',
              priority: ManifestPriority([2, 1, 1]),
              showInPeakList: true,
              polygons: [],
              basemapKeys: [],
              mapSet: [],
            ),
          ],
        );

        final result = service([
          peak(id: 1, osmId: 9001, name: 'Triglav', distanceMeters: 30),
        ], canonicalRegionResolver: resolver).correlate(rows: [row()]);

        expect(result.canonicalRows, isEmpty);
        expect(
          result.reviewRows.single.correlationReason,
          'tied_canonical_region_priorities',
        );
      },
    );
  });
}

class _FakeCanonicalRegionResolver extends SloveniaCanonicalRegionResolver {
  const _FakeCanonicalRegionResolver({required this.candidateRegions});

  final List<RegionManifestRegionData> candidateRegions;

  @override
  List<RegionManifestRegionData> candidateRegionsForPoint(LatLng point) {
    return candidateRegions;
  }
}
