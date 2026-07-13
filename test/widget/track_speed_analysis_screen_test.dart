import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/track_speed_analysis_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/screens/track_speed_analysis_screen.dart';
import 'package:peak_bagger/services/track_speed_analysis_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets(
    'settings tile opens Track Speed Analysis and shows first-load state',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      final completer = Completer<TrackSpeedAnalysisReport>();
      await _pumpSettingsScreen(
        tester,
        runner: _FakeTrackSpeedAnalysisRunner([(_) => completer.future]),
      );

      await _openTrackSpeedAnalysis(tester);
      await tester.pump();

      expect(
        find.byKey(const Key('track-speed-analysis-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('track-speed-analysis-loading')),
        findsOneWidget,
      );
      expect(find.text('Analysing tracks...'), findsOneWidget);
      expect(
        find.byKey(const Key('track-speed-analysis-progress-text')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('track-speed-analysis-refresh-action')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'screen shows exact empty state copy and keeps actions visible on narrow large text layouts',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      final completer = Completer<TrackSpeedAnalysisReport>();

      await _pumpTrackSpeedAnalysisScreen(
        tester,
        runner: _FakeTrackSpeedAnalysisRunner([(_) => completer.future]),
        viewportSize: const Size(360, 780),
        textScaleFactor: 2.0,
      );

      completer.complete(_emptyReport());
      await _settleRouteAndMicrotasks(tester);

      expect(find.text('No analysis data yet'), findsOneWidget);
      expect(
        find.text(
          'Import timestamped Tasmanian tracks and recalculate track statistics to build walking-speed analysis.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('track-speed-analysis-refresh-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'screen shows failure state with retry action and concise error summary',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      await _pumpSettingsScreen(
        tester,
        runner: _FakeTrackSpeedAnalysisRunner([
          (_) => Future<TrackSpeedAnalysisReport>.error(
            Exception('Local analysis blew up'),
          ),
        ]),
      );

      await _openTrackSpeedAnalysis(tester);
      await _settleRouteAndMicrotasks(tester);

      expect(
        find.byKey(const Key('track-speed-analysis-error-state')),
        findsOneWidget,
      );
      expect(find.text('Analysis failed'), findsOneWidget);
      expect(find.text('Local analysis blew up'), findsOneWidget);
      expect(
        find.byKey(const Key('track-speed-analysis-retry-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'retry stays visible but disabled while a failure rerun is active',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      final retryCompleter = Completer<TrackSpeedAnalysisReport>();
      await _pumpSettingsScreen(
        tester,
        runner: _FakeTrackSpeedAnalysisRunner([
          (_) => Future<TrackSpeedAnalysisReport>.error(
            Exception('Local analysis blew up'),
          ),
          (_) => retryCompleter.future,
        ]),
      );

      await _openTrackSpeedAnalysis(tester);
      await _settleRouteAndMicrotasks(tester);

      await tester.tap(
        find.byKey(const Key('track-speed-analysis-retry-action')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('track-speed-analysis-error-state')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('track-speed-analysis-retry-action')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('track-speed-analysis-refresh-progress')),
        findsOneWidget,
      );

      retryCompleter.complete(_sampleReport());
      await _settleRouteAndMicrotasks(tester);
    },
  );

  testWidgets(
    'screen renders aggregate report sections and filtered-track note',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      await _pumpSettingsScreen(
        tester,
        runner: _FakeTrackSpeedAnalysisRunner([(_) async => _sampleReport()]),
      );

      await _openTrackSpeedAnalysis(tester);
      await _settleRouteAndMicrotasks(tester);

      expect(
        find.byKey(const Key('track-speed-analysis-section-track-type')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('track-speed-analysis-section-hiking-difficulty')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'track-speed-analysis-section-track-type-and-hiking-difficulty',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('track-speed-analysis-section-gradient-band')),
        findsOneWidget,
      );
      expect(find.text('path'), findsOneWidget);
      expect(find.text('sac_scale: mountain_hiking'), findsOneWidget);
      expect(
        find.textContaining(
          'Analysis uses the same filtered-track basis as current track statistics when available.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual refresh keeps prior report visible and disables active-run actions',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      final refreshCompleter = Completer<TrackSpeedAnalysisReport>();
      final runner = _FakeTrackSpeedAnalysisRunner([
        (_) async => _sampleReport(),
        (_) => refreshCompleter.future,
      ]);
      await _pumpSettingsScreen(tester, runner: runner);

      await _openTrackSpeedAnalysis(tester);
      await _settleRouteAndMicrotasks(tester);

      expect(find.text('path'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('track-speed-analysis-refresh-action')),
      );
      await tester.pump();

      expect(find.text('path'), findsOneWidget);
      expect(
        find.byKey(const Key('track-speed-analysis-refresh-progress')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('track-speed-analysis-refresh-action')),
            )
            .onPressed,
        isNull,
      );

      refreshCompleter.complete(_sampleReport());
      await tester.pumpAndSettle();
      expect(runner.callCount, 2);
    },
  );

  testWidgets(
    'leaving the screen during an active run does not update disposed state',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      final completer = Completer<TrackSpeedAnalysisReport>();
      await _pumpSettingsScreen(
        tester,
        runner: _FakeTrackSpeedAnalysisRunner([(_) => completer.future]),
      );

      await _openTrackSpeedAnalysis(tester);
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await _settleRouteAndMicrotasks(tester);

      completer.complete(_sampleReport());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('track-speed-analysis-screen')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpTrackSpeedAnalysisScreen(
  WidgetTester tester, {
  required TrackSpeedAnalysisRunner runner,
  Size viewportSize = const Size(800, 1200),
  double textScaleFactor = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        trackSpeedAnalysisRunnerProvider.overrideWithValue(runner),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: const TrackSpeedAnalysisScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openTrackSpeedAnalysis(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('track-speed-analysis-tile')),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('settings-scrollable')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(
    find.byKey(const Key('track-speed-analysis-tile')),
  );
  await tester.tap(find.byKey(const Key('track-speed-analysis-tile')));
  await tester.pump();
}

Future<void> _settleRouteAndMicrotasks(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  required TrackSpeedAnalysisRunner runner,
  Size viewportSize = const Size(800, 1200),
  double textScaleFactor = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        trackSpeedAnalysisRunnerProvider.overrideWithValue(runner),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

TrackSpeedAnalysisReport _emptyReport() {
  return const TrackSpeedAnalysisReport(
    sections: [
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.trackType,
        rows: [],
      ),
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.hikingDifficulty,
        rows: [],
      ),
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.trackTypeAndHikingDifficulty,
        rows: [],
      ),
      TrackSpeedAnalysisSection(
        kind: TrackSpeedAnalysisSectionKind.gradientBand,
        rows: [],
      ),
    ],
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

class _FakeTrackSpeedAnalysisRunner implements TrackSpeedAnalysisRunner {
  _FakeTrackSpeedAnalysisRunner(this._outcomes);

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
      throw StateError('Unexpected analysis call ${callCount + 1}.');
    }
    final next = _outcomes[callCount];
    callCount += 1;
    onProgress?.call(
      const TrackSpeedAnalysisProgress(processedTracks: 0, totalTracks: 1),
    );
    return next(onProgress);
  }
}
