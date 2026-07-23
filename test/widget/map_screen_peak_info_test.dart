import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/peak_marker_info_settings_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_peak_layer.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_admin_editor.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';
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

  testWidgets('main-map markers omit ownership rings for single-list peaks', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(),
      overrides: [
        peakOwnershipRingSegmentsProvider.overrideWithValue(
          const <int, List<PeakOwnershipRingSegment>>{},
        ),
      ],
    );

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('peak-marker-paint')))
                .painter!
            as PeakViewportPainter;

    expect(painter.individuals.single.ownershipRingSegments, isEmpty);
  });

  testWidgets('main-map markers expose ownership rings for multi-list peaks', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak().copyWith(
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {9, 2},
        previousSpecificPeakListIds: {9, 2},
      ),
      peakListRepository: _peakListRepository([
        (
          peakList: PeakList(
            peakListId: 9,
            name: 'Abels',
            colour: 0xFF4C8BF5,
          ),
          items: const [PeakListItem(peakOsmId: 6406, points: 0)],
        ),
        (
          peakList: PeakList(
            peakListId: 2,
            name: 'HWC Peak Baggers',
            colour: 0xFF6347EA,
          ),
          items: const [PeakListItem(peakOsmId: 6406, points: 0)],
        ),
      ]),
      overrides: [
        peakOwnershipRingSettingsProvider.overrideWith(
          _StaticPeakOwnershipRingNotifier.new,
        ),
      ],
    );

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('peak-marker-paint')))
                .painter!
            as PeakViewportPainter;

    expect(
      painter.individuals.single.ownershipRingSegments
          .map((segment) => segment.peakListId)
          .toList(),
      [9, 2],
    );
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

  testWidgets('peak popup edit action is shown before drop marker', (
    tester,
  ) async {
    final content = PeakInfoContent(
      peak: Peak(
        id: 1,
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -43.0,
        longitude: 147.0,
      ),
      mapName: 'Adamsons',
      mapNameOrigin: MapNameOrigin.sheet,
      listNames: const [],
      ascentRows: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PeakInfoPopupCard(
              content: content,
              onClose: () {},
              onEdit: () {},
              onSaveEdit: (_) async => null,
              onDropMarker: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('peak-info-popup-edit'))).dx,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('peak-info-popup-drop-marker')))
            .dx,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PeakInfoPopupCard(
              content: content,
              onClose: () {},
              onDropMarker: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit')), findsNothing);
  });

  testWidgets('editing hovered peak pins popup and shows inline form', (
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

    expect(container.read(mapProvider).isPeakInfoHovered, isTrue);

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).isPeakInfoPinned, isTrue);
    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsOneWidget);
    expect(find.byKey(const Key('peak-info-popup-drop-marker')), findsNothing);
  });

  testWidgets('typing in inline edit field keeps popup open', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-info-popup-name')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsOneWidget);
  });

  testWidgets('top-right close icon closes popup during inline editing', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-info-popup-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup')), findsNothing);
    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsNothing);
  });

  testWidgets('inline popup edit shows saving feedback and saves peak', (
    tester,
  ) async {
    final peak = Peak(
      id: 1,
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = _DelayedPeakRepository(
      const Duration(milliseconds: 50),
      InMemoryPeakStorage([peak]),
    );

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

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-info-popup-name')),
      'Bonnet Hill Summit',
    );
    await tester.enterText(
      find.byKey(const Key('peak-info-popup-elevation')),
      '1234',
    );

    await tester.tap(find.byKey(const Key('peak-info-popup-save')));
    await tester.pump();

    expect(find.text('Saving...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsNothing);
    expect(
      container.read(mapProvider).peakInfoPeak?.name,
      'Bonnet Hill Summit',
    );
    expect(find.text('Bonnet Hill Summit'), findsOneWidget);
    expect(find.text('Height: 1234 m'), findsOneWidget);

    final saved = peakRepository.findById(1)!;
    expect(saved.name, 'Bonnet Hill Summit');
    expect(saved.elevation, 1234);
    expect(saved.sourceOfTruth, Peak.sourceOfTruthHwc);
    expect(saved.verified, isTrue);
  });

  testWidgets('inline popup edit validates name and elevation', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('peak-info-popup-name')), '');
    await tester.enterText(
      find.byKey(const Key('peak-info-popup-elevation')),
      'abc',
    );

    await tester.tap(find.byKey(const Key('peak-info-popup-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsOneWidget);
    expect(find.text(PeakAdminEditor.nameRequiredError), findsOneWidget);
    expect(find.text(PeakAdminEditor.elevationError), findsOneWidget);
  });

  testWidgets('inline popup edit preserves draft on save failure', (
    tester,
  ) async {
    final peakRepository = _ThrowingPeakRepository();

    await _pumpMap(tester, _mapStateWithPeak(), peakRepository: peakRepository);

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-info-popup-name')),
      'Broken Name',
    );

    await tester.tap(find.byKey(const Key('peak-info-popup-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsOneWidget);
    expect(find.byKey(const Key('peak-info-popup-error')), findsOneWidget);
    expect(find.textContaining('Failed to save peak:'), findsOneWidget);

    final nameField = tester.widget<TextField>(
      find.byKey(const Key('peak-info-popup-name')),
    );
    expect(nameField.controller?.text, 'Broken Name');
  });

  testWidgets('edit in peak admin button hides during inline editing', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('peak-info-popup-edit-admin')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit-admin')), findsNothing);
  });

  testWidgets('footer text buttons align to the right edge', (tester) async {
    final content = PeakInfoContent(
      peak: Peak(
        id: 1,
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -43.0,
        longitude: 147.0,
      ),
      mapName: 'Adamsons',
      mapNameOrigin: MapNameOrigin.sheet,
      listNames: const [],
      ascentRows: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PeakInfoPopupCard(
              key: const Key('peak-info-popup-card-under-test'),
              content: content,
              onClose: () {},
              onEdit: () async {},
              onSaveEdit: (_) async => null,
              onEditInAdmin: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final popupRight = tester
        .getTopRight(find.byKey(const Key('peak-info-popup-card-under-test')))
        .dx;
    final adminButtonRight = tester
        .getTopRight(find.byKey(const Key('peak-info-popup-edit-admin')))
        .dx;

    expect(popupRight - adminButtonRight, inInclusiveRange(0, 16));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();

    final saveRight = tester
        .getTopRight(find.byKey(const Key('peak-info-popup-save')))
        .dx;

    expect(popupRight - saveRight, inInclusiveRange(0, 16));
  });

  testWidgets('move to marker is disabled without a persisted marker', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();

    final moveRow = tester.widget<InkWell>(
      find.byKey(const Key('peak-info-popup-move-to-marker')),
    );
    expect(moveRow.onTap, isNull);
  });

  testWidgets('move to marker updates draft MGRS from persisted marker', (
    tester,
  ) async {
    final markerLocation = const LatLng(-42.9995, 147.0005);
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    await waypointsRepository.saveMarker(
      location: markerLocation,
      name: 'Saved',
    );
    final marker = waypointsRepository.getCurrentMarker()!;
    final expected = PeakMgrsConverter.fromLatLng(
      LatLng(marker.latitude, marker.longitude),
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(),
      waypointsRepository: waypointsRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-info-popup-move-to-marker')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'MGRS: ${expected.gridZoneDesignator} ${expected.mgrs100kId} ${expected.easting} ${expected.northing}',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-info-popup-error')), findsNothing);
  });

  testWidgets('move to marker preserves original draft on invalid marker', (
    tester,
  ) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'DM',
      easting: '80000',
      northing: '95000',
    );
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    await waypointsRepository.saveMarker(
      location: const LatLng(-35.0, 146.5),
      name: 'Outside',
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(peak: peak),
      waypointsRepository: waypointsRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-info-popup-move-to-marker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-error')), findsOneWidget);
    expect(find.text(PeakAdminEditor.tasmaniaError), findsOneWidget);
    expect(find.text('MGRS: 55G DM 80000 95000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-info-popup-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-info-popup-edit-form')), findsNothing);
    expect(find.text('MGRS: 55G DM 80000 95000'), findsOneWidget);
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

  testWidgets('non-peak click opens chooser without selecting location', (
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
    expect(state.selectedLocation, isNull);
    expect(find.byKey(const Key('map-tap-action-popup')), findsOneWidget);
  });

  testWidgets('background click closes open peak popup and opens chooser', (
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

    await tester.tapAt(center + const Offset(-100, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak, isNull);
    expect(state.selectedLocation, isNull);
    expect(find.byKey(const Key('map-tap-action-popup')), findsOneWidget);
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

  testWidgets('opening Search popup closes peak popup', (tester) async {
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
    expect(find.byKey(const Key('map-search-input')), findsOneWidget);
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
    final peakListRepository = _peakListRepository([
      (
        peakList: PeakList(name: '  Abels  ')..peakListId = 1,
        items: const [PeakListItem(peakOsmId: 6406, points: 1)],
      ),
      (
        peakList: PeakList(name: '   ')..peakListId = 2,
        items: const [PeakListItem(peakOsmId: 6406, points: 2)],
      ),
    ]);

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
    final peakListRepository = _peakListRepository([
      (
        peakList: PeakList(name: 'HWC  ')..peakListId = 1,
        items: const [PeakListItem(peakOsmId: 6406, points: 1)],
      ),
      (
        peakList: PeakList(name: 'Abels  ')..peakListId = 2,
        items: const [PeakListItem(peakOsmId: 6406, points: 2)],
      ),
    ]);

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

  testWidgets('drop marker persists singleton marker row', (tester) async {
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
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
      waypointsRepository: waypointsRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('peak-info-popup-drop-marker')));
    await tester.pump();

    final marker = waypointsRepository.getCurrentMarker();
    expect(marker, isNotNull);
    expect(marker!.name, 'Bonnet Hill');
    expect(marker.type, 'marker');
    expect(marker.latitude, closeTo(-43.0, 1e-9));
    expect(marker.longitude, closeTo(147.0, 1e-9));
    expect(marker.mgrs, isNotEmpty);
  });

  test('map startup restores persisted marker without moving camera', () async {
    final tasmapRepository = await TestTasmapRepository.create();
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage([
        Waypoints(
          id: 2,
          name: 'Saved Marker',
          type: Waypoints.typeMarker,
          latitude: -42.6,
          longitude: 146.6,
          mgrs: '55G EN 34028 50395',
        ),
      ]),
    );
    final center = const LatLng(-41.5, 146.5);

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: GpxTrackRepository.test(
              InMemoryGpxTrackStorage(),
            ),
            routeRepository: routeRepository,
            routeElevationSampler: const NoopRouteElevationSampler(),
            routePlanner: _NoopRoutePlanner(),
            peaksBaggedRepository: PeaksBaggedRepository.test(
              InMemoryPeaksBaggedStorage(),
            ),
            waypointsRepository: waypointsRepository,
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(mapProvider).center, center);
    expect(
      container.read(mapProvider).selectedLocation,
      const LatLng(-42.6, 146.6),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);

    expect(state.center, center);
    expect(state.selectedLocation, const LatLng(-42.6, 146.6));
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

  testWidgets('peak popup falls back to region and omits empty lists', (
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

    expect(find.text('Region: Tasmanian'), findsOneWidget);
    expect(find.textContaining('Alt Name:'), findsNothing);
    expect(find.textContaining('List(s):'), findsNothing);
  });

  testWidgets('mgrs readout falls back to region when no sheet matches', (
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

    final mapNameRichText = tester.widget<RichText>(
      find
          .descendant(
            of: find.byKey(const Key('map-mgrs-readout')),
            matching: find.byType(RichText),
          )
          .first,
    );

    expect(mapNameRichText.text.toPlainText(), 'Tasmanian');
  });

  testWidgets(
    'select peaks FAB opens drawer and none/all peaks update markers',
    (tester) async {
      final peakListRepository = _peakListRepository([
        (
          peakList: PeakList(name: 'Alpha')..peakListId = 1,
          items: const [PeakListItem(peakOsmId: 6406, points: 1)],
        ),
        (
          peakList: PeakList(name: 'Zero')..peakListId = 4,
          items: const [PeakListItem(peakOsmId: 9999, points: 1)],
        ),
      ]);
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

  testWidgets('drawer shows legacy Tasmania list values in Tasmania only', (
    tester,
  ) async {
    final peakListRepository = _peakListRepository([
      (
        peakList: PeakList(name: 'Bravo', region: 'new-south-wales')..peakListId = 2,
        items: const [
          PeakListItem(peakOsmId: 7000, points: 2),
          PeakListItem(peakOsmId: 9999, points: 1),
        ],
      ),
      (
        peakList: PeakList(name: 'Alpha', region: '')..peakListId = 1,
        items: const [PeakListItem(peakOsmId: 6406, points: 1)],
      ),
      (
        peakList: PeakList(name: 'Zero', region: 'victoria')..peakListId = 4,
        items: const [PeakListItem(peakOsmId: 9999, points: 1)],
      ),
      (peakList: PeakList(name: 'Broken', region: 'tasmania')..peakListId = 3, items: const []),
    ]);

    await _pumpMap(
      tester,
      MapState(
        center: const LatLng(-44.0, 148.8867),
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

    expect(find.byKey(const Key('peak-list-item-All Peaks')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-item-Alpha')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-item-Zero')), findsNothing);
    expect(find.byKey(const Key('peak-list-item-Broken')), findsNothing);

    container
        .read(mapProvider.notifier)
        .updateVisibleBounds(
          LatLngBounds(const LatLng(-34.5, 147.0), const LatLng(-33.0, 150.5)),
        );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-item-Alpha')), findsNothing);
    expect(find.byKey(const Key('peak-list-item-Bravo')), findsOneWidget);
  });

  testWidgets('drawer falls back to all peaks when no lists render', (
    tester,
  ) async {
    final zero = PeakList(name: 'Zero', region: 'tasmania')..peakListId = 4;
    final broken = PeakList(name: 'Broken', region: 'tasmania')..peakListId = 5;
    await _pumpMap(
      tester,
      MapState(
        center: const LatLng(0, 0),
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
        InMemoryPeakListStorage([zero, broken]),
        itemStorage: InMemoryPeakListItemEntityStorage([
          PeakListItemEntity(id: 1, points: 1)
            ..peakList.target = zero
            ..peak.target = Peak(
              osmId: 9999,
              name: 'Missing',
              latitude: -43.0,
              longitude: 147.0,
            ),
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
  WaypointsRepository? waypointsRepository,
}) async {
  final tasmapRepository = await TestTasmapRepository.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            state,
            peakRepository: peakRepository,
            waypointsRepository: waypointsRepository,
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
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

PeakListRepository _peakListRepository(
  List<({PeakList peakList, List<PeakListItem> items})> definitions,
) {
  final peakLists = [for (final definition in definitions) definition.peakList];
  final peakListsById = {for (final peakList in peakLists) peakList.peakListId: peakList};
  final items = <PeakListItemEntity>[];
  var itemId = 1;
  for (final definition in definitions) {
    for (final item in definition.items) {
      items.add(
        PeakListItemEntity(id: itemId++, points: item.points)
          ..peakList.target = peakListsById[definition.peakList.peakListId]!
          ..peak.target = Peak(
            osmId: item.peakOsmId,
            name: 'Peak ${item.peakOsmId}',
            latitude: -42,
            longitude: 146,
          ),
      );
    }
  }

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    itemStorage: InMemoryPeakListItemEntityStorage(items),
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

class _StaticPeakOwnershipRingNotifier
    extends PeakOwnershipRingSettingsNotifier {
  @override
  bool build() => true;
}

class _DelayedPeakRepository extends PeakRepository {
  _DelayedPeakRepository(this.delay, PeakStorage storage) : super.test(storage);

  final Duration delay;

  @override
  Future<PeakSaveResult> saveDetailed(Peak peak) async {
    await Future<void>.delayed(delay);
    return super.saveDetailed(peak);
  }
}

class _ThrowingPeakRepository extends PeakRepository {
  _ThrowingPeakRepository()
    : super.test(
        InMemoryPeakStorage([
          Peak(
            id: 1,
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
        ]),
      );

  @override
  Future<PeakSaveResult> saveDetailed(Peak peak) async {
    throw StateError('boom');
  }
}

class _NoopRoutePlanner extends RoutePlanner {
  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    return PlannedRouteSegment(points: [start, end], distanceMeters: 0);
  }

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    return RoutePlanningResult(
      status: RoutePlanningStatus.routed,
      points: [start, end],
      distanceMeters: 0,
      startAnchor: RouteEndpointAnchor(
        point: start,
        type: RouteEndpointAnchorType.raw,
      ),
      endAnchor: RouteEndpointAnchor(
        point: end,
        type: RouteEndpointAnchorType.raw,
      ),
    );
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    return const RouteEndpointProbeResult(isOnTrack: false);
  }
}
