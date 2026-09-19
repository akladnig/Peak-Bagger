import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
  testWidgets('renders a persisted track date in local time', (tester) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Arthurs Peak',
      trackDate: DateTime.utc(2026, 7, 22, 14),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: MapTrackInfoPanel(track: track, onClose: () {}),
        ),
      ),
    );

    expect(
      find.text(formatTrackDate(track.trackDate!.toLocal())),
      findsOneWidget,
    );
  });

  testWidgets('renders combined distance metric for a track', (tester) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Test Track',
      distance2d: 12400,
      distance3d: 0,
      ascent: 638,
      totalTimeMillis: 5400000,
      lowestElevation: 1022,
      highestElevation: 1377,
      elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: track,
              onClose: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Distance (2d/3d)'), findsOneWidget);
    expect(find.text('12.4 / 0.0 km'), findsOneWidget);
  });

  testWidgets('renders elevation profile chart for a track', (tester) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Test Track',
      lowestElevation: 1022,
      highestElevation: 1377,
      elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: track,
              onClose: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('elevation-profile-chart')), findsOneWidget);
    final chart = tester.widget<ElevationProfileChart>(
      find.byType(ElevationProfileChart),
    );
    expect(chart.minElevation, track.lowestElevation);
    expect(chart.maxElevation, track.highestElevation);
  });

  testWidgets('derives highest-elevation rows without correlated peaks', (
    tester,
  ) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Profile Track',
      peakCorrelationProcessed: true,
      distanceToPeak: 99999,
      distanceFromPeak: 1,
      elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-01T00:00:00"},
  {"distanceMeters":1250,"elevationMeters":500,"timeLocal":"2024-01-01T00:10:30"},
  {"distanceMeters":2600,"elevationMeters":500,"timeLocal":"2024-01-01T00:20:00"},
  {"distanceMeters":3000,"elevationMeters":200,"timeLocal":"2024-01-02T01:15:30"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: UiConstants.preferredLeftWidth,
            child: MapTrackInfoPanel(track: track, onClose: () {}),
          ),
        ),
      ),
    );

    expect(find.text('To highest elevation'), findsOneWidget);
    expect(find.text('From highest elevation'), findsOneWidget);
    expect(find.text('1.3 km / 00:11'), findsOneWidget);
    expect(find.text('1.8 km / 25:05'), findsOneWidget);
    _expectOneLineNonOverlapping(
      tester,
      label: 'To highest elevation',
      value: '1.3 km / 00:11',
    );
    _expectOneLineNonOverlapping(
      tester,
      label: 'From highest elevation',
      value: '1.8 km / 25:05',
    );
  });

  testWidgets('omits highest-elevation durations for unusable timestamps', (
    tester,
  ) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Untimed Profile',
      peakCorrelationProcessed: true,
      elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-01T00:00:00"},
  {"distanceMeters":1250,"elevationMeters":500},
  {"distanceMeters":3000,"elevationMeters":200,"timeLocal":"2024-01-01T01:00:00"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: MapTrackInfoPanel(track: track, onClose: () {}),
        ),
      ),
    );

    expect(find.text('1.3 km'), findsOneWidget);
    expect(find.text('1.8 km'), findsOneWidget);
    expect(find.textContaining(' / 00:'), findsNothing);
  });

  testWidgets(
    'omits highest-elevation durations for non-chronological timestamps',
    (tester) async {
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: 'Non-chronological Profile',
        peakCorrelationProcessed: true,
        elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-01T00:00:00"},
  {"distanceMeters":1250,"elevationMeters":500,"timeLocal":"2024-01-01T00:10:00"},
  {"distanceMeters":3000,"elevationMeters":200,"timeLocal":"2024-01-01T00:05:00"}
]
''',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.light,
          home: Scaffold(
            body: MapTrackInfoPanel(track: track, onClose: () {}),
          ),
        ),
      );

      expect(find.text('1.3 km'), findsOneWidget);
      expect(find.text('1.8 km'), findsOneWidget);
      expect(find.textContaining(' / 00:'), findsNothing);
    },
  );

  testWidgets('forwards track chart hover callback', (tester) async {
    final hoverEvents = <ElevationProfileChartHoverSample?>[];
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Test Track',
      lowestElevation: 1022,
      highestElevation: 1377,
      elevationProfile: '''
[
  {"segmentIndex":0,"pointIndex":0,"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"segmentIndex":0,"pointIndex":1,"distanceMeters":12,"elevationMeters":null,"timeLocal":null},
  {"segmentIndex":1,"pointIndex":0,"distanceMeters":24,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: track,
              onClose: () {},
              onExport: () {},
              onElevationProfileHoverChanged: hoverEvents.add,
            ),
          ),
        ),
      ),
    );

    final chart = tester.widget<ElevationProfileChart>(
      find.byType(ElevationProfileChart),
    );
    final sample = ElevationProfileChartHoverSample(
      sampleIndex: 2,
      sample: ElevationProfileSample(
        segmentIndex: 1,
        pointIndex: 0,
        distanceMeters: 24,
        elevationMeters: 120,
        timeLocal: DateTime.utc(2024, 1, 15, 8, 10),
      ),
      xValue: 24,
      axisMode: ElevationProfileAxisMode.distance,
    );

    chart.onHoverChanged?.call(sample);

    expect(hoverEvents.last, isNotNull);
    expect(hoverEvents.last!.sampleIndex, 2);
    expect(hoverEvents.last!.sample.segmentIndex, 1);
    expect(hoverEvents.last!.sample.pointIndex, 0);
  });

  testWidgets('renders a visibility row for a track', (tester) async {
    var visible = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final track = GpxTrack(
                contentHash: 'hash',
                trackName: 'Test Track',
                visible: visible,
                lowestElevation: 1022,
                highestElevation: 1377,
                elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
              );

              return SizedBox(
                width: 600,
                child: MapTrackInfoPanel(
                  track: track,
                  onClose: () {},
                  onExport: () {},
                  onVisibilityChanged: (value) {
                    setState(() {
                      visible = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final switchFinder = find.byKey(
      const Key('track-info-panel-visibility-switch'),
    );
    expect(find.text('Hide this track on the map'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    final label = find.text('Hide this track on the map');
    expect(
      tester.getRect(label).left,
      lessThan(tester.getRect(switchFinder).left),
    );
    expect(
      (tester.getRect(label).center.dy - tester.getRect(switchFinder).center.dy)
          .abs(),
      lessThan(1),
    );

    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Show this track on the map'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });

  testWidgets(
    'places the track statistics recalculation button above visibility',
    (tester) async {
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: 'Test Track',
        visible: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: MapTrackInfoPanel(
                track: track,
                onClose: () {},
                onTrackStatisticsRecalculate: () {},
              ),
            ),
          ),
        ),
      );

      final recalculateButton = find.byKey(
        const Key('track-info-panel-recalculate-button'),
      );
      final visibilityRow = find.byKey(
        const Key('track-info-panel-visibility-row'),
      );
      await tester.ensureVisible(visibilityRow);
      await tester.pumpAndSettle();

      expect(recalculateButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(recalculateButton).onPressed,
        isNotNull,
      );
      expect(
        tester.getRect(recalculateButton).bottom,
        lessThan(tester.getRect(visibilityRow).top),
      );
    },
  );

  testWidgets('shows disabled inline recalculation progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: GpxTrack(contentHash: 'hash', trackName: 'Test Track'),
              onClose: () {},
              onTrackStatisticsRecalculate: () {},
              isTrackStatisticsRecalculating: true,
            ),
          ),
        ),
      ),
    );

    final recalculateButton = find.byKey(
      const Key('track-info-panel-recalculate-button'),
    );
    await tester.ensureVisible(recalculateButton);

    expect(tester.widget<FilledButton>(recalculateButton).onPressed, isNull);
    expect(
      find.byKey(const Key('track-info-panel-recalculate-busy-indicator')),
      findsOneWidget,
    );
    expect(find.text('Recalculating...'), findsOneWidget);
  });

  testWidgets('renders a labelled peak correlation removal control', (
    tester,
  ) async {
    final track =
        GpxTrack(gpxTrackId: 10, contentHash: 'hash', trackName: 'Test Track')
          ..peaks.add(
            Peak(
              osmId: 42,
              name: 'Test Peak',
              elevation: 1234,
              latitude: 0,
              longitude: 0,
            ),
          );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: MapTrackInfoPanel(
            track: track,
            onClose: () {},
            onPeakCorrelationRemove:
                ({required trackId, required peak, required trackName}) async =>
                    null,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('map-track-correlation-remove-10-42')),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove peak correlation'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove peak correlation'), findsOneWidget);
    final deleteIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('map-track-correlation-remove-10-42')),
        matching: find.byIcon(Icons.delete_forever),
      ),
    );
    expect(deleteIcon.color, Colors.red);
  });

  testWidgets('uses click cursors only for enabled track panel controls', (
    tester,
  ) async {
    final removalCompleter = Completer<String?>();
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash',
      trackName: 'Test Track',
    )..peaks.add(Peak(osmId: 42, name: 'Test Peak', latitude: 0, longitude: 0));

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: MapTrackInfoPanel(
            track: track,
            onClose: () {},
            onExport: () {},
            onTrackStatisticsRecalculate: () {},
            onVisibilityChanged: (_) {},
            onPeakCorrelationRemove:
                ({required trackId, required peak, required trackName}) =>
                    removalCompleter.future,
          ),
        ),
      ),
    );

    final close = find.byKey(const Key('track-info-panel-close'));
    final export = find.byKey(const Key('track-info-panel-export-button'));
    final recalculate = find.byKey(
      const Key('track-info-panel-recalculate-button'),
    );
    final visibility = find.byKey(
      const Key('track-info-panel-visibility-switch'),
    );
    final removal = find.byKey(const Key('map-track-correlation-remove-10-42'));
    for (final control in [close, export, recalculate, visibility, removal]) {
      _expectCursor(tester, control, SystemMouseCursors.click);
    }

    await tester.tap(removal);
    await tester.pump();
    _expectCursor(tester, removal, SystemMouseCursors.basic);
    removalCompleter.complete(null);
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.light,
        home: Scaffold(
          body: MapTrackInfoPanel(
            track: track,
            onClose: () {},
            isTrackStatisticsRecalculating: true,
          ),
        ),
      ),
    );

    _expectCursor(tester, close, SystemMouseCursors.click);
    for (final control in [export, recalculate, visibility]) {
      _expectCursor(tester, control, SystemMouseCursors.basic);
    }
  });

  testWidgets(
    'uses a scoped onSecondary content theme and keeps export separate',
    (tester) async {
      final track = GpxTrack(
        contentHash: 'hash',
        trackName: 'Test Track',
        distance2d: 12400,
        distance3d: 0,
        ascent: 638,
        totalTimeMillis: 5400000,
        visible: true,
        lowestElevation: 1022,
        highestElevation: 1377,
        elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: MapTrackInfoPanel(
                track: track,
                onClose: () {},
                onExport: () {},
                onVisibilityChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final panel = tester.widget<Card>(
        find.byKey(const Key('track-info-panel')),
      );
      final contentThemeFinder = find.byKey(
        const Key('track-info-panel-content-theme'),
      );
      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('track-info-panel-visibility-switch')),
      );
      final closeIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('track-info-panel-close')),
          matching: find.byIcon(Icons.close),
        ),
      );
      final exportButton = tester.widget<FilledButton>(
        find.byKey(const Key('track-info-panel-export-button')),
      );
      final exportIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('track-info-panel-export-button')),
          matching: find.byIcon(Icons.download),
        ),
      );

      expect(panel.color, MyTheme.light.colorScheme.surfaceContainer);
      expect(contentThemeFinder, findsOneWidget);

      final contentTheme = tester.widget<Theme>(contentThemeFinder).data;
      expect(contentTheme.iconTheme.color, contentTheme.colorScheme.onSurface);
      expect(
        contentTheme.textTheme.titleMedium?.color,
        contentTheme.colorScheme.onSurface,
      );
      expect(
        contentTheme.textTheme.bodySmall?.color,
        contentTheme.colorScheme.onSurface,
      );
      expect(closeIcon.color, isNull);
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('12.4 / 0.0 km')),
        ).style.color,
        contentTheme.colorScheme.onSurface,
      );
      expect(
        find.descendant(
          of: contentThemeFinder,
          matching: find.byKey(const Key('track-info-panel-export-button')),
        ),
        findsNothing,
      );
      expect(switchWidget.thumbColor, isNull);
      expect(switchWidget.trackColor, isNull);
      expect(switchWidget.overlayColor, isNull);
      expect(exportButton.style, isNull);
      expect(exportIcon.color, isNull);
    },
  );
}

void _expectCursor(WidgetTester tester, Finder control, MouseCursor cursor) {
  final region = find
      .ancestor(of: control, matching: find.byType(MouseRegion))
      .first;
  expect(tester.widget<MouseRegion>(region).cursor, cursor);
}

void _expectOneLineNonOverlapping(
  WidgetTester tester, {
  required String label,
  required String value,
}) {
  final labelRect = tester.getRect(find.text(label));
  final valueRect = tester.getRect(find.text(value));
  expect((labelRect.top - valueRect.top).abs(), lessThan(1));
  expect(labelRect.right, lessThanOrEqualTo(valueRect.left));
}
