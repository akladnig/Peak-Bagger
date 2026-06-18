import 'package:objectbox/objectbox.dart';

@Entity()
class Waypoints {
  static const typeHome = 'home';
  static const typeMarker = 'marker';
  static const typeFavourite = 'favourite';

  @Id()
  int id = 0;

  String name;
  String type;
  double latitude;
  double longitude;
  String mgrs;

  Waypoints({
    this.id = 0,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.mgrs,
  });
}
