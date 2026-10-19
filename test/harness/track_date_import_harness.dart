import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/track_date_derivation_provider.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mapping_catalog_fixture.dart';
import 'test_tasmap_repository.dart';

class TrackDateImportHarness {
  TrackDateImportHarness._(
    this.directory,
    this.container,
    this.tracks,
    this.ascents,
  );

  final Directory directory;
  final ProviderContainer container;
  final GpxTrackRepository tracks;
  final PeaksBaggedRepository ascents;

  static Future<TrackDateImportHarness> create({
    TrackDateDerivationService? dateService,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'track-date-import',
    );
    debugBushwalkingRootOverride = directory.path;
    Directory(
      '${directory.path}/Tracks/Australia/Tasmania',
    ).createSync(recursive: true);
    final tracks = GpxTrackRepository.test(InMemoryGpxTrackStorage());
    final ascents = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
      loadTracks: tracks.getAllTracks,
    );
    final tasmap = await TestTasmapRepository.create();
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        if (dateService != null)
          trackDateDerivationServiceProvider.overrideWithValue(dateService),
        mapProvider.overrideWith(
          () => MapNotifier(
            mappingCatalog: testMappingCatalog,
            gpxTrackRepository: tracks,
            peaksBaggedRepository: ascents,
            tasmapRepository: tasmap,
            peakRepository: PeakRepository.test(
              InMemoryPeakStorage([
                Peak(
                  osmId: 10,
                  name: 'Fixture peak',
                  latitude: -42.8821,
                  longitude: 147.3272,
                  elevation: 100,
                ),
              ]),
            ),
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    return TrackDateImportHarness._(directory, container, tracks, ascents);
  }

  File file(String name, String gpx) =>
      File('${directory.path}/$name.gpx')..writeAsStringSync(gpx);

  Future<void> close() async {
    container.dispose();
    debugBushwalkingRootOverride = null;
    await directory.delete(recursive: true);
  }
}
