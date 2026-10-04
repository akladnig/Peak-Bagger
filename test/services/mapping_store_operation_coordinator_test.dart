import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';

void main() {
  group('MappingStoreOperationKey', () {
    test('retains only the canonical parameters for every operation kind', () {
      expect(MappingStoreOperationKey.peakSeed('tasmania').parameters, {
        'regionKey': 'tasmania',
      });
      expect(MappingStoreOperationKey.tasmapBootstrap().parameters, isEmpty);
      expect(
        MappingStoreOperationKey.routeGraphRefresh('northeast-alps').parameters,
        {'routingCoverageKey': 'northeast-alps'},
      );
      expect(
        MappingStoreOperationKey.demRead(
          demSourceKey: 'elvisRuntime',
          routeGeometryIdentity: 'route-1',
          geometryVersion: '3',
        ).parameters,
        {
          'demSourceKey': 'elvisRuntime',
          'routeGeometryIdentity': 'route-1',
          'geometryVersion': '3',
        },
      );
      expect(
        MappingStoreOperationKey.polygonDisplay('Polygons/tas.poly').parameters,
        {'path': 'Polygons/tas.poly'},
      );
    });
  });

  group('MappingStoreOperationCoordinator', () {
    test(
      'joins duplicate pending work without a second action or failure',
      () async {
        final coordinator = MappingStoreOperationCoordinator();
        final complete = Completer<void>();
        var calls = 0;
        final key = MappingStoreOperationKey.peakSeed('tasmania');

        final first = coordinator.run<void>(
          key: key,
          action: () {
            calls++;
            return complete.future;
          },
        );
        final duplicate = coordinator.run<void>(
          key: key,
          action: () {
            calls++;
            return Future.value();
          },
        );

        expect(identical(first, duplicate), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        complete.complete();
        await first;
        expect(coordinator.failures, isEmpty);
      },
    );

    test(
      'queues distinct failures FIFO and coalesces matching failures',
      () async {
        final coordinator = MappingStoreOperationCoordinator();
        final firstKey = MappingStoreOperationKey.peakSeed('tasmania');
        final secondKey = MappingStoreOperationKey.peakSeed('fvg');

        await expectLater(
          coordinator.run<void>(
            key: firstKey,
            action: () => Future.error(
              MappingStoreOperationException(paths: ['Peaks/tasmania.json']),
            ),
          ),
          throwsA(isA<MappingStoreOperationException>()),
        );
        await expectLater(
          coordinator.run<void>(
            key: secondKey,
            action: () => Future.error(
              MappingStoreOperationException(paths: ['Peaks/fvg.json']),
            ),
          ),
          throwsA(isA<MappingStoreOperationException>()),
        );
        await expectLater(
          coordinator.run<void>(
            key: firstKey,
            action: () => Future.error(
              MappingStoreOperationException(paths: ['Peaks/tasmania-v2.json']),
            ),
          ),
          throwsA(isA<MappingStoreOperationException>()),
        );

        expect(coordinator.failures.map((failure) => failure.key), [
          firstKey,
          secondKey,
        ]);
        expect(coordinator.activeFailure!.paths, ['Peaks/tasmania-v2.json']);

        coordinator.dismissActive();
        expect(coordinator.activeFailure!.key, secondKey);
      },
    );

    test('a successful retry removes the active failure', () async {
      final coordinator = MappingStoreOperationCoordinator();
      var shouldFail = true;
      final key = MappingStoreOperationKey.tasmapUpdate();

      await expectLater(
        coordinator.run<void>(
          key: key,
          action: () {
            if (shouldFail) {
              return Future.error(
                MappingStoreOperationException(paths: ['Maps/tasmap50k.csv']),
              );
            }
            return Future.value();
          },
          writerTables: const ['Tasmap50k'],
        ),
        throwsA(isA<MappingStoreOperationException>()),
      );
      shouldFail = false;

      await coordinator.retryActive();

      expect(coordinator.activeFailure, isNull);
    });

    test('a dismissed failure can retry its original operation key', () async {
      final coordinator = MappingStoreOperationCoordinator();
      var shouldFail = true;
      var calls = 0;
      final key = MappingStoreOperationKey.peakSeed('tasmania');

      Future<void> load() async {
        calls++;
        if (shouldFail) {
          throw MappingStoreOperationException(paths: ['Peaks/tasmania.json']);
        }
      }

      await expectLater(
        coordinator.run<void>(key: key, action: load),
        throwsA(isA<MappingStoreOperationException>()),
      );
      coordinator.dismissActive();
      shouldFail = false;

      await coordinator.retry(key);

      expect(calls, 2);
      expect(coordinator.failures, isEmpty);
    });

    test('a failed retry updates its one active failure', () async {
      final coordinator = MappingStoreOperationCoordinator();
      var attempts = 0;
      final key = MappingStoreOperationKey.naturalFeaturesRefresh();

      Future<void> fail() {
        attempts++;
        return Future.error(
          MappingStoreOperationException(
            paths: [
              attempts == 1
                  ? 'Features/first.json'
                  : 'Features/repaired-but-invalid.json',
            ],
          ),
        );
      }

      await expectLater(
        coordinator.run<void>(key: key, action: fail),
        throwsA(isA<MappingStoreOperationException>()),
      );

      await coordinator.retryActive();

      expect(coordinator.failures, hasLength(1));
      expect(coordinator.activeFailure!.paths, [
        'Features/repaired-but-invalid.json',
      ]);
    });

    test(
      'independent operations run concurrently but same writers serialize',
      () async {
        final coordinator = MappingStoreOperationCoordinator();
        final first = Completer<void>();
        final second = Completer<void>();
        var running = 0;
        var maximumRunning = 0;

        Future<void> run(Completer<void> complete) async {
          running++;
          maximumRunning = maximumRunning < running ? running : maximumRunning;
          await complete.future;
          running--;
        }

        final firstOperation = coordinator.run<void>(
          key: MappingStoreOperationKey.peakSeed('tasmania'),
          action: () => run(first),
          writerTables: const ['Peak'],
        );
        final secondOperation = coordinator.run<void>(
          key: MappingStoreOperationKey.peakSeed('fvg'),
          action: () => run(second),
          writerTables: const ['Peak'],
        );
        final independent = coordinator.run<void>(
          key: MappingStoreOperationKey.routeGraphBootstrap('northeast-alps'),
          action: () => run(Completer<void>()..complete()),
          writerTables: const ['RouteGraphManifest'],
        );

        await Future<void>.delayed(Duration.zero);
        expect(maximumRunning, 2);
        first.complete();
        await Future<void>.delayed(Duration.zero);
        expect(maximumRunning, 2);
        second.complete();
        await Future.wait([firstOperation, secondOperation, independent]);
      },
    );
  });

  group('MappingStoreBootstrapCoordinator', () {
    test(
      'runs each eligible operation once and skips no-op source reads',
      () async {
        final operationCoordinator = MappingStoreOperationCoordinator();
        var sourceReads = 0;
        final coordinator = MappingStoreBootstrapCoordinator(
          operationCoordinator: operationCoordinator,
          operations: [
            MappingStoreBootstrapOperation(
              key: MappingStoreOperationKey.tasmapBootstrap(),
              shouldRun: () => false,
              run: () async => sourceReads++,
            ),
            MappingStoreBootstrapOperation(
              key: MappingStoreOperationKey.naturalFeaturesBootstrap(),
              shouldRun: () => true,
              run: () async => sourceReads++,
            ),
          ],
        );

        await Future.wait([coordinator.schedule(), coordinator.schedule()]);

        expect(sourceReads, 1);
      },
    );
  });

  test('revalidates a path immediately before it is opened', () async {
    final fileSystem = _FileSystem();
    final access = MappingStoreOperationFileAccess(
      rootPath: '/mapping',
      fileSystem: fileSystem,
    );

    final content = await access.readText('Peaks/tasmania.json');

    expect(content, 'source');
    expect(fileSystem.canonicalized, [
      '/mapping',
      '/mapping/Peaks/tasmania.json',
    ]);
    expect(fileSystem.checkedReadable, ['/mapping/Peaks/tasmania.json']);
  });
}

class _FileSystem implements MappingStoreFileSystem {
  final List<String> canonicalized = [];
  final List<String> checkedReadable = [];

  @override
  Future<void> checkReadable(String absolutePath) async {
    checkedReadable.add(absolutePath);
  }

  @override
  Future<String> canonicalize(String absolutePath) async {
    canonicalized.add(absolutePath);
    return absolutePath;
  }

  @override
  Future<bool> fileExists(String absolutePath) async => true;

  @override
  Future<MappingStoreFileMetadata> metadata(String absolutePath) {
    throw UnimplementedError();
  }

  @override
  Future<String> readText(String absolutePath) async => 'source';
}
