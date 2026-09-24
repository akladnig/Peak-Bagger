import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';

void main() {
  test('save assigns an id to a natural feature', () {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage(),
    );

    final naturalFeature = repository.save(
      NaturalFeature(
        name: 'Mount Field',
        tag: 'peak',
        latitude: -42.68,
        longitude: 146.56,
        osmId: 123,
        osmType: 'node',
      ),
    );

    expect(naturalFeature.id, isNonZero);
    expect(repository.getAllNaturalFeatures(), [naturalFeature]);
  });

  test('matches OSM identities by type and numeric id', () {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage(),
    );
    final node = repository.save(
      NaturalFeature(
        name: 'Node Feature',
        tag: 'peak',
        latitude: -42.68,
        longitude: 146.56,
        osmId: 123,
        osmType: 'node',
      ),
    );
    final way = repository.save(
      NaturalFeature(
        name: 'Way Feature',
        tag: 'peak',
        latitude: -42.69,
        longitude: 146.57,
        osmId: 123,
        osmType: 'way',
      ),
    );

    expect(repository.getAllNaturalFeatures(), hasLength(2));
    expect(
      repository.findByOsmIdentity(osmType: 'node', osmId: 123),
      same(node),
    );
    expect(repository.findByOsmIdentity(osmType: 'way', osmId: 123), same(way));
  });

  test('deletion removes a feature without retaining a suppression record', () {
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage(),
    );
    final feature = repository.save(
      NaturalFeature(
        name: 'Deleted Lake',
        tag: 'water',
        latitude: -42.68,
        longitude: 146.56,
        osmId: 456,
        osmType: 'way',
      ),
    );

    expect(repository.delete(feature.id), isTrue);
    expect(repository.findById(feature.id), isNull);
    expect(
      repository.findByOsmIdentity(osmType: 'way', osmId: 456),
      isNull,
    );

    final recreated = repository.save(
      NaturalFeature(
        name: 'Recreated Lake',
        tag: 'water',
        latitude: -42.68,
        longitude: 146.56,
        osmId: 456,
        osmType: 'way',
      ),
    );
    expect(recreated.sourceOfTruth, 'OSM');
  });

  test('ObjectBox generates an id for a natural feature', () async {
    final directory = await Directory.systemTemp.createTemp(
      'natural-feature-repository',
    );
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final store = await openStore(directory: directory.path);
    addTearDown(store.close);

    final naturalFeature = NaturalFeatureRepository(store).save(
      NaturalFeature(
        name: 'Mount Field',
        tag: 'peak',
        latitude: -42.68,
        longitude: 146.56,
        osmId: 123,
        osmType: 'node',
      ),
    );

    expect(naturalFeature.id, isNonZero);
    expect(store.box<NaturalFeature>().get(naturalFeature.id), isNotNull);
  });
}
