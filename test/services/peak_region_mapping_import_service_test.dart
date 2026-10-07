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
    'NE beats Slovenia and Slovenia beats Croatia in either import order',
    () async {
      for (final (preferred, lower) in [
        ('italy-nord-est', 'slovenia'),
        ('slovenia', 'croatia'),
      ]) {
        for (final order in [
          [preferred, lower],
          [lower, preferred],
        ]) {
          final repository = PeakRepository.test(InMemoryPeakStorage());
          final service = _italyService(
            regionKeys: const ['italy-nord-est', 'slovenia', 'croatia'],
            sources: {
              for (final key in ['italy-nord-est', 'slovenia', 'croatia'])
                'Peaks/$key.json': jsonEncode({
                  'elements': [
                    if (key == preferred)
                      _peak(id: 1, name: '$preferred winner'),
                    if (key == lower) ...[
                      _peak(id: 1, name: '$lower shadow'),
                      _peak(id: 2, name: '$lower unique'),
                    ],
                  ],
                }),
            },
          );
          for (final key in order) {
            final result = await service.updateRegion(
              peakRepository: repository,
              regionKey: key,
            );
            if (key == lower) {
              expect(result.importedPeakCount, 1);
              expect(result.skippedPeakCount, 1);
            }
          }
          final peaks = {
            for (final peak in repository.getAllPeaks()) peak.osmId: peak,
          };
          expect(peaks, hasLength(2));
          expect(peaks[1]!.region, preferred);
          expect(peaks[1]!.name, '$preferred winner');
          expect(peaks[2]!.region, lower);
        }
      }
    },
  );

  test(
    'NE source owns overlapping peaks even when NW is imported first',
    () async {
      for (final order in [
        ['italy-nord-est', 'italy-nord-ovest'],
        ['italy-nord-ovest', 'italy-nord-est'],
      ]) {
        final repository = PeakRepository.test(InMemoryPeakStorage());
        final service = _italyService();
        for (final key in order) {
          final result = await service.updateRegion(
            peakRepository: repository,
            regionKey: key,
          );
          if (key == 'italy-nord-ovest') {
            expect(result.importedPeakCount, 1);
            expect(result.skippedPeakCount, 1);
            expect(
              repository.getAllPeaks().where(
                (peak) => peak.osmId == 1 && peak.region == key,
              ),
              isEmpty,
            );
          }
        }
        final peaks = {
          for (final peak in repository.getAllPeaks()) peak.osmId: peak,
        };
        expect(peaks, hasLength(2));
        expect(peaks[1]!.name, 'NE winner');
        expect(peaks[1]!.region, 'italy-nord-est');
        expect(peaks[2]!.region, 'italy-nord-ovest');
        expect(repository.regionFingerprints(), {
          'italy-nord-est': 'ne-fingerprint',
          'italy-nord-ovest': 'nw-fingerprint',
        });
      }
    },
  );

  test(
    'new precedence transfers existing lower-owned peaks without losing IDs or user state',
    () async {
      for (final (preferred, lower) in [
        ('italy-nord-est', 'slovenia'),
        ('slovenia', 'croatia'),
      ]) {
        for (final order in [
          [preferred, lower],
          [lower, preferred],
        ]) {
          final repository = PeakRepository.test(
            InMemoryPeakStorage([
              Peak(
                id: 17,
                osmId: 1,
                name: 'Stored lower owner',
                latitude: -41.7,
                longitude: 145.9,
                region: lower,
                notes: 'Keep border notes',
                rating: 4.5,
                peakbaggerPid: 42,
                verified: true,
              ),
            ]),
          );
          final service = _italyService(
            regionKeys: const ['italy-nord-est', 'slovenia', 'croatia'],
            sources: {
              for (final key in ['italy-nord-est', 'slovenia', 'croatia'])
                'Peaks/$key.json': jsonEncode({
                  'elements': [
                    if (key == preferred || key == lower)
                      _peak(id: 1, name: '$key source'),
                  ],
                }),
            },
          );
          for (final key in order) {
            await service.updateRegion(
              peakRepository: repository,
              regionKey: key,
            );
            final retained = repository.getAllPeaks().single;
            expect(retained.id, 17);
            expect(retained.notes, 'Keep border notes');
            expect(retained.rating, 4.5);
            expect(retained.peakbaggerPid, 42);
            expect(retained.verified, isTrue);
          }
          expect(repository.getAllPeaks().single.region, preferred);
        }
      }
    },
  );

  test(
    'three-source overlaps belong to NE and count once per losing source',
    () async {
      for (final order in [
        ['italy-nord-est', 'slovenia', 'croatia'],
        ['italy-nord-est', 'croatia', 'slovenia'],
        ['slovenia', 'italy-nord-est', 'croatia'],
        ['slovenia', 'croatia', 'italy-nord-est'],
        ['croatia', 'italy-nord-est', 'slovenia'],
        ['croatia', 'slovenia', 'italy-nord-est'],
      ]) {
        final repository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              id: 17,
              osmId: 1,
              name: 'Old Croatia',
              latitude: -41.7,
              longitude: 145.9,
              region: 'croatia',
              notes: 'Retain me',
            ),
          ]),
        );
        final service = _italyService(
          regionKeys: const ['italy-nord-est', 'slovenia', 'croatia'],
          sources: {
            for (final key in order)
              'Peaks/$key.json': jsonEncode({
                'elements': [_peak(id: 1, name: key)],
              }),
          },
        );
        for (final key in order) {
          final result = await service.updateRegion(
            peakRepository: repository,
            regionKey: key,
          );
          expect(result.skippedPeakCount, key == 'italy-nord-est' ? 0 : 1);
          expect(repository.getAllPeaks().single.id, 17);
          expect(repository.getAllPeaks().single.notes, 'Retain me');
        }
        expect(repository.getAllPeaks().single.region, 'italy-nord-est');
      }
    },
  );

  test('new source precedence still refuses user-owned rows', () async {
    for (final (preferred, lower) in [
      ('italy-nord-est', 'slovenia'),
      ('slovenia', 'croatia'),
    ]) {
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            id: 17,
            osmId: 1,
            name: 'User border peak',
            latitude: -41.7,
            longitude: 145.9,
            region: lower,
            sourceOfTruth: Peak.sourceOfTruthHwc,
          ),
        ]),
      );
      final service = _italyService(
        regionKeys: const ['italy-nord-est', 'slovenia', 'croatia'],
        sources: {
          for (final key in ['italy-nord-est', 'slovenia', 'croatia'])
            'Peaks/$key.json': jsonEncode({
              'elements': [if (key == preferred) _peak(id: 1, name: preferred)],
            }),
        },
      );
      await expectLater(
        service.updateRegion(peakRepository: repository, regionKey: preferred),
        throwsA(isA<MappingStoreOperationException>()),
      );
      expect(repository.getAllPeaks().single.name, 'User border peak');
      expect(repository.getAllPeaks().single.region, lower);
      expect(repository.regionFingerprints(), isEmpty);
    }
  });

  test(
    'Croatia fails atomically on a malformed or missing preferred source',
    () async {
      for (final badSource in ['missing', 'malformed', 'duplicate']) {
        final repository = PeakRepository.test(InMemoryPeakStorage());
        final valid = _peak(id: 1, name: 'Shared');
        final service = _italyService(
          regionKeys: const ['italy-nord-est', 'slovenia', 'croatia'],
          sources: {
            'Peaks/italy-nord-est.json': jsonEncode({'elements': <Object?>[]}),
            'Peaks/croatia.json': jsonEncode({
              'elements': [valid],
            }),
            if (badSource != 'missing')
              'Peaks/slovenia.json': jsonEncode({
                'elements': [
                  if (badSource == 'malformed')
                    {...valid, 'lat': 91}
                  else ...[
                    valid,
                    valid,
                  ],
                ],
              }),
          },
        );
        await expectLater(
          service.updateRegion(
            peakRepository: repository,
            regionKey: 'croatia',
          ),
          throwsA(
            isA<MappingStoreOperationException>().having(
              (error) => error.paths,
              'paths',
              ['Peaks/slovenia.json'],
            ),
          ),
        );
        expect(repository.getAllPeaks(), isEmpty);
        expect(repository.regionFingerprints(), isEmpty);
      }
    },
  );

  test(
    'NE transfer retains an existing NW peak and its user fields in either refresh order',
    () async {
      for (final order in [
        ['italy-nord-est', 'italy-nord-ovest'],
        ['italy-nord-ovest', 'italy-nord-est'],
      ]) {
        final repository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              id: 17,
              osmId: 1,
              name: 'Old NW owner',
              latitude: -41.7,
              longitude: 145.9,
              region: 'italy-nord-ovest',
              peakbaggerPid: 42,
              rating: 4.5,
              notes: 'Keep boundary notes',
              verified: true,
            ),
          ]),
        );
        final service = _italyService();
        for (final key in order) {
          await service.updateRegion(
            peakRepository: repository,
            regionKey: key,
          );
          final winner = repository.getAllPeaks().singleWhere(
            (peak) => peak.osmId == 1,
          );
          expect(winner.id, 17);
          expect(winner.notes, 'Keep boundary notes');
          expect(winner.peakbaggerPid, 42);
          expect(winner.rating, 4.5);
          expect(winner.verified, isTrue);
        }
        expect(
          repository
              .getAllPeaks()
              .singleWhere((peak) => peak.osmId == 1)
              .region,
          'italy-nord-est',
        );
      }
    },
  );

  test(
    'overlap precedence still protects user-owned and unowned peaks',
    () async {
      for (final existing in [
        Peak(
          id: 17,
          osmId: 1,
          name: 'User',
          latitude: -41.7,
          longitude: 145.9,
          region: 'italy-nord-ovest',
          sourceOfTruth: Peak.sourceOfTruthHwc,
        ),
        Peak(
          id: 18,
          osmId: 1,
          name: 'Legacy',
          latitude: -41.7,
          longitude: 145.9,
          region: 'retired-region',
        ),
      ]) {
        final repository = PeakRepository.test(InMemoryPeakStorage([existing]));
        await expectLater(
          _italyService().updateRegion(
            peakRepository: repository,
            regionKey: 'italy-nord-est',
          ),
          throwsA(isA<MappingStoreOperationException>()),
        );
        expect(repository.getAllPeaks().single.name, existing.name);
        expect(repository.getAllPeaks().single.region, existing.region);
        expect(repository.regionFingerprints(), isEmpty);
      }
    },
  );

  test(
    'NW validates shadowed records and the preferred source before any write',
    () async {
      final valid = _peak(id: 1, name: 'Valid');
      final invalid = {...valid, 'lat': 91};
      for (final (ne, nw, failurePath) in [
        ([valid], [invalid], 'Peaks/italy-nord-ovest.json'),
        ([invalid], [valid], 'Peaks/italy-nord-est.json'),
        ([valid, valid], [valid], 'Peaks/italy-nord-est.json'),
        ([valid], [valid, valid], 'Peaks/italy-nord-ovest.json'),
      ]) {
        final repository = PeakRepository.test(InMemoryPeakStorage());
        final service = _italyService(
          sources: {
            'Peaks/italy-nord-est.json': jsonEncode({'elements': ne}),
            'Peaks/italy-nord-ovest.json': jsonEncode({'elements': nw}),
          },
        );
        await expectLater(
          service.updateRegion(
            peakRepository: repository,
            regionKey: 'italy-nord-ovest',
          ),
          throwsA(
            isA<MappingStoreOperationException>().having(
              (error) => error.paths,
              'paths',
              contains(failurePath),
            ),
          ),
        );
        expect(repository.getAllPeaks(), isEmpty);
        expect(repository.regionFingerprints(), isEmpty);
      }
    },
  );

  test(
    'a missing preferred source prevents NW reconciliation with its exact path',
    () async {
      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = _italyService(
        sources: {
          'Peaks/italy-nord-ovest.json': jsonEncode({
            'elements': [_peak(id: 1, name: 'NW')],
          }),
        },
      );
      await expectLater(
        service.updateRegion(
          peakRepository: repository,
          regionKey: 'italy-nord-ovest',
        ),
        throwsA(
          isA<MappingStoreOperationException>().having(
            (error) => error.paths,
            'paths',
            ['Peaks/italy-nord-est.json'],
          ),
        ),
      );
      expect(repository.regionFingerprints(), isEmpty);
      expect(repository.getAllPeaks(), isEmpty);
    },
  );

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

PeakRegionAssetImportService _italyService({
  Map<String, String>? sources,
  List<String> regionKeys = const ['italy-nord-est', 'italy-nord-ovest'],
}) {
  final base = _catalog();
  final catalog = MappingCatalog(
    rootPath: base.rootPath,
    regions: [
      for (final (key, priority, fingerprint) in [
        ('italy-nord-est', '2.1', 'ne-fingerprint'),
        ('italy-nord-ovest', '2.2', 'nw-fingerprint'),
        ('slovenia', '3', 'slo-fingerprint'),
        ('croatia', '4', 'cro-fingerprint'),
      ].where((region) => regionKeys.contains(region.$1)))
        MappingCatalogRegion(
          key: key,
          name: key,
          shortName: key,
          priority: ManifestPriority.parse(priority),
          showInPeakList: true,
          polyPaths: const [],
          polygons: const [],
          basemapKeys: const [],
          mapSet: const [],
          peakListFilterAliases: const [],
          routingCoverage: null,
          seedOnStartup: true,
          composite: false,
          peaks: ['Peaks/$key.json'],
          highways: const [],
          fingerprint: fingerprint,
        ),
    ],
    basemaps: base.basemaps,
    tasmapCatalogPath: base.tasmapCatalogPath,
    naturalFeaturesCatalogPath: base.naturalFeaturesCatalogPath,
    demSources: base.demSources,
    routingCoverageRegionKeys: base.routingCoverageRegionKeys,
  );
  final inputs =
      sources ??
      {
        'Peaks/italy-nord-est.json': jsonEncode({
          'elements': [_peak(id: 1, name: 'NE winner')],
        }),
        'Peaks/italy-nord-ovest.json': jsonEncode({
          'elements': [
            _peak(id: 1, name: 'NW shadow'),
            _peak(id: 2, name: 'NW unique'),
          ],
        }),
      };
  return PeakRegionAssetImportService(
    catalog: catalog,
    sourceReader: (path) async =>
        inputs[path] ?? (throw StateError('Missing $path')),
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
