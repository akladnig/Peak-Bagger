import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/track_speed_analysis_service.dart';

import 'track_speed_analysis_robot.dart';

void main() {
  testWidgets(
    'track speed analysis journey refreshes without losing prior results',
    (tester) async {
      final initialLoad = Completer<TrackSpeedAnalysisReport>();
      final refreshLoad = Completer<TrackSpeedAnalysisReport>();
      final robot = TrackSpeedAnalysisRobot(
        tester,
        _baseState(),
        analysisOutcomes: [
          (_) => initialLoad.future,
          (_) => refreshLoad.future,
        ],
      );

      await robot.pumpApp();
      await robot.openTrackSpeedAnalysis();

      robot.expectLoadingVisible();
      robot.expectRefreshDisabled();

      initialLoad.complete(_sampleReport());
      await robot.waitForSettledUi();

      robot.expectReportVisible();
      robot.expectPathRowVisible();

      await robot.tapRefresh();

      robot.expectRefreshProgressVisible();
      robot.expectRefreshDisabled();
      robot.expectPathRowVisible();

      refreshLoad.complete(_sampleReport());
      await robot.waitForSettledUi();

      robot.expectReportVisible();
      robot.expectRefreshProgressHidden();
      expect(robot.runnerCallCount, 2);
    },
  );

  testWidgets('track speed analysis journey disables retry while rerun is active', (
    tester,
  ) async {
    final retryLoad = Completer<TrackSpeedAnalysisReport>();
    final robot = TrackSpeedAnalysisRobot(
      tester,
      _baseState(),
      analysisOutcomes: [
        (_) => Future<TrackSpeedAnalysisReport>.error(
          Exception('Local analysis blew up'),
        ),
        (_) => retryLoad.future,
      ],
    );

    await robot.pumpApp();
    await robot.openTrackSpeedAnalysis();
    await robot.waitForSettledUi();

    robot.expectErrorVisible('Local analysis blew up');
    robot.expectRetryEnabled();

    await robot.tapRetry();

    robot.expectRetryDisabled();
    robot.expectRefreshProgressVisible();

    retryLoad.complete(_sampleReport());
    await robot.waitForSettledUi();

    robot.expectReportVisible();
    robot.expectRefreshProgressHidden();
    expect(robot.runnerCallCount, 2);
  });
}

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
  );
}

TrackSpeedAnalysisReport _sampleReport() {
  return const TrackSpeedAnalysisReport(
    sections: [
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.trackType,
        rows: [
          TrackSpeedAnalysisRow(
            label: 'path',
            trackType: 'path',
            medianSpeedKmh: 4.5,
            sampleCount: 3,
            totalMovingDistanceMeters: 1234,
            totalMovingTime: Duration(minutes: 15),
          ),
        ],
      ),
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.hikingDifficulty,
        rows: [
          TrackSpeedAnalysisRow(
            label: 'sac_scale: mountain_hiking',
            hikingDifficultyFamily: 'sac_scale',
            hikingDifficultyValue: 'mountain_hiking',
            medianSpeedKmh: 4.1,
            sampleCount: 3,
            totalMovingDistanceMeters: 1234,
            totalMovingTime: Duration(minutes: 15),
          ),
        ],
      ),
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.trackTypeAndHikingDifficulty,
        rows: [
          TrackSpeedAnalysisRow(
            label: 'path + sac_scale: mountain_hiking',
            trackType: 'path',
            hikingDifficultyFamily: 'sac_scale',
            hikingDifficultyValue: 'mountain_hiking',
            medianSpeedKmh: 4.1,
            sampleCount: 3,
            totalMovingDistanceMeters: 1234,
            totalMovingTime: Duration(minutes: 15),
          ),
        ],
      ),
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.gradientBand,
        rows: [
          TrackSpeedAnalysisRow(
            label: '+5% to +10%',
            gradientBand: '+5% to +10%',
            medianSpeedKmh: 3.8,
            sampleCount: 3,
            totalMovingDistanceMeters: 1234,
            totalMovingTime: Duration(minutes: 15),
          ),
        ],
      ),
    ],
  );
}
