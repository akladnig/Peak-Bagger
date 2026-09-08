import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';

class RouteGraphCoverageDefinition {
  const RouteGraphCoverageDefinition({
    required this.key,
    required this.displayName,
    required this.sourceRegions,
  });

  final String key;
  final String displayName;
  final List<RouteGraphCoverageSourceRegion> sourceRegions;
}

class RouteGraphCoverageSourceRegion {
  const RouteGraphCoverageSourceRegion({
    required this.key,
    required this.priority,
    required this.sourceAssets,
  });

  final String key;
  final ManifestPriority priority;
  final List<RouteGraphCoverageSourceAsset> sourceAssets;
}

class RouteGraphCoverageSourceAsset {
  const RouteGraphCoverageSourceAsset({
    required this.path,
    required this.overpass,
  });

  final String path;
  final Map<String, Object?> overpass;
}

class RouteGraphCoverageImportInput {
  const RouteGraphCoverageImportInput({
    required this.definition,
    required this.sourceHash,
    required this.mergedOverpass,
    required this.acceptedWayCount,
    this.unavailableFootprint = const [],
  });

  final RouteGraphCoverageDefinition definition;
  final String sourceHash;
  final Map<String, Object?> mergedOverpass;
  final int acceptedWayCount;
  final List<RouteGraphFootprintBound> unavailableFootprint;

  List<Object?> get elements => mergedOverpass['elements']! as List<Object?>;
}
