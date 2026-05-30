import 'package:objectbox/objectbox.dart';

@Entity()
class RouteGraphManifest {
  static const readinessBootstrapping = 'bootstrapping';
  static const readinessReady = 'ready';
  static const readinessFailed = 'failed';
  static const manifestId = 1;

  @Id(assignable: true)
  int id;

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

  RouteGraphManifest({
    this.id = manifestId,
    this.sourceHash = '',
    this.schemaVersion = '',
    this.activeGeneration = 0,
    this.importedAt,
    this.chunkCount = 0,
    this.nodeCount = 0,
    this.edgeCount = 0,
    this.readinessState = readinessBootstrapping,
    this.lastError,
  });

  bool get hasActiveGeneration {
    return activeGeneration > 0 && readinessState == readinessReady;
  }

  bool get isFailed => readinessState == readinessFailed;

  RouteGraphManifest copyWith({
    int? id,
    String? sourceHash,
    String? schemaVersion,
    int? activeGeneration,
    DateTime? importedAt,
    int? chunkCount,
    int? nodeCount,
    int? edgeCount,
    String? readinessState,
    String? lastError,
    bool clearLastError = false,
  }) {
    return RouteGraphManifest(
      id: id ?? this.id,
      sourceHash: sourceHash ?? this.sourceHash,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeGeneration: activeGeneration ?? this.activeGeneration,
      importedAt: importedAt ?? this.importedAt,
      chunkCount: chunkCount ?? this.chunkCount,
      nodeCount: nodeCount ?? this.nodeCount,
      edgeCount: edgeCount ?? this.edgeCount,
      readinessState: readinessState ?? this.readinessState,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
