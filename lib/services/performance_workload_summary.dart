import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/gpx_track.dart';
import '../models/peak.dart';
import '../models/peak_list.dart';
import '../models/peaks_bagged.dart';
import '../models/route.dart';
import '../models/route_graph_manifest.dart';
import '../objectbox.g.dart';
import '../providers/dashboard_layout_provider.dart';
import '../providers/peak_marker_info_settings_provider.dart';
import 'migration_marker_store.dart';

/// Expensive read-only workload pass, deliberately separate from timed runs.
/// No names, IDs, coordinates, GPX text, database bytes or private settings.
Map<String, Object?> summarizeTrackGeometry(Iterable<GpxTrack> tracks) {
  var gpxVertices = 0;
  final displayVertices = <String, int>{};
  for (final track in tracks) {
    if (track.gpxFile.isNotEmpty) {
      gpxVertices += XmlDocument.parse(
        track.gpxFile,
      ).findAllElements('trkpt').length;
    }
    final display = GpxTrack.decodeDisplayTrackPointsByZoom(
      track.displayTrackPointsByZoom,
    );
    for (final entry in display.entries) {
      final count = entry.value.fold<int>(
        0,
        (total, segment) => total + segment.length,
      );
      displayVertices.update(
        '${entry.key}',
        (total) => total + count,
        ifAbsent: () => count,
      );
    }
  }
  return {
    'gpx_vertices': gpxVertices,
    'display_vertices_by_zoom': displayVertices,
  };
}

Map<String, Object?> capturePerformanceWorkload(
  Store store,
  SharedPreferences prefs,
) => {
  'record_counts': {
    'GpxTrack': store.box<GpxTrack>().count(),
    'Peak': store.box<Peak>().count(),
    'PeaksBagged': store.box<PeaksBagged>().count(),
    'PeakList': store.box<PeakList>().count(),
    'PeakListItemEntity': store.box<PeakListItemEntity>().count(),
    'Route': store.box<Route>().count(),
  },
  'stored_track_geometry': summarizeTrackGeometry(
    store.box<GpxTrack>().getAll(),
  ),
  'migration_flags': {
    for (final key in [
      MigrationMarkerStore.migrationKey,
      MigrationMarkerStore.peaksBaggedBackfillKey,
      MigrationMarkerStore.itemVisibilityBackfillKey,
      MigrationMarkerStore.peakListCoverageBackfillKey,
    ])
      key: prefs.getBool(key) ?? false,
  },
  'saved_dashboard_order': prefs.getStringList(dashboardCardOrderStorageKey),
  'saved_peak_info': prefs.getBool(peakMarkerInfoKey),
  'saved_theme': {
    'mode': prefs.getString('theme_mode'),
    'seed': prefs.getString('theme_seed_color'),
    'variant': prefs.getString('theme_scheme_variant'),
    'contrast': prefs.getDouble('theme_contrast_level'),
  },
  'graph_manifests': [
    for (final manifest in store.box<RouteGraphManifest>().getAll())
      {
        'coverage': manifest.routingCoverageKey,
        'source_hash': manifest.sourceHash,
        'schema': manifest.schemaVersion,
        'generation': manifest.activeGeneration,
        'readiness': manifest.readinessState,
        'nodes': manifest.nodeCount,
        'ways': manifest.edgeCount,
        'chunks': manifest.chunkCount,
      },
  ],
};
