import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class RouteGraphTrailDisplayChunk {
  @Id(assignable: true)
  int id;

  @Unique()
  String recordKey;

  @Index()
  int generation;

  @Index()
  String routingCoverageKey;

  @Index()
  int cacheZoom;

  @Index()
  String chunkKey;

  String payloadJson;

  @Transient()
  List<RouteGraphTrailDisplayWay>? decodedWaysCache;

  RouteGraphTrailDisplayChunk({
    this.id = 0,
    required this.recordKey,
    required this.generation,
    this.routingCoverageKey = '',
    required this.cacheZoom,
    required this.chunkKey,
    required this.payloadJson,
  });

  static String recordKeyFor({
    String routingCoverageKey = '',
    required int generation,
    required int cacheZoom,
    required String chunkKey,
  }) {
    return '$routingCoverageKey|$generation|$cacheZoom|$chunkKey';
  }

  List<RouteGraphTrailDisplayWay> decodeWays() {
    final cached = decodedWaysCache;
    if (cached != null) {
      return cached;
    }

    final decoded = jsonDecode(payloadJson);
    if (decoded is! List) {
      throw const FormatException(
        'Trail display chunk payload must be a JSON list.',
      );
    }

    final ways = decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Trail display chunk way payload must be a JSON object.',
            );
          }

          final typed = Map<String, dynamic>.from(entry);
          final osmWayId = typed['osmWayId'];
          final points = typed['points'];
          if (osmWayId is! int || points is! List) {
            throw const FormatException(
              'Trail display chunk way payload missing required fields.',
            );
          }

          return RouteGraphTrailDisplayWay(
            osmWayId: osmWayId,
            points: _decodePoints(points),
          );
        })
        .toList(growable: false);
    decodedWaysCache = ways;
    return ways;
  }

  static String encodeWays(List<RouteGraphTrailDisplayWay> ways) {
    return jsonEncode(
      ways
          .map(
            (way) => {
              'osmWayId': way.osmWayId,
              'points': way.points
                  .map((point) => [point.latitude, point.longitude])
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    );
  }

  RouteGraphTrailDisplayChunk copyWith({
    int? id,
    String? recordKey,
    int? generation,
    String? routingCoverageKey,
    int? cacheZoom,
    String? chunkKey,
    String? payloadJson,
  }) {
    return RouteGraphTrailDisplayChunk(
      id: id ?? this.id,
      recordKey: recordKey ?? this.recordKey,
      generation: generation ?? this.generation,
      routingCoverageKey: routingCoverageKey ?? this.routingCoverageKey,
      cacheZoom: cacheZoom ?? this.cacheZoom,
      chunkKey: chunkKey ?? this.chunkKey,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }
}

class RouteGraphTrailDisplayWay {
  const RouteGraphTrailDisplayWay({
    required this.osmWayId,
    required this.points,
  });

  final int osmWayId;
  final List<LatLng> points;
}

List<LatLng> _decodePoints(List<dynamic> points) {
  final decodedPoints = <LatLng>[];
  for (final point in points) {
    if (point is! List || point.length != 2) {
      throw const FormatException(
        'Trail display chunk point must be a lat/lon pair.',
      );
    }

    final lat = point[0];
    final lon = point[1];
    if (lat is! num || lon is! num) {
      throw const FormatException(
        'Trail display chunk point must contain numeric coordinates.',
      );
    }
    decodedPoints.add(LatLng(lat.toDouble(), lon.toDouble()));
  }

  return decodedPoints;
}
