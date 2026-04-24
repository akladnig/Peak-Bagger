import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_objectbox_admin_repository.dart';

void main() {
  testWidgets('admin browser filters rows and closes details pane', (
    tester,
  ) async {
    await _pumpApp(tester, repository: TestObjectBoxAdminRepository());

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('objectbox-admin-peak-add')), findsOneWidget);
    expect(find.byKey(const Key('objectbox-admin-peak-edit')), findsOneWidget);
    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-1')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('objectbox-admin-details-close')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-details-close')));
    await tester.pumpAndSettle();

    expect(find.text('Select a row to inspect full values.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cradle');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('Peak delete refresh keeps other selection intact', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa'),
      _buildPeak(id: 2, osmId: 202, name: 'Ossa Spur'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final peakRepository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: peakRepository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    expect(find.text('Peak #1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-delete-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-2')),
      findsNothing,
    );
    expect(find.text('Peak #1'), findsOneWidget);
    expect(find.text('Mt Ossa'), findsWidgets);
  });

  testWidgets('non-Peak entities stay browse-only', (tester) async {
    await _pumpApp(tester, repository: TestObjectBoxAdminRepository());

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PeakList').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('objectbox-admin-peak-edit')), findsNothing);
    expect(find.byKey(const Key('objectbox-admin-peak-add')), findsNothing);
    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-1')),
      findsNothing,
    );
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('admin browser loads rows in chunks of 50', (tester) async {
    final rows = List<ObjectBoxAdminRow>.generate(
      60,
      (index) => ObjectBoxAdminRow(
        primaryKeyValue: index + 1,
        values: {'id': index + 1, 'name': 'Peak $index'},
      ),
    );

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        rowsByEntity: {
          'Peak': rows,
          'Tasmap50k': const [],
          'GpxTrack': const [],
        },
      ),
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Peak 59'), findsNothing);

    final rowList = find.byKey(const Key('objectbox-admin-row-list'));
    await tester.drag(rowList, const Offset(0, -3000));
    await tester.pumpAndSettle();

    if (find.text('Peak 59').evaluate().isEmpty) {
      await tester.drag(rowList, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }

    expect(find.text('Peak 59'), findsOneWidget);
  });

  testWidgets('admin browser scrolls header with rows', (tester) async {
    final rows = List<ObjectBoxAdminRow>.generate(
      60,
      (index) => ObjectBoxAdminRow(
        primaryKeyValue: index + 1,
        values: {'id': index + 1, 'name': 'Peak $index'},
      ),
    );

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        rowsByEntity: {
          'Peak': rows,
          'Tasmap50k': const [],
          'GpxTrack': const [],
        },
      ),
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final header = find.byKey(const Key('objectbox-admin-header-row'));
    final rowList = find.byKey(const Key('objectbox-admin-row-list'));
    final initialTop = tester.getTopLeft(header).dy;

    await tester.drag(rowList, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(header).dy, closeTo(initialTop, 0.1));
  });

  testWidgets('admin browser keeps first column fixed horizontally', (
    tester,
  ) async {
    const entity = ObjectBoxAdminEntityDescriptor(
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
          name: 'area',
          typeLabel: 'double',
          nullable: false,
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
          name: 'elevation',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'prominence',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    );

    final rows = List<ObjectBoxAdminRow>.generate(
      20,
      (index) => ObjectBoxAdminRow(
        primaryKeyValue: index + 1,
        values: {
          'id': index + 1,
          'name': 'Peak $index',
          'area': 1000.0 + index,
          'latitude': -41.0 - index,
          'longitude': 146.0 + index,
          'elevation': 100 + index,
          'prominence': 300 + index,
        },
      ),
    );

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [entity],
        rowsByEntity: {'Peak': rows},
      ),
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    final horizontalScrollView = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    final scrollView = tester.widget<SingleChildScrollView>(
      horizontalScrollView.first,
    );
    final controller = scrollView.controller!;

    final nameCell = find.text('Peak 0');
    final rowOneCell = find.text('1000.0');
    final rowTwoCell = find.text('1001.0');
    final nameBefore = tester.getTopLeft(nameCell).dx;
    final rowOneBefore = tester.getTopLeft(rowOneCell).dx;
    final rowTwoBefore = tester.getTopLeft(rowTwoCell).dx;

    controller.jumpTo(200);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(nameCell).dx, closeTo(nameBefore, 0.1));
    expect(tester.getTopLeft(rowOneCell).dx, isNot(closeTo(rowOneBefore, 0.1)));
    expect(tester.getTopLeft(rowTwoCell).dx, isNot(closeTo(rowTwoBefore, 0.1)));
  });

  testWidgets('gpx track export appears only for gpx rows', (tester) async {
    final entity = ObjectBoxAdminEntityDescriptor(
      name: 'GpxTrack',
      displayName: 'GpxTrack',
      primaryKeyField: 'gpxTrackId',
      primaryNameField: 'trackName',
      fields: const [
        ObjectBoxAdminFieldDescriptor(
          name: 'gpxTrackId',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: true,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'trackName',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: true,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'gpxFile',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'filteredTrack',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    );

    final repository = TestObjectBoxAdminRepository(
      entities: [entity],
      rowsByEntity: {
        'GpxTrack': [
          ObjectBoxAdminRow(
            primaryKeyValue: 7,
            values: {
              'gpxTrackId': 7,
              'trackName': 'Mt Anne',
              'gpxFile': '<gpx><trk></trk></gpx>',
              'filteredTrack': '<gpx><trk></trk></gpx>',
            },
          ),
        ],
      },
    );

    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('objectbox-admin-export-gpx')), findsOneWidget);
    expect(find.text('No gpxFile selected'), findsOneWidget);

    await tester.tap(find.text('Mt Anne'));
    await tester.pumpAndSettle();

    expect(find.text('No gpxFile selected'), findsNothing);
    expect(find.widgetWithText(ListTile, 'filteredTrack'), findsOneWidget);

    await tester.tap(find.byKey(const Key('objectbox-admin-export-gpx')));
    await tester.pumpAndSettle();

    expect(repository.exportCallCount, 1);
    expect(repository.exportedRow!.values['gpxFile'], '<gpx><trk></trk></gpx>');
  });

  testWidgets('gpx track rows show elevation stats in details', (tester) async {
    final entity = ObjectBoxAdminEntityDescriptor(
      name: 'GpxTrack',
      displayName: 'GpxTrack',
      primaryKeyField: 'gpxTrackId',
      primaryNameField: 'trackName',
      fields: const [
        ObjectBoxAdminFieldDescriptor(
          name: 'gpxTrackId',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: true,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'trackName',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: true,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'filteredTrack',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'distance2d',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'distance3d',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'distanceToPeak',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'distanceFromPeak',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'lowestElevation',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'highestElevation',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'descent',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'startElevation',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'endElevation',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'elevationProfile',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    );

    final repository = TestObjectBoxAdminRepository(
      entities: [entity],
      rowsByEntity: {
        'GpxTrack': [
          ObjectBoxAdminRow(
            primaryKeyValue: 7,
            values: {
              'gpxTrackId': 7,
              'trackName': 'Mt Anne',
              'filteredTrack':
                  '<gpx><trk><trkseg><trkpt lat="-42.12340000" lon="146.12340000"/></trkseg></trk></gpx>',
              'distance2d': 1234,
              'distance3d': 0,
              'distanceToPeak': 0,
              'distanceFromPeak': 0,
              'lowestElevation': 0,
              'highestElevation': 0,
              'descent': 0,
              'startElevation': 0,
              'endElevation': 0,
              'elevationProfile':
                  '[{"segmentIndex":0,"pointIndex":0,"distanceMeters":0.0,"elevationMeters":100.0,"timeLocal":null}]',
            },
          ),
        ],
      },
    );

    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Anne'));
    await tester.pumpAndSettle();

    final distance2dTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'distance2d'),
    );
    final detailsScrollable = find
        .descendant(
          of: find.byKey(const Key('objectbox-admin-details-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    expect((distance2dTile.subtitle as SelectableText).data, '1234');

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'filteredTrack'),
      200,
      scrollable: detailsScrollable,
    );
    expect(
      (tester
                  .widget<ListTile>(
                    find.widgetWithText(ListTile, 'filteredTrack'),
                  )
                  .subtitle
              as SelectableText)
          .data,
      contains('<gpx><trk>'),
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'distance3d'),
      200,
      scrollable: detailsScrollable,
    );
    expect(
      (tester
                  .widget<ListTile>(find.widgetWithText(ListTile, 'distance3d'))
                  .subtitle
              as SelectableText)
          .data,
      '0',
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'descent'),
      200,
      scrollable: detailsScrollable,
    );
    expect(
      (tester
                  .widget<ListTile>(find.widgetWithText(ListTile, 'descent'))
                  .subtitle
              as SelectableText)
          .data,
      '0',
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'startElevation'),
      200,
      scrollable: detailsScrollable,
    );
    expect(
      (tester
                  .widget<ListTile>(
                    find.widgetWithText(ListTile, 'startElevation'),
                  )
                  .subtitle
              as SelectableText)
          .data,
      '0',
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'endElevation'),
      200,
      scrollable: detailsScrollable,
    );
    expect(
      (tester
                  .widget<ListTile>(
                    find.widgetWithText(ListTile, 'endElevation'),
                  )
                  .subtitle
              as SelectableText)
          .data,
      '0',
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'elevationProfile'),
      200,
      scrollable: detailsScrollable,
    );
    expect(
      (tester
                  .widget<ListTile>(
                    find.widgetWithText(ListTile, 'elevationProfile'),
                  )
                  .subtitle
              as SelectableText)
          .data,
      contains('segmentIndex'),
    );
  });

  testWidgets('gpx track rows show time stats in schema', (tester) async {
    final entity = ObjectBoxAdminEntityDescriptor(
      name: 'GpxTrack',
      displayName: 'GpxTrack',
      primaryKeyField: 'gpxTrackId',
      primaryNameField: 'trackName',
      fields: const [
        ObjectBoxAdminFieldDescriptor(
          name: 'gpxTrackId',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: true,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'trackName',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: true,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'filteredTrack',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'startDateTime',
          typeLabel: 'DateTime',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'endDateTime',
          typeLabel: 'DateTime',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'totalTimeMillis',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'movingTime',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'restingTime',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'pausedTime',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    );

    final repository = TestObjectBoxAdminRepository(
      entities: [entity],
      rowsByEntity: {
        'GpxTrack': [
          ObjectBoxAdminRow(
            primaryKeyValue: 7,
            values: {
              'gpxTrackId': 7,
              'trackName': 'Mt Anne',
              'filteredTrack':
                  '<gpx><trk><trkseg><trkpt lat="-42.12340000" lon="146.12340000"/></trkseg></trk></gpx>',
              'startDateTime': DateTime.utc(2024, 1, 15, 1, 0),
              'endDateTime': DateTime.utc(2024, 1, 15, 2, 30),
              'totalTimeMillis': 5400000,
              'movingTime': 4800000,
              'restingTime': 300000,
              'pausedTime': 90000,
            },
          ),
        ],
      },
    );

    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Anne'));
    await tester.pumpAndSettle();

    expect(find.text('startDateTime'), findsWidgets);
    expect(find.text('endDateTime'), findsWidgets);
    expect(find.text('totalTimeMillis'), findsWidgets);
    expect(find.text('movingTime'), findsWidgets);
    expect(find.text('restingTime'), findsWidgets);
    expect(find.text('pausedTime'), findsWidgets);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  TestObjectBoxAdminRepository? repository,
  List<ObjectBoxAdminEntityDescriptor>? entities,
  PeakRepository? peakRepository,
  PeakDeleteGuard? peakDeleteGuard,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
            peakRepository:
                peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
          ),
        ),
        objectboxAdminRepositoryProvider.overrideWithValue(
          repository ?? TestObjectBoxAdminRepository(entities: entities),
        ),
        if (peakRepository != null)
          peakRepositoryProvider.overrideWithValue(peakRepository),
        if (peakDeleteGuard != null)
          peakDeleteGuardProvider.overrideWithValue(peakDeleteGuard),
        if (peakRepository == null)
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
        if (peakDeleteGuard == null)
          peakDeleteGuardProvider.overrideWithValue(
            PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
          ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
}

Peak _buildPeak({required int id, required int osmId, required String name}) {
  final location = const LatLng(-41.5, 146.5);
  final components = PeakMgrsConverter.fromLatLng(location);
  return Peak(
    id: id,
    osmId: osmId,
    name: name,
    latitude: location.latitude,
    longitude: location.longitude,
    gridZoneDesignator: components.gridZoneDesignator,
    mgrs100kId: components.mgrs100kId,
    easting: components.easting,
    northing: components.northing,
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
        name: 'osmId',
        typeLabel: 'int',
        nullable: false,
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
        name: 'area',
        typeLabel: 'String',
        nullable: true,
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
  return ObjectBoxAdminRow(
    primaryKeyValue: peak.id,
    values: {
      'id': peak.id,
      'osmId': peak.osmId,
      'name': peak.name,
      'latitude': peak.latitude,
      'longitude': peak.longitude,
      'area': peak.area,
      'gridZoneDesignator': peak.gridZoneDesignator,
      'mgrs100kId': peak.mgrs100kId,
      'easting': peak.easting,
      'northing': peak.northing,
      'sourceOfTruth': peak.sourceOfTruth,
    },
  );
}

class _MutablePeakRepository extends PeakRepository {
  _MutablePeakRepository(this._peaks, this._rowsByEntity)
    : super.test(InMemoryPeakStorage(_peaks));

  final List<Peak> _peaks;
  final Map<String, List<ObjectBoxAdminRow>> _rowsByEntity;

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
  Future<void> delete(int peakId) async {
    _peaks.removeWhere((peak) => peak.id == peakId);
    _rowsByEntity['Peak'] = _peaks.map(_peakRow).toList(growable: false);
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
