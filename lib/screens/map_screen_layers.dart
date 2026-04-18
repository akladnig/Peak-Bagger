import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';

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
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      ),
    );
  }

  return polygons;
}

List<Marker> buildPeakMarkers({
  required List<Peak> peaks,
  required double zoom,
  required Set<int> correlatedPeakIds,
  required SvgPicture tickedPeakMarker,
  required SvgPicture untickedPeakMarker,
}) {
  if (zoom < 9) {
    return const [];
  }

  return peaks
      .map((peak) {
        final child = correlatedPeakIds.contains(peak.osmId)
            ? tickedPeakMarker
            : untickedPeakMarker;

        return Marker(
          point: LatLng(peak.latitude, peak.longitude),
          width: 20,
          height: 20,
          child: child,
        );
      })
      .toList(growable: false);
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

PolylineLayer buildTrackPolylines(
  List<GpxTrack> tracks,
  double zoom, {
  int? selectedTrackId,
}) {
  final polylines = <Polyline>[];
  final selectedBasePolylines = <Polyline>[];
  final selectedOverlayPolylines = <Polyline>[];
  final displayZoom = zoom.round().clamp(6, 18);

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
