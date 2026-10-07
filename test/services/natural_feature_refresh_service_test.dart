import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/natural_feature_refresh_service.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

void main() {
  const mgrs = PeakMgrsComponents(
    gridZoneDesignator: '55G',
    mgrs100kId: 'AA',
    easting: '12345',
    northing: '67890',
  );

  NaturalFeatureRefreshService serviceFor(
    String source, {
    NaturalFeatureRepository? repository,
    NaturalFeatureMgrsConverter? converter,
    NaturalFeatureRefreshPersistence? persistence,
  }) {
    return NaturalFeatureRefreshService(
      repository ??
          NaturalFeatureRepository.test(InMemoryNaturalFeatureStorage()),
      fileReader: (_) async => source,
      mgrsConverter: converter ?? (_) => mgrs,
      persistence: persistence,
    );
  }

  test(
    'maps fixture candidates and ignores untagged geometry dependencies',
    () async {
      final source = await File(
        'test/fixtures/natural_features/basic.json',
      ).readAsString();
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage(),
      );

      final result = await serviceFor(source, repository: repository).refresh();

      expect(result.createdCount, 1);
      expect(result.skippedCount, 1);
      final feature = repository.getAllNaturalFeatures().single;
      expect(feature.name, 'Lake Dobson');
      expect(feature.altName, 'The Lake');
      expect(feature.tag, 'lake');
      expect(feature.country, 'Australia');
      expect(feature.region, 'Tasmania');
      expect(feature.county, isEmpty);
    },
  );

  test('uses fixed-plane centroids for closed and open ways', () {
    final plan = buildNaturalFeatureRefreshPlan({
      'manualIdentities': const <String>[],
      'sourceText': '''{
        "elements": [
          {"type":"node","id":1,"lat":-43,"lon":146},
          {"type":"node","id":2,"lat":-43,"lon":147},
          {"type":"node","id":3,"lat":-42,"lon":147},
          {"type":"node","id":4,"lat":-42,"lon":146},
          {"type":"way","id":5,"nodes":[1,2,3,4,1],"tags":{"name":"Area","natural":"wood"}},
          {"type":"way","id":6,"nodes":[1,2,3],"tags":{"name":"Line","natural":"cliff"}}
        ]
      }''',
    });

    final features = plan['features']! as List<Object?>;
    final area = features[0]! as Map<Object?, Object?>;
    final line = features[1]! as Map<Object?, Object?>;
    expect(area['latitude'], closeTo(-42.5, 0.000001));
    expect(area['longitude'], closeTo(146.5, 0.000001));
    expect(line['latitude'], closeTo(-42.713162, 0.000001));
    expect(line['longitude'], closeTo(146.786838, 0.000001));
  });

  test('skips a well-formed node-only site relation with a diagnostic', () {
    final plan = buildNaturalFeatureRefreshPlan({
      'sourceText': '''{"elements":[
        {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Tree","natural":"tree"}},
        {"type":"node","id":2,"lat":-42.1,"lon":146.1},
        {"type":"relation","id":20,"members":[{"type":"node","ref":1},{"type":"node","ref":2,"role":""}],"tags":{"name":"Sisters Hills","natural":"mountain_range","type":"site"}}
      ]}''',
    });

    final features = plan['features']! as List<Object?>;
    expect(features, hasLength(1));
    expect((features.single! as Map<Object?, Object?>)['name'], 'Tree');
    expect(plan['skippedCount'], 1);
    expect(
      plan['geometryErrors'],
      contains(
        'Skipped relation:20 — Sisters Hills: '
        'node-only relation has no supported centroid geometry.',
      ),
    );
  });

  test('does not skip malformed or broken supported relation geometry', () async {
    for (final (dependencies, members, relationType) in [
      ('', '[]', 'site'),
      ('', '[{"type":"node","ref":0}]', 'site'),
      ('', '[{"type":"node","ref":999}]', 'site'),
      (
        '{"type":"node","id":1,"lat":91,"lon":146},',
        '[{"type":"node","ref":1}]',
        'site',
      ),
      (
        '{"type":"node","id":1,"lat":-42,"lon":146},',
        '[{"type":"node","ref":1,"role":1}]',
        'site',
      ),
      (
        '{"type":"node","id":1,"lat":-42,"lon":146},',
        '[{"type":"node","ref":1}]',
        'multipolygon',
      ),
      ('', '[{"type":"way","ref":10}]', 'site'),
      (
        '{"type":"node","id":1,"lat":-42,"lon":146},'
            '{"type":"node","id":2,"lat":-42,"lon":146},'
            '{"type":"way","id":10,"nodes":[1,2]},',
        '[{"type":"way","ref":10}]',
        'site',
      ),
    ]) {
      var writes = 0;
      await expectLater(
        serviceFor(
          '{"elements":[$dependencies'
          '{"type":"node","id":90,"lat":-42,"lon":146,"tags":{"name":"Tree","natural":"tree"}},'
          '{"type":"relation","id":20,"members":$members,"tags":{"name":"Hills","natural":"mountain_range","type":"$relationType"}}]}',
          persistence: ({required upserts, required deletedIds}) => writes++,
        ).refresh(),
        throwsA(isA<MappingStoreOperationException>()),
      );
      expect(writes, 0);
    }
  });

  test(
    'rejects duplicate eligible relations even when their geometry is unsupported',
    () async {
      var writes = 0;
      await expectLater(
        serviceFor(
          '''{"elements":[
          {"type":"node","id":1,"lat":-42,"lon":146},
          {"type":"relation","id":20,"members":[{"type":"node","ref":1}],"tags":{"name":"Hills","natural":"mountain_range","type":"site"}},
          {"type":"relation","id":20,"members":[{"type":"node","ref":1}],"tags":{"name":"Hills","natural":"mountain_range","type":"site"}}
        ]}''',
          persistence: ({required upserts, required deletedIds}) => writes++,
        ).refresh(),
        throwsA(
          isA<MappingStoreOperationException>().having(
            (error) => error.cause,
            'cause',
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Duplicate eligible source OSM feature identity for relation:20',
            ),
          ),
        ),
      );
      expect(writes, 0);
    },
  );

  test('retains existing OSM and Manual rows for a skipped relation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'skipped-relation-',
    );
    final store = await openStore(directory: directory.path);
    addTearDown(() async {
      store.close();
      await directory.delete(recursive: true);
    });
    final repository = NaturalFeatureRepository(store);
    final osm = repository.save(
      NaturalFeature(
        name: 'Existing hills',
        altName: 'Curated name',
        tag: 'mountain_range',
        latitude: -41,
        longitude: 147,
        osmType: 'relation',
        osmId: 20,
      ),
    );
    final manual = repository.save(
      NaturalFeature(
        name: 'Manual hills',
        tag: 'mountain_range',
        latitude: -43,
        longitude: 145,
        osmType: 'relation',
        osmId: 20,
        sourceOfTruth: 'Manual',
      ),
    );
    final diagnostics = <String>[];
    final service = NaturalFeatureRefreshService(
      repository,
      fileReader: (_) async => '''{"elements":[
        {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Tree","natural":"tree"}},
        {"type":"relation","id":20,"members":[{"type":"node","ref":1}],"tags":{"name":"Sisters Hills","natural":"mountain_range","type":"site"}}
      ]}''',
      mgrsConverter: (_) => mgrs,
      diagnosticLogger: diagnostics.add,
    );

    final first = await service.refresh();
    expect(first.createdCount, 1);
    expect(first.updatedCount, 0);
    expect(first.skippedCount, 1);
    final originalIds = repository
        .getAllNaturalFeatures()
        .map((row) => row.id)
        .toSet();
    final second = await service.refresh();
    expect(second.createdCount, 0);
    expect(second.updatedCount, 1);
    expect(second.skippedCount, 1);
    final rows = repository.getAllNaturalFeatures();
    expect(rows.map((row) => row.id).toSet(), originalIds);
    expect(rows, hasLength(3));
    final retainedOsm = rows.singleWhere((row) => row.id == osm.id);
    expect(retainedOsm.name, osm.name);
    expect(retainedOsm.altName, osm.altName);
    expect(retainedOsm.latitude, osm.latitude);
    expect(retainedOsm.longitude, osm.longitude);
    expect(retainedOsm.sourceRecordKey, 'OSM:relation:20');
    final retainedManual = rows.singleWhere((row) => row.id == manual.id);
    expect(retainedManual.name, manual.name);
    expect(retainedManual.latitude, manual.latitude);
    expect(retainedManual.longitude, manual.longitude);
    expect(retainedManual.sourceRecordKey, 'Manual:relation:20');
    expect(
      diagnostics.where(
        (message) => message.startsWith('Skipped relation:20 — Sisters Hills:'),
      ),
      hasLength(2),
    );
  });

  test(
    'preserves a Manual row while creating an OSM row with the same identity',
    () async {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([
          NaturalFeature(
            id: 7,
            name: 'Curated lake',
            tag: 'lake',
            latitude: -42.7,
            longitude: 146.5,
            osmId: 44,
            osmType: 'node',
            sourceOfTruth: 'Manual',
          ),
        ]),
      );
      final result = await serviceFor(
        '''{"elements":[{"type":"node","id":44,"lat":-42.6,"lon":146.4,"tags":{"name":"Source lake","natural":"water"}}]}''',
        repository: repository,
      ).refresh();

      expect(result.protectedCount, 0);
      expect(result.skippedCount, 0);
      expect(repository.getAllNaturalFeatures(), hasLength(2));
      expect(
        repository
            .getAllNaturalFeatures()
            .where((feature) => feature.sourceOfTruth == 'Manual')
            .single
            .name,
        'Curated lake',
      );
      expect(
        repository
            .getAllNaturalFeatures()
            .where((feature) => feature.sourceOfTruth == 'OSM')
            .single
            .sourceKey,
        'OSM:node:44',
      );
    },
  );

  test('rejects duplicate source identities before persistence', () async {
    var persisted = false;

    await expectLater(
      serviceFor(
        '''{"elements":[
          {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"One","natural":"tree"}},
          {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Two","natural":"tree"}}
        ]}''',
        persistence: ({required upserts, required deletedIds}) =>
            persisted = true,
      ).refresh(),
      throwsA(anything),
    );

    expect(persisted, isFalse);
  });

  test('rejects identical eligible features with their OSM identity', () async {
    var writes = 0;
    await expectLater(
      serviceFor(
        '''{"elements":[
          {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Tree","natural":"tree"}},
          {"type":"node","id":1,"lat":-42,"lon":146},
          {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Tree","natural":"tree"}}
        ]}''',
        persistence: ({required upserts, required deletedIds}) => writes++,
      ).refresh(),
      throwsA(
        isA<MappingStoreOperationException>().having(
          (error) => error.cause,
          'cause',
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Duplicate eligible source OSM feature identity for node:1',
          ),
        ),
      ),
    );
    expect(writes, 0);
  });

  test('rejects conflicting dependency geometry before any writes', () async {
    for (final (identity, dependencies) in [
      (
        'node:1',
        '{"type":"node","id":1,"lat":-42,"lon":146},'
            '{"type":"node","id":1,"lat":-42.1,"lon":146}',
      ),
      (
        'way:10',
        '{"type":"way","id":10,"nodes":[1,2]},'
            '{"type":"way","id":10,"nodes":[2,1]}',
      ),
      (
        'relation:20',
        '{"type":"relation","id":20,"members":[{"type":"way","ref":10,"role":"outer"}]},'
            '{"type":"relation","id":20,"members":[{"type":"way","ref":10,"role":"inner"}]}',
      ),
    ]) {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([_feature(id: 7)]),
      );
      var writes = 0;
      await expectLater(
        serviceFor(
          '{"elements":['
          '{"type":"node","id":99,"lat":-42,"lon":146,"tags":{"name":"Changed","natural":"tree"}},'
          '$dependencies]}',
          repository: repository,
          persistence: ({required upserts, required deletedIds}) => writes++,
        ).refresh(),
        throwsA(
          isA<MappingStoreOperationException>().having(
            (error) => error.cause,
            'cause',
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Conflicting source OSM geometry for $identity',
            ),
          ),
        ),
      );
      expect(writes, 0);
      final preserved = repository.getAllNaturalFeatures().single;
      expect(preserved.id, 7);
      expect(preserved.name, 'Feature 7');
    }
  });

  test('imports a tagged way repeated as an untagged skeleton once', () async {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage(),
    );
    final result = await serviceFor('''{"elements":[
        {"type":"node","id":1,"lat":-42,"lon":146},
        {"type":"node","id":2,"lat":-42.1,"lon":146.1},
        {"type":"way","id":10,"nodes":[1,2],"tags":{"name":"Cliff","natural":"cliff"}},
        {"type":"way","id":10,"nodes":[1,2]}
      ]}''', repository: repository).refresh();

    expect(result.createdCount, 1);
    expect(result.skippedCount, 0);
    final feature = repository.getAllNaturalFeatures().single;
    expect(feature.osmId, 10);
    expect(feature.osmType, 'way');
    expect(feature.name, 'Cliff');
    expect(feature.latitude, closeTo(-42.05, 0.000001));
    expect(feature.longitude, closeTo(146.05, 0.000001));
  });

  test('accepts matching node dependencies before a tagged node', () async {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage(),
    );
    final result = await serviceFor('''{"elements":[
        {"type":"node","id":1,"lat":-42,"lon":146},
        {"type":"node","id":1,"lat":-42.0,"lon":146.0},
        {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Tree","natural":"tree"}}
      ]}''', repository: repository).refresh();

    expect(result.createdCount, 1);
    expect(result.skippedCount, 0);
    expect(repository.getAllNaturalFeatures().single.name, 'Tree');
  });

  test(
    'refreshes skeleton pairs without changing ownership or ObjectBox IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'skeleton-refresh-',
      );
      final store = await openStore(directory: directory.path);
      addTearDown(() async {
        store.close();
        await directory.delete(recursive: true);
      });
      final repository = NaturalFeatureRepository(store);
      final osm = repository.save(
        NaturalFeature(
          name: 'Curated cliff',
          altName: 'Alternate cliff',
          tag: 'old',
          county: 'Curated county',
          latitude: -42,
          longitude: 146,
          osmId: 10,
          osmType: 'way',
        ),
      );
      final manual = repository.save(
        NaturalFeature(
          name: 'Manual cliff',
          tag: 'manual',
          latitude: -41,
          longitude: 147,
          osmId: 10,
          osmType: 'way',
          sourceOfTruth: 'Manual',
        ),
      );
      final omitted = repository.save(_feature(id: 0));
      final service = serviceFor('''{"elements":[
        {"type":"node","id":1,"lat":-42,"lon":146},
        {"type":"node","id":2,"lat":-42.1,"lon":146.1},
        {"type":"way","id":10,"nodes":[1,2]},
        {"type":"way","id":10,"nodes":[1,2],"tags":{"name":"Cliff","natural":"cliff"}}
      ]}''', repository: repository);

      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await service.refresh();
        expect(result.createdCount, 0);
        expect(result.updatedCount, 1);
        final rows = repository.getAllNaturalFeatures();
        expect(
          rows.map((row) => row.id),
          unorderedEquals([osm.id, manual.id, omitted.id]),
        );
        final updated = rows.singleWhere((row) => row.id == osm.id);
        expect(updated.name, 'Curated cliff');
        expect(updated.altName, 'Alternate cliff');
        expect(updated.county, 'Curated county');
        expect(updated.tag, 'cliff');
        expect(updated.sourceRecordKey, 'OSM:way:10');
        final protected = rows.singleWhere((row) => row.id == manual.id);
        expect(protected.name, manual.name);
        expect(protected.tag, manual.tag);
        expect(protected.latitude, manual.latitude);
        expect(protected.sourceRecordKey, 'Manual:way:10');
      }
    },
  );

  test(
    'accepts matching relation skeletons regardless of source order',
    () async {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage(),
      );
      final result = await serviceFor('''{"elements":[
        {"type":"relation","id":20,"members":[{"ref":10,"type":"way"}]},
        {"type":"relation","id":20,"members":[{"type":"way","ref":10,"role":""}],"tags":{"name":"Coast","natural":"cliff"}},
        {"type":"way","id":10,"nodes":[1,2]},
        {"type":"node","id":1,"lat":-42,"lon":146},
        {"type":"node","id":2,"lat":-42.1,"lon":146.1},
        {"type":"way","id":10,"nodes":[1,2],"tags":{"name":"Cliff","natural":"cliff"}}
      ]}''', repository: repository).refresh();

      expect(result.createdCount, 2);
      expect(result.skippedCount, 0);
      expect(
        repository.getAllNaturalFeatures().map((feature) => feature.name),
        unorderedEquals(['Coast', 'Cliff']),
      );
      for (final feature in repository.getAllNaturalFeatures()) {
        expect(feature.latitude, closeTo(-42.05, 0.000001));
        expect(feature.longitude, closeTo(146.05, 0.000001));
      }
    },
  );

  for (final source in [
    'invalid-json',
    '{}',
    '{"elements":[{"type":"node","id":1,"lat":-42,"lon":146},{"type":"node","id":1,"lat":-42.1,"lon":146}]}',
    '{"elements":[{"type":"node","id":1,"lat":91,"lon":146,"tags":{"name":"Invalid","natural":"tree"}}]}',
    '{"elements":[{"type":"node","id":1,"lat":-42,"lon":146},{"type":"way","id":10,"nodes":[1],"tags":{"name":"Invalid way","natural":"cliff"}}]}',
    '{"elements":[{"type":"node","id":1,"lat":-42,"lon":146},{"type":"node","id":2,"lat":-42.1,"lon":146.1},{"type":"way","id":10,"nodes":[1,2]},{"type":"relation","id":20,"tags":{"name":"Cliff","natural":"cliff"},"members":[{"type":"way","ref":10},{"type":"node","ref":0}]}]}',
  ]) {
    test('rejects malformed supporting source $source before writes', () async {
      var writes = 0;
      await expectLater(
        serviceFor(
          source,
          persistence: ({required upserts, required deletedIds}) {
            writes++;
          },
        ).refresh(),
        throwsA(isA<MappingStoreOperationException>()),
      );
      expect(writes, 0);
    });
  }

  test(
    'rejects malformed selected candidates without changing stored rows',
    () async {
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([
          NaturalFeature(
            id: 5,
            name: 'Existing lake',
            tag: 'lake',
            latitude: -42,
            longitude: 146,
            osmId: 5,
            osmType: 'node',
          ),
        ]),
      );

      await expectLater(
        serviceFor(
          '''{"elements":[{"type":"node","id":6,"lat":"invalid","lon":146,"tags":{"name":"Broken lake","natural":"water"}}]}''',
          repository: repository,
        ).refresh(),
        throwsA(isA<MappingStoreOperationException>()),
      );

      expect(repository.getAllNaturalFeatures().single.name, 'Existing lake');
    },
  );

  test('keeps stored records when MGRS conversion fails', () async {
    var persisted = false;
    await expectLater(
      serviceFor(
        '''{"elements":[{"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"One","natural":"tree"}}]}''',
        converter: (_) => throw const FormatException('invalid MGRS'),
        persistence: ({required upserts, required deletedIds}) =>
            persisted = true,
      ).refresh(),
      throwsA(isA<MappingStoreOperationException>()),
    );
    expect(persisted, isFalse);
  });

  test('preserves curated OSM fields and ObjectBox ids on update', () async {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage([
        NaturalFeature(
          id: 7,
          name: 'Curated name',
          altName: 'Curated alternate',
          tag: 'old',
          country: 'Custom country',
          county: 'Custom county',
          region: 'Custom region',
          latitude: -42,
          longitude: 146,
          osmId: 1,
          osmType: 'node',
        ),
      ]),
    );
    final result = await serviceFor(
      '''{"elements":[{"type":"node","id":1,"lat":-42.5,"lon":146.5,"tags":{"name":"Source name","natural":"water"}}]}''',
      repository: repository,
    ).refresh();

    expect(result.updatedCount, 1);
    final updated = repository.getAllNaturalFeatures().single;
    expect(updated.id, 7);
    expect(updated.name, 'Curated name');
    expect(updated.altName, 'Curated alternate');
    expect(updated.country, 'Custom country');
    expect(updated.county, 'Custom county');
    expect(updated.region, 'Custom region');
    expect(updated.tag, 'water');
  });

  test('reports an unavailable Mapping source with its catalog path', () async {
    final service = NaturalFeatureRefreshService(
      NaturalFeatureRepository.test(InMemoryNaturalFeatureStorage()),
      fileReader: (_) => throw FileSystemException(),
    );

    await expectLater(
      service.refresh(),
      throwsA(
        isA<MappingStoreOperationException>().having(
          (error) => error.paths,
          'paths',
          ['naturalFeatures.catalog'],
        ),
      ),
    );
  });

  test(
    'migrates duplicate OSM rows by retaining the lowest ObjectBox id',
    () async {
      var persisted = false;
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([_feature(id: 1), _feature(id: 2)]),
      );

      await serviceFor(
        '''{"elements":[]}''',
        repository: repository,
        persistence: ({required upserts, required deletedIds}) {
          persisted = true;
          expect(upserts.single.id, 1);
          expect(deletedIds, [2]);
        },
      ).refresh();

      expect(persisted, isTrue);
    },
  );

  test('retains OSM rows that are absent from a successful source', () async {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage([_feature(id: 1)]),
    );

    await serviceFor('''{"elements":[]}''', repository: repository).refresh();

    final retained = repository.getAllNaturalFeatures().single;
    expect(retained.id, 1);
    expect(retained.sourceKey, 'OSM:node:99');
  });

  test(
    'reconciles legacy duplicates before indexing without touching Manual rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'legacy-features',
      );
      final store = await openStore(directory: directory.path);
      addTearDown(() async {
        store.close();
        await directory.delete(recursive: true);
      });
      final box = store.box<NaturalFeature>();
      final first = _feature(id: 0)..sourceRecordKey = null;
      final second = _feature(id: 0)..sourceRecordKey = null;
      final manual = _feature(id: 0)
        ..sourceOfTruth = 'Manual'
        ..sourceKey = 'Manual:node:99'
        ..sourceRecordKey = null;
      box.putMany([first, second, manual]);
      final survivorId = first.id;
      await serviceFor(
        '{"elements":[]}',
        repository: NaturalFeatureRepository(store),
      ).refresh();
      expect(box.getAll().map((row) => row.id).toSet(), {
        survivorId,
        manual.id,
      });
      expect(box.get(survivorId)!.sourceRecordKey, 'OSM:node:99');
      expect(box.get(manual.id)!.sourceOfTruth, 'Manual');
    },
  );

  test(
    'a write-phase persistence failure rolls ObjectBox changes back',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'natural-feature-refresh',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final store = await openStore(directory: directory.path);
      addTearDown(store.close);
      final repository = NaturalFeatureRepository.test(
        ObjectBoxNaturalFeatureStorage(
          store,
          failureForTest: NaturalFeatureWriteFailure.afterFirstWrite,
        ),
      );
      final box = store.box<NaturalFeature>();
      final service = serviceFor('''{"elements":[
        {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"One","natural":"tree"}},
        {"type":"node","id":2,"lat":-42.1,"lon":146.1,"tags":{"name":"Two","natural":"tree"}}
      ]}''', repository: repository);

      await expectLater(service.refresh(), throwsA(isA<StateError>()));
      expect(box.count(), 0);
    },
  );
}

NaturalFeature _feature({required int id}) {
  return NaturalFeature(
    id: id,
    name: 'Feature $id',
    tag: 'tree',
    latitude: -42,
    longitude: 146,
    osmId: 99,
    osmType: 'node',
  );
}
