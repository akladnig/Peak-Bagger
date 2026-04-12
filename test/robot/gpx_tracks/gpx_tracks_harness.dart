import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/main.dart' as app_main;
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/gpx_importer.dart';

class GpxTracksHarness {
  GpxTracksHarness({
    required this.container,
    required this.storeDir,
    required this.tracksDir,
    required this.tasmaniaDir,
  });

  final ProviderContainer container;
  final Directory storeDir;
  final Directory tracksDir;
  final Directory tasmaniaDir;

  static Future<GpxTracksHarness> create() async {
    final root = await Directory.systemTemp.createTemp('gpx-tracks-harness');
    final storeDir = Directory('${root.path}/store')..createSync();
    final tracksDir = Directory('${root.path}/Tracks')..createSync();
    final tasmaniaDir = Directory('${tracksDir.path}/Tasmania')..createSync();

    await File('${tracksDir.path}/tas-track.gpx').writeAsString(_tasmanianGpx);

    GpxImporter.debugTracksFolderOverride = tracksDir.path;
    GpxImporter.debugTasmaniaFolderOverride = tasmaniaDir.path;

    app_main.objectboxStore = await openStore(directory: storeDir.path);

    final container = ProviderContainer();
    return GpxTracksHarness(
      container: container,
      storeDir: storeDir,
      tracksDir: tracksDir,
      tasmaniaDir: tasmaniaDir,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    GpxImporter.debugTracksFolderOverride = null;
    GpxImporter.debugTasmaniaFolderOverride = null;
    app_main.objectboxStore.close();
    final root = storeDir.parent;
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}

const _tasmanianGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Mt Anne</name>
    <trkseg>
      <trkpt lat="-42.1234" lon="146.1234">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.2234" lon="146.2234">
        <time>2024-01-15T09:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
