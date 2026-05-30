import 'package:objectbox/objectbox.dart';

@Entity()
class RouteGraphWayIndex {
  @Id(assignable: true)
  int id;

  @Unique()
  String recordKey;

  @Index()
  int generation;

  @Index()
  String chunkKey;

  @Index()
  int osmWayId;

  @Index()
  String? highway;

  @Index()
  String? surface;

  @Index()
  String? footway;

  @Index()
  String? foot;

  @Index()
  String? route;

  @Index()
  String? access;

  @Index()
  String? name;

  @Index()
  String? normalizedName;

  @Index()
  int lengthMeters;

  @Index()
  int tagCount;

  String tagsJson;

  RouteGraphWayIndex({
    this.id = 0,
    required this.recordKey,
    required this.generation,
    required this.chunkKey,
    required this.osmWayId,
    this.highway,
    this.surface,
    this.footway,
    this.foot,
    this.route,
    this.access,
    this.name,
    this.normalizedName,
    required this.lengthMeters,
    required this.tagCount,
    required this.tagsJson,
  });

  static String recordKeyFor({
    required int generation,
    required String chunkKey,
    required int osmWayId,
  }) {
    return '$generation|$chunkKey|$osmWayId';
  }

  RouteGraphWayIndex copyWith({
    int? id,
    String? recordKey,
    int? generation,
    String? chunkKey,
    int? osmWayId,
    String? highway,
    String? surface,
    String? footway,
    String? foot,
    String? route,
    String? access,
    String? name,
    String? normalizedName,
    int? lengthMeters,
    int? tagCount,
    String? tagsJson,
  }) {
    return RouteGraphWayIndex(
      id: id ?? this.id,
      recordKey: recordKey ?? this.recordKey,
      generation: generation ?? this.generation,
      chunkKey: chunkKey ?? this.chunkKey,
      osmWayId: osmWayId ?? this.osmWayId,
      highway: highway ?? this.highway,
      surface: surface ?? this.surface,
      footway: footway ?? this.footway,
      foot: foot ?? this.foot,
      route: route ?? this.route,
      access: access ?? this.access,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      tagCount: tagCount ?? this.tagCount,
      tagsJson: tagsJson ?? this.tagsJson,
    );
  }
}
