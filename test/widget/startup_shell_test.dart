import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/startup_shell.dart';

void main() {
  testWidgets(
    'pending retry is visible, single-flight and preserves updated failures',
    (tester) async {
      final coordinator = _PendingRetryCoordinator();
      await tester.pumpWidget(
        StartupShell(
          coordinator: coordinator,
          readyBuilder: (_) => const MaterialApp(home: Text('ready app')),
        ),
      );
      await tester.pump();
      final retry = tester
          .widget<FilledButton>(
            find.byKey(const Key('mapping-store-unavailable-retry')),
          )
          .onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(coordinator.retryCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('ready app'), findsNothing);
      coordinator.pending.complete(
        StartupResult.unavailable(
          ['/local/new-failure'],
          rootPath: '/local/replica',
          isReplica: true,
          diagnostic: 'Updated validation failure.',
        ),
      );
      await tester.pump();
      expect(find.text('/local/new-failure'), findsOneWidget);
      expect(find.text('Updated validation failure.'), findsOneWidget);
      coordinator.pending = Completer<StartupResult>();
      await tester.tap(
        find.byKey(const Key('mapping-store-unavailable-retry')),
      );
      await tester.pump();
      coordinator.pending.complete(StartupResult.ready(_catalog));
      await tester.pump();
      expect(find.text('ready app'), findsOneWidget);
    },
  );
  testWidgets(
    'long local paths scroll at enlarged text scale while controls remain reachable',
    (tester) async {
      tester.view.physicalSize = const Size(640, 300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var quits = 0;
      await tester.pumpWidget(
        StartupShell(
          coordinator: _FakeStartupCoordinator(
            StartupResult.unavailable(
              List.generate(40, (i) => '/local/replica/missing/$i'),
              rootPath:
                  '/Users/a/Library/Application Support/${'long-path/' * 20}',
              isReplica: true,
              diagnostic: 'Local replica validation failed.',
            ),
          ),
          readyBuilder: (_) => const Text('ready app'),
          onQuit: () => quits++,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('mapping-store-unavailable-path-list')),
        const Offset(0, -500),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mapping-store-unavailable-quit')));
      expect(quits, 1);
    },
  );
  testWidgets(
    'replica startup shows exact local diagnostics and keyboard-reachable Quit',
    (tester) async {
      var quits = 0;
      await tester.pumpWidget(
        StartupShell(
          coordinator: _FakeStartupCoordinator(
            StartupResult.unavailable(
              ['/local/replica/generations/broken/payload/DEM/cop30_hh.tif'],
              rootPath: '/local/replica',
              isReplica: true,
              diagnostic: 'Local replica validation failed.',
            ),
          ),
          readyBuilder: (_) => const Text('ready app'),
          onQuit: () => quits++,
        ),
      );
      await tester.pump();
      expect(find.text('Mapping runtime replica unavailable'), findsOneWidget);
      expect(find.text('/local/replica'), findsOneWidget);
      expect(find.text('Local replica validation failed.'), findsOneWidget);
      expect(find.text('/Volumes/Services/Mapping'), findsNothing);
      expect(find.textContaining('Initial synchronization'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(quits, 1);
    },
  );
  testWidgets(
    'production root supplies startup context and hands off at ready',
    (tester) async {
      final coordinator = _PendingStartupCoordinator();
      var readyAppBuilds = 0;
      await tester.pumpWidget(
        StartupShell(
          coordinator: coordinator,
          readyBuilder: (_) {
            readyAppBuilds++;
            return const MaterialApp(home: Text('ready app'));
          },
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Checking Mapping data store...'), findsOneWidget);
      expect(readyAppBuilds, 0);

      coordinator.setState(StartupState.initializing);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Initializing...'), findsOneWidget);

      coordinator.complete(StartupResult.unavailable(['region_manifest.json']));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Mapping data store unavailable'), findsOneWidget);
      expect(find.text('region_manifest.json'), findsOneWidget);
      expect(readyAppBuilds, 0);

      coordinator.retryResult = StartupResult.ready(_catalog);
      await tester.tap(
        find.byKey(const Key('mapping-store-unavailable-retry')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ready app'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );

  testWidgets('checking is non-interactive and does not construct ready app', (
    tester,
  ) async {
    final coordinator = _PendingStartupCoordinator();
    var readyAppBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupShell(
          coordinator: coordinator,
          readyBuilder: (_) {
            readyAppBuilds++;
            return const Text('ready app');
          },
        ),
      ),
    );

    expect(find.text('Checking Mapping data store...'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(readyAppBuilds, 0);
  });

  testWidgets('shows the macOS-only state before constructing the ready app', (
    tester,
  ) async {
    final coordinator = _FakeStartupCoordinator(
      const StartupResult.unsupportedPlatform(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupShell(
          coordinator: coordinator,
          readyBuilder: (_) => const Text('ready app'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Peak Bagger requires macOS.'), findsOneWidget);
    expect(find.byKey(const Key('unsupported-platform-quit')), findsOneWidget);
    expect(find.text('ready app'), findsNothing);
  });

  testWidgets('retries an unavailable Mapping store and then opens ready app', (
    tester,
  ) async {
    final coordinator = _FakeStartupCoordinator(
      StartupResult.unavailable(['Polygons/tasmania.poly']),
      retryResult: StartupResult.ready(_catalog),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupShell(
          coordinator: coordinator,
          readyBuilder: (_) => const Text('ready app'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mapping data store unavailable'), findsOneWidget);
    expect(
      find.byKey(const Key('mapping-store-unavailable-path-list')),
      findsOneWidget,
    );
    expect(find.text('Polygons/tasmania.poly'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mapping-store-unavailable-retry')));
    await tester.pump();

    expect(coordinator.retryCalls, 1);
    expect(find.text('ready app'), findsOneWidget);
  });

  testWidgets('unavailable state keeps controls reachable while paths scroll', (
    tester,
  ) async {
    final paths = List.generate(40, (index) => 'Missing/path-$index.poly');
    var quitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: StartupShell(
            coordinator: _FakeStartupCoordinator(
              StartupResult.unavailable(paths),
            ),
            readyBuilder: (_) => const Text('ready app'),
            onQuit: () => quitCalls++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mapping data store unavailable'), findsOneWidget);
    expect(find.text('/Volumes/Services/Mapping'), findsOneWidget);
    expect(
      find.byKey(const Key('mapping-store-unavailable-path-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-unavailable-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-unavailable-quit')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('mapping-store-unavailable-path-list')),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mapping-store-unavailable-quit')));

    expect(quitCalls, 1);
  });

  testWidgets('initialization failure shows diagnostics and supports quit', (
    tester,
  ) async {
    var quitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupShell(
          coordinator: _FakeStartupCoordinator(
            const StartupResult.initializationFailed('ObjectBox failed'),
          ),
          readyBuilder: (_) => const Text('ready app'),
          onQuit: () => quitCalls++,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Initialization failed'), findsOneWidget);
    expect(find.text('ObjectBox failed'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('startup-initialization-failed-quit')),
    );
    expect(quitCalls, 1);
  });

  test(
    'production coordinator rejects non-macOS before opening the store',
    () async {
      final result = await MappingStoreStartupCoordinator(
        isMacOS: false,
        mappingDataStore: MappingDataStore(rootPath: '/does-not-exist'),
        initialize: (_) async {},
      ).start();

      expect(result.state, StartupState.unsupportedPlatform);
    },
  );

  testWidgets('renders initializing while ready dependencies are opening', (
    tester,
  ) async {
    final coordinator = _PendingStartupCoordinator();

    await tester.pumpWidget(
      MaterialApp(
        home: StartupShell(
          coordinator: coordinator,
          readyBuilder: (_) => const Text('ready app'),
        ),
      ),
    );
    expect(find.text('Checking Mapping data store...'), findsOneWidget);

    coordinator.setState(StartupState.initializing);
    await tester.pump();

    expect(find.text('Initializing...'), findsOneWidget);
  });
}

final _catalog = MappingCatalog(
  rootPath: '/test',
  regions: const [],
  basemaps: const [],
  tasmapCatalogPath: 'Maps/tasmap50k.csv',
  naturalFeaturesCatalogPath: 'Features/tasmania_natural_features.json',
  demSources: const {},
  routingCoverageRegionKeys: const {},
);

class _FakeStartupCoordinator implements StartupCoordinator {
  _FakeStartupCoordinator(this.result, {StartupResult? retryResult})
    : _retryResult = retryResult ?? result;

  final StartupResult result;
  final StartupResult _retryResult;
  var retryCalls = 0;
  final ValueNotifier<StartupState> _state = ValueNotifier(
    StartupState.checking,
  );

  @override
  ValueListenable<StartupState> get state => _state;

  @override
  Future<StartupResult> start() async => result;

  @override
  Future<StartupResult> retry() async {
    retryCalls++;
    return _retryResult;
  }
}

class _PendingStartupCoordinator implements StartupCoordinator {
  final ValueNotifier<StartupState> _state = ValueNotifier(
    StartupState.checking,
  );
  final _result = Completer<StartupResult>();
  StartupResult? retryResult;

  @override
  ValueListenable<StartupState> get state => _state;

  void setState(StartupState state) => _state.value = state;

  void complete(StartupResult result) => _result.complete(result);

  @override
  Future<StartupResult> start() => _result.future;

  @override
  Future<StartupResult> retry() async => retryResult ?? await _result.future;
}

class _PendingRetryCoordinator extends _FakeStartupCoordinator {
  _PendingRetryCoordinator()
    : super(
        StartupResult.unavailable(
          ['/local/replica'],
          rootPath: '/local/replica',
          isReplica: true,
        ),
      );
  var pending = Completer<StartupResult>();
  @override
  Future<StartupResult> retry() {
    retryCalls++;
    return pending.future;
  }
}
