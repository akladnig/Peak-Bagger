import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/services/natural_feature_admin_editor.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

void main() {
  final feature = NaturalFeature(
    id: 7,
    name: 'Blue Lake',
    tag: 'water',
    latitude: 46.8,
    longitude: 13.5,
    gridZoneDesignator: '33T',
    mgrs100kId: 'WN',
    easting: '00000',
    northing: '00000',
    osmId: 123,
    osmType: 'way',
  );
  final entity = ObjectBoxAdminEntityDescriptor(
    name: 'NaturalFeature',
    displayName: 'Natural Features',
    primaryKeyField: 'id',
    primaryNameField: 'name',
    fields: const [
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
        name: 'tag',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'country',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'county',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'region',
        typeLabel: 'String',
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
        name: 'osmId',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'osmType',
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

  Widget buildPane({required bool locked}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 800,
        child: ObjectBoxAdminDetailsPane(
          row: naturalFeatureToAdminRow(feature),
          entity: entity,
          peakList: null,
          route: null,
          naturalFeature: feature,
          isCreatingPeak: false,
          isNaturalFeatureMutationLocked: locked,
          createOsmId: 0,
          onClose: () {},
          onViewPeakOnMap: (_) {},
          onViewGpxTrackOnMap: null,
          onViewRouteOnMap: null,
          onPeakSubmit: (_) async => null,
          onPeakListSubmit: (_) async => null,
          onRouteSubmit: (_) async => null,
          onNaturalFeatureSubmit: (_) async => null,
        ),
      ),
    ),
  );

  testWidgets(
    'natural feature editor exposes identity as read-only and locks mutations',
    (tester) async {
      await tester.pumpWidget(buildPane(locked: false));
      await tester.tap(
        find.byKey(const Key('objectbox-admin-natural-feature-edit')),
      );
      await tester.pumpAndSettle();

      for (final field in ['id', 'osmType', 'osmId', 'gridZoneDesignator']) {
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(Key('objectbox-admin-natural-feature-$field')),
              )
              .enabled,
          isFalse,
        );
      }
      expect(
        find.byKey(const Key('objectbox-admin-natural-feature-save')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('objectbox-admin-peak-add')), findsNothing);

      await tester.pumpWidget(buildPane(locked: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('objectbox-admin-natural-feature-save')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  test(
    'NaturalFeatureAdminEditor retains a stored grid zone for MGRS input',
    () {
      final result = NaturalFeatureAdminEditor.validateAndBuild(
        source: feature,
        coordinateSource: NaturalFeatureAdminCoordinateSource.mgrs,
        form: NaturalFeatureAdminEditor.normalize(feature),
      );

      expect(result.naturalFeature?.gridZoneDesignator, '33T');
    },
  );
}
