import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

void main() {
  test('getEntities exposes current schema metadata', () {
    final repository = ObjectBoxAdminRepositoryImpl(
      modelDefinition: getObjectBoxModel(),
    );

    final entities = repository.getEntities();

    expect(entities.map((entity) => entity.name), [
      'Peak',
      'Tasmap50k',
      'GpxTrack',
    ]);
    expect(entities.first.primaryKeyField, 'id');
    expect(entities.first.primaryNameField, 'name');
    expect(
      entities[1].fields.map((field) => field.name),
      containsAll([
        'id',
        'series',
        'name',
        'p1',
        'p2',
        'p3',
        'p4',
        'p5',
        'p6',
        'p7',
        'p8',
      ]),
    );
    expect(
      entities[1].fields.map((field) => field.name),
      isNot(contains('tl')),
    );
    expect(
      entities.first.fields.map((field) => field.name),
      containsAll([
        'id',
        'name',
        'elevation',
        'latitude',
        'longitude',
        'area',
        'gridZoneDesignator',
        'mgrs100kId',
        'easting',
        'northing',
      ]),
    );
    expect(entities.last.primaryKeyField, 'gpxTrackId');
    expect(entities.last.primaryNameField, 'trackName');
    expect(
      entities.last.fields.map((field) => field.name),
      containsAll([
        'gpxTrackId',
        'trackName',
        'distance2d',
        'distance3d',
        'distanceToPeak',
        'distanceFromPeak',
        'lowestElevation',
        'highestElevation',
        'ascent',
        'descent',
        'gpxFile',
        'filteredTrack',
        'startElevation',
        'endElevation',
        'elevationProfile',
      ]),
    );
  });

  test('filter/sort helper matches entity names case-insensitively', () {
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
      ],
    );

    final rows = objectBoxAdminFilterAndSortRows(
      entity,
      rows: const [
        ObjectBoxAdminRow(
          primaryKeyValue: 3,
          values: {'id': 3, 'name': 'Cradle'},
        ),
        ObjectBoxAdminRow(
          primaryKeyValue: 1,
          values: {'id': 1, 'name': 'Mt Ossa'},
        ),
        ObjectBoxAdminRow(
          primaryKeyValue: 2,
          values: {'id': 2, 'name': 'Ossa Spur'},
        ),
      ],
      searchQuery: 'OSSA',
      ascending: false,
    );

    expect(rows.map((row) => row.values['name']), ['Ossa Spur', 'Mt Ossa']);
  });

  test('exportGpxFile writes the selected track to downloads', () async {
    final tempDir = await Directory.systemTemp.createTemp('objectbox-admin');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repository = ObjectBoxAdminRepositoryImpl(
      downloadsDirectoryPath: tempDir.path,
    );

    final exportedPath = await repository.exportGpxFile(
      ObjectBoxAdminRow(
        primaryKeyValue: 7,
        values: {
          'gpxTrackId': 7,
          'trackName': 'Mt Ossa',
          'trackDate': DateTime(2024, 1, 15),
          'gpxFile': '<gpx><trk></trk></gpx>',
        },
      ),
    );

    final exportedFile = File(exportedPath);
    expect(exportedFile.existsSync(), isTrue);
    expect(await exportedFile.readAsString(), '<gpx><trk></trk></gpx>');
    expect(exportedPath, startsWith(tempDir.path));
  });
}
