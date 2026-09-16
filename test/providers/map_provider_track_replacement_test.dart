import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_managed_file_operations.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_replacement_recovery_issue_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'replaces a unique canonical match while retaining its display identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      final existing = _existingTrack();
      final repository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([existing]),
      );
      final operations = _FakeManagedFileOperations();
      final file = _incomingFile('replacement-success');
      addTearDown(() => file.parent.deleteSync(recursive: true));
      final notifier = await _notifier(
        repository: repository,
        operations: operations,
      );

      final result = await notifier.importGpxFiles(
        pathToEditedNames: {file.path: 'Mount Anne'},
      );

      expect(result.addedCount, 0);
      expect(result.replacedCount, 1);
      expect(result.errorCount, 0);
      expect(result.items.single.track.gpxTrackId, 7);
      expect(result.items.single.track.visible, isFalse);
      expect(result.items.single.track.trackColour, 0xFF123456);
      expect(notifier.state.selectedTrackId, 7);
      expect(operations.calls, ['resolve', 'backup', 'move', 'cleanup']);
    },
  );

  test(
    'restores files and leaves the stored Track unchanged on move failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      final existing = _existingTrack();
      final repository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([existing]),
      );
      final operations = _FakeManagedFileOperations(failMove: true);
      final file = _incomingFile('replacement-move-failure');
      addTearDown(() => file.parent.deleteSync(recursive: true));
      final notifier = await _notifier(
        repository: repository,
        operations: operations,
      );

      final result = await notifier.importGpxFiles(
        pathToEditedNames: {file.path: 'Mount Anne'},
      );

      expect(result.replacedCount, 0);
      expect(result.errorCount, 1);
      expect(
        result.errors.single.reason,
        'Cannot replace Track because the incoming managed file could not be moved.',
      );
      expect(repository.findById(7)!.contentHash, 'old');
      expect(operations.calls, [
        'resolve',
        'backup',
        'move',
        'restore-managed',
      ]);
    },
  );
}

Future<MapNotifier> _notifier({
  required GpxTrackRepository repository,
  required GpxManagedFileOperations operations,
}) async {
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
          managedFileOperations: operations,
          trackReplacementRecoveryIssueStore:
              InMemoryTrackReplacementRecoveryIssueStore(),
          loadPositionOnBuild: false,
          loadPeaksOnBuild: false,
          loadTracksOnBuild: false,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(mapProvider.notifier);
}

GpxTrack _existingTrack() => GpxTrack(
  gpxTrackId: 7,
  contentHash: 'old',
  trackName: 'Mount Anne 15-01-2024',
  trackDate: DateTime(2024, 1, 15),
  startDateTime: DateTime(2024, 1, 15, 8),
  gpxFile: '<gpx />',
  visible: false,
  trackColour: 0xFF123456,
)..peaks.add(Peak(osmId: 1, name: 'Old peak', latitude: -42, longitude: 147));

File _incomingFile(String prefix) {
  final directory = Directory.systemTemp.createTempSync(prefix);
  return File('${directory.path}/incoming.gpx')..writeAsStringSync(_gpx);
}

class _FakeManagedFileOperations implements GpxManagedFileOperations {
  _FakeManagedFileOperations({this.failMove = false});

  final bool failMove;
  final calls = <String>[];

  @override
  Future<void> backupManagedFile({
    required String destinationPath,
    required String backupPath,
  }) async {
    calls.add('backup');
  }

  @override
  bool fileExists(String path) => true;

  @override
  Future<void> moveIncomingFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    calls.add('move');
    if (failMove) {
      throw StateError('injected move failure');
    }
  }

  @override
  Future<void> removeBackup(String backupPath) async {
    calls.add('cleanup');
  }

  @override
  Future<String> resolveReplacementDestination({
    required String sourcePath,
    required GpxTrack replacementTrack,
  }) async {
    calls.add('resolve');
    return '/managed/mount-anne.gpx';
  }

  @override
  Future<void> restoreIncomingFile({
    required String destinationPath,
    required String sourcePath,
  }) async {
    calls.add('restore-source');
  }

  @override
  Future<void> restoreManagedFile({
    required String backupPath,
    required String destinationPath,
  }) async {
    calls.add('restore-managed');
  }
}

const _gpx = '''
<gpx version="1.1"><trk><name>Mount Anne (15-01-2024)</name><trkseg>
<trkpt lat="-42.0" lon="147.0"><time>2024-01-15T08:00:00Z</time></trkpt>
<trkpt lat="-42.01" lon="147.01"><time>2024-01-15T09:00:00Z</time></trkpt>
</trkseg></trk></gpx>
''';
