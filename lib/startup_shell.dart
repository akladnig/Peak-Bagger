import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/performance_measurement.dart';
import 'package:peak_bagger/services/mapping_runtime_config.dart';
import 'package:peak_bagger/services/mapping_runtime_selection.dart';

enum StartupState {
  checking,
  unavailable,
  unsupportedPlatform,
  initializing,
  initializationFailed,
  ready,
}

class StartupResult {
  const StartupResult._({
    required this.state,
    this.catalog,
    this.pathFailures = const [],
    this.diagnostic,
    this.rootPath = mappingStoreRootPath,
    this.isReplica = false,
  });

  StartupResult.unavailable(
    Iterable<String> pathFailures, {
    String rootPath = mappingStoreRootPath,
    bool isReplica = false,
    String? diagnostic,
  }) : this._(
         state: StartupState.unavailable,
         pathFailures: List.unmodifiable(pathFailures),
         rootPath: rootPath,
         isReplica: isReplica,
         diagnostic: diagnostic,
       );

  const StartupResult.unsupportedPlatform()
    : this._(state: StartupState.unsupportedPlatform);

  const StartupResult.initializationFailed(String diagnostic)
    : this._(state: StartupState.initializationFailed, diagnostic: diagnostic);

  const StartupResult.ready(MappingCatalog catalog)
    : this._(state: StartupState.ready, catalog: catalog);

  final StartupState state;
  final MappingCatalog? catalog;
  final List<String> pathFailures;
  final String? diagnostic;
  final String rootPath;
  final bool isReplica;
}

abstract interface class StartupCoordinator {
  ValueListenable<StartupState> get state;
  Future<StartupResult> start();
  Future<StartupResult> retry();
}

typedef MappingCatalogInitializer =
    Future<void> Function(MappingCatalog catalog);

class MappingStoreStartupCoordinator implements StartupCoordinator {
  MappingStoreStartupCoordinator({
    required this.isMacOS,
    this.mappingDataStore,
    this.prepareCatalog,
    required this.initialize,
  }) : assert((mappingDataStore == null) != (prepareCatalog == null));

  final bool isMacOS;
  final MappingDataStore? mappingDataStore;
  final Future<MappingCatalog> Function()? prepareCatalog;
  final MappingCatalogInitializer initialize;
  Future<StartupResult>? _attempt;
  StartupResult? _terminal;
  final ValueNotifier<StartupState> _state = ValueNotifier(
    StartupState.checking,
  );

  @override
  ValueListenable<StartupState> get state => _state;

  @override
  Future<StartupResult> start() => _runOnce();

  @override
  Future<StartupResult> retry() => _runOnce();

  Future<StartupResult> _runOnce() {
    if (_terminal != null) return Future.value(_terminal);
    return _attempt ??= _start()
        .then((result) {
          if (result.state == StartupState.ready ||
              result.state == StartupState.initializationFailed) {
            _terminal = result;
          }
          _state.value = result.state;
          return result;
        })
        .whenComplete(() => _attempt = null);
  }

  Future<StartupResult> _start() async {
    _state.value = StartupState.checking;
    if (!isMacOS) {
      return const StartupResult.unsupportedPlatform();
    }
    final MappingCatalog catalog;
    if (mappingDataStore != null) {
      performanceMeasurement.context['selected_root'] =
          mappingDataStore!.rootPath;
    }
    performanceMeasurement.context['filesystem_transport'] =
        const String.fromEnvironment(
          'MEASUREMENT_TRANSPORT',
          defaultValue: 'unspecified',
        );
    try {
      if (prepareCatalog != null) {
        catalog = await prepareCatalog!();
      } else {
        final preflight = await performanceMeasurement.phase(
          'startup.manifest-path-validation',
          mappingDataStore!.preflight,
        );
        catalog = await performanceMeasurement.phase(
          'startup.polygon-catalog',
          () => mappingDataStore!.loadCatalogFromPreflight(preflight),
        );
      }
      performanceMeasurement.context['selected_root'] = catalog.rootPath;
    } on MappingRuntimeConfigurationFailure catch (error) {
      return StartupResult.unavailable(
        [error.path],
        rootPath: error.path,
        isReplica: true,
        diagnostic: error.toString(),
      );
    } on MappingRuntimeUnavailable catch (error) {
      return StartupResult.unavailable(
        error.paths,
        rootPath: error.rootPath,
        isReplica: error.isReplica,
        diagnostic: error.diagnostic,
      );
    } on MappingStoreFailure catch (error) {
      return StartupResult.unavailable(error.paths);
    } catch (error) {
      return StartupResult.unavailable([error.toString()]);
    }
    try {
      _state.value = StartupState.initializing;
      await performanceMeasurement.phase(
        'startup.ready-dependencies',
        () => initialize(catalog),
      );
      performanceMeasurement.event('startup.shell-handoff');
      return StartupResult.ready(catalog);
    } catch (error) {
      return StartupResult.initializationFailed(error.toString());
    }
  }
}

class StartupShell extends StatefulWidget {
  const StartupShell({
    required this.coordinator,
    required this.readyBuilder,
    this.onQuit,
    super.key,
  });

  final StartupCoordinator coordinator;
  final Widget Function(MappingCatalog catalog) readyBuilder;
  final VoidCallback? onQuit;

  @override
  State<StartupShell> createState() => _StartupShellState();
}

class _StartupShellState extends State<StartupShell> {
  StartupResult? _result;
  bool _running = false;
  late StartupState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.coordinator.state.value;
    widget.coordinator.state.addListener(_onStateChanged);
    _run(retry: false);
  }

  @override
  void dispose() {
    widget.coordinator.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() => _state = widget.coordinator.state.value);
    }
  }

  Future<void> _run({required bool retry}) async {
    if (_running) return;
    _running = true;
    setState(() {
      _result = null;
      _state = StartupState.checking;
    });
    final result = retry
        ? await widget.coordinator.retry()
        : await widget.coordinator.start();
    _running = false;
    if (mounted) {
      setState(() {
        _result = result;
        _state = result.state;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (_state == StartupState.ready && result != null) {
      return widget.readyBuilder(result.catalog!);
    }
    // Production mounts this shell directly with runApp. Startup scaffolds need
    // their own Material context before the ready app creates its routed root.
    final home = switch (_state) {
      StartupState.checking => const _StartupStatus(
        message: 'Checking Mapping data store...',
      ),
      StartupState.unsupportedPlatform => _UnsupportedPlatform(
        onQuit: widget.onQuit,
      ),
      StartupState.unavailable => _UnavailableStore(
        paths: result!.pathFailures,
        rootPath: result.rootPath,
        isReplica: result.isReplica,
        diagnostic: result.diagnostic,
        onRetry: () => _run(retry: true),
        onQuit: widget.onQuit,
      ),
      StartupState.initializing => const _StartupStatus(
        message: 'Initializing...',
      ),
      StartupState.initializationFailed => _InitializationFailed(
        diagnostic: result?.diagnostic ?? 'Unknown initialization failure.',
        onQuit: widget.onQuit,
      ),
      StartupState.ready => const _StartupStatus(
        message: 'Checking Mapping data store...',
      ),
    };
    return MaterialApp(
      title: 'Peak Bagger',
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}

class _StartupStatus extends StatelessWidget {
  const _StartupStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [const CircularProgressIndicator(), Text(message)],
      ),
    ),
  );
}

class _UnsupportedPlatform extends StatelessWidget {
  const _UnsupportedPlatform({this.onQuit});

  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const Text('Peak Bagger requires macOS.'),
          FilledButton(
            key: const Key('unsupported-platform-quit'),
            onPressed: onQuit,
            child: const Text('Quit'),
          ),
        ],
      ),
    ),
  );
}

class _UnavailableStore extends StatelessWidget {
  const _UnavailableStore({
    required this.paths,
    required this.onRetry,
    required this.rootPath,
    required this.isReplica,
    this.diagnostic,
    this.onQuit,
  });

  final List<String> paths;
  final String rootPath;
  final bool isReplica;
  final String? diagnostic;
  final VoidCallback onRetry;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      key: const Key('mapping-store-unavailable-path-list'),
                      children: [
                        Text(
                          isReplica
                              ? 'Mapping runtime replica unavailable'
                              : 'Mapping data store unavailable',
                        ),
                        const SizedBox(height: 16),
                        Text(rootPath),
                        const SizedBox(height: 16),
                        if (diagnostic != null) Text(diagnostic!),
                        for (final path in paths) Text(path),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        key: const Key('mapping-store-unavailable-retry'),
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                      FilledButton.tonal(
                        key: const Key('mapping-store-unavailable-quit'),
                        onPressed: onQuit,
                        child: const Text('Quit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InitializationFailed extends StatelessWidget {
  const _InitializationFailed({required this.diagnostic, this.onQuit});

  final String diagnostic;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const Text('Initialization failed'),
          Text(diagnostic),
          FilledButton(
            key: const Key('startup-initialization-failed-quit'),
            onPressed: onQuit,
            child: const Text('Quit'),
          ),
        ],
      ),
    ),
  );
}
