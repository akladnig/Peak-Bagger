import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/manifest_priority.dart';

import '../harness/route_graph_mapping_harness.dart';
import '../harness/mapping_coverage_fixture.dart';

void main() {
  for (final priority in ['1', '2']) {
    test(
      'catalog overlap priority $priority controls routing eligibility',
      () async {
        final tasmania = mappingCoverageCatalog.regions.first;
        final other = MappingCatalogRegion(
          key: 'overlap',
          name: 'Overlap',
          shortName: 'Overlap',
          priority: ManifestPriority.parse(priority),
          showInPeakList: false,
          polyPaths: const [],
          polygons: tasmania.polygons,
          basemapKeys: const [],
          mapSet: const [],
          peakListFilterAliases: const [],
          routingCoverage: 'northeast-alps',
          seedOnStartup: false,
          composite: false,
          peaks: const [],
          highways: const ['Highways/northeast-alps.json'],
          fingerprint: null,
        );
        final catalog = MappingCatalog(
          rootPath: mappingCoverageCatalog.rootPath,
          regions: [...mappingCoverageCatalog.regions, other],
          basemaps: const [],
          tasmapCatalogPath: mappingCoverageCatalog.tasmapCatalogPath,
          naturalFeaturesCatalogPath:
              mappingCoverageCatalog.naturalFeaturesCatalogPath,
          demSources: mappingCoverageCatalog.demSources,
          routingCoverageRegionKeys:
              mappingCoverageCatalog.routingCoverageRegionKeys,
        );
        final harness = await RouteGraphMappingHarness.create(catalog: catalog);
        addTearDown(harness.dispose);
        harness.plan();
        await _settle();
        expect(
          harness.planner.coverages,
          priority == '1' ? isEmpty : ['northeast-alps'],
        );
        expect(harness.operations.failures, isEmpty);
        if (priority == '1') expect(harness.access.reads, isEmpty);
      },
    );
  }
  test(
    'catalog endpoints select a coverage independently of graph footprints',
    () async {
      final harness = await RouteGraphMappingHarness.create();
      addTearDown(harness.dispose);
      await harness.coordinator.ensureCoverage('northeast-alps');
      harness.access.reads.clear();
      harness.plan(
        start: const LatLng(46, 14),
        end: const LatLng(46.001, 14.001),
      );
      await _settle();
      expect(harness.planner.coverages, ['northeast-alps']);
      expect(harness.access.reads, isEmpty);
      expect(harness.container.read(mapProvider).routeDraftError, isNull);
    },
  );

  test(
    'different and uncovered endpoint coverages never trigger Mapping reads',
    () async {
      final harness = await RouteGraphMappingHarness.create();
      addTearDown(harness.dispose);
      harness.plan(start: const LatLng(-42, 146), end: const LatLng(46, 14));
      await _settle();
      expect(harness.planner.coverages, isEmpty);
      expect(harness.access.reads, isEmpty);
      expect(harness.operations.failures, isEmpty);
      expect(
        harness.container.read(mapProvider).routeDraftError,
        contains('outside routing coverage'),
      );
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
