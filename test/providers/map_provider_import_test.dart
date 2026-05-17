import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('import selects the newly added track and bumps focus', () async {
    SharedPreferences.setMockInitialValues({});
    final homeRoot = Directory(
      Platform.environment['HOME'] ?? Directory.current.path,
    );
    final importDir = Directory(
      '${homeRoot.path}/Documents/Bushwalking/Tracks/Tasmania',
    )..createSync(recursive: true);
    final gpxFile = File('${importDir.path}/selected-track-import.gpx')
      ..writeAsStringSync(_tasmanianTrackGpx);

    final tasmapRepository = await TestTasmapRepository.create();
    final repository = TestWritableGpxTrackRepository();
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: repository,
            peaksBaggedRepository: PeaksBaggedRepository.test(
              InMemoryPeaksBaggedStorage(),
            ),
            migrationMarkerStore: const MigrationMarkerStore(),
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    final focusSerialBefore = notifier.state.selectedTrackFocusSerial;

    final result = await notifier.importGpxFiles(
      pathToEditedNames: {gpxFile.path: 'Selected Track'},
    );

    expect(result.addedCount, 1);
    expect(notifier.state.tracks, hasLength(1));
    expect(notifier.state.showTracks, isTrue);
    expect(notifier.state.selectedTrackId, result.items.first.track.gpxTrackId);
    expect(
      notifier.state.selectedTrackFocusSerial,
      focusSerialBefore + 1,
    );
  });

  test('non-added import keeps the current selected track', () async {
    SharedPreferences.setMockInitialValues({});

    final existingTrack = GpxTrack(
      gpxTrackId: 7,
      contentHash: 'hash-7',
      trackName: 'Track 7',
      gpxFile: '<gpx></gpx>',
    );
    final repository = TestWritableGpxTrackRepository([existingTrack]);
    final tasmapRepository = await TestTasmapRepository.create();
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: repository,
            peaksBaggedRepository: PeaksBaggedRepository.test(
              InMemoryPeaksBaggedStorage(),
            ),
            migrationMarkerStore: const MigrationMarkerStore(),
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [existingTrack],
      selectedTrackId: 7,
    );
    final focusSerialBefore = notifier.state.selectedTrackFocusSerial;
    final importDir = Directory.systemTemp.createTempSync('gpx-import-noop');
    addTearDown(() => importDir.deleteSync(recursive: true));
    final gpxFile = File('${importDir.path}/outside-tasmania.gpx')
      ..writeAsStringSync(_nonTasmanianTrackGpx);

    final result = await notifier.importGpxFiles(
      pathToEditedNames: {gpxFile.path: 'Outside Tasmania'},
    );

    expect(result.addedCount, 0);
    expect(notifier.state.tracks, hasLength(1));
    expect(notifier.state.selectedTrackId, 7);
    expect(notifier.state.selectedTrackFocusSerial, focusSerialBefore);
  });
}

class TestWritableGpxTrackRepository extends GpxTrackRepository {
  TestWritableGpxTrackRepository([List<GpxTrack> tracks = const []])
      : _tracks = List<GpxTrack>.from(tracks),
        super.test(InMemoryGpxTrackStorage());

  final List<GpxTrack> _tracks;
  int _nextTrackId = 1;

  @override
  int putTrack(GpxTrack track) {
    if (track.gpxTrackId == 0) {
      track.gpxTrackId = _nextTrackId++;
    } else if (track.gpxTrackId >= _nextTrackId) {
      _nextTrackId = track.gpxTrackId + 1;
    }

    _tracks.removeWhere((existing) => existing.gpxTrackId == track.gpxTrackId);
    _tracks.add(track);
    return track.gpxTrackId;
  }

  @override
  List<GpxTrack> getAllTracks() {
    return List<GpxTrack>.unmodifiable(_tracks);
  }

  @override
  void deleteAll() {
    _tracks.clear();
  }

  @override
  int replaceTrack({required GpxTrack existing, required GpxTrack replacement}) {
    replacement.gpxTrackId = existing.gpxTrackId;
    _tracks
      ..removeWhere((track) => track.gpxTrackId == existing.gpxTrackId)
      ..add(replacement);
    return replacement.gpxTrackId;
  }

  @override
  bool deleteTrack(int id) {
    final previousLength = _tracks.length;
    _tracks.removeWhere((track) => track.gpxTrackId == id);
    return _tracks.length != previousLength;
  }
}

const _tasmanianTrackGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Selected Track</name>
    <trkseg>
      <trkpt lat="-43.0" lon="147.0"><time>2024-01-15T08:00:00Z</time></trkpt>
      <trkpt lat="-43.0" lon="147.01"><time>2024-01-15T09:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';

const _nonTasmanianTrackGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Outside Tasmania</name>
    <trkseg>
      <trkpt lat="-30.0" lon="150.0"><time>2024-01-15T08:00:00Z</time></trkpt>
      <trkpt lat="-30.1" lon="150.1"><time>2024-01-15T09:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
