import 'package:objectbox/objectbox.dart';

@Entity()
class Peak {
  static const sourceOfTruthOsm = 'OSM';
  static const sourceOfTruthHwc = 'HWC';

  @Id(assignable: true)
  int id = 0;

  @Unique()
  int osmId;

  String name;
  String altName;
  double? elevation;
  double latitude;
  double longitude;
  String? area;
  String gridZoneDesignator;
  String mgrs100kId;
  String easting;
  String northing;
  bool verified;
  String sourceOfTruth;

  Peak({
    this.id = 0,
    this.osmId = 0,
    required this.name,
    this.altName = '',
    this.elevation,
    required this.latitude,
    required this.longitude,
    this.area,
    this.gridZoneDesignator = '',
    this.mgrs100kId = '',
    this.easting = '',
    this.northing = '',
    this.verified = false,
    this.sourceOfTruth = sourceOfTruthOsm,
  });

  Peak copyWith({
    int? osmId,
    String? name,
    String? altName,
    double? elevation,
    double? latitude,
    double? longitude,
    String? area,
    String? gridZoneDesignator,
    String? mgrs100kId,
    String? easting,
    String? northing,
    bool? verified,
    String? sourceOfTruth,
  }) {
    return Peak(
      id: id,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      altName: altName ?? this.altName,
      elevation: elevation ?? this.elevation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      area: area ?? this.area,
      gridZoneDesignator: gridZoneDesignator ?? this.gridZoneDesignator,
      mgrs100kId: mgrs100kId ?? this.mgrs100kId,
      easting: easting ?? this.easting,
      northing: northing ?? this.northing,
      verified: verified ?? this.verified,
      sourceOfTruth: sourceOfTruth ?? this.sourceOfTruth,
    );
  }

  static Peak fromOverpass(Map<String, dynamic> json) {
    final osmId = json['id'] as int? ?? int.tryParse('${json['id']}') ?? 0;
    final tags = json['tags'] as Map<String, dynamic>?;
    final name = tags?['name'] as String? ?? 'Unknown';

    double? elevation;
    final eleValue = tags?['ele'];
    if (eleValue != null) {
      if (eleValue is double) {
        elevation = eleValue;
      } else if (eleValue is String) {
        final parsed = double.tryParse(eleValue);
        if (parsed != null) {
          elevation = parsed;
        }
      }
    }

    double lat;
    double lon;
    if (json['center'] != null) {
      lat = (json['center'] as Map<String, dynamic>)['lat'] as double;
      lon = (json['center'] as Map<String, dynamic>)['lon'] as double;
    } else {
      lat = json['lat'] as double;
      lon = json['lon'] as double;
    }

    return Peak(
      osmId: osmId,
      name: name,
      elevation: elevation,
      latitude: lat,
      longitude: lon,
    );
  }
}
