# Route ObjectBox Entity
## Goal
Create a new objectBox Entity named Route
The entity should have the following schema:
- id (autoincrement)
- name (String)
- gpxRoute - stored a list of <LatLng> see below
- displayRoutePointsByZoom (String)
- colour (String)
- distance2d (double)
- distance3d (double)
- ascent (double)
- descent (double)
- startElevation (double)
- endElevation (double)
- lowestElevation (double)
- highestElevation (double)

This should also be able to be viewed in ObjectBox Admin


Use a transient List<LatLng> backed by a persisted JSON String.
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';
@Entity()
class TrackLine {
  @Id()
  int id = 0;
  @Transient()
  List<LatLng> points = [];
  String get pointsJson => jsonEncode(
        points.map((p) => [p.latitude, p.longitude]).toList(),
      );
  set pointsJson(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      points = [];
      return;
    }
    points = decoded
        .whereType<List>()
        .where((pair) => pair.length == 2)
        .map((pair) => LatLng(
              (pair[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            ))
        .toList(growable: false);
  }
}

Notes:
- ObjectBox Dart does not use @Convert for this.
- This stores the whole list in one DB string field.
