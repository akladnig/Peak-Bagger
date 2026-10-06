import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

void main() {
  group('Tasmap CSV reconciliation', () {
    late Directory directory;
    late Store store;
    late TasmapRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'tasmap-reconciliation',
      );
      store = await openStore(directory: directory.path);
      repository = TasmapRepository(store);
    });

    tearDown(() async {
      store.close();
      await directory.delete(recursive: true);
    });

    test(
      'updates the lowest-id duplicate, deletes duplicates and omitted rows',
      () async {
        final survivor = _map(name: 'Wellington', parent: 'old');
        final duplicate = _map(name: '  wellington ', parent: 'duplicate');
        final omitted = _map(name: 'Omitted');
        store.box<Tasmap50k>().putMany([survivor, duplicate, omitted]);

        final result = await repository.reconcileCsvContents(
          _csv(
            rows: [_row(name: ' Wellington ', parent: 'new')],
          ),
        );

        final maps = repository.getAllMaps();
        expect(maps, hasLength(1));
        expect(maps.single.id, survivor.id);
        expect(maps.single.parentSeries, 'new');
        expect(result.selectionRetargets, {duplicate.id: survivor.id});
        expect(repository.getMapById(omitted.id), isNull);
      },
    );

    test(
      'does not change rows when the catalog content is unchanged',
      () async {
        final original = _map();
        store.box<Tasmap50k>().put(original);

        final result = await repository.reconcileCsvContents(
          _csv(rows: [_row()]),
        );

        expect(result.changed, isFalse);
        expect(repository.getAllMaps().single.id, original.id);
      },
    );

    test('preserves rows when parsing fails before reconciliation', () async {
      final original = _map();
      store.box<Tasmap50k>().put(original);

      await expectLater(
        repository.reconcileCsvContents('Series,Name\nTQ08,Wellington'),
        throwsFormatException,
      );

      final preserved = repository.getAllMaps().single;
      expect(preserved.id, original.id);
      expect(preserved.name, original.name);
      expect(preserved.parentSeries, original.parentSeries);
    });

    test(
      'clears a changed parent in place and leaves unchanged sheets intact',
      () async {
        final changed = _map(parent: 'old');
        final unchanged = _map(name: 'Banks Strait', parent: '');
        store.box<Tasmap50k>().putMany([changed, unchanged]);
        final contents = _csv(
          rows: [
            _row(parent: ''),
            _row(name: 'Banks Strait', parent: '   '),
          ],
        );

        final result = await repository.reconcileCsvContents(contents);

        expect(result.changed, isTrue);
        expect(repository.mapCount, 2);
        expect(repository.getMapById(changed.id)!.parentSeries, isEmpty);
        expect(repository.getMapById(unchanged.id)!.name, unchanged.name);
        expect(repository.getMapById(unchanged.id)!.parentSeries, isEmpty);
        expect(result.selectionRetargets, isEmpty);

        final repeated = await repository.reconcileCsvContents(contents);

        expect(repeated.changed, isFalse);
        expect(
          repository.getAllMaps().map((map) => map.id),
          unorderedEquals([changed.id, unchanged.id]),
        );
      },
    );
  });
}

Tasmap50k _map({String name = 'Wellington', String parent = '8312'}) =>
    Tasmap50k(
      series: 'TQ08',
      name: name,
      parentSeries: parent,
      mgrs100kIds: 'EN',
      eastingMin: 0,
      eastingMax: 39999,
      northingMin: 40000,
      northingMax: 69999,
      mgrsMid: 'EN',
      eastingMid: 20000,
      northingMid: 55000,
      p1: 'EN0000069999',
      p2: 'EN3999969999',
      p3: 'EN3999940000',
      p4: 'EN0000040000',
    );

String _csv({required List<List<String>> rows}) =>
    '${_headers.join(',')}\n${rows.map((row) => row.join(',')).join('\n')}';

List<String> _row({String name = 'Wellington', String parent = '8312'}) => [
  'TQ08',
  name,
  parent,
  'EN',
  '0',
  '39999',
  '40000',
  '69999',
  'EN',
  '20000',
  '55000',
  'EN0000069999',
  'EN3999969999',
  'EN3999940000',
  'EN0000040000',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
];

const _headers = [
  'Series',
  'Name',
  'Parent',
  'MGRS',
  'eastingMin',
  'eastingMax',
  'northingMin',
  'northingMax',
  'mgrsMid',
  'eastingMid',
  'northingMid',
  'p1',
  'p2',
  'p3',
  'p4',
  'p5',
  'p6',
  'p7',
  'p8',
  'p9',
  'p10',
  'p11',
  'p12',
];
