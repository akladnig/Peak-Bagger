import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum RouteMarkerKind { circle, target, numbered }

typedef RouteDraftDisplayMarkerKind = RouteMarkerKind;

@immutable
class RouteMarkerDisplay {
  const RouteMarkerDisplay({
    required this.id,
    required this.point,
    required this.kind,
    this.number,
    this.isCommitted = true,
  });

  final String id;
  final LatLng point;
  final RouteMarkerKind kind;
  final int? number;
  final bool isCommitted;

  RouteMarkerDisplay copyWith({
    String? id,
    LatLng? point,
    RouteMarkerKind? kind,
    int? number,
    bool? isCommitted,
  }) {
    return RouteMarkerDisplay(
      id: id ?? this.id,
      point: point ?? this.point,
      kind: kind ?? this.kind,
      number: number ?? this.number,
      isCommitted: isCommitted ?? this.isCommitted,
    );
  }

  @override
  bool operator ==(Object other) =>
          identical(this, other) ||
      other is RouteMarkerDisplay &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          point == other.point &&
          kind == other.kind &&
          number == other.number &&
          isCommitted == other.isCommitted;

  @override
  int get hashCode => Object.hash(id, point, kind, number, isCommitted);
}

typedef RouteDraftDisplayMarker = RouteMarkerDisplay;
