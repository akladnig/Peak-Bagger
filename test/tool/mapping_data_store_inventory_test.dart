import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const nonDart = {
    'tool/convert_osm_boundary_to_poly.sh': 'store-isolated',
    'elvis_dem.sh': 'store-isolated',
    'local_topo/tasmania/scripts/rebuild_stack.sh': 'resolver-validated',
    'local_topo/tasmania/scripts/manual_refresh.sh': 'resolver-validated',
    'local_topo/tasmania/scripts/scheduled_refresh.sh': 'resolver-validated',
    'local_topo/tasmania/scripts/_common.sh': 'resolver-validated',
    'local_topo/tasmania/scripts/start_stack.sh': 'store-isolated',
    'local_topo/tasmania/scripts/stop_stack.sh': 'store-isolated',
    'local_topo/tasmania/scripts/prepare_smoke_fixture.sh': 'store-isolated',
    'local_topo/tasmania/scripts/prerender_tiles.mjs': 'store-isolated',
    'local_topo/tasmania/scripts/review_cartography.mjs': 'store-isolated',
    'local_topo/tasmania/scripts/smoke.mjs': 'store-isolated',
  };

  // Work Item 12 removes these legacy contracts. No new direct I/O can be
  // added during this intermediate resolver slice, including to new tools.
  const legacyToolIo = {
    'tool/peak_prominence_csv.dart': 1,
    'tool/region_peak_fingerprint_support.dart': 3,
    'tool/download_tasmania_thelist_dem.dart': 10,
    'tool/elvis_dem.dart': 15,
    'tool/generate_region_manifest_catalog.dart': 4,
    'tool/sync_peakbagger_csv.dart': 9,
    'tool/rank_fvg_peaks.dart': 8,
    'tool/slovenia_hribi_source_peak_list.dart': 1,
  };
  final directIo = RegExp(
    r'\b(File|Directory|RandomAccessFile)\s*\(|\bProcess\.',
  );

  test('every Dart tool is inventoried, every non-Dart tool classified', () {
    final inventory = File('docs/mapping-data-store.md').readAsStringSync();
    for (final file in Directory('tool').listSync().whereType<File>().where(
      (file) => file.path.endsWith('.dart'),
    )) {
      expect(
        inventory,
        contains('<!-- inventory:${file.path} -->'),
        reason: file.path,
      );
    }
    for (final entry in nonDart.entries) {
      expect(File(entry.key).existsSync(), isTrue);
      final line = inventory
          .split('\n')
          .singleWhere(
            (line) => line.contains('<!-- inventory:${entry.key} -->'),
          );
      expect(line.toLowerCase(), contains(entry.value), reason: entry.key);
    }
    expect(inventory, contains('Highways/slovenia-highways.json'));
    expect(inventory, contains('shipped app must never query Overpass'));
    expect(inventory, contains('veneto.poly'));
    expect(inventory, contains('all-peaks-sorted-p100.csv'));
  });

  test(
    'Mapping-aware runtime I/O is restricted to resolver and named non-store adapters',
    () {
      const resolverOwners = {
        'lib/services/mapping_store_core.dart',
        'lib/services/mapping_tool_resolver.dart',
      };
      const nonStoreAdapters = {
        'lib/services/route_elevation_sampler.dart':
            2, // host library/data probes
        'lib/services/tasmap_repository.dart': 2, // explicit user CSV imports
        'lib/services/route_graph_peak_list_generation_service.dart':
            5, // user CSV/reports
        'lib/providers/map_provider.dart': 4, // managed Bushwalking GPX storage
        'lib/services/gpx_importer.dart':
            18, // user GPX reads/moves and import logs
      };
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (!RegExp(
              r"services/mapping_(data_store|store_core|store_resolver|tool_resolver)\.dart",
            ).hasMatch(source) &&
            !source.contains('MappingStoreOperationFileAccess(')) {
          continue;
        }
        final count = directIo.allMatches(source).length;
        if (resolverOwners.contains(file.path)) continue;
        expect(
          count,
          nonStoreAdapters[file.path] ?? 0,
          reason:
              'Unauthorized direct Mapping I/O in ${file.path}; use resolver operations.',
        );
      }
      // The opaque GDAL adapter must receive a validated path through the resolver.
      final elevation = File(
        'lib/services/route_elevation_sampler.dart',
      ).readAsStringSync();
      expect(elevation, contains('_fileAccess.open('));
    },
  );

  test(
    'new tools cannot introduce direct store I/O; legacy cutover I/O is frozen',
    () {
      for (final file in Directory('tool').listSync().whereType<File>().where(
        (file) => file.path.endsWith('.dart'),
      )) {
        final source = file.readAsStringSync();
        if (file.path == 'tool/mapping_store.dart') {
          expect(directIo.allMatches(source), hasLength(1));
          expect(source, contains("'test/fixtures/mapping_store/v1'"));
        } else {
          expect(
            directIo.allMatches(source).length,
            legacyToolIo[file.path] ?? 0,
            reason: file.path,
          );
        }
      }
    },
  );

  test('shipped runtime never imports tool manifests or tool-only modes', () {
    const toolOnlyFiles = {
      'mapping_tool_manifest.dart',
      'mapping_tool_resolver.dart',
      'mapping_store_contract_verifier.dart',
    };
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.dart') &&
                  !toolOnlyFiles.contains(p.basename(file.path)),
            )) {
      final source = file.readAsStringSync();
      if (p.basename(file.path) == 'mapping_store_core.dart') {
        expect(source, contains('value != mappingToolManifestPath'));
      } else {
        expect(
          source,
          isNot(contains('tool_manifest.json')),
          reason: file.path,
        );
      }
      expect(
        source,
        isNot(contains('services/mapping_tool_')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('services/mapping_store_contract_verifier.dart')),
        reason: file.path,
      );
    }
  });
}
