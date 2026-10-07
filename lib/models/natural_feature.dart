import 'package:objectbox/objectbox.dart';

@Entity()
class NaturalFeature {
  @Id()
  int id = 0;

  String name;
  String altName;
  String tag;
  String country;
  String county;
  String region;
  double latitude;
  double longitude;
  String gridZoneDesignator;
  String mgrs100kId;
  String easting;
  String northing;
  int osmId;
  String osmType;
  String sourceOfTruth;
  String sourceKey;

  /// Nullable additive index: legacy rows can open before reconciliation removes
  /// duplicates. New and reconciled rows always persist their canonical key.
  @Unique()
  String? sourceRecordKey;

  NaturalFeature({
    this.id = 0,
    required this.name,
    this.altName = '',
    required this.tag,
    this.country = '',
    this.county = '',
    this.region = '',
    required this.latitude,
    required this.longitude,
    this.gridZoneDesignator = '',
    this.mgrs100kId = '',
    this.easting = '',
    this.northing = '',
    required this.osmId,
    required this.osmType,
    this.sourceOfTruth = 'OSM',
    String? sourceKey,
    String? sourceRecordKey,
  }) : sourceKey = sourceKey ?? '$sourceOfTruth:$osmType:$osmId',
       sourceRecordKey = sourceRecordKey ?? '$sourceOfTruth:$osmType:$osmId';
}
