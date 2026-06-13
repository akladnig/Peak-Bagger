import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_marker_info_settings_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/theme.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('hovering a peak sets click cursor and highlight', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    final center = tester.getCenter(region);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredPeakId, 6406);
    expect(tester.widget<MouseRegion>(region).cursor, SystemMouseCursors.click);
    expect(find.byKey(const Key('peak-marker-hover-6406')), findsOneWidget);
    expect(find.byKey(const Key('peak-marker-name-6406')), findsNothing);
    expect(find.byKey(const Key('peak-marker-height-6406')), findsNothing);
    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(find.text('Bonnet Hill'), findsOneWidget);
  });

  testWidgets('hovering away closes transient peak popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);

    await gesture.moveTo(center + const Offset(100, 0));
    await tester.pump();

    expect(container.read(mapProvider).hoveredPeakId, isNull);
    expect(find.byKey(const Key('peak-info-popup')), findsNothing);
  });

  testWidgets('leaving the map closes transient peak popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);

    await gesture.moveTo(tester.getTopLeft(region) - const Offset(20, 20));
    await tester.pump();

    expect(find.byKey(const Key('peak-info-popup')), findsNothing);
  });

  testWidgets('clicking a hovered peak pins the popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    await gesture.down(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(mapProvider).isPeakInfoPinned, isTrue);

    await gesture.moveTo(center + const Offset(100, 0));
    await tester.pump();

    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);
  });

  testWidgets('peak markers render info labels when enabled', (tester) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
      overrides: [
        peakMarkerInfoSettingsProvider.overrideWith(
          () => _StaticPeakMarkerInfoNotifier(true),
        ),
      ],
    );

    expect(find.byKey(const Key('peak-marker-name-6406')), findsOneWidget);
    expect(find.byKey(const Key('peak-marker-height-6406')), findsOneWidget);
    expect(
      tester.widget<OutlinedText>(
        find.byKey(const Key('peak-marker-name-6406')),
      ),
      isA<OutlinedText>()
          .having((widget) => widget.maxLines, 'maxLines', 2)
          .having(
            (widget) => widget.overflow,
            'overflow',
            TextOverflow.ellipsis,
          ),
    );
    expect(
      tester.widget<OutlinedText>(
        find.byKey(const Key('peak-marker-height-6406')),
      ),
      isA<OutlinedText>()
          .having((widget) => widget.maxLines, 'maxLines', 1)
          .having(
            (widget) => widget.overflow,
            'overflow',
            TextOverflow.ellipsis,
          ),
    );
  });

  testWidgets('peak marker labels cap width and ellipsize long names', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'A very long peak name that should wrap neatly',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
      overrides: [
        peakMarkerInfoSettingsProvider.overrideWith(
          () => _StaticPeakMarkerInfoNotifier(true),
        ),
      ],
    );

    final labelsFinder = find.byKey(const Key('peak-marker-labels-6406'));
    expect(labelsFinder, findsOneWidget);

    final labelsWidth = tester.getSize(labelsFinder).width;
    expect(
      labelsWidth,
      lessThanOrEqualTo(peakMarkerLabelMaxWidth(tester.element(labelsFinder))),
    );

    final nameWidget = tester.widget<OutlinedText>(
      find.byKey(const Key('peak-marker-name-6406')),
    );
    expect(nameWidget.maxLines, 2);
    expect(nameWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets('clicking a peak opens peak popup without selecting location', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        selectedLocation: const LatLng(-42.0, 146.0),
        showInfoPopup: true,
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final beforeLocation = container.read(mapProvider).selectedLocation;

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.showInfoPopup, isFalse);
    expect(state.peakInfoPeak?.osmId, 6406);
    expect(state.selectedLocation, beforeLocation);
    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(find.text('Bonnet Hill'), findsOneWidget);
  });

  testWidgets('pinned peak popup suppresses the overlapping label', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
      overrides: [
        peakMarkerInfoSettingsProvider.overrideWith(
          () => _StaticPeakMarkerInfoNotifier(true),
        ),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(find.byKey(const Key('peak-marker-name-6406')), findsNothing);
    expect(find.byKey(const Key('peak-marker-height-6406')), findsNothing);
  });

  testWidgets('moving off a peak clears hover without closing peak popup', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();
    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(mapProvider).hoveredPeakId, 6406);
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await gesture.moveTo(center + const Offset(100, 0));
    await tester.pump();

    expect(container.read(mapProvider).hoveredPeakId, isNull);
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);
    expect(tester.widget<MouseRegion>(region).cursor, SystemMouseCursors.grab);
  });

  testWidgets('non-peak click keeps selected-location behavior', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region) + const Offset(100, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak, isNull);
    expect(state.selectedLocation, isNotNull);
    expect(state.selectedLocation!.longitude, isNot(closeTo(147.0, 0.001)));
  });

  testWidgets('background click closes open peak popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);

    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await tester.tapAt(center + const Offset(-100, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak, isNull);
    expect(state.selectedLocation, isNotNull);
  });

  testWidgets('hiding peaks or zooming below threshold closes peak popup', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);

    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    container
        .read(mapProvider.notifier)
        .selectPeakList(PeakListSelectionMode.none);
    await tester.pump();
    expect(container.read(mapProvider).peakInfoPeak, isNull);
    expect(container.read(mapProvider).hoveredPeakId, isNull);

    container
        .read(mapProvider.notifier)
        .selectPeakList(PeakListSelectionMode.allPeaks);
    await tester.pump();
    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    container
        .read(mapProvider.notifier)
        .requestCameraMove(center: const LatLng(-43.0, 147.0), zoom: 7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(mapProvider).peakInfoPeak, isNull);
  });

  testWidgets('removing the open peak closes peak popup', (tester) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    await _pumpMap(
      tester,
      _mapStateWithPeak(peak: peak),
      peakRepository: peakRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await peakRepository.clearAll();
    await container.read(mapProvider.notifier).reloadPeakMarkers();
    await tester.pump();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
  });

  testWidgets('reload keeps open peak popup content fresh', (tester) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    await _pumpMap(
      tester,
      _mapStateWithPeak(peak: peak),
      peakRepository: peakRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.altName, '');

    await peakRepository.save(
      Peak(
        id: peak.id,
        osmId: 6406,
        name: 'Bonnet Hill',
        altName: 'Updated Alternate',
        latitude: -43.0,
        longitude: 147.0,
      ),
    );
    await container.read(mapProvider.notifier).reloadPeakMarkers();
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak?.altName, 'Updated Alternate');
    expect(state.peakInfo?.mapName, isNotEmpty);
    expect(state.peakInfo?.listNames, isEmpty);
  });

  testWidgets('opening peak search closes peak popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    final searchPeaksFab = find.byKey(const Key('search-peaks-fab'));
    await tester.ensureVisible(searchPeaksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(searchPeaksFab).onPressed!();
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
    expect(container.read(mapProvider).showPeakSearch, isTrue);
  });

  testWidgets('peak popup shows MGRS row under map row', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
          gridZoneDesignator: '55G',
          mgrs100kId: 'DM',
          easting: '80000',
          northing: '95000',
        ),
      ),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Map: Adamsons'), findsOneWidget);
    expect(find.text('MGRS: 55G DM 80000 95000'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Map: Adamsons')).dy,
      lessThan(tester.getTopLeft(find.text('MGRS: 55G DM 80000 95000')).dy),
    );
  });

  testWidgets('peak popup shows singular trimmed list label', (tester) async {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: '  Abels  ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
        PeakList(
          name: '   ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 2),
          ]),
        )..peakListId = 2,
      ]),
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
      peakListRepository: peakListRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('List: Abels'), findsOneWidget);
    expect(find.textContaining('Lists:'), findsNothing);
  });

  testWidgets('peak popup shows plural trimmed list label and MGRS', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'HWC  ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Abels  ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 2),
          ]),
        )..peakListId = 2,
      ]),
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
          gridZoneDesignator: '55G',
          mgrs100kId: 'DM',
          easting: '80000',
          northing: '95000',
        ),
      ),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
      peakListRepository: peakListRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Height: 1234 m'), findsOneWidget);
    expect(find.text('Map: Adamsons'), findsOneWidget);
    expect(find.text('MGRS: 55G DM 80000 95000'), findsOneWidget);
    expect(find.text('Lists: Abels, HWC'), findsOneWidget);
  });

  testWidgets('peak popup shows drop marker button and my ascents', (
    tester,
  ) async {
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(
          baggedId: 1,
          peakId: 6406,
          gpxId: 11,
          date: DateTime.utc(2026, 5, 16),
        ),
        PeaksBagged(
          baggedId: 2,
          peakId: 6406,
          gpxId: 10,
          date: DateTime.utc(2026, 5, 16),
        ),
      ]),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([
        GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Alpha Loop',
          trackDate: DateTime.utc(2026, 5, 16),
        ),
        GpxTrack(
          gpxTrackId: 11,
          contentHash: 'hash-11',
          trackName: 'Beta Loop',
          trackDate: DateTime.utc(2026, 5, 16),
        ),
      ]),
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
      peaksBaggedRepository: peaksBaggedRepository,
      gpxTrackRepository: gpxTrackRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Close Peak Info'), findsOneWidget);
    expect(find.byTooltip('Drop a Marker on the Peak'), findsOneWidget);
    expect(
      find.byKey(const Key('peak-info-popup-drop-marker')),
      findsOneWidget,
    );
    expect(find.text('Height: 1234 m'), findsOneWidget);
    expect(find.text('My Ascents:'), findsOneWidget);
    expect(find.text('Alpha Loop (16 May 2026)'), findsOneWidget);
    expect(find.text('Beta Loop (16 May 2026)'), findsOneWidget);
  });

  testWidgets('drop marker updates selected location without recentering', (
    tester,
  ) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        selectedLocation: const LatLng(-42.5, 146.5),
        peak: peak,
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final before = container.read(mapProvider);

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-drop-marker')));
    await tester.pump();

    final after = container.read(mapProvider);
    expect(after.selectedLocation, isNotNull);
    expect(after.selectedLocation!.latitude, closeTo(peak.latitude, 1e-9));
    expect(after.selectedLocation!.longitude, closeTo(peak.longitude, 1e-9));
    expect(after.center, equals(before.center));
    expect(after.zoom, equals(before.zoom));
    expect(find.byKey(const Key('peak-info-popup')), findsNothing);
  });

  testWidgets('open popup refreshes ascent rows when bagged revision changes', (
    tester,
  ) async {
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(
          baggedId: 1,
          peakId: 6406,
          gpxId: 10,
          date: DateTime.utc(2026, 5, 15),
        ),
      ]),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([
        GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Old Loop',
          trackDate: DateTime.utc(2026, 5, 15),
        ),
        GpxTrack(
          gpxTrackId: 11,
          contentHash: 'hash-11',
          trackName: 'New Loop',
          trackDate: DateTime.utc(2026, 5, 16),
        ),
      ]),
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
      peaksBaggedRepository: peaksBaggedRepository,
      gpxTrackRepository: gpxTrackRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Old Loop (15 May 2026)'), findsOneWidget);
    expect(find.text('New Loop (16 May 2026)'), findsNothing);

    await peaksBaggedRepository.rebuildFromTracks([
      GpxTrack(
          gpxTrackId: 11,
          contentHash: 'hash-11',
          trackName: 'New Loop',
          trackDate: DateTime.utc(2026, 5, 16),
        )
        ..peaks.add(
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
        ),
    ]);
    container.read(peaksBaggedRevisionProvider.notifier).increment();
    await tester.pump();

    expect(find.text('Old Loop (15 May 2026)'), findsNothing);
    expect(find.text('New Loop (16 May 2026)'), findsOneWidget);
    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
  });

  testWidgets('peak popup shows non-empty alternate name after title', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          altName: '  Kunanyi foothill  ',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bonnet Hill'), findsOneWidget);
    expect(find.text('Alt Name: Kunanyi foothill'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bonnet Hill')).dy,
      lessThan(tester.getTopLeft(find.text('Alt Name: Kunanyi foothill')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Alt Name: Kunanyi foothill')).dy,
      lessThan(tester.getTopLeft(find.text('Height: 1234 m')).dy),
    );
  });

  testWidgets('peak popup derives map from lat lng when MGRS is incomplete', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final mapCenter = tasmapRepository.getMapCenter(
      tasmapRepository.getAllMaps().first,
    )!;

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        center: mapCenter,
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          latitude: mapCenter.latitude,
          longitude: mapCenter.longitude,
        ),
      ),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Map: Adamsons'), findsOneWidget);
  });

  testWidgets(
    'peak popup hides whitespace-only MGRS and keeps lat lng map fallback',
    (tester) async {
      final tasmapRepository = await TestTasmapRepository.create();
      final mapCenter = tasmapRepository.getMapCenter(
        tasmapRepository.getAllMaps().first,
      )!;

      await _pumpMap(
        tester,
        _mapStateWithPeak(
          center: mapCenter,
          peak: Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: mapCenter.latitude,
            longitude: mapCenter.longitude,
            gridZoneDesignator: ' 55G ',
            mgrs100kId: '   ',
            easting: ' 80000 ',
            northing: ' 95000 ',
          ),
        ),
        overrides: [
          tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(tasmapRepository),
          ),
        ],
      );

      final region = find.byKey(const Key('map-interaction-region'));
      await tester.tapAt(tester.getCenter(region));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Map: Adamsons'), findsOneWidget);
      expect(find.textContaining('MGRS:'), findsNothing);
    },
  );

  testWidgets('peak popup falls back to unknown map and omits empty lists', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create(maps: []);

    await _pumpMap(
      tester,
      _mapStateWithPeak(),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Map: Unknown'), findsOneWidget);
    expect(find.textContaining('Alt Name:'), findsNothing);
    expect(find.textContaining('List(s):'), findsNothing);
  });

  testWidgets(
    'select peaks FAB opens drawer and none/all peaks update markers',
    (tester) async {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Alpha',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 6406, points: 1),
            ]),
          )..peakListId = 1,
          PeakList(
            name: 'Zero',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 9999, points: 1),
            ]),
          )..peakListId = 4,
        ]),
      );
      await _pumpMap(
        tester,
        _mapStateWithPeak(),
        peakListRepository: peakListRepository,
      );

      final region = find.byKey(const Key('map-interaction-region'));
      final container = ProviderScope.containerOf(tester.element(region));

      expect(find.byKey(const Key('peak-marker-layer')), findsOneWidget);

      final showPeaksFab = find.byKey(const Key('show-peaks-fab'));
      await tester.ensureVisible(showPeaksFab);
      await tester.pumpAndSettle();
      await tester.tap(showPeaksFab);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-lists-drawer')), findsOneWidget);
      expect(find.text('Peak Lists'), findsOneWidget);

      await tester.tap(find.byKey(const Key('peak-list-item-Alpha')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('peak-list-item-Alpha')));
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.none,
      );
      expect(find.byKey(const Key('peak-marker-layer')), findsNothing);

      await tester.tap(find.byKey(const Key('peak-list-item-All Peaks')));
      await tester.pumpAndSettle();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.allPeaks,
      );
      expect(find.byKey(const Key('peak-marker-layer')), findsOneWidget);
    },
  );

  testWidgets('drawer follows cursor region and updates live', (tester) async {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Bravo',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 7000, points: 2),
            const PeakListItem(peakOsmId: 9999, points: 1),
          ]),
        )..peakListId = 2,
        PeakList(name: 'Broken', peakList: '{"oops":true}')..peakListId = 3,
        PeakList(
          name: 'Alpha',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Zero',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 9999, points: 1),
          ]),
        )..peakListId = 4,
      ]),
    );

    await _pumpMap(
      tester,
      MapState(
        center: const LatLng(-43.0, 147.0),
        cursorPoint: const LatLng(-44.0, 148.8867),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
          Peak(
            osmId: 7000,
            name: 'Other Peak',
            latitude: -37.75984,
            longitude: 158.7979,
          ),
        ],
      ),
      peakListRepository: peakListRepository,
    );

    final showPeaksFab = find.byKey(const Key('show-peaks-fab'));
    await tester.ensureVisible(showPeaksFab);
    await tester.pumpAndSettle();
    await tester.tap(showPeaksFab);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    expect(find.byKey(const Key('peak-list-item-Alpha')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-item-Zero')), findsNothing);
    expect(find.byKey(const Key('peak-list-item-Bravo')), findsNothing);
    expect(find.byKey(const Key('peak-list-item-Broken')), findsNothing);
    expect(find.text('1 renderable peak'), findsOneWidget);
    expect(find.textContaining('0 renderable peaks'), findsNothing);

    container
        .read(mapProvider.notifier)
        .setCursorMgrs(const LatLng(-37.75984, 158.7979));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-item-Alpha')), findsNothing);
    expect(find.byKey(const Key('peak-list-item-Bravo')), findsOneWidget);
    expect(find.text('1 renderable peak'), findsOneWidget);
  });

  testWidgets('drawer falls back to all peaks when no lists render', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      MapState(
        center: const LatLng(-43.0, 147.0),
        cursorPoint: const LatLng(0, 0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
        ],
      ),
      peakListRepository: PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Zero',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 9999, points: 1),
            ]),
          )..peakListId = 4,
          PeakList(name: 'Broken', peakList: '{not-json}')..peakListId = 5,
        ]),
      ),
    );

    final showPeaksFab = find.byKey(const Key('show-peaks-fab'));
    await tester.ensureVisible(showPeaksFab);
    await tester.pumpAndSettle();
    await tester.tap(showPeaksFab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-item-All Peaks')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-item-Zero')), findsNothing);
    expect(find.byKey(const Key('peak-list-item-Broken')), findsNothing);
    expect(find.textContaining('renderable peak'), findsNothing);
  });

  testWidgets(
    'drawer shows all peaks and unavailable message on repository error',
    (tester) async {
      await _pumpMap(
        tester,
        _mapStateWithPeak(),
        peakListRepository: PeakListRepository.test(_ThrowingPeakListStorage()),
      );

      final showPeaksFab = find.byKey(const Key('show-peaks-fab'));
      await tester.ensureVisible(showPeaksFab);
      await tester.pumpAndSettle();
      await tester.tap(showPeaksFab);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-list-item-All Peaks')), findsOneWidget);
      expect(
        find.byKey(const Key('peak-list-selection-unavailable-message')),
        findsOneWidget,
      );
      expect(find.textContaining('renderable peak'), findsNothing);
    },
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapState state, {
  overrides = const [],
  PeakRepository? peakRepository,
  PeakListRepository? peakListRepository,
  PeaksBaggedRepository? peaksBaggedRepository,
  GpxTrackRepository? gpxTrackRepository,
}) async {
  final tasmapRepository = await TestTasmapRepository.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(state, peakRepository: peakRepository),
        ),
        peakListRepositoryProvider.overrideWithValue(
          peakListRepository ??
              PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          peaksBaggedRepository ??
              PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(
          gpxTrackRepository ??
              GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
      child: ProviderScope(
        overrides: [...overrides],
        child: const MaterialApp(home: MapScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

MapState _mapStateWithPeak({
  LatLng center = const LatLng(-43.0, 147.0),
  LatLng? selectedLocation,
  bool showInfoPopup = false,
  Peak? peak,
}) {
  return MapState(
    center: center,
    zoom: 15,
    basemap: Basemap.tracestrack,
    selectedLocation: selectedLocation,
    showInfoPopup: showInfoPopup,
    peaks: [
      peak ??
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
    ],
  );
}

class _ThrowingPeakListStorage extends InMemoryPeakListStorage {
  @override
  List<PeakList> getAll() {
    throw StateError('boom');
  }
}

class _StaticPeakMarkerInfoNotifier extends PeakMarkerInfoSettingsNotifier {
  _StaticPeakMarkerInfoNotifier(this.value);

  final bool value;

  @override
  bool build() => value;
}
