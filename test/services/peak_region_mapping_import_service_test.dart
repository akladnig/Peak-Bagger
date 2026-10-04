import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/peak_region_asset_import_service.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'imports only eligible peak nodes and records the region fingerprint',
    () async {
      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = _service({
        'Peaks/tasmania.json': jsonEncode({
          'elements': [
            _peak(id: 1, name: ' Cradle Mountain '),
            {
              'type': 'way',
              'id': 2,
              'tags': {'natural': 'peak'},
            },
            {
              'type': 'node',
              'id': 3,
              'tags': {'natural': 'volcano'},
            },
          ],
        }),
      });

      final result = await service.updateRegion(
        peakRepository: repository,
        regionKey: 'tasmania',
      );

      expect(result.importedPeakCount, 1);
      expect(result.skippedPeakCount, 2);
      expect(repository.getAllPeaks().single.name, 'Cradle Mountain');
      expect(repository.getAllPeaks().single.region, 'tasmania');
      expect(repository.regionFingerprints(), {'tasmania': 'tas-fingerprint'});
    },
  );

  test(
    'malformed eligible source leaves region peaks and fingerprint unchanged',
    () async {
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            id: 7,
            osmId: 1,
            name: 'Stored peak',
            latitude: -41.7,
            longitude: 145.9,
            region: 'tasmania',
          ),
        ]),
      );
      await repository.migrateRegionFingerprints({
        'tasmania': 'old-fingerprint',
      });
      final service = _service({
        'Peaks/tasmania.json': jsonEncode({
          'elements': [
            _peak(id: 1, name: 'Updated peak'),
            _peak(id: 0, name: 'Broken peak'),
          ],
        }),
      });

      await expectLater(
        service.updateRegion(peakRepository: repository, regionKey: 'tasmania'),
        throwsA(isA<MappingStoreOperationException>()),
      );

      expect(repository.getAllPeaks().single.name, 'Stored peak');
      expect(repository.regionFingerprints(), {'tasmania': 'old-fingerprint'});
    },
  );

  test(
    'does not read a source for a fingerprint-current manual update',
    () async {
      final repository = PeakRepository.test(InMemoryPeakStorage());
      await repository.migrateRegionFingerprints({
        'tasmania': 'tas-fingerprint',
        'slovenia': 'slo-fingerprint',
      });
      var reads = 0;
      final service = PeakRegionAssetImportService(
        catalog: _catalog(),
        sourceReader: (_) async {
          reads += 1;
          return '{}';
        },
      );

      expect(
        service.changedSeedableRegionKeys(peakRepository: repository),
        isEmpty,
      );
      expect(reads, 0);
    },
  );

  test(
    'non-object entries and duplicate source identities fail a region',
    () async {
      for (final elements in [
        <Object?>[_peak(id: 1, name: 'Cradle Mountain'), 'not an object'],
        <Object?>[
          _peak(id: 1, name: 'Cradle Mountain'),
          _peak(id: 1, name: 'Duplicate Cradle'),
        ],
      ]) {
        final repository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              id: 7,
              osmId: 7,
              name: 'Stored peak',
              latitude: -41.7,
              longitude: 145.9,
              region: 'tasmania',
            ),
          ]),
        );
        await repository.migrateRegionFingerprints({
          'tasmania': 'old-fingerprint',
        });
        final service = _service({
          'Peaks/tasmania.json': jsonEncode({'elements': elements}),
        });

        await expectLater(
          service.updateRegion(
            peakRepository: repository,
            regionKey: 'tasmania',
          ),
          throwsA(isA<MappingStoreOperationException>()),
        );

        expect(repository.getAllPeaks().single.name, 'Stored peak');
        expect(repository.regionFingerprints(), {
          'tasmania': 'old-fingerprint',
        });
      }
    },
  );

  test('rejects identities owned by another region or user data', () async {
    final service = _service({
      'Peaks/tasmania.json': jsonEncode({
        'elements': [_peak(id: 1, name: 'Cradle Mountain')],
      }),
    });
    for (final existing in [
      Peak(
        id: 4,
        osmId: 1,
        name: 'Slovenian owner',
        latitude: 46.3,
        longitude: 13.8,
        region: 'slovenia',
      ),
      Peak(
        id: 5,
        osmId: 1,
        name: 'User owner',
        latitude: -41.7,
        longitude: 145.9,
        region: 'tasmania',
        sourceOfTruth: Peak.sourceOfTruthHwc,
      ),
    ]) {
      final repository = PeakRepository.test(InMemoryPeakStorage([existing]));
      await expectLater(
        service.updateRegion(peakRepository: repository, regionKey: 'tasmania'),
        throwsA(isA<MappingStoreOperationException>()),
      );
      expect(repository.getAllPeaks().single.name, existing.name);
      expect(repository.regionFingerprints(), isEmpty);
    }
  });

  test('rejects identities held by an unowned legacy OSM row', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 4,
          osmId: 1,
          name: 'Legacy peak',
          latitude: -41.7,
          longitude: 145.9,
          region: 'retired-region',
        ),
      ]),
    );
    final service = _service({
      'Peaks/tasmania.json': jsonEncode({
        'elements': [_peak(id: 1, name: 'Cradle Mountain')],
      }),
    });

    await expectLater(
      service.updateRegion(peakRepository: repository, regionKey: 'tasmania'),
      throwsA(isA<MappingStoreOperationException>()),
    );

    expect(repository.getAllPeaks().single.name, 'Legacy peak');
    expect(repository.regionFingerprints(), isEmpty);
  });

  test('reconciles owned rows while preserving user-owned fields', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 4,
          osmId: 1,
          peakbaggerPid: 10,
          name: 'Old Cradle',
          latitude: -41.7,
          longitude: 145.9,
          region: 'tasmania',
          rating: 4.5,
          durationMinutes: 120,
          durationLabel: '2h',
          difficulty: 'Hard',
          viaFerrata: 'None',
          notes: 'Keep me',
          verified: true,
        ),
        Peak(
          id: 5,
          osmId: 2,
          name: 'Removed source peak',
          latitude: -41.8,
          longitude: 145.8,
          region: 'tasmania',
        ),
        Peak(
          id: 6,
          osmId: 3,
          name: 'User peak',
          latitude: -41.9,
          longitude: 145.7,
          region: 'tasmania',
          sourceOfTruth: Peak.sourceOfTruthHwc,
        ),
      ]),
    );
    await repository.migrateRegionFingerprints({'tasmania': 'old'});
    final service = _service({
      'Peaks/tasmania.json': jsonEncode({
        'elements': [_peak(id: 1, name: 'New Cradle')],
      }),
    });

    await service.updateRegion(
      peakRepository: repository,
      regionKey: 'tasmania',
    );

    final peaks = {
      for (final peak in repository.getAllPeaks()) peak.osmId: peak,
    };
    final updated = peaks[1]!;
    expect(updated.id, 4);
    expect(updated.name, 'New Cradle');
    expect(updated.peakbaggerPid, 10);
    expect(updated.rating, 4.5);
    expect(updated.durationMinutes, 120);
    expect(updated.durationLabel, '2h');
    expect(updated.difficulty, 'Hard');
    expect(updated.viaFerrata, 'None');
    expect(updated.notes, 'Keep me');
    expect(updated.verified, isTrue);
    expect(peaks.containsKey(2), isFalse);
    expect(peaks[3]!.sourceOfTruth, Peak.sourceOfTruthHwc);
    expect(repository.regionFingerprints(), {'tasmania': 'tas-fingerprint'});
  });

  test(
    'a populated store migrates markers without opening a seed source',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(name: 'Existing', latitude: -41.7, longitude: 145.9),
        ]),
      );
      var reads = 0;
      final service = PeakRegionAssetImportService(
        catalog: _catalog(),
        sourceReader: (_) async {
          reads += 1;
          return '{}';
        },
      );

      final result = await service.syncOnStartup(peakRepository: repository);

      expect(result.hasChanges, isFalse);
      expect(reads, 0);
      expect(service.changedSeedableRegionKeys(peakRepository: repository), [
        'tasmania',
        'slovenia',
      ]);
    },
  );

  test(
    'automatic seeding reads eligible sources only for an empty store',
    () async {
      var reads = 0;
      final service = PeakRegionAssetImportService(
        catalog: _catalog(),
        sourceReader: (path) async {
          reads += 1;
          return jsonEncode({
            'elements': [
              _peak(id: path == 'Peaks/tasmania.json' ? 1 : 2, name: path),
            ],
          });
        },
      );

      final emptyRepository = PeakRepository.test(InMemoryPeakStorage());
      await service.syncOnStartup(peakRepository: emptyRepository);
      expect(reads, 2);
      expect(emptyRepository.getAllPeaks(), hasLength(2));

      final populatedRepository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(name: 'Existing', latitude: -41.7, longitude: 145.9),
        ]),
      );
      await service.syncOnStartup(peakRepository: populatedRepository);
      expect(reads, 2);
    },
  );

  test(
    'migrates only valid legacy seedable markers before retiring preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        PeakRegionImportMarkerStore.fingerprintsKey: jsonEncode({
          'tasmania': ' legacy-tas ',
          'italy': 'ignored-composite',
          'unknown': 'ignored-unknown',
          'slovenia': '',
        }),
      });
      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = _service(const {});

      await service.migrateLegacyFingerprints(peakRepository: repository);

      expect(repository.regionFingerprints(), {'tasmania': 'legacy-tas'});
      expect(
        await const PeakRegionImportMarkerStore().loadFingerprints(),
        isEmpty,
      );
    },
  );
}

PeakRegionAssetImportService _service(Map<String, String> sources) {
  return PeakRegionAssetImportService(
    catalog: _catalog(),
    sourceReader: (path) async {
      final source = sources[path];
      if (source == null) {
        throw StateError('Missing source $path');
      }
      return source;
    },
  );
}

MappingCatalog _catalog() {
  return MappingCatalog(
    rootPath: '/mapping',
    regions: [
      MappingCatalogRegion(
        key: 'tasmania',
        name: 'Tasmania',
        shortName: 'Tas',
        priority: ManifestPriority.parse('1'),
        showInPeakList: true,
        polyPaths: const [],
        polygons: const [],
        basemapKeys: const [],
        mapSet: const [],
        peakListFilterAliases: const [],
        routingCoverage: null,
        seedOnStartup: true,
        composite: false,
        peaks: const ['Peaks/tasmania.json'],
        highways: const [],
        fingerprint: 'tas-fingerprint',
      ),
      MappingCatalogRegion(
        key: 'slovenia',
        name: 'Slovenia',
        shortName: 'Slo',
        priority: ManifestPriority.parse('2'),
        showInPeakList: true,
        polyPaths: const [],
        polygons: const [],
        basemapKeys: const [],
        mapSet: const [],
        peakListFilterAliases: const [],
        routingCoverage: null,
        seedOnStartup: true,
        composite: false,
        peaks: const ['Peaks/slovenia.json'],
        highways: const [],
        fingerprint: 'slo-fingerprint',
      ),
      MappingCatalogRegion(
        key: 'italy',
        name: 'Italy',
        shortName: 'Italy',
        priority: ManifestPriority.parse('3'),
        showInPeakList: true,
        polyPaths: const [],
        polygons: const [],
        basemapKeys: const [],
        mapSet: const [],
        peakListFilterAliases: const [],
        routingCoverage: null,
        seedOnStartup: true,
        composite: true,
        peaks: const ['Peaks/italy.json'],
        highways: const [],
        fingerprint: null,
      ),
    ],
    basemaps: const [],
    tasmapCatalogPath: 'Maps/tasmap50k.csv',
    naturalFeaturesCatalogPath: 'Features/features.json',
    demSources: const {},
    routingCoverageRegionKeys: const {},
  );
}

Map<String, Object?> _peak({required int id, required String name}) {
  return {
    'type': 'node',
    'id': id,
    'lat': -41.7,
    'lon': 145.9,
    'tags': {'natural': 'peak', 'name': name, 'ele': '1545'},
  };
}
