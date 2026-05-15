import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'dashboard_robot.dart';

void main() {
  testWidgets('elevation journey scrolls, toggles, hovers, and clamps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final robot = DashboardRobot(tester);
    final notifier = TestMapNotifier(
      const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        tasmapRepositoryProvider.overrideWithValue(
          await TestTasmapRepository.create(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await robot.pumpApp(container: container);
    await robot.openDashboard();

    notifier.setTracks([
      for (var day = 1; day <= 15; day++)
        _track(
          day,
          DateTime(2026, 5, day, 10),
          ascent: day * 10,
        ),
    ]);
    await tester.pumpAndSettle();

    await _selectPeriod(tester, 'Month');

    final initialSummary = _summary(tester);
    expect(initialSummary.total, isNotEmpty);
    expect(initialSummary.average, isNotEmpty);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('elevation-next-window'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('elevation-prev-window')));
    await tester.pumpAndSettle();

    final afterPrev = _summary(tester);
    expect(afterPrev.total, isNot(initialSummary.total));
    expect(afterPrev.average, isNot(initialSummary.average));

    await tester.tap(find.byKey(const Key('elevation-next-window')));
    await tester.pumpAndSettle();

    expect(_summary(tester), initialSummary);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('elevation-prev-window')));
      await tester.pumpAndSettle();
    }

    expect(
      tester.widget<IconButton>(find.byKey(const Key('elevation-prev-window'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('elevation-next-window'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('elevation-mode-fab')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);

    await _hoverBucket(tester, 0);

    expect(find.byKey(const Key('elevation-tooltip')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('elevation-tooltip')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('elevation-tooltip')),
        matching: find.text('10 m'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('elevation-period-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _hoverBucket(WidgetTester tester, int index) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);

  final bucket = find.byKey(Key('elevation-bucket-$index'));
  await mouse.addPointer(location: tester.getCenter(bucket));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(bucket));
  await tester.pump();
}

({String total, String average}) _summary(WidgetTester tester) {
  return (
    total: tester.widget<Text>(find.textContaining('Total')).data ?? '',
    average: tester.widget<Text>(find.textContaining('Average')).data ?? '',
  );
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  double? ascent,
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    ascent: ascent,
  );
}
