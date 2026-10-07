import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';

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
  });

  StartupResult.unavailable(Iterable<String> pathFailures)
    : this._(
        state: StartupState.unavailable,
        pathFailures: List.unmodifiable(pathFailures),
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
    required this.mappingDataStore,
    required this.initialize,
  });

  final bool isMacOS;
  final MappingDataStore mappingDataStore;
  final MappingCatalogInitializer initialize;
  final ValueNotifier<StartupState> _state = ValueNotifier(
    StartupState.checking,
  );

  @override
  ValueListenable<StartupState> get state => _state;

  @override
  Future<StartupResult> start() => _start();

  @override
  Future<StartupResult> retry() => _start();

  Future<StartupResult> _start() async {
    _state.value = StartupState.checking;
    if (!isMacOS) {
      return const StartupResult.unsupportedPlatform();
    }
    final MappingCatalog catalog;
    try {
      final preflight = await mappingDataStore.preflight();
      catalog = await mappingDataStore.loadCatalogFromPreflight(preflight);
    } on MappingStoreFailure catch (error) {
      return StartupResult.unavailable(error.paths);
    } catch (error) {
      return StartupResult.unavailable([error.toString()]);
    }
    try {
      _state.value = StartupState.initializing;
      await initialize(catalog);
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
    setState(() {
      _result = null;
      _state = StartupState.checking;
    });
    final result = retry
        ? await widget.coordinator.retry()
        : await widget.coordinator.start();
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
    this.onQuit,
  });

  final List<String> paths;
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
                  const Text('Mapping data store unavailable'),
                  const SizedBox(height: 16),
                  const Text('/Volumes/Services/Mapping'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      key: const Key('mapping-store-unavailable-path-list'),
                      children: [for (final path in paths) Text(path)],
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
