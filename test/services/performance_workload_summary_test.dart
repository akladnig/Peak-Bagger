import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/performance_workload_summary.dart';

void main() {
  test('workload can summarize the actual ObjectBox model read-only', () async {
    final directory = await Directory.systemTemp.createTemp('workload-test');
    final store = await openStore(directory: directory.path);
    addTearDown(() {
      store.close();
      directory.deleteSync(recursive: true);
    });
    SharedPreferences.setMockInitialValues({});
    final summary = capturePerformanceWorkload(
      store,
      await SharedPreferences.getInstance(),
    );
    expect((summary['record_counts'] as Map)['PeakListItemEntity'], 0);
    expect(store.box<GpxTrack>().count(), 0);
  });
  test('track workload exposes vertex counts but no personal content', () {
    final track = GpxTrack(
      contentHash: 'private',
      trackName: 'private walk',
      gpxFile:
          '<gpx><trk><trkseg><trkpt lat="-42" lon="146"/><trkpt lat="-43" lon="147"/></trkseg></trk></gpx>',
      displayTrackPointsByZoom:
          '{"10":[[[-42,146],[-43,147]]],"11":[[[-42,146]]]}',
    );
    final summary = summarizeTrackGeometry([track]);
    expect(summary['gpx_vertices'], 2);
    expect(summary['display_vertices_by_zoom'], {'10': 2, '11': 1});
    expect('$summary', isNot(contains('private')));
    expect('$summary', isNot(contains('-42')));
  });
}
