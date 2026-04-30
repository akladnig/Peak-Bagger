import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_peak_overpass_service.dart';
import '../../harness/test_tasmap_repository.dart';

void main() {
  test('importing a single correlated track ticks the peak marker', () async {
    SharedPreferences.setMockInitialValues({});

    final homeRoot = Directory(
      Platform.environment['HOME'] ?? Directory.current.path,
    );
    final importDir = Directory(
      '${homeRoot.path}/Documents/Bushwalking/Tracks/Tasmania',
    )..createSync(recursive: true);
    final gpxFile = File('${importDir.path}/single-track-import.gpx');
    gpxFile.writeAsStringSync(_correlatedTrackGpx);

    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    );
    final tasmapRepository = await TestTasmapRepository.create();
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: peakRepository,
            overpassService: TestPeakOverpassService(peaks: [peak]),
            gpxTrackRepository: TestWritableGpxTrackRepository(),
            peaksBaggedRepository: peaksBaggedRepository,
            tasmapRepository: tasmapRepository,
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final mapNotifier = container.read(mapProvider.notifier);
    await mapNotifier.reloadPeakMarkers();
    await mapNotifier.importGpxFiles(
      pathToEditedNames: {gpxFile.path: 'Correlated Track'},
    );

    expect(mapNotifier.state.tracks, hasLength(1));
    expect(mapNotifier.correlatedPeakIds, contains(6406));
  });
}

class TestWritableGpxTrackRepository extends GpxTrackRepository {
  TestWritableGpxTrackRepository() : super.test(InMemoryGpxTrackStorage());

  final List<GpxTrack> _tracks = [];
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

const _correlatedTrackGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Correlated Track</name>
    <trkseg>
      <trkpt lat="-43.0" lon="147.0"><time>2024-01-15T08:00:00Z</time></trkpt>
      <trkpt lat="-43.0" lon="147.01"><time>2024-01-15T09:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
