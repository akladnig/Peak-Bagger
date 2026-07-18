import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';

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

  testWidgets('admin browser opens Route details pane', (tester) async {
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([
        app_route.Route(
          id: 1,
          name: 'Mt Ossa Route',
          gpxRoute: const [LatLng(-41.5, 146.5)],
          displayRoutePointsByZoom: '{}',
        ),
      ]),
    );

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(),
      routeRepository: routeRepository,
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Ossa Route'));
    await tester.pumpAndSettle();

    expect(find.text('Mt Ossa Route').last, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('objectbox-admin-details-list')),
        matching: find.widgetWithText(ListTile, 'name'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('objectbox-admin-route-view-on-map')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('objectbox-admin-route-edit')), findsOneWidget);
    expect(
      find.byKey(const Key('objectbox-admin-details-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('objectbox-admin-route-delete-1')),
      findsOneWidget,
    );
    expect(find.text('0x00000000'), findsOneWidget);
    expect(find.text('gpxRouteJson').last, findsOneWidget);
    expect(find.text('displayRoutePointsByZoom').last, findsOneWidget);

    await tester.tap(find.byKey(const Key('objectbox-admin-route-edit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('objectbox-admin-route-save')), findsOneWidget);
    expect(find.byKey(const Key('objectbox-admin-route-name')), findsOneWidget);
    expect(find.byKey(const Key('objectbox-admin-route-id')), findsOneWidget);
  });

  testWidgets('route save refreshes the selected row', (tester) async {
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([
        app_route.Route(
          id: 1,
          name: 'Mt Ossa Route',
          desc: 'A scenic route',
          gpxRoute: const [LatLng(-41.5, 146.5)],
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
        ),
      ]),
    );
    final repository = _RouteAwareObjectBoxAdminRepository(
      base: TestObjectBoxAdminRepository(),
      routeRepository: routeRepository,
    );

    await _pumpApp(
      tester,
      repository: repository,
      routeRepository: routeRepository,
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Ossa Route'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-route-edit')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-route-name')),
      'Updated Route',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('objectbox-admin-route-visible')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('objectbox-admin-route-edit-form')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-route-visible')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-route-save')));
    await tester.pumpAndSettle();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(find.text('Updated Route updated.'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('objectbox-admin-route-update-success-close')),
    );
    await tester.pumpAndSettle();

    expect(routeRepository.findById(1)?.name, 'Updated Route');
    expect(routeRepository.findById(1)?.visible, isFalse);
    expect(find.text('Updated Route'), findsWidgets);
  });

  testWidgets('route delete refreshes the route table', (tester) async {
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([
        app_route.Route(
          id: 1,
          name: 'Mt Ossa Route',
          gpxRoute: const [LatLng(-41.5, 146.5)],
          displayRoutePointsByZoom: '{}',
        ),
      ]),
    );
    final repository = _RouteAwareObjectBoxAdminRepository(
      base: TestObjectBoxAdminRepository(),
      routeRepository: routeRepository,
    );

    await _pumpApp(
      tester,
      repository: repository,
      routeRepository: routeRepository,
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Ossa Route'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-route-delete-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete Route?'), findsOneWidget);
    expect(
      find.text(
        'This will permanently delete the Mt Ossa Route. Do you want to proceed?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(routeRepository.findById(1), isNull);
    expect(
      find.byKey(const Key('objectbox-admin-route-delete-1')),
      findsNothing,
    );
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
    expect(find.text('Mt Ossa').last, findsOneWidget);

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-delete-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-2')),
      findsNothing,
    );
    expect(find.text('Mt Ossa').last, findsOneWidget);
    expect(find.text('Mt Ossa'), findsWidgets);
  });

  testWidgets('admin browser opens GpxTrack details pane', (tester) async {
    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        rowsByEntity: {
          'GpxTrack': [
            const ObjectBoxAdminRow(
              primaryKeyValue: 1,
              values: {'gpxTrackId': 1, 'trackName': 'Ridge Walk'},
            ),
          ],
        },
      ),
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GpxTrack').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ridge Walk'));
    await tester.pumpAndSettle();

    expect(find.text('Ridge Walk'), findsWidgets);
    expect(
      find.byKey(const Key('objectbox-admin-details-close')),
      findsOneWidget,
    );
  });

  testWidgets('PeakList exposes edit without add or delete actions', (
    tester,
  ) async {
    await _pumpApp(tester, repository: TestObjectBoxAdminRepository());

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PeakList').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abels'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('objectbox-admin-peak-list-edit')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('objectbox-admin-peak-add')), findsNothing);
    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-1')),
      findsNothing,
    );
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Abels'), findsWidgets);
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
    final nameBefore = tester.getTopLeft(nameCell).dx;

    controller.jumpTo(controller.offset + 200);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(nameCell).dx, closeTo(nameBefore, 0.1));
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
    expect(
      find.descendant(
        of: find.byKey(const Key('objectbox-admin-details-list')),
        matching: find.widgetWithText(ListTile, 'trackName'),
      ),
      findsNothing,
    );
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
        ObjectBoxAdminFieldDescriptor(
          name: 'averageSpeedKmh',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'movingSpeedKmh',
          typeLabel: 'double',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'maxSpeedKmh',
          typeLabel: 'double',
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
              'startDateTime': DateTime.utc(2025, 3, 10, 8, 0),
              'endDateTime': DateTime.utc(2025, 3, 10, 8, 54, 35),
              'totalTimeMillis': 3275000,
              'movingTime': 30000,
              'restingTime': 1505000,
              'pausedTime': 1740000,
              'averageSpeedKmh': 8.2,
              'movingSpeedKmh': 8.4,
              'maxSpeedKmh': 12.1,
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
    expect(find.text('averageSpeedKmh'), findsWidgets);
    expect(find.text('movingSpeedKmh'), findsWidgets);
    expect(find.text('maxSpeedKmh'), findsWidgets);
    final detailsScrollable = find
        .descendant(
          of: find.byKey(const Key('objectbox-admin-details-list')),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.text('totalTimeMillis').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('00:54:35'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('movingTime').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('00:00:30'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('restingTime').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('00:25:05'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('pausedTime').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('00:29:00'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('averageSpeedKmh').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('8.2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('movingSpeedKmh').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('8.4'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('maxSpeedKmh').last,
      200,
      scrollable: detailsScrollable,
    );
    expect(find.text('12.1'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  ObjectBoxAdminRepository? repository,
  List<ObjectBoxAdminEntityDescriptor>? entities,
  PeakRepository? peakRepository,
  PeakListRepository? peakListRepository,
  PeakDeleteGuard? peakDeleteGuard,
  RouteRepository? routeRepository,
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
        routeRepositoryProvider.overrideWithValue(
          routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
        ),
        peakListRepositoryProvider.overrideWithValue(
          peakListRepository ??
              PeakListRepository.test(
                InMemoryPeakListStorage([
                  PeakList(
                    peakListId: 1,
                    name: 'Abels',
                    region: 'tasmania',
                    peakList: '[{"peakOsmId":101,"points":"3"}]',
                    colour: 0xFF4C8BF5,
                  ),
                ]),
              ),
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
        name: 'region',
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
      'region': peak.region,
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
  List<PeakListItemEntity> loadPeakListItems() => const [];

  @override
  List<PeaksBagged> loadPeaksBagged() => const [];
}
