import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/track_speed_analysis_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/track_speed_analysis_service.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class TrackSpeedAnalysisRobot {
  TrackSpeedAnalysisRobot(
    this.tester,
    MapState initialState, {
    required List<
      Future<TrackSpeedAnalysisReport> Function(
        void Function(TrackSpeedAnalysisProgress progress)? onProgress,
      )
    >
    analysisOutcomes,
  }) : repositoryFuture = TestTasmapRepository.create(),
       notifier = TestPeakNotifier(initialState),
       _runner = _FakeTrackSpeedAnalysisRunner(analysisOutcomes);

  final WidgetTester tester;
  final Future<TestTasmapRepository> repositoryFuture;
  final TestPeakNotifier notifier;
  final _FakeTrackSpeedAnalysisRunner _runner;

  Finder get settingsScrollable => find.byKey(const Key('settings-scrollable'));
  Finder get settingsScrollableViewport => find
      .descendant(of: settingsScrollable, matching: find.byType(Scrollable))
      .first;
  Finder get trackSpeedAnalysisTile =>
      find.byKey(const Key('track-speed-analysis-tile'));
  Finder get trackSpeedAnalysisScreen =>
      find.byKey(const Key('track-speed-analysis-screen'));
  Finder get trackSpeedAnalysisLoading =>
      find.byKey(const Key('track-speed-analysis-loading'));
  Finder get refreshAction =>
      find.byKey(const Key('track-speed-analysis-refresh-action'));
  Finder get refreshProgress =>
      find.byKey(const Key('track-speed-analysis-refresh-progress'));
  Finder get retryAction =>
      find.byKey(const Key('track-speed-analysis-retry-action'));
  Finder get errorState =>
      find.byKey(const Key('track-speed-analysis-error-state'));
  Finder get sectionTrackType =>
      find.byKey(const Key('track-speed-analysis-section-track-type'));

  int get runnerCallCount => _runner.callCount;

  Future<void> pumpApp() async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = await repositoryFuture;
    final tasmapNotifier = TestTasmapNotifier(repository);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(() => tasmapNotifier),
          tasmapRepositoryProvider.overrideWithValue(repository),
          routeGraphStoreProvider.overrideWithValue(_ReadyRouteGraphStore()),
          trackSpeedAnalysisRunnerProvider.overrideWithValue(_runner),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openTrackSpeedAnalysis() async {
    await tester.scrollUntilVisible(
      trackSpeedAnalysisTile,
      200,
      scrollable: settingsScrollableViewport,
    );
    await tester.ensureVisible(trackSpeedAnalysisTile);
    await tester.tap(trackSpeedAnalysisTile, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> tapRefresh() async {
    await tester.tap(refreshAction, warnIfMissed: false);
    await tester.pump();
  }

  Future<void> tapRetry() async {
    await tester.tap(retryAction, warnIfMissed: false);
    await tester.pump();
  }

  Future<void> waitForSettledUi() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  void expectLoadingVisible() {
    expect(trackSpeedAnalysisScreen, findsOneWidget);
    expect(trackSpeedAnalysisLoading, findsOneWidget);
    expect(find.text('Analysing tracks...'), findsOneWidget);
  }

  void expectReportVisible() {
    expect(trackSpeedAnalysisScreen, findsOneWidget);
    expect(sectionTrackType, findsOneWidget);
  }

  void expectPathRowVisible() {
    expect(find.text('path'), findsOneWidget);
  }

  void expectRefreshProgressVisible() {
    expect(refreshProgress, findsOneWidget);
  }

  void expectRefreshProgressHidden() {
    expect(refreshProgress, findsNothing);
  }

  void expectRefreshDisabled() {
    expect(tester.widget<TextButton>(refreshAction).onPressed, isNull);
  }

  void expectRetryEnabled() {
    expect(tester.widget<TextButton>(retryAction).onPressed, isNotNull);
  }

  void expectRetryDisabled() {
    expect(tester.widget<TextButton>(retryAction).onPressed, isNull);
  }

  void expectErrorVisible(String contains) {
    expect(errorState, findsOneWidget);
    expect(find.text('Analysis failed'), findsOneWidget);
    expect(find.textContaining(contains), findsOneWidget);
  }
}

class _FakeTrackSpeedAnalysisRunner implements TrackSpeedAnalysisRunner {
  _FakeTrackSpeedAnalysisRunner(
    List<
      Future<TrackSpeedAnalysisReport> Function(
        void Function(TrackSpeedAnalysisProgress progress)? onProgress,
      )
    >
    outcomes,
  ) : _outcomes =
          List<
            Future<TrackSpeedAnalysisReport> Function(
              void Function(TrackSpeedAnalysisProgress progress)? onProgress,
            )
          >.from(outcomes);

  final List<
    Future<TrackSpeedAnalysisReport> Function(
      void Function(TrackSpeedAnalysisProgress progress)? onProgress,
    )
  >
  _outcomes;
  int callCount = 0;

  @override
  Future<TrackSpeedAnalysisReport> analyze({
    void Function(TrackSpeedAnalysisProgress progress)? onProgress,
  }) {
    if (callCount >= _outcomes.length) {
      return Future<TrackSpeedAnalysisReport>.error(
        StateError('Unexpected analysis call ${callCount + 1}.'),
      );
    }

    final next = _outcomes[callCount];
    callCount += 1;
    onProgress?.call(
      const TrackSpeedAnalysisProgress(processedTracks: 0, totalTracks: 1),
    );
    return next(onProgress);
  }
}

class _ReadyRouteGraphStore implements RouteGraphStore {
  @override
  Future<void> bootstrapData() async {}

  @override
  Future<trip_routing.TripService> preload() async =>
      trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
