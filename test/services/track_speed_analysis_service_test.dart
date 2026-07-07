import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/track_speed_analysis_service.dart';

void main() {
  test(
    'analyze builds ordered aggregate sections from filtered repaired and raw tracks',
    () {
      final pathStart = const LatLng(-43.0, 146.0);
      final pathEnd = _moveEast(pathStart, 100);
      final roadStart = const LatLng(-42.0, 147.0);
      final roadEnd = _moveEast(roadStart, 200);
      final offTrackStart = const LatLng(-41.0, 148.0);
      final offTrackEnd = _moveEast(offTrackStart, 100);

      final service = _service(
        tracks: [
          GpxTrack(
            contentHash: 'filtered-track',
            trackName: 'Filtered Track',
            gpxFile: _gpx([
              _point(pathStart, 100, DateTime.utc(2024, 1, 1, 8, 0, 0)),
              _point(_moveEast(pathStart, 40), 100, DateTime.utc(2024, 1, 1, 8, 1, 0)),
            ]),
            filteredTrack: _gpx([
              _point(const LatLng(-44.1, 146.0), 80, DateTime.utc(2024, 1, 1, 7, 50, 0)),
              _point(pathStart, 100, DateTime.utc(2024, 1, 1, 8, 0, 0)),
              _point(pathEnd, 130, DateTime.utc(2024, 1, 1, 8, 1, 0)),
              _point(pathEnd, 130, DateTime.utc(2024, 1, 1, 8, 1, 30)),
            ]),
          ),
          GpxTrack(
            contentHash: 'repaired-track',
            trackName: 'Repaired Track',
            gpxFile: _gpx([
              _point(roadStart, 150, DateTime.utc(2024, 1, 1, 9, 0, 0)),
              _point(_moveEast(roadStart, 40), 140, DateTime.utc(2024, 1, 1, 9, 2, 0)),
            ]),
            gpxFileRepaired: _gpx([
              _point(roadStart, 150, DateTime.utc(2024, 1, 1, 9, 0, 0)),
              _point(roadEnd, 120, DateTime.utc(2024, 1, 1, 9, 2, 0)),
            ]),
          ),
          GpxTrack(
            contentHash: 'raw-track',
            trackName: 'Raw Track',
            gpxFile: _gpx([
              _point(offTrackStart, null, DateTime.utc(2024, 1, 1, 10, 0, 0)),
              _point(offTrackEnd, null, DateTime.utc(2024, 1, 1, 10, 1, 40)),
            ]),
          ),
          GpxTrack(
            contentHash: 'invalid-track',
            trackName: 'Invalid Track',
            gpxFile: _gpx([
              _point(const LatLng(-43.2, 146.2), 100, null),
              _point(const LatLng(-43.21, 146.21), 110, null),
            ]),
          ),
        ],
        chunks: [
          _chunk(
            chunkKey: '0_0',
            payloadJson: _payload([
              _node(1, pathStart),
              _node(2, pathEnd),
              _way(10, [1, 2], {'highway': 'path', 'sac_scale': ' Mountain_Hiking '}),
              _node(3, roadStart),
              _node(4, roadEnd),
              _way(11, [3, 4], {'highway': 'service', 'trail_visibility': 'Intermediate'}),
            ]),
          ),
        ],
        wayIndexRows: [
          _wayIndexRow(
            chunkKey: '0_0',
            osmWayId: 10,
            highway: 'path',
            tagsJson: '{"highway":"path","sac_scale":" Mountain_Hiking "}',
          ),
          _wayIndexRow(
            chunkKey: '0_0',
            osmWayId: 11,
            highway: 'service',
            tagsJson: '{"highway":"service","trail_visibility":"Intermediate"}',
          ),
        ],
      );

      final report = service.analyze();

      expect(
        report.sections.map((section) => section.kind),
        [
          TrackSpeedAnalysisSectionKind.trackType,
          TrackSpeedAnalysisSectionKind.hikingDifficulty,
          TrackSpeedAnalysisSectionKind.trackTypeAndHikingDifficulty,
          TrackSpeedAnalysisSectionKind.gradientBand,
        ],
      );

      final trackTypeRows = report.sections[0].rows;
      expect(trackTypeRows.map((row) => row.label), ['path', 'road', 'off-track']);
      expect(trackTypeRows.map((row) => row.sampleCount), [1, 1, 1]);

      final hikingRows = report.sections[1].rows;
      expect(
        hikingRows.map((row) => (row.hikingDifficultyFamily, row.hikingDifficultyValue)),
        [
          ('sac_scale', 'mountain_hiking'),
          ('trail_visibility', 'intermediate'),
          ('off-track', 'off-track'),
        ],
      );

      final combinedRows = report.sections[2].rows;
      expect(combinedRows.map((row) => row.trackType), ['path', 'road', 'off-track']);
      expect(
        combinedRows.map((row) => (row.hikingDifficultyFamily, row.hikingDifficultyValue)),
        [
          ('sac_scale', 'mountain_hiking'),
          ('trail_visibility', 'intermediate'),
          ('off-track', 'off-track'),
        ],
      );

      final gradientRows = report.sections[3].rows;
      expect(
        gradientRows.map((row) => row.label),
        ['-20% to -10%', '>= +20%', 'gradient unknown'],
      );

      final expectedPathDistance = const Distance().as(
        LengthUnit.Meter,
        pathStart,
        pathEnd,
      );
      final expectedRoadDistance = const Distance().as(
        LengthUnit.Meter,
        roadStart,
        roadEnd,
      );
      final expectedOffTrackDistance = const Distance().as(
        LengthUnit.Meter,
        offTrackStart,
        offTrackEnd,
      );

      expect(trackTypeRows[0].medianSpeedKmh, closeTo(expectedPathDistance * 3600 / 60000, 0.001));
      expect(trackTypeRows[0].totalMovingDistanceMeters, closeTo(expectedPathDistance, 0.001));
      expect(trackTypeRows[0].totalMovingTime, const Duration(minutes: 1));
      expect(trackTypeRows[1].medianSpeedKmh, closeTo(expectedRoadDistance * 3600 / 120000, 0.001));
      expect(trackTypeRows[1].totalMovingDistanceMeters, closeTo(expectedRoadDistance, 0.001));
      expect(trackTypeRows[1].totalMovingTime, const Duration(minutes: 2));
      expect(trackTypeRows[2].medianSpeedKmh, closeTo(expectedOffTrackDistance * 3600 / 100000, 0.001));
      expect(trackTypeRows[2].totalMovingDistanceMeters, closeTo(expectedOffTrackDistance, 0.001));
      expect(trackTypeRows[2].totalMovingTime, const Duration(minutes: 1, seconds: 40));
    },
  );

  test('analyze falls back when filtered track is not usable and groups matched unknown difficulty', () {
    final stepsStart = const LatLng(-42.5, 146.5);
    final stepsEnd = _moveEast(stepsStart, 80);

    final service = _service(
      tracks: [
        GpxTrack(
          contentHash: 'fallback-track',
          trackName: 'Fallback Track',
          gpxFile: _gpx([
            _point(const LatLng(-41.2, 148.2), 50, DateTime.utc(2024, 1, 2, 9, 0, 0)),
            _point(const LatLng(-41.2, 148.2005), 50, DateTime.utc(2024, 1, 2, 9, 1, 0)),
          ]),
          filteredTrack: '<gpx><trk><trkseg><trkpt lat="-42.0" lon="146.0"></trkseg></trk></gpx>',
          gpxFileRepaired: _gpx([
            _point(stepsStart, 100, DateTime.utc(2024, 1, 2, 9, 0, 0)),
            _point(stepsEnd, 100, DateTime.utc(2024, 1, 2, 9, 1, 0)),
          ]),
        ),
      ],
      chunks: [
        _chunk(
          chunkKey: '0_0',
          payloadJson: _payload([
            _node(1, stepsStart),
            _node(2, stepsEnd),
            _way(12, [1, 2], {'highway': 'steps'}),
          ]),
        ),
      ],
      wayIndexRows: [
        _wayIndexRow(
          chunkKey: '0_0',
          osmWayId: 12,
          highway: 'steps',
          tagsJson: '{"highway":"steps"}',
        ),
      ],
    );

    final report = service.analyze();

    expect(report.sections[0].rows.map((row) => row.label), ['steps']);
    expect(
      report.sections[1].rows.map((row) => (row.hikingDifficultyFamily, row.hikingDifficultyValue)),
      [('unknown', 'unknown')],
    );
    expect(report.sections[2].rows.single.trackType, 'steps');
    expect(report.sections[3].rows.map((row) => row.label), ['-5% to +5%']);
  });

  test('analyzeWithProgress reports per-track progress', () async {
    final service = _service(
      tracks: [
        GpxTrack(
          contentHash: 'progress-track',
          trackName: 'Progress Track',
          gpxFile: _gpx([
            _point(const LatLng(-42.5, 146.5), 100, DateTime.utc(2024, 1, 2, 9, 0, 0)),
            _point(const LatLng(-42.5, 146.501), 110, DateTime.utc(2024, 1, 2, 9, 1, 0)),
          ]),
        ),
      ],
      chunks: const [],
      wayIndexRows: const [],
    );

    final seen = <(int, int)>[];
    await service.analyzeWithProgress(
      onProgress: (progress) {
        seen.add((progress.processedTracks, progress.totalTracks));
      },
    );

    expect(seen, [(0, 1), (1, 1)]);
  });
}

TrackSpeedAnalysisService _service({
  required List<GpxTrack> tracks,
  required List<RouteGraphChunk> chunks,
  required List<RouteGraphWayIndex> wayIndexRows,
}) {
  return TrackSpeedAnalysisService(
    gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage(tracks)),
    routeGraphQueryService: RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            activeGeneration: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
          chunks: chunks,
          wayIndexRows: wayIndexRows,
        ),
      ),
    ),
  );
}

RouteGraphChunk _chunk({required String chunkKey, required String payloadJson}) {
  return RouteGraphChunk(
    recordKey: '1|$chunkKey',
    chunkKey: chunkKey,
    generation: 1,
    minLat: -44.0,
    minLon: 143.0,
    maxLat: -39.0,
    maxLon: 149.0,
    elementCount: 0,
    payloadJson: payloadJson,
  );
}

RouteGraphWayIndex _wayIndexRow({
  required String chunkKey,
  required int osmWayId,
  required String? highway,
  required String tagsJson,
}) {
  return RouteGraphWayIndex(
    recordKey: '1|$chunkKey|$osmWayId',
    generation: 1,
    chunkKey: chunkKey,
    osmWayId: osmWayId,
    highway: highway,
    lengthMeters: 100,
    tagCount: 1,
    tagsJson: tagsJson,
  );
}

Map<String, Object?> _node(int id, LatLng point) {
  return {'type': 'node', 'id': id, 'lat': point.latitude, 'lon': point.longitude};
}

Map<String, Object?> _way(int id, List<int> nodes, Map<String, Object?> tags) {
  return {'type': 'way', 'id': id, 'nodes': nodes, 'tags': tags};
}

String _payload(List<Map<String, Object?>> elements) {
  final pieces = elements.map((element) {
    final entries = element.entries.map((entry) {
      final value = entry.value;
      if (value is String) {
        return '"${entry.key}":"$value"';
      }
      if (value is List<int>) {
        return '"${entry.key}":[${value.join(',')}]';
      }
      if (value is Map<String, Object?>) {
        final tagEntries = value.entries
            .map((tag) => '"${tag.key}":"${tag.value}"')
            .join(',');
        return '"${entry.key}":{$tagEntries}';
      }
      return '"${entry.key}":$value';
    }).join(',');
    return '{$entries}';
  }).join(',');
  return '{"elements":[$pieces]}';
}

String _gpx(List<_GpxPoint> points) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="test">')
    ..writeln('  <trk>')
    ..writeln('    <name>Test Track</name>')
    ..writeln('    <trkseg>');
  for (final point in points) {
    buffer.writeln(
      '      <trkpt lat="${point.location.latitude}" lon="${point.location.longitude}">',
    );
    if (point.elevation != null) {
      buffer.writeln('        <ele>${point.elevation}</ele>');
    }
    if (point.time != null) {
      buffer.writeln('        <time>${point.time!.toIso8601String()}</time>');
    }
    buffer.writeln('      </trkpt>');
  }
  buffer
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return buffer.toString();
}

_GpxPoint _point(LatLng location, double? elevation, DateTime? time) {
  return _GpxPoint(location: location, elevation: elevation, time: time);
}

LatLng _moveEast(LatLng origin, double meters) {
  final latRadians = origin.latitude * math.pi / 180;
  final lonDelta = meters / (111320 * math.cos(latRadians));
  return LatLng(origin.latitude, origin.longitude + lonDelta);
}

class _GpxPoint {
  const _GpxPoint({
    required this.location,
    required this.elevation,
    required this.time,
  });

  final LatLng location;
  final double? elevation;
  final DateTime? time;
}
