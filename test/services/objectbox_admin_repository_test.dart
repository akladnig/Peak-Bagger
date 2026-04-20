import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
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
      'PeakList',
      'PeaksBagged',
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
        'osmId',
        'name',
        'elevation',
        'latitude',
        'longitude',
        'area',
        'gridZoneDesignator',
        'mgrs100kId',
        'easting',
        'northing',
        'sourceOfTruth',
      ]),
    );
    expect(entities[2].primaryKeyField, 'gpxTrackId');
    expect(entities[2].primaryNameField, 'trackName');
    expect(
      entities[2].fields.map((field) => field.name),
      containsAll([
        'gpxTrackId',
        'trackName',
        'trackDate',
        'startDateTime',
        'endDateTime',
        'peakCorrelationProcessed',
        'peaks',
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
        'totalTimeMillis',
        'movingTime',
        'restingTime',
        'pausedTime',
      ]),
    );
    expect(
      entities[2].fields
          .singleWhere((field) => field.name == 'peaks')
          .typeLabel,
      'relation<Peak>',
    );
    expect(entities[3].primaryKeyField, 'peakListId');
    expect(entities[3].primaryNameField, 'name');
    expect(
      entities[3].fields.map((field) => field.name),
      containsAll(['peakListId', 'name', 'peakList']),
    );
    expect(entities[4].primaryKeyField, 'baggedId');
    expect(
      entities[4].fields.map((field) => field.name),
      containsAll(['baggedId', 'peakId', 'gpxId', 'date']),
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

  test('peakToAdminRow includes the MGRS fields', () {
    final row = peakToAdminRow(
      Peak(
        id: 42,
        osmId: 4242,
        name: 'Mount Milner',
        latitude: -41.2,
        longitude: 146.1,
        gridZoneDesignator: '55G',
        mgrs100kId: 'DN',
        easting: '17710',
        northing: '03594',
        sourceOfTruth: Peak.sourceOfTruthHwc,
      ),
    );

    expect(row.primaryKeyValue, 42);
    expect(row.values['osmId'], 4242);
    expect(row.values['gridZoneDesignator'], '55G');
    expect(row.values['mgrs100kId'], 'DN');
    expect(row.values['easting'], '17710');
    expect(row.values['northing'], '03594');
    expect(row.values['sourceOfTruth'], Peak.sourceOfTruthHwc);
  });

  test('gpxTrackToAdminRow includes correlation fields', () {
    final track =
        GpxTrack(
            gpxTrackId: 7,
            contentHash: 'hash',
            trackName: 'Mt Ossa',
            trackDate: DateTime.utc(2024, 1, 15),
            startDateTime: DateTime.utc(2024, 1, 15, 1, 0),
            endDateTime: DateTime.utc(2024, 1, 15, 2, 30),
            totalTimeMillis: 5400000,
            movingTime: 4800000,
            restingTime: 300000,
            pausedTime: 90000,
            peakCorrelationProcessed: true,
          )
          ..peaks.addAll([
            Peak(osmId: 11, name: 'Peak A', latitude: -41.0, longitude: 146.0),
            Peak(osmId: 22, name: 'Peak B', latitude: -41.1, longitude: 146.1),
          ]);

    final row = gpxTrackToAdminRow(track);

    expect(row.values['trackDate'], DateTime.utc(2024, 1, 15));
    expect(row.values['startDateTime'], DateTime.utc(2024, 1, 15, 1, 0));
    expect(row.values['endDateTime'], DateTime.utc(2024, 1, 15, 2, 30));
    expect(row.values['totalTimeMillis'], 5400000);
    expect(row.values['movingTime'], 4800000);
    expect(row.values['restingTime'], 300000);
    expect(row.values['pausedTime'], 90000);
    expect(row.values['peakCorrelationProcessed'], isTrue);
    expect(row.values['peaks'], ['Peak A (11)', 'Peak B (22)']);
  });

  test('peakListToAdminRow includes previewable payload fields', () {
    final row = peakListToAdminRow(
      PeakList(
        peakListId: 9,
        name: 'Abels',
        peakList:
            '[{"peakOsmId":101,"points":"3"},{"peakOsmId":202,"points":"6"}]',
      ),
    );

    expect(row.primaryKeyValue, 9);
    expect(row.values['peakListId'], 9);
    expect(row.values['name'], 'Abels');
    expect(
      objectBoxAdminPreviewValue(row.values['peakList']),
      contains('peakOsmId'),
    );
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
