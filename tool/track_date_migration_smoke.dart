/// Controlled native startup/retry check. Never opens the app's data directory.
/// flutter run -d macos -t tool/track_date_migration_smoke.dart
library;

import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/providers/track_date_migration_provider.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import 'package:peak_bagger/services/track_date_migration_repository.dart';
import 'package:peak_bagger/services/track_date_migration_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/track_date_migration_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await Directory.systemTemp.createTemp(
    'walk-date-native-smoke-',
  );
  final store = await openStore(directory: directory.path);
  store.box<GpxTrack>().putMany([
    GpxTrack(
      gpxTrackId: 7,
      contentHash: 'native-hobart',
      trackName: 'Hobart fixture',
      trackDate: DateTime.utc(2026, 12, 31),
      gpxFile:
          '<gpx><trk><trkseg><trkpt lat="-42.8821" lon="147.3272"><time>2026-12-31T13:30:00Z</time></trkpt></trkseg></trk></gpx>',
    ),
    GpxTrack(
      gpxTrackId: 8,
      contentHash: 'native-skip',
      trackName: 'Missing timestamp fixture',
      trackDate: DateTime.utc(2001),
      gpxFile:
          '<gpx><trk><trkseg><trkpt lat="34.0522" lon="-118.2437"/></trkseg></trk></gpx>',
    ),
  ]);
  store.box<PeaksBagged>().put(
    PeaksBagged(
      baggedId: 70,
      peakId: 10,
      gpxId: 7,
      date: DateTime.utc(2026, 12, 31, 13),
    ),
  );
  var failOnce = true;
  final repository = ObjectBoxTrackDateMigrationRepository(
    store,
    beforeWriteForTest: (stage) {
      if (stage == TrackDateMigrationWriteStage.completion && failOnce) {
        failOnce = false;
        throw StateError('Controlled native smoke: final commit failure');
      }
    },
  );
  final service = TrackDateMigrationService(
    repository: repository,
    derivation: TrackDateDerivationService.offline,
    yieldToUi: () => Future<void>.delayed(const Duration(seconds: 1)),
  );
  final container = ProviderContainer(
    overrides: [trackDateMigrationServiceProvider.overrideWithValue(service)],
  );
  container.listen(trackDateMigrationProvider, (_, next) {
    debugPrint(
      'NATIVE DATE SMOKE: ${next.status.name}; database=${directory.path}',
    );
    if (next.status == TrackDateMigrationStatus.failed) {
      assert(repository.readCompletion() == null);
      assert(
        store.box<GpxTrack>().get(7)!.trackDate == DateTime.utc(2026, 12, 31),
      );
      assert(
        store.box<PeaksBagged>().get(70)!.date ==
            DateTime.utc(2026, 12, 31, 13),
      );
      debugPrint('NATIVE DATE SMOKE: rollback verified');
    }
    if (next.isReady) {
      assert(repository.readCompletion()!.completedVersion == 1);
      assert(store.box<GpxTrack>().get(7)!.trackDate == DateTime.utc(2027));
      assert(store.box<PeaksBagged>().get(70)!.date == DateTime.utc(2027));
      debugPrint('NATIVE DATE SMOKE: durable correction verified');
    }
  });
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _SmokeApp(
        onQuit: () async {
          service.dispose();
          container.dispose();
          store.close();
          await directory.delete(recursive: true);
        },
      ),
    ),
  );
}

class _SmokeApp extends ConsumerStatefulWidget {
  const _SmokeApp({required this.onQuit});
  final Future<void> Function() onQuit;

  @override
  ConsumerState<_SmokeApp> createState() => _SmokeAppState();
}

class _SmokeAppState extends ConsumerState<_SmokeApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await widget.onQuit();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trackDateMigrationBootstrapProvider);
    return MaterialApp(
      theme: MyTheme.light,
      darkTheme: MyTheme.dark,
      themeMode: const bool.fromEnvironment('MIGRATION_SMOKE_DARK')
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const TrackDateMigrationHost(child: _SmokeDone()),
    );
  }
}

class _SmokeDone extends StatelessWidget {
  const _SmokeDone();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Text('Controlled startup complete — no production data used.'),
    ),
  );
}
