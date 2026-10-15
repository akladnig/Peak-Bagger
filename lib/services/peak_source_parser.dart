import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'peak_mgrs_converter.dart';

/// The importer's pure source parser, shared by background source validation.
({List<Peak> peaks, int skippedPeakCount}) parsePeakSource(
  String source, {
  required String regionKey,
  required String path,
  PeakMgrsComponents Function(LatLng)? mgrsConverter,
}) {
  final decoded = jsonDecode(source);
  if (decoded is! Map || decoded['elements'] is! List) {
    throw const FormatException('Peak source must contain an elements list.');
  }
  final peaks = <Peak>[];
  var skipped = 0;
  for (final element in decoded['elements'] as List) {
    if (element is! Map) {
      throw const FormatException('Peak source elements must be objects.');
    }
    final value = Map<String, dynamic>.from(element);
    final tags = value['tags'];
    if (value['type'] != 'node' || tags is! Map || tags['natural'] != 'peak') {
      skipped++;
      continue;
    }
    final id = value['id'];
    final name = tags['name'];
    final lat = value['lat'];
    final lon = value['lon'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw FormatException('Invalid peak record in $path.');
    }
    final elevation = tags['ele'];
    final parsedElevation = elevation is num
        ? elevation.toDouble()
        : elevation is String
        ? double.tryParse(elevation.trim())
        : null;
    late PeakMgrsComponents components;
    try {
      components = (mgrsConverter ?? PeakMgrsConverter.fromLatLng)(
        LatLng(lat.toDouble(), lon.toDouble()),
      );
    } on Object {
      throw FormatException('Unable to derive MGRS fields in $path.');
    }
    peaks.add(
      Peak(
        osmId: id,
        name: name.trim(),
        elevation: parsedElevation?.isFinite == true ? parsedElevation : null,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
        region: regionKey,
        sourceOfTruth: Peak.sourceOfTruthOsm,
        gridZoneDesignator: components.gridZoneDesignator,
        mgrs100kId: components.mgrs100kId,
        easting: components.easting,
        northing: components.northing,
      ),
    );
  }
  return (peaks: peaks, skippedPeakCount: skipped);
}
