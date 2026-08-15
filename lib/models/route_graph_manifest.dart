import 'dart:convert';

import 'package:objectbox/objectbox.dart';

@Entity()
class RouteGraphManifest {
  static const readinessBootstrapping = 'bootstrapping';
  static const readinessReady = 'ready';
  static const readinessFailed = 'failed';
  static const manifestId = 1;

  @Id(assignable: true)
  int id;

  @Unique()
  String routingCoverageKey;

  String sourceHash;
  String schemaVersion;
  int activeGeneration;
  @Property(type: PropertyType.dateUtc)
  DateTime? importedAt;
  int chunkCount;
  int nodeCount;
  int edgeCount;
  String readinessState;
  String? lastError;
  String sourceRegionKeysJson;
  String unavailableFootprintJson;

  RouteGraphManifest({
    this.id = 0,
    this.routingCoverageKey = '',
    this.sourceHash = '',
    this.schemaVersion = '',
    this.activeGeneration = 0,
    this.importedAt,
    this.chunkCount = 0,
    this.nodeCount = 0,
    this.edgeCount = 0,
    this.readinessState = readinessBootstrapping,
    this.lastError,
    this.sourceRegionKeysJson = '[]',
    this.unavailableFootprintJson = '[]',
  });

  bool get hasActiveGeneration {
    return activeGeneration > 0 && readinessState == readinessReady;
  }

  bool get isFailed => readinessState == readinessFailed;

  List<String> get sourceRegionKeys => List<String>.unmodifiable(
    (jsonDecode(sourceRegionKeysJson) as List).cast<String>(),
  );

  List<RouteGraphFootprintBound> get unavailableFootprint =>
      RouteGraphFootprintBound.decodeList(unavailableFootprintJson);

  RouteGraphManifest copyWith({
    int? id,
    String? routingCoverageKey,
    String? sourceHash,
    String? schemaVersion,
    int? activeGeneration,
    DateTime? importedAt,
    int? chunkCount,
    int? nodeCount,
    int? edgeCount,
    String? readinessState,
    String? lastError,
    String? sourceRegionKeysJson,
    String? unavailableFootprintJson,
    bool clearLastError = false,
  }) {
    return RouteGraphManifest(
      id: id ?? this.id,
      routingCoverageKey: routingCoverageKey ?? this.routingCoverageKey,
      sourceHash: sourceHash ?? this.sourceHash,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeGeneration: activeGeneration ?? this.activeGeneration,
      importedAt: importedAt ?? this.importedAt,
      chunkCount: chunkCount ?? this.chunkCount,
      nodeCount: nodeCount ?? this.nodeCount,
      edgeCount: edgeCount ?? this.edgeCount,
      readinessState: readinessState ?? this.readinessState,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      sourceRegionKeysJson: sourceRegionKeysJson ?? this.sourceRegionKeysJson,
      unavailableFootprintJson:
          unavailableFootprintJson ?? this.unavailableFootprintJson,
    );
  }
}

class RouteGraphFootprintBound {
  const RouteGraphFootprintBound({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  bool contains(double latitude, double longitude) {
    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLon &&
        longitude <= maxLon;
  }

  Map<String, double> toJson() => {
    'minLat': minLat,
    'minLon': minLon,
    'maxLat': maxLat,
    'maxLon': maxLon,
  };

  static String encodeList(List<RouteGraphFootprintBound> bounds) =>
      jsonEncode(bounds.map((bound) => bound.toJson()).toList(growable: false));

  static List<RouteGraphFootprintBound> decodeList(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Route graph footprint must be a JSON list.');
    }
    return List<RouteGraphFootprintBound>.unmodifiable(
      decoded.map((value) {
        if (value is! Map) {
          throw const FormatException(
            'Route graph footprint bound must be an object.',
          );
        }
        final minLat = value['minLat'];
        final minLon = value['minLon'];
        final maxLat = value['maxLat'];
        final maxLon = value['maxLon'];
        if (minLat is! num ||
            minLon is! num ||
            maxLat is! num ||
            maxLon is! num) {
          throw const FormatException(
            'Route graph footprint bound is invalid.',
          );
        }
        return RouteGraphFootprintBound(
          minLat: minLat.toDouble(),
          minLon: minLon.toDouble(),
          maxLat: maxLat.toDouble(),
          maxLon: maxLon.toDouble(),
        );
      }),
    );
  }
}
