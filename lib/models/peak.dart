import 'package:objectbox/objectbox.dart';

@Entity()
class Peak {
  @Id()
  int id = 0;

  String name;
  double? elevation;
  double latitude;
  double longitude;
  String? area;

  Peak({
    this.id = 0,
    required this.name,
    this.elevation,
    required this.latitude,
    required this.longitude,
    this.area,
  });

  static Peak fromOverpass(Map<String, dynamic> json) {
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
      name: name,
      elevation: elevation,
      latitude: lat,
      longitude: lon,
    );
  }
}
