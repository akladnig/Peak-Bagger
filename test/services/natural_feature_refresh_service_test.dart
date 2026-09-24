import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/natural_feature_refresh_service.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
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

  test('protects Manual identity before attempting invalid geometry', () async {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage([
        NaturalFeature(
          id: 7,
          name: 'Curated lake',
          tag: 'lake',
          latitude: -42.7,
          longitude: 146.5,
          osmId: 44,
          osmType: 'way',
          sourceOfTruth: 'Manual',
        ),
      ]),
    );
    final result = await serviceFor(
      '''{"elements":[{"type":"way","id":44,"nodes":[999],"tags":{"name":"Source lake","natural":"water"}}]}''',
      repository: repository,
    ).refresh();

    expect(result.protectedCount, 1);
    expect(result.skippedCount, 0);
    expect(repository.getAllNaturalFeatures().single.name, 'Curated lake');
  });

  test('rejects duplicate source identities before persistence', () async {
    var persisted = false;

    await expectLater(
      serviceFor('''{"elements":[
          {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"One","natural":"tree"}},
          {"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"Two","natural":"tree"}}
        ]}''', persistence: (_) => persisted = true).refresh(),
      throwsA(anything),
    );

    expect(persisted, isFalse);
  });

  test('keeps stored records when MGRS conversion fails', () async {
    var persisted = false;
    final result = await serviceFor(
      '''{"elements":[{"type":"node","id":1,"lat":-42,"lon":146,"tags":{"name":"One","natural":"tree"}}]}''',
      converter: (_) => throw const FormatException('invalid MGRS'),
      persistence: (_) => persisted = true,
    ).refresh();

    expect(result.createdCount, 0);
    expect(result.skippedCount, 1);
    expect(persisted, isTrue);
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

  test('reports the fixed unavailable-source failure', () async {
    final service = NaturalFeatureRefreshService(
      NaturalFeatureRepository.test(InMemoryNaturalFeatureStorage()),
      fileReader: (_) => throw FileSystemException(),
    );

    await expectLater(
      service.refresh(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Error refreshing natural features: source file is unavailable at '
              '/Volumes/Services/Features/tasmania_natural_features.json',
        ),
      ),
    );
  });

  test(
    'rejects duplicate stored identities without persisting a plan',
    () async {
      var persisted = false;
      final repository = NaturalFeatureRepository.test(
        InMemoryNaturalFeatureStorage([_feature(id: 1), _feature(id: 2)]),
      );

      await expectLater(
        serviceFor(
          '''{"elements":[]}''',
          repository: repository,
          persistence: (_) => persisted = true,
        ).refresh(),
        throwsA(isA<StateError>()),
      );

      expect(persisted, isFalse);
      expect(repository.getAllNaturalFeatures(), hasLength(2));
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
