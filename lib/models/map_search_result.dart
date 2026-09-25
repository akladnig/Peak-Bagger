import 'package:latlong2/latlong.dart';

import 'gpx_track.dart';
import 'natural_feature.dart';
import 'peak.dart';
import 'route.dart' as app_route;
import 'tasmap50k.dart';

enum MapSearchResultType { peak, track, route, natural, road, map }

enum MapSearchCategory { peaks, tracksRoutes, natural, roads, maps }

@Deprecated('Use MapSearchCategory sets.')
enum MapSearchEntityFilter { all, peaks, tracksRoutes, natural, roads, maps }

enum MapSearchSort { nameAscending, nameDescending }

enum MapSearchGroup { none, region, type }

class MapSearchPage {
  const MapSearchPage({required this.results, required this.isExhausted});

  final List<MapSearchResult> results;
  final bool isExhausted;
}

class MapSearchResult {
  const MapSearchResult._({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.anchor,
    this.trailingText,
    this.displayDate,
    this.regionKey,
    this.regionName,
    this.mapName,
    this.peak,
    this.track,
    this.route,
    this.naturalFeature,
    this.road,
    this.map,
  });

  const MapSearchResult.peak({
    required String id,
    required String title,
    required String subtitle,
    required LatLng anchor,
    String? trailingText,
    DateTime? displayDate,
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
         displayDate: displayDate,
         regionKey: regionKey,
         regionName: regionName,
         mapName: mapName,
         peak: peak,
       );

  MapSearchResult.track({
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
         displayDate:
             track.trackDate?.toLocal() ?? track.startDateTime?.toLocal(),
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

  MapSearchResult.road({
    required String subtitle,
    String? regionKey,
    String? regionName,
    required MapSearchRoad road,
  }) : this._(
         type: MapSearchResultType.road,
         id: '${road.osmWayId}',
         title: road.name,
         subtitle: subtitle,
         anchor: road.anchor,
         regionKey: regionKey,
         regionName: regionName,
         road: road,
       );

  const MapSearchResult.natural({
    required String id,
    required String title,
    required String subtitle,
    required LatLng anchor,
    String? regionKey,
    String? regionName,
    required NaturalFeature naturalFeature,
  }) : this._(
         type: MapSearchResultType.natural,
         id: id,
         title: title,
         subtitle: subtitle,
         anchor: anchor,
         regionKey: regionKey,
         regionName: regionName,
         naturalFeature: naturalFeature,
       );

  final MapSearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String? trailingText;
  final DateTime? displayDate;
  final LatLng anchor;
  final String? regionKey;
  final String? regionName;
  final String? mapName;
  final Peak? peak;
  final GpxTrack? track;
  final app_route.Route? route;
  final NaturalFeature? naturalFeature;
  final MapSearchRoad? road;
  final Tasmap50k? map;

  String get normalizedTitle => title.trim().toLowerCase();
}

class MapSearchRoad {
  const MapSearchRoad({
    required this.osmWayId,
    required this.name,
    required this.highway,
    required this.surface,
    required this.anchor,
    required this.routingCoverageKey,
    required this.generation,
    required this.chunkKey,
  });

  final int osmWayId;
  final String name;
  final String? highway;
  final String? surface;
  final LatLng anchor;
  final String routingCoverageKey;
  final int generation;
  final String chunkKey;
}
