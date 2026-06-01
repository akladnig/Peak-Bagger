import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/map_grid_geometry.dart';
import 'package:peak_bagger/services/map_ruler_scale.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/widgets/route_marker.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';

import '../core/constants.dart';
import '../core/number_formatters.dart';
import '../theme.dart';

String mapTileUrl(Basemap basemap) {
  switch (basemap) {
    case Basemap.tracestrack:
      return 'https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=8bd67b17be9041b60f241c2aa45ecf0d';
    case Basemap.openstreetmap:
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    case Basemap.tasmapTopo:
      return 'https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/Topographic/MapServer/tile/{z}/{y}/{x}';
    case Basemap.tasmap50k:
      return 'https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/TasmapRaster/MapServer/tile/{z}/{y}/{x}';
    case Basemap.tasmap25k:
      return 'https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/Tasmap25K/MapServer/tile/{z}/{y}/{x}';
  }
}

Widget buildMapRectangle(TasmapRepository repo, Tasmap50k map) {
  final points = repo.getMapPolygonPoints(map);
  if (points.length < 4) {
    return const SizedBox.shrink();
  }

  return TasmapOutlineLayer(key: const Key('tasmap-layer'), points: points);
}

List<TasmapPolygonLabelEntry> buildSelectedMapLabelEntries(
  TasmapRepository repo,
  Tasmap50k map,
  double zoom,
  Color color,
) {
  if (zoom < 10) {
    return const [];
  }

  final points = repo.getMapPolygonPoints(map);
  if (points.length < 4) {
    return const [];
  }

  final label = formatTasmapPolygonLabel(map);
  if (label == null) {
    return const [];
  }

  return [TasmapPolygonLabelEntry(points: points, label: label, color: color)];
}

List<Polygon> buildAllMapRectangles(TasmapRepository repo) {
  final polygons = <Polygon>[];

  for (final map in repo.getAllMaps()) {
    final points = repo.getMapPolygonPoints(map);
    if (points.length < 4) {
      continue;
    }

    polygons.add(
      Polygon(
        points: points,
        color: Colors.transparent,
        borderColor: mapGridColour,
        borderStrokeWidth: MapConstants.mapGridBorderWidth,
      ),
    );
  }

  return polygons;
}

MapMgrsGridGeometry buildVisibleMgrsGridGeometry({
  required LatLngBounds visibleBounds,
  required double zoom,
  required double latitude,
}) {
  final rulerScale = selectMapRulerScale(zoom: zoom, latitude: latitude);
  final interval = mapMgrsGridIntervalForRulerMeters(rulerScale.distanceMeters);
  final metersPerPixel = mapMetersPerPixel(zoom: zoom, latitude: latitude);
  final verticalLabelInsetMeters =
      MapConstants.showMgrsGridBorderLabelBackground ||
          interval != MapMgrsGridInterval.oneKilometer
      ? 0.0
      : (MapConstants.mapMgrsGridBorderLabelHeight +
                MapConstants.mapMgrsGridBorderLabelTrimGap) *
            metersPerPixel;
  final horizontalLabelInsetMeters =
      MapConstants.showMgrsGridBorderLabelBackground ||
          interval != MapMgrsGridInterval.oneKilometer
      ? 0.0
      : (MapConstants.mapMgrsGridBorderLabelWidth +
                MapConstants.mapMgrsGridBorderLabelTrimGap) *
            metersPerPixel;
  final horizontalLabelRightInsetMeters =
      MapConstants.showMgrsGridBorderLabelBackground ||
          interval != MapMgrsGridInterval.oneKilometer
      ? 0.0
      : (MapConstants.mapMgrsGridBorderLabelRightInset +
                MapConstants.mapMgrsGridBorderLabelWidth +
                MapConstants.mapMgrsGridBorderLabelTrimGap) *
            metersPerPixel;
  final verticalLineRightInsetMeters =
      interval != MapMgrsGridInterval.oneKilometer
      ? 0.0
      : (MapConstants.mapMgrsGridBorderLabelRightInset +
                MapConstants.mapMgrsGridBorderLabelWidth +
                MapConstants.mapMgrsGridBorderLabelTrimGap) *
            metersPerPixel;
  return buildMapMgrsGridGeometry(
    visibleBounds: visibleBounds,
    interval: interval,
    verticalLabelInsetMeters: verticalLabelInsetMeters,
    verticalLineRightInsetMeters: verticalLineRightInsetMeters,
    horizontalLabelWestInsetMeters: horizontalLabelInsetMeters,
    horizontalLabelEastInsetMeters: horizontalLabelRightInsetMeters,
  );
}

PolylineLayer buildMgrsGridLayer(MapMgrsGridGeometry geometry) {
  return PolylineLayer(
    key: const Key('mgrs-grid-layer'),
    polylines: [
      for (final line in geometry.lines)
        Polyline(
          points: line,
          color: mapGridColour,
          strokeWidth: MapConstants.mapMgrsGridBorderWidth,
        ),
    ],
  );
}

class MapMgrsGridLabelLayer extends StatelessWidget {
  const MapMgrsGridLabelLayer({required this.labels, super.key});

  final List<MapGridBorderLabel> labels;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final widgets = <Widget>[];

    for (final label in labels) {
      final offset = camera.latLngToScreenOffset(label.anchor);
      if (!offset.dx.isFinite || !offset.dy.isFinite) {
        continue;
      }
      widgets.add(_MapMgrsGridBorderLabelWidget(label: label, offset: offset));
    }

    return MobileLayerTransformer(
      child: Stack(key: const Key('mgrs-grid-label-layer'), children: widgets),
    );
  }
}

class _MapMgrsGridBorderLabelWidget extends StatelessWidget {
  const _MapMgrsGridBorderLabelWidget({
    required this.label,
    required this.offset,
  });

  final MapGridBorderLabel label;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final left = switch (label.side) {
      MapGridLabelSide.left => 0.0,
      MapGridLabelSide.right => null,
      MapGridLabelSide.top || MapGridLabelSide.bottom =>
        offset.dx - MapConstants.mapMgrsGridBorderLabelWidth / 2,
    };
    final right = label.side == MapGridLabelSide.right
        ? MapConstants.mapMgrsGridBorderLabelRightInset
        : null;
    final top = switch (label.side) {
      MapGridLabelSide.top => 0.0,
      MapGridLabelSide.bottom => null,
      MapGridLabelSide.left || MapGridLabelSide.right =>
        offset.dy - MapConstants.mapMgrsGridBorderLabelHeight / 2,
    };
    final bottom = label.side == MapGridLabelSide.bottom ? 0.0 : null;

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MapConstants.showMgrsGridBorderLabelBackground
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              label.label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: mapGridColour,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<Marker> buildPeakMarkers({
  required List<Peak> peaks,
  required double zoom,
  required bool showPeakInfo,
  required Set<int> correlatedPeakIds,
  required SvgPicture tickedPeakMarker,
  required SvgPicture untickedPeakMarker,
  int? hoveredPeakId,
  bool suppressBelowZoom = true,
}) {
  if (suppressBelowZoom && zoom < 8) {
    return const [];
  }

  final untickedMarkers = <Marker>[];
  final tickedMarkers = <Marker>[];

  for (final peak in peaks) {
    final markerChild = correlatedPeakIds.contains(peak.osmId)
        ? tickedPeakMarker
        : untickedPeakMarker;
    final keyedMarkerChild = KeyedSubtree(
      key: Key('peak-marker-${peak.osmId}'),
      child: markerChild,
    );
    final isHovered = peak.osmId == hoveredPeakId;
    final marker = Marker(
      key: Key('peak-marker-hitbox-${peak.osmId}'),
      point: LatLng(peak.latitude, peak.longitude),
      width: isHovered ? 32 : 20,
      height: isHovered ? 32 : 20,
      child: _PeakMarkerContent(
        peak: peak,
        markerChild: keyedMarkerChild,
        hovered: isHovered,
        showPeakInfo: showPeakInfo && zoom >= MapConstants.peakInfoMinZoom,
      ),
    );
    if (correlatedPeakIds.contains(peak.osmId)) {
      tickedMarkers.add(marker);
    } else {
      untickedMarkers.add(marker);
    }
  }

  return [...untickedMarkers, ...tickedMarkers];
}

class _PeakMarkerContent extends StatelessWidget {
  const _PeakMarkerContent({
    required this.peak,
    required this.markerChild,
    required this.hovered,
    required this.showPeakInfo,
  });

  final Peak peak;
  final Widget markerChild;
  final bool hovered;
  final bool showPeakInfo;

  @override
  Widget build(BuildContext context) {
    final markerSize = hovered ? 32.0 : 20.0;
    final labelTop = markerSize;
    final labelWidth = peakMarkerLabelMaxWidth(context);

    return SizedBox(
      width: markerSize,
      height: markerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hovered)
            Stack(
              key: Key('peak-marker-hover-${peak.osmId}'),
              alignment: Alignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 3),
                  ),
                ),
                SizedBox.square(dimension: 20, child: markerChild),
              ],
            )
          else
            SizedBox.square(dimension: 20, child: markerChild),
          if (showPeakInfo)
            Positioned(
              top: labelTop,
              left: (markerSize - labelWidth) / 2,
              width: labelWidth,
              child: _PeakMarkerLabels(peak: peak),
            ),
        ],
      ),
    );
  }
}

class _PeakMarkerLabels extends StatelessWidget {
  const _PeakMarkerLabels({required this.peak});

  final Peak peak;

  @override
  Widget build(BuildContext context) {
    final maxWidth = peakMarkerLabelMaxWidth(context);
    final name = peak.name.trim().isEmpty ? '—' : peak.name.trim();
    final height = peak.elevation == null
        ? '—'
        : formatElevation(peak.elevation!.round(), showUnits: false);
    final labelStyle = peakMarkerLabelTextStyle(context);

    return ConstrainedBox(
      key: Key('peak-marker-labels-${peak.osmId}'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OutlinedText(
            key: Key('peak-marker-name-${peak.osmId}'),
            text: name,
            style: labelStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          OutlinedText(
            key: Key('peak-marker-height-${peak.osmId}'),
            text: height,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

List<TasmapPolygonLabelEntry> buildOverlayLabelEntries(
  TasmapRepository repo,
  double zoom,
  Color color,
) {
  if (zoom < 10) {
    return const [];
  }

  final entries = <TasmapPolygonLabelEntry>[];
  for (final map in repo.getAllMaps()) {
    final points = repo.getMapPolygonPoints(map);
    if (points.length < 4) {
      continue;
    }

    final label = formatTasmapPolygonLabel(map);
    if (label == null) {
      continue;
    }

    entries.add(
      TasmapPolygonLabelEntry(points: points, label: label, color: color),
    );
  }

  return entries;
}

PolylineLayer buildDraftRoutePolylines({
  required List<LatLng> committedPoints,
  required List<LatLng> provisionalPoints,
  required int colour,
}) {
  final polylines = <Polyline>[];

  if (committedPoints.length >= 2) {
    polylines.add(
      Polyline(
        points: committedPoints,
        color: Color(colour),
        strokeWidth: RouteUI.width,
      ),
    );
  }

  if (provisionalPoints.length >= 2) {
    polylines.add(
      Polyline(
        points: provisionalPoints,
        color: Color(colour),
        strokeWidth: RouteUI.width,
      ),
    );
  }

  return PolylineLayer(
    key: const Key('route-draft-polyline-layer'),
    polylines: polylines,
  );
}

List<Marker> buildRouteDraftMarkers({
  required List<RouteDraftDisplayMarker> markers,
  required int colour,
  String? hoveredMarkerId,
  int? hoveredSegmentIndex,
  LatLng? hoveredSegmentPoint,
  ValueChanged<String>? onHoverEnter,
  ValueChanged<String>? onHoverExit,
  ValueChanged<String>? onPointerDown,
  void Function(String, Offset delta)? onPointerMove,
  ValueChanged<String>? onPointerUp,
  ValueChanged<String>? onTap,
  ValueChanged<String>? onPanStart,
  void Function(String, Offset delta)? onPanUpdate,
  ValueChanged<String>? onPanEnd,
}) {
  final routeMarkers = <Marker>[
    for (final marker in markers)
      Marker(
        key: Key('route-draft-marker-${marker.id}'),
        point: marker.point,
        width: _routeDraftMarkerSize(marker.kind, marker.id == hoveredMarkerId),
        height: _routeDraftMarkerSize(
          marker.kind,
          marker.id == hoveredMarkerId,
        ),
        child: _RouteDraftMarkerHoverTarget(
          marker: marker,
          color: Color(colour),
          hovered: marker.id == hoveredMarkerId,
          onHoverEnter: onHoverEnter,
          onHoverExit: onHoverExit,
          onPointerDown: onPointerDown,
          onPointerMove: onPointerMove,
          onPointerUp: onPointerUp,
          onTap: onTap,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
        ),
      ),
  ];

  if (hoveredSegmentIndex != null && hoveredSegmentPoint != null) {
    routeMarkers.add(
      Marker(
        key: Key('route-draft-segment-hover-$hoveredSegmentIndex'),
        point: hoveredSegmentPoint,
        width: RouteUI.markerNumberedSize,
        height: RouteUI.markerNumberedSize,
        child: RouteMarker(
          kind: RouteMarkerKind.circle,
          color: Color(colour),
          size: RouteUI.markerNumberedSize,
          strokeWidth: RouteUI.strokeWidth,
        ),
      ),
    );
  }

  return routeMarkers;
}

double _routeDraftMarkerSize(RouteMarkerKind kind, bool hovered) {
  final baseSize = switch (kind) {
    RouteMarkerKind.numbered => RouteUI.markerNumberedSize,
    RouteMarkerKind.circle || RouteMarkerKind.target => RouteUI.markerSize,
  };
  return hovered ? baseSize * RouteUI.markerZoom : baseSize;
}

class _RouteDraftMarkerHoverTarget extends StatelessWidget {
  const _RouteDraftMarkerHoverTarget({
    required this.marker,
    required this.color,
    required this.hovered,
    this.onHoverEnter,
    this.onHoverExit,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final RouteDraftDisplayMarker marker;
  final Color color;
  final bool hovered;
  final ValueChanged<String>? onHoverEnter;
  final ValueChanged<String>? onHoverExit;
  final ValueChanged<String>? onPointerDown;
  final void Function(String, Offset delta)? onPointerMove;
  final ValueChanged<String>? onPointerUp;
  final ValueChanged<String>? onTap;
  final ValueChanged<String>? onPanStart;
  final void Function(String, Offset delta)? onPanUpdate;
  final ValueChanged<String>? onPanEnd;

  @override
  Widget build(BuildContext context) {
    final markerSize = _routeDraftMarkerSize(marker.kind, hovered);
    final markerWidget = RouteMarker(
      kind: marker.kind,
      color: color,
      number: marker.number,
      size: markerSize,
      strokeWidth: RouteUI.strokeWidth,
    );

    return MouseRegion(
      key: Key('route-draft-marker-hitbox-${marker.id}'),
      onEnter: onHoverEnter == null ? null : (_) => onHoverEnter!(marker.id),
      onExit: onHoverExit == null ? null : (_) => onHoverExit!(marker.id),
      child: Listener(
        onPointerDown: onPointerDown == null
            ? null
            : (_) => onPointerDown!(marker.id),
        onPointerMove: onPointerMove == null
            ? null
            : (event) => onPointerMove!(marker.id, event.delta),
        onPointerUp: onPointerUp == null
            ? null
            : (_) => onPointerUp!(marker.id),
        onPointerCancel: onPointerUp == null
            ? null
            : (_) => onPointerUp!(marker.id),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null ? null : () => onTap!(marker.id),
          onPanStart: onPanStart == null ? null : (_) => onPanStart!(marker.id),
          onPanUpdate: onPanUpdate == null
              ? null
              : (details) => onPanUpdate!(marker.id, details.delta),
          onPanEnd: onPanEnd == null ? null : (_) => onPanEnd!(marker.id),
          onPanCancel: onPanEnd == null ? null : () => onPanEnd!(marker.id),
          child: SizedBox.square(
            dimension: markerSize,
            child: hovered
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        key: Key('route-draft-marker-hover-${marker.id}'),
                        width: RouteUI.markerNumberedSize,
                        height: RouteUI.markerNumberedSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color,
                            width: RouteUI.strokeWidth,
                          ),
                        ),
                      ),
                      markerWidget,
                    ],
                  )
                : markerWidget,
          ),
        ),
      ),
    );
  }
}

PolylineLayer buildRoutePolylines(List<app_route.Route> routes, double zoom) {
  final polylines = <Polyline>[];
  final displayZoom = zoom.round().clamp(
    MapConstants.trackMinZoom,
    MapConstants.trackMaxZoom,
  );

  for (final route in routes) {
    try {
      for (final segment in route.getSegmentsForZoom(displayZoom)) {
        if (segment.isEmpty) {
          continue;
        }
        polylines.add(
          Polyline(
            points: segment,
            color: Color(route.colour),
            strokeWidth: RouteUI.width,
          ),
        );
      }
    } catch (_) {
      if (route.gpxRoute.isEmpty) {
        continue;
      }
      polylines.add(
        Polyline(
          points: route.gpxRoute,
          color: Color(route.colour),
          strokeWidth: RouteUI.width,
        ),
      );
    }
  }

  return PolylineLayer(polylines: polylines);
}

PolylineLayer buildTrackPolylines(
  List<GpxTrack> tracks,
  double zoom, {
  int? selectedTrackId,
}) {
  final polylines = <Polyline>[];
  final selectedBasePolylines = <Polyline>[];
  final selectedOverlayPolylines = <Polyline>[];
  final displayZoom = zoom.round().clamp(
    MapConstants.peakMinZoom,
    MapConstants.peakMaxZoom,
  );

  for (final track in tracks) {
    final isSelected = track.gpxTrackId == selectedTrackId;
    final color = Color(track.trackColour);
    final trackColor = selectedTrackId == null || isSelected
        ? color
        : color.withValues(alpha: 0.6);
    try {
      for (final segment in track.getSegmentsForZoom(displayZoom)) {
        if (segment.isEmpty) continue;
        if (isSelected) {
          selectedBasePolylines.add(
            Polyline(
              points: segment,
              color: trackColor,
              strokeWidth: 4.0,
              borderStrokeWidth: 2.0,
              borderColor: const Color(0x66000000),
            ),
          );
          selectedOverlayPolylines.add(
            Polyline(points: segment, color: Colors.white, strokeWidth: 0.6),
          );
        } else {
          polylines.add(
            Polyline(points: segment, color: trackColor, strokeWidth: 3.0),
          );
        }
      }
    } catch (_) {
      continue;
    }
  }

  return PolylineLayer(
    polylines: [
      ...polylines,
      ...selectedBasePolylines,
      ...selectedOverlayPolylines,
    ],
  );
}

PolylineLayer buildTrailPolylines(List<Polyline> polylines) {
  return PolylineLayer(
    key: const Key('trail-polyline-layer'),
    polylines: polylines,
  );
}
