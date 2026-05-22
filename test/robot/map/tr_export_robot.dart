import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/gpx_export_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';

import '../../harness/test_gpx_file_picker.dart';
import '../../harness/test_map_notifier.dart';

class TrExportRobot {
  TrExportRobot(
    this.tester,
    this.initialState, {
    required this.trackRepository,
    required this.routeRepository,
    GpxExportService? exportService,
    this.gpxFilePicker,
    this.surfaceSize = const Size(1600, 900),
  }) : exportService = exportService ?? FakeTrExportService();

  final WidgetTester tester;
  final MapState initialState;
  final GpxTrackRepository trackRepository;
  final RouteRepository routeRepository;
  final GpxExportService exportService;
  final GpxFilePicker? gpxFilePicker;
  final Size surfaceSize;

  late final TestMapNotifier notifier;

  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get exportButton => find.byKey(const Key('tracks-routes-export-button'));
  Finder get exportConfirm =>
      find.byKey(const Key('tracks-routes-export-confirm'));
  Finder get exportCancel =>
      find.byKey(const Key('tracks-routes-export-cancel'));
  Finder get drawer => find.byKey(const Key('tracks-routes-drawer'));

  Future<void> pumpApp() async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    notifier = TestMapNotifier(
      initialState,
      gpxTrackRepository: trackRepository,
      routeRepository: routeRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          gpxTrackRepositoryProvider.overrideWithValue(trackRepository),
          routeRepositoryProvider.overrideWithValue(routeRepository),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
          peaksBaggedRepositoryProvider.overrideWithValue(
            PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
          ),
          gpxExportServiceProvider.overrideWithValue(exportService),
          if (gpxFilePicker != null)
            gpxFilePickerProvider.overrideWithValue(gpxFilePicker!)
          else
            gpxFilePickerProvider.overrideWithValue(FakeGpxFilePicker()),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> selectTrack(int trackId) async {
    notifier.selectTrack(trackId);
    await tester.pump();
  }

  Future<void> selectRoute(int routeId) async {
    notifier.selectRoute(routeId);
    await tester.pump();
  }

  Future<void> openTracksRoutesDrawer() async {
    await tester.tap(showTracksFab);
    await tester.pumpAndSettle();
  }

  Future<void> exportSelected() async {
    await tester.tap(exportButton);
    await tester.pumpAndSettle();
  }

  Future<void> confirmOverwrite() async {
    await tester.tap(exportConfirm);
    await tester.pumpAndSettle();
  }

  void expectExportWritten() {
    expect((exportService as FakeTrExportService).writeCallCount, 1);
  }

  void expectSnackbarContains(String text) {
    expect(find.textContaining(text), findsOneWidget);
  }

  void expectDrawerVisible() {
    expect(drawer, findsOneWidget);
  }
}

final class FakeTrExportService extends GpxExportService {
  FakeTrExportService()
    : super(
        trackDownloadsDirectoryResolver: () => Directory('/fake/track'),
        routeExportsDirectoryResolver: () => Directory('/fake/route'),
      );

  int writeCallCount = 0;
  GpxExportPlan? lastPlan;

  @override
  GpxExportPlan planTrackExport(GpxTrack track) {
    return GpxExportPlan(
      path: '/fake/track/${_stem(track.trackName)}.gpx',
      contents: track.gpxFile,
    );
  }

  @override
  GpxExportPlan planRouteExport(app_route.Route route) {
    return GpxExportPlan(
      path: '/fake/route/${_stem(route.name)}.gpx',
      contents: '<route>${route.name}</route>',
    );
  }

  @override
  bool fileExists(GpxExportPlan plan) => false;

  @override
  Future<String> writeExport(GpxExportPlan plan) async {
    lastPlan = plan;
    writeCallCount += 1;
    return plan.path;
  }

  String _stem(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'[\s/\\]+'), '-');
    return sanitized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
  }
}
