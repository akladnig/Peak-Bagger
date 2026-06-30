import 'package:latlong2/latlong.dart';

import 'gpx_track.dart';
import 'peak.dart';
import 'route.dart' as app_route;
import 'tasmap50k.dart';

enum MapSearchResultType { peak, track, route, map }

enum MapSearchEntityFilter { all, peaks, tracksRoutes, natural, roads, maps }

enum MapSearchSort { nameAscending, nameDescending }

class MapSearchResult {
  const MapSearchResult._({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.anchor,
    this.trailingText,
    this.regionKey,
    this.regionName,
    this.mapName,
    this.peak,
    this.track,
    this.route,
    this.map,
  });

  const MapSearchResult.peak({
    required String id,
    required String title,
    required String subtitle,
    required LatLng anchor,
    String? trailingText,
    String? regionKey,
    String? regionName,
    String? mapName,
    required Peak peak,
  }) : this._(
         type: MapSearchResultType.peak,
         id: id,
         title: title,
         subtitle: subtitle,
         anchor: anchor,
         trailingText: trailingText,
         regionKey: regionKey,
         regionName: regionName,
         mapName: mapName,
         peak: peak,
       );

  const MapSearchResult.track({
    required String id,
    required String title,
    required String subtitle,
    required LatLng anchor,
    String? regionKey,
    String? regionName,
    String? mapName,
    required GpxTrack track,
  }) : this._(
         type: MapSearchResultType.track,
         id: id,
         title: title,
         subtitle: subtitle,
         anchor: anchor,
         regionKey: regionKey,
         regionName: regionName,
         mapName: mapName,
         track: track,
       );

  const MapSearchResult.route({
    required String id,
    required String title,
    required String subtitle,
    required LatLng anchor,
    String? regionKey,
    String? regionName,
    String? mapName,
    required app_route.Route route,
  }) : this._(
         type: MapSearchResultType.route,
         id: id,
         title: title,
         subtitle: subtitle,
         anchor: anchor,
         regionKey: regionKey,
         regionName: regionName,
         mapName: mapName,
         route: route,
       );

  const MapSearchResult.map({
    required String id,
    required String title,
    required String subtitle,
    required LatLng anchor,
    String? regionKey,
    String? regionName,
    required Tasmap50k map,
  }) : this._(
         type: MapSearchResultType.map,
         id: id,
         title: title,
         subtitle: subtitle,
         anchor: anchor,
         regionKey: regionKey,
         regionName: regionName,
         map: map,
       );

  final MapSearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String? trailingText;
  final LatLng anchor;
  final String? regionKey;
  final String? regionName;
  final String? mapName;
  final Peak? peak;
  final GpxTrack? track;
  final app_route.Route? route;
  final Tasmap50k? map;

  String get normalizedTitle => title.trim().toLowerCase();
}
