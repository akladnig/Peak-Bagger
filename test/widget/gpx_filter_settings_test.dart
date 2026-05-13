import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('shows loading label before filter config resolves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(_baseState())),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();

    expect(find.text('Loading filter settings...'), findsOneWidget);
  });

  testWidgets('expands filter section and persists settings changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(_baseState())),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('gpx-filter-settings-section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('gpx-filter-settings-section')));
    await tester.pumpAndSettle();

    await container
        .read(gpxFilterSettingsProvider.notifier)
        .setHampelWindow(9);
    await tester.pumpAndSettle();

    final config = await container.read(gpxFilterSettingsProvider.future);
    expect(config.hampelWindow, 9);
  });

  testWidgets('shows outlier filter and none options', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(_baseState())),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gpx-filter-settings-section')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gpx-filter-outlier-filter')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('settings-scrollable')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('gpx-filter-outlier-filter')));

    await tester.tap(find.byKey(const Key('gpx-filter-outlier-filter')));
    await tester.pumpAndSettle();
    expect(find.text('None'), findsWidgets);
    expect(find.text('Hampel Filter'), findsAtLeastNWidgets(1));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('disables dependent windows when filters are none', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(_baseState())),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gpx-filter-settings-section')));
    await tester.pumpAndSettle();

    await container
        .read(gpxFilterSettingsProvider.notifier)
        .setOutlierFilter(GpxTrackOutlierFilter.none);
    await container
        .read(gpxFilterSettingsProvider.notifier)
        .setElevationSmoother(GpxTrackElevationSmoother.none);
    await container
        .read(gpxFilterSettingsProvider.notifier)
        .setPositionSmoother(GpxTrackPositionSmoother.none);
    await tester.pumpAndSettle();

    expect(find.textContaining('Outlier Filter: None'), findsOneWidget);
    expect(
      find.widgetWithText(DropdownButtonFormField<GpxTrackOutlierFilter>, 'None'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        DropdownButtonFormField<GpxTrackElevationSmoother>,
        'None',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        DropdownButtonFormField<GpxTrackPositionSmoother>,
        'None',
      ),
      findsOneWidget,
    );

    expect(
      tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('gpx-filter-hampel-window')),
      ).onChanged,
      isNull,
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('gpx-filter-elevation-window')),
      ).onChanged,
      isNull,
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('gpx-filter-position-window')),
      ).onChanged,
      isNull,
    );
  });
}

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 10,
    basemap: Basemap.tracestrack,
  );
}
