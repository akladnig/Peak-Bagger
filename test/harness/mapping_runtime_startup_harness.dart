import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_runtime_selection.dart';
import 'package:peak_bagger/startup_shell.dart';

import 'mapping_catalog_fixture.dart';
import 'test_map_notifier.dart';

/// Deterministic startup readiness seam. Real filesystem/atomic activation lives
/// in service tests; this journey pumps pending work without native/network I/O.
class MappingRuntimeStartupHarness {
  MappingRuntimeStartupHarness() {
    SharedPreferences.setMockInitialValues({});
    coordinator = MappingStoreStartupCoordinator(
      isMacOS: true,
      prepareCatalog: () async {
        if (!_ready) {
          throw MappingRuntimeUnavailable(
            rootPath: '/local/replica',
            paths: ['/local/replica'],
            diagnostic:
                'Initial synchronization must complete before this replica can be used.',
          );
        }
        return _readiness.future;
      },
      initialize: (catalog) async {
        initializeCalls++;
        catalogRoots.add(catalog.rootPath);
        final bagged = PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage());
        container = ProviderContainer(
          overrides: [
            mappingCatalogProvider.overrideWithValue(catalog),
            mapProvider.overrideWith(
              () => TestMapNotifier(
                const MapState(
                  center: LatLng(-41.5, 146.5),
                  zoom: 10,
                  basemap: Basemap.tracestrack,
                ),
                peaksBaggedRepository: bagged,
              ),
            ),
            peakListRepositoryProvider.overrideWithValue(
              PeakListRepository.test(InMemoryPeakListStorage()),
            ),
            peaksBaggedRepositoryProvider.overrideWithValue(bagged),
          ],
        );
      },
    );
  }
  late final MappingStoreStartupCoordinator coordinator;
  bool _ready = false;
  final _readiness = Completer<MappingCatalog>();
  int initializeCalls = 0;
  final catalogRoots = <String>[];
  ProviderContainer? container;
  Widget get shell => StartupShell(
    coordinator: coordinator,
    readyBuilder: (_) => UncontrolledProviderScope(
      container: container!,
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  void dispose() => container?.dispose();
  void synchronizationReady() => _ready = true;
  void finishReadiness() => _readiness.complete(
    MappingCatalog(
      rootPath: '/local/replica/generations/complete/payload',
      regions: testMappingCatalog.regions,
      basemaps: testMappingCatalog.basemaps,
      tasmapCatalogPath: testMappingCatalog.tasmapCatalogPath,
      naturalFeaturesCatalogPath: testMappingCatalog.naturalFeaturesCatalogPath,
      demSources: testMappingCatalog.demSources,
      routingCoverageRegionKeys: testMappingCatalog.routingCoverageRegionKeys,
      polygonDisplayPaths: testMappingCatalog.polygonDisplayPaths,
    ),
  );
}
