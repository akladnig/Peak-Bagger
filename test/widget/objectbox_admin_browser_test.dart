import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_objectbox_admin_repository.dart';

void main() {
  testWidgets('admin browser filters rows and closes details pane', (
    tester,
  ) async {
    await _pumpApp(tester, TestObjectBoxAdminRepository());

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();

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
      TestObjectBoxAdminRepository(
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
      TestObjectBoxAdminRepository(
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
      TestObjectBoxAdminRepository(
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
            },
          ),
        ],
      },
    );

    await _pumpApp(tester, repository);

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('objectbox-admin-export-gpx')), findsOneWidget);
    expect(find.text('No gpxFile selected'), findsOneWidget);

    await tester.tap(find.text('Mt Anne'));
    await tester.pumpAndSettle();

    expect(find.text('No gpxFile selected'), findsNothing);

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

    await _pumpApp(tester, repository);

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mt Anne'));
    await tester.pumpAndSettle();

    final distance2dTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'distance2d'),
    );
    final distance3dTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'distance3d'),
    );
    final detailsScrollable = find
        .descendant(
          of: find.byKey(const Key('objectbox-admin-details-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    expect((distance2dTile.subtitle as SelectableText).data, '1234');
    expect((distance3dTile.subtitle as SelectableText).data, '0');

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
}

Future<void> _pumpApp(
  WidgetTester tester,
  TestObjectBoxAdminRepository repository,
) async {
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
          ),
        ),
        objectboxAdminRepositoryProvider.overrideWithValue(repository),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
}
