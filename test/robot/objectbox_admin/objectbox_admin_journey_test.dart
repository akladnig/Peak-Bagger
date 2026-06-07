import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';

import '../../harness/test_objectbox_admin_repository.dart';
import 'objectbox_admin_robot.dart';

void main() {
  testWidgets('admin shell edits and saves a peak row', (tester) async {
    final robot = ObjectBoxAdminRobot(tester);
    final peak = _buildPeak(
      id: 1,
      osmId: 101,
      name: 'Mt Ossa',
      region: 'Old Area',
    );
    final peaks = [peak];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': [_peakRow(peak)],
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final peakRepository = _MutablePeakRepository(peaks, rowsByEntity);

    await robot.pumpApp(
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: peakRepository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await robot.openAdminFromMenu();
    await robot.selectRow('Mt Ossa');
    await robot.startEditingPeak();
    await robot.enterPeakField('name', 'Mt Ossa Peak');
    await robot.enterPeakAltName('Ossa');
    await robot.setPeakVerified(verified: true);
    await robot.submitPeakEdit();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(find.text('Mt Ossa Peak updated.'), findsOneWidget);

    await robot.closePeakSuccessDialog();

    final editContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final editMapState = editContainer.read(mapProvider);
    expect(editMapState.peaks, hasLength(1));
    expect(editMapState.peaks.single.name, 'Mt Ossa Peak');
    expect(editMapState.peaks.single.altName, 'Ossa');
    expect(editMapState.peaks.single.verified, isTrue);
    expect(peakRepository.findById(1)?.name, 'Mt Ossa Peak');
    expect(peakRepository.findById(1)?.altName, 'Ossa');
    expect(peakRepository.findById(1)?.verified, isTrue);
    expect(find.text('Mt Ossa Peak'), findsWidgets);
  });

  testWidgets('admin shell browses a Route row', (tester) async {
    final robot = ObjectBoxAdminRobot(tester);

    await robot.pumpApp(repository: TestObjectBoxAdminRepository());

    await robot.openAdminFromMenu();
    await tester.tap(robot.entityDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route').last);
    await tester.pumpAndSettle();

    await robot.selectRow('Mt Ossa Route');

    expect(find.text('Route #1'), findsOneWidget);
    expect(find.text('gpxRouteJson').last, findsOneWidget);
    expect(
      find.byKey(const Key('objectbox-admin-details-close')),
      findsOneWidget,
    );
  });

  testWidgets('admin shell routes, edits, and deletes a Route row', (
    tester,
  ) async {
    final robot = ObjectBoxAdminRobot(tester);
    final route = app_route.Route(
      id: 1,
      name: 'Mt Ossa Route',
      desc: 'A scenic route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      displayRoutePointsByZoom: '{}',
      colour: 0,
      distance2d: 12.5,
      distance3d: 13.2,
      ascent: 850,
      descent: 840,
      startElevation: 120,
      endElevation: 1210,
      lowestElevation: 110,
      highestElevation: 1600,
    );
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([route]),
    );
    final objectboxRepository = _RouteAwareObjectBoxAdminRepository(
      base: TestObjectBoxAdminRepository(),
      routeRepository: routeRepository,
    );

    await robot.pumpApp(
      repository: objectboxRepository,
      routeRepository: routeRepository,
    );

    await robot.openAdminFromMenu();
    await tester.tap(robot.entityDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route').last);
    await tester.pumpAndSettle();

    await robot.selectRow('Mt Ossa Route');
    await robot.viewRouteOnMainMap();

    expect(
      find.descendant(of: robot.appBarTitle, matching: find.text('Map')),
      findsOneWidget,
    );
    final mapContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    expect(mapContainer.read(mapProvider).selectedRouteId, 1);
    expect(mapContainer.read(mapProvider).selectedTrackId, isNull);
    expect(mapContainer.read(mapProvider).showRoutes, isTrue);

    await robot.openAdminFromMenu();
    await robot.selectRow('Mt Ossa Route');
    await robot.startEditingRoute();
    await robot.enterRouteField('name', 'Updated Route');
    await robot.submitRouteEdit();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(find.text('Updated Route updated.'), findsOneWidget);

    await robot.closeRouteSuccessDialog();
    expect(routeRepository.findById(1)?.name, 'Updated Route');
    expect(find.text('Updated Route'), findsWidgets);

    await robot.deleteRoute(1);
    expect(find.text('Delete Route?'), findsOneWidget);
    expect(
      find.text(
        'This will permanently delete the Updated Route. Do you want to proceed?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(routeRepository.findById(1), isNull);
    expect(find.byKey(const Key('objectbox-admin-route-delete-1')), findsNothing);

    await tester.tap(find.byKey(const Key('nav-map')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: robot.appBarTitle, matching: find.text('Map')),
      findsOneWidget,
    );
    expect(mapContainer.read(mapProvider).selectedRouteId, isNull);
  });

  testWidgets(
    'admin shell calculates and saves synchronized peak coordinates',
    (tester) async {
      final robot = ObjectBoxAdminRobot(tester);
      final peak = _buildPeak(
        id: 1,
        osmId: 101,
        name: 'Mt Ossa',
        region: 'Old Area',
      );
      final peaks = [peak];
      final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
        'Peak': [_peakRow(peak)],
        'PeakList': const [],
        'Tasmap50k': const [],
        'GpxTrack': const [],
        'PeaksBagged': const [],
      };
      final peakRepository = _MutablePeakRepository(peaks, rowsByEntity);
      final expectedComponents = PeakMgrsConverter.fromLatLng(
        const LatLng(-41.6, 146.5),
      );

      await robot.pumpApp(
        repository: TestObjectBoxAdminRepository(
          entities: [_peakEntity()],
          rowsByEntity: rowsByEntity,
        ),
        peakRepository: peakRepository,
        peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
      );

      await robot.openAdminFromMenu();
      await robot.selectRow('Mt Ossa');
      await robot.startEditingPeak();
      await robot.enterPeakField('latitude', '-41.600000');
      await robot.calculatePeakCoordinates();
      await robot.submitPeakEdit();

      expect(find.text('Update Successful'), findsOneWidget);

      final saved = peakRepository.findById(1)!;
      expect(saved.latitude, -41.6);
      expect(saved.longitude, 146.5);
      expect(saved.mgrs100kId, expectedComponents.mgrs100kId);
      expect(saved.easting, expectedComponents.easting);
      expect(saved.northing, expectedComponents.northing);
    },
  );

  testWidgets('admin shell adds a peak row from the add button', (
    tester,
  ) async {
    final robot = ObjectBoxAdminRobot(tester);
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', region: 'Old Area'),
      _buildPeak(id: 2, osmId: 202, name: 'Ossa Spur', region: 'Far East'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final peakRepository = _MutablePeakRepository(peaks, rowsByEntity);

    await robot.pumpApp(
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: peakRepository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await robot.openAdminFromMenu();
    expect(robot.addPeakButton, findsOneWidget);

    await robot.startCreatingPeak();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(robot.peakField('osmId')).controller!.text,
      '-1',
    );
    await robot.enterPeakField('name', 'New Peak');
    await robot.enterPeakField('osmId', '303');
    await robot.enterPeakField('latitude', '-41.5');
    await robot.enterPeakField('longitude', '146.5');
    await tester.pumpAndSettle();
    await robot.submitPeakEdit();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(find.text('New Peak updated.'), findsOneWidget);

    await robot.closePeakSuccessDialog();

    final createContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final createMapState = createContainer.read(mapProvider);
    expect(createMapState.peaks, hasLength(3));
    expect(
      createMapState.peaks.singleWhere((peak) => peak.osmId == 303).name,
      'New Peak',
    );
    expect(
      createContainer.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
      3,
    );
    expect(peakRepository.findByOsmId(303)?.name, 'New Peak');
    expect(find.text('Peak #3'), findsOneWidget);
  });

  testWidgets('admin shell views a peak on the main map', (tester) async {
    final robot = ObjectBoxAdminRobot(tester);
    final peak = _buildPeak(
      id: 1,
      osmId: 101,
      name: 'Mt Ossa',
      region: 'Old Area',
    );
    final peaks = [peak];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': [_peakRow(peak)],
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final peakRepository = _MutablePeakRepository(peaks, rowsByEntity);

    await robot.pumpApp(
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: peakRepository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await robot.openAdminFromMenu();
    await robot.selectRow('Mt Ossa');

    expect(robot.peakViewOnMapButton, findsOneWidget);

    await robot.viewPeakOnMainMap();

    expect(
      find.descendant(of: robot.appBarTitle, matching: find.text('Map')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final mapState = container.read(mapProvider);
    expect(mapState.center.latitude, closeTo(peak.latitude, 0.001));
    expect(mapState.center.longitude, closeTo(peak.longitude, 0.001));
    expect(mapState.zoom, MapConstants.defaultZoom);
    expect(mapState.selectedLocation, isNotNull);
  });
}

Peak _buildPeak({
  required int id,
  required int osmId,
  required String name,
  String altName = '',
  String? region,
  bool verified = false,
}) {
  final location = const LatLng(-41.5, 146.5);
  final components = PeakMgrsConverter.fromLatLng(location);
  return Peak(
    id: id,
    osmId: osmId,
    name: name,
    altName: altName,
    latitude: location.latitude,
    longitude: location.longitude,
    region: region,
    gridZoneDesignator: components.gridZoneDesignator,
    mgrs100kId: components.mgrs100kId,
    easting: components.easting,
    northing: components.northing,
    verified: verified,
  );
}

ObjectBoxAdminEntityDescriptor _peakEntity() {
  return const ObjectBoxAdminEntityDescriptor(
    name: 'Peak',
    displayName: 'Peak',
    primaryKeyField: 'id',
    primaryNameField: 'name',
    fields: [
      ObjectBoxAdminFieldDescriptor(
        name: 'id',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: true,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'name',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: true,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'altName',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'osmId',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'region',
        typeLabel: 'String',
        nullable: true,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'latitude',
        typeLabel: 'double',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'longitude',
        typeLabel: 'double',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'gridZoneDesignator',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'mgrs100kId',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'easting',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'northing',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'verified',
        typeLabel: 'bool',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'sourceOfTruth',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
    ],
  );
}

ObjectBoxAdminRow _peakRow(Peak peak) {
  return peakToAdminRow(peak);
}

class _MutablePeakRepository extends PeakRepository {
  _MutablePeakRepository(this._peaks, this._rowsByEntity)
    : super.test(InMemoryPeakStorage(_peaks));

  final List<Peak> _peaks;
  final Map<String, List<ObjectBoxAdminRow>> _rowsByEntity;

  @override
  List<Peak> getAllPeaks() => List<Peak>.unmodifiable(_peaks);

  @override
  Peak? findByOsmId(int osmId) {
    for (final peak in _peaks) {
      if (peak.osmId == osmId) {
        return peak;
      }
    }
    return null;
  }

  @override
  Peak? findById(int peakId) {
    for (final peak in _peaks) {
      if (peak.id == peakId) {
        return peak;
      }
    }
    return null;
  }

  @override
  Future<PeakSaveResult> saveDetailed(Peak peak) async {
    final index = _peaks.indexWhere((entry) => entry.id == peak.id);
    final saved = peak.copyWith();
    if (index == -1) {
      saved.id = peak.id == 0 ? _peaks.length + 1 : peak.id;
      _peaks.add(saved);
    } else {
      saved.id = peak.id;
      _peaks[index] = saved;
    }

    _rowsByEntity['Peak'] = _peaks.map(_peakRow).toList(growable: false);
    return PeakSaveResult(peak: saved);
  }
}

class _RouteAwareObjectBoxAdminRepository implements ObjectBoxAdminRepository {
  _RouteAwareObjectBoxAdminRepository({
    required this.base,
    required this.routeRepository,
  });

  final TestObjectBoxAdminRepository base;
  final RouteRepository routeRepository;

  @override
  List<ObjectBoxAdminEntityDescriptor> getEntities() => base.getEntities();

  @override
  Future<List<ObjectBoxAdminRow>> loadRows(
    ObjectBoxAdminEntityDescriptor entity, {
    required String searchQuery,
    required bool ascending,
  }) async {
    if (entity.name == 'Route') {
      return objectBoxAdminFilterAndSortRows(
        entity,
        rows: routeRepository.getAllRoutes().map(routeToAdminRow).toList(),
        searchQuery: searchQuery,
        ascending: ascending,
      );
    }

    return base.loadRows(
      entity,
      searchQuery: searchQuery,
      ascending: ascending,
    );
  }

  @override
  Future<String> exportGpxFile(ObjectBoxAdminRow row) {
    return base.exportGpxFile(row);
  }
}

class _NoopPeakDeleteGuardSource implements PeakDeleteGuardSource {
  @override
  List<GpxTrack> loadGpxTracks() => const [];

  @override
  List<PeakList> loadPeakLists() => const [];

  @override
  List<PeaksBagged> loadPeaksBagged() => const [];
}
