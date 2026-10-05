import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import '../fixtures/polygon_mapping_store.dart';

void main() {
  test('parsePolygonAsset reads a Tasmania fixture polygon', () {
    final result = parsePolygonAsset(
      _tasmaniaPolygon,
      assetPath: 'Polygons/tasmania.poly',
    );

    expect(result.isSuccess, isTrue);
    expect(result.asset!.assetPath, 'Polygons/tasmania.poly');
    expect(result.asset!.name, 'none');
    expect(result.asset!.points, hasLength(8));
    expect(result.asset!.points.first, const LatLng(-44.0, 148.8867));
  });

  test('parsePolygonAsset reads a Croatia fixture polygon', () {
    final result = parsePolygonAsset(
      _croatiaPolygon,
      assetPath: 'Polygons/croatia.poly',
    );

    expect(result.isSuccess, isTrue);
    expect(result.asset!.assetPath, 'Polygons/croatia.poly');
    expect(result.asset!.name, 'none');
    expect(result.asset!.points, isNotEmpty);
    expect(result.asset!.points.first, const LatLng(42.43746, 18.51463));
  });

  test('parsePolygonAsset rejects malformed coordinates', () {
    final result = parsePolygonAsset(
      'none\n1\ninvalid line\nEND\nEND\n',
      assetPath: 'Polygons/broken.poly',
    );

    expect(result.isSuccess, isFalse);
    expect(result.error, contains('Polygons/broken.poly'));
    expect(result.error, contains('invalid coordinate line'));
  });

  test('display parser rejects non-finite and out-of-bounds coordinates', () {
    for (final coordinate in ['NaN 0', 'Infinity 0', '181 0', '0 -91']) {
      expect(
        parsePolygonAsset(
          'none\n1\n$coordinate\n1 0\n1 1\nEND\nEND\n',
          assetPath: 'Polygons/broken.poly',
        ).isSuccess,
        isFalse,
      );
    }
  });

  test(
    'startup and repository creation never inspect optional targets',
    () async {
      final store = PolygonMappingStore();
      final catalog = await store.loadCatalog();
      final repository = PolygonAssetRepository(
        catalog: catalog,
        fileSystem: store,
      );
      final optional =
          '${PolygonMappingStore.root}/${PolygonMappingStore.optionalPath}';
      expect(repository.paths, contains(PolygonMappingStore.optionalPath));
      expect(store.resolutions, isNot(contains(optional)));
      expect(store.checks, isNot(contains(optional)));
      expect(store.reads, isNot(contains(optional)));
      await expectLater(
        repository.loadPolygon(PolygonMappingStore.optionalPath),
        throwsA(isA<MappingStoreOperationException>()),
      );
      store.repairOptional();
      final polygon = await repository.loadPolygon(
        PolygonMappingStore.optionalPath,
      );
      expect(polygon.assetPath, PolygonMappingStore.optionalPath);
      expect(polygon.points, hasLength(3));
    },
  );

  test('unlisted and unsafe requests never reach the reader', () async {
    final store = PolygonMappingStore();
    final repository = PolygonAssetRepository(
      catalog: await store.loadCatalog(),
      fileSystem: store,
    );
    store.reads.clear();
    for (final path in [
      'Polygons/unlisted.poly',
      '/tmp/evil.poly',
      'Polygons/../evil.poly',
      'Polygons/./optional.poly',
      r'Polygons\optional.poly',
      '',
    ]) {
      await expectLater(
        repository.loadPolygon(path),
        throwsA(isA<MappingStoreOperationException>()),
      );
    }
    expect(store.reads, isEmpty);
  });

  test(
    'symlink changed after preflight is revalidated before a display read',
    () async {
      final store = PolygonMappingStore()..repairOptional();
      final repository = PolygonAssetRepository(
        catalog: await store.loadCatalog(),
        fileSystem: store,
      );
      final optional =
          '${PolygonMappingStore.root}/${PolygonMappingStore.optionalPath}';
      expect(
        await repository.loadPolygon(PolygonMappingStore.optionalPath),
        isNotNull,
      );
      store.reads.clear();
      store.symlinks[optional] = '/outside/optional.poly';
      store.files['/outside/optional.poly'] = polygonText;
      await expectLater(
        repository.loadPolygon(PolygonMappingStore.optionalPath),
        throwsA(isA<MappingStoreOperationException>()),
      );
      expect(store.reads, isEmpty);
      store.symlinks[optional] =
          '${PolygonMappingStore.root}/Polygons/tasmania.poly';
      expect(
        await repository.loadPolygon(PolygonMappingStore.optionalPath),
        isNotNull,
      );
      expect(
        store.reads.single,
        '${PolygonMappingStore.root}/Polygons/tasmania.poly',
      );
    },
  );

  test(
    'unreadable, read errors, and malformed sources are typed path failures',
    () async {
      final store = PolygonMappingStore()..repairOptional();
      final repository = PolygonAssetRepository(
        catalog: await store.loadCatalog(),
        fileSystem: store,
      );
      final optional =
          '${PolygonMappingStore.root}/${PolygonMappingStore.optionalPath}';
      final failure = throwsA(
        isA<MappingStoreOperationException>().having(
          (error) => error.paths,
          'paths',
          [PolygonMappingStore.optionalPath],
        ),
      );
      store.unreadable.add(optional);
      await expectLater(
        repository.loadPolygon(PolygonMappingStore.optionalPath),
        failure,
      );
      store.unreadable.clear();
      store.optionalReadError = StateError('Read failed after metadata check');
      await expectLater(
        repository.loadPolygon(PolygonMappingStore.optionalPath),
        failure,
      );
      store.optionalReadError = null;
      store.files[optional] = 'malformed';
      await expectLater(
        repository.loadPolygon(PolygonMappingStore.optionalPath),
        failure,
      );
      store.files[optional] = 'none\n1\ninvalid line\nEND\nEND\n';
      await expectLater(
        repository.loadPolygon(PolygonMappingStore.optionalPath),
        failure,
      );
    },
  );
}

const _tasmaniaPolygon = '''
none
1
148.8867 -44.0
143.4704 -44.0
143.4704 -39.1982
146.2510 -39.19759
146.6251 -39.19687
146.9203 -39.19721
147.1105 -39.19767
148.8867 -39.52946
END
END
''';

const _croatiaPolygon = '''
none
1
18.51463 42.43746
18.53434 42.42769
18.55029 42.38946
18.48013 42.24400
END
END
''';
