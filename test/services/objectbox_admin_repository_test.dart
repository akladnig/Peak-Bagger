import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
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
      'Route',
      'RouteGraphChunk',
      'RouteGraphManifest',
      'RouteGraphWayIndex',
      'RouteGraphTrailDisplayChunk',
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
        'p9',
        'p10',
        'p11',
        'p12',
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
        'gpxFileRepaired',
        'filteredTrack',
        'startElevation',
        'endElevation',
        'elevationProfile',
        'totalTimeMillis',
        'movingTime',
        'restingTime',
        'pausedTime',
        'averageSpeedKmh',
        'movingSpeedKmh',
        'maxSpeedKmh',
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
    expect(entities[4].primaryNameField, 'gpxId');
    expect(
      entities[4].fields.map((field) => field.name),
      containsAll(['baggedId', 'peakId', 'gpxId', 'date']),
    );
    expect(
      entities[6].fields.map((field) => field.name),
      containsAll([
        'id',
        'recordKey',
        'chunkKey',
        'generation',
        'minLat',
        'minLon',
        'maxLat',
        'maxLon',
        'elementCount',
        'payloadJson',
      ]),
    );
    expect(entities[6].primaryKeyField, 'id');
    expect(entities[6].primaryNameField, 'chunkKey');
    expect(entities[5].primaryKeyField, 'id');
    expect(entities[5].primaryNameField, 'name');
    expect(
      entities[5].fields.map((field) => field.name),
      containsAll([
        'id',
        'name',
        'desc',
        'gpxRouteJson',
        'displayRoutePointsByZoom',
        'colour',
        'distance2d',
        'distance3d',
        'ascent',
        'descent',
        'startElevation',
        'endElevation',
        'lowestElevation',
        'highestElevation',
      ]),
    );
    expect(entities.last.primaryKeyField, 'id');
    expect(entities.last.primaryNameField, 'recordKey');
  });

  test('routeGraphChunkToAdminRow exposes chunk metadata', () {
    final row = routeGraphChunkToAdminRow(
      RouteGraphChunk(
        id: 42,
        recordKey: '7|0_0',
        chunkKey: '0_0',
        generation: 7,
        minLat: -42,
        minLon: 146,
        maxLat: -41,
        maxLon: 147,
        elementCount: 3,
        payloadJson: '{"elements":[]}',
      ),
    );

    expect(row.primaryKeyValue, 42);
    expect(row.values['recordKey'], '7|0_0');
    expect(row.values['chunkKey'], '0_0');
    expect(row.values['generation'], 7);
    expect(row.values['payloadJson'], '{"elements":[]}');
  });

  test('routeGraphManifestToAdminRow exposes manifest metadata', () {
    final row = routeGraphManifestToAdminRow(
      RouteGraphManifest(
        id: RouteGraphManifest.manifestId,
        sourceHash: 'source-hash',
        schemaVersion: 'route-graph-v1',
        activeGeneration: 7,
        importedAt: DateTime.utc(2025, 1, 2, 3, 4),
        chunkCount: 1,
        nodeCount: 2,
        edgeCount: 1,
        readinessState: RouteGraphManifest.readinessReady,
        lastError: 'none',
      ),
    );

    expect(row.primaryKeyValue, RouteGraphManifest.manifestId);
    expect(row.values['sourceHash'], 'source-hash');
    expect(row.values['schemaVersion'], 'route-graph-v1');
    expect(row.values['readinessState'], RouteGraphManifest.readinessReady);
    expect(row.values['lastError'], 'none');
  });

  test(
    'routeGraphTrailDisplayChunkToAdminRow exposes trail display metadata',
    () {
      final row = routeGraphTrailDisplayChunkToAdminRow(
        RouteGraphTrailDisplayChunk(
          id: 12,
          recordKey: '7|15|0_0',
          generation: 7,
          cacheZoom: 15,
          chunkKey: '0_0',
          payloadJson: '[]',
        ),
      );

      expect(row.primaryKeyValue, 12);
      expect(row.values['recordKey'], '7|15|0_0');
      expect(row.values['generation'], 7);
      expect(row.values['cacheZoom'], 15);
      expect(row.values['chunkKey'], '0_0');
      expect(row.values['payloadJson'], '[]');
    },
  );

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

  test(
    'filter/sort helper matches peak alternate names case-insensitively',
    () {
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
            name: 'altName',
            typeLabel: 'String',
            nullable: false,
            isPrimaryKey: false,
            isPrimaryName: false,
          ),
        ],
      );

      final rows = objectBoxAdminFilterAndSortRows(
        entity,
        rows: const [
          ObjectBoxAdminRow(
            primaryKeyValue: 3,
            values: {'id': 3, 'name': 'Cradle', 'altName': 'Mountain'},
          ),
          ObjectBoxAdminRow(
            primaryKeyValue: 1,
            values: {'id': 1, 'name': 'Mt Ossa', 'altName': 'Queen'},
          ),
          ObjectBoxAdminRow(
            primaryKeyValue: 2,
            values: {'id': 2, 'name': 'Pelion West', 'altName': 'Ossa Spur'},
          ),
        ],
        searchQuery: ' ossa ',
        ascending: true,
      );

      expect(rows.map((row) => row.values['name']), ['Mt Ossa', 'Pelion West']);
    },
  );

  test('filter/sort helper matches route names case-insensitively', () {
    const entity = ObjectBoxAdminEntityDescriptor(
      name: 'Route',
      displayName: 'Route',
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
          primaryKeyValue: 2,
          values: {'id': 2, 'name': 'Other Route'},
        ),
        ObjectBoxAdminRow(
          primaryKeyValue: 1,
          values: {'id': 1, 'name': 'Mt Ossa Route'},
        ),
      ],
      searchQuery: 'ossa',
      ascending: true,
    );

    expect(rows.map((row) => row.values['name']), ['Mt Ossa Route']);
  });

  test('formatFieldValue renders GpxTrack durations as hh:mm:ss', () {
    expect(
      objectBoxAdminFormatFieldValue(
        entityName: 'GpxTrack',
        fieldName: 'totalTimeMillis',
        value: 5400000,
      ),
      '01:30:00',
    );
    expect(
      objectBoxAdminFormatFieldValue(
        entityName: 'GpxTrack',
        fieldName: 'movingTime',
        value: 90061000,
      ),
      '25:01:01',
    );
    expect(
      objectBoxAdminFormatFieldValue(
        entityName: 'GpxTrack',
        fieldName: 'restingTime',
        value: 300000,
      ),
      '00:05:00',
    );
    expect(
      objectBoxAdminFormatFieldValue(
        entityName: 'GpxTrack',
        fieldName: 'pausedTime',
        value: null,
      ),
      '—',
    );
  });

  test('peakToAdminRow includes editable peak metadata', () {
    final row = peakToAdminRow(
      Peak(
        id: 42,
        osmId: 4242,
        name: 'Mount Milner',
        altName: 'Milner',
        latitude: -41.2,
        longitude: 146.1,
        gridZoneDesignator: '55G',
        mgrs100kId: 'DN',
        easting: '17710',
        northing: '03594',
        verified: true,
        sourceOfTruth: Peak.sourceOfTruthHwc,
      ),
    );

    expect(row.primaryKeyValue, 42);
    expect(row.values['osmId'], 4242);
    expect(row.values['altName'], 'Milner');
    expect(row.values['gridZoneDesignator'], '55G');
    expect(row.values['mgrs100kId'], 'DN');
    expect(row.values['easting'], '17710');
    expect(row.values['northing'], '03594');
    expect(row.values['verified'], isTrue);
    expect(row.values['sourceOfTruth'], Peak.sourceOfTruthHwc);
  });

  test('peakFromAdminRow reconstructs editable peak metadata', () {
    final peak = peakFromAdminRow(
      const ObjectBoxAdminRow(
        primaryKeyValue: 42,
        values: {
          'id': 42,
          'osmId': 4242,
          'name': 'Mount Milner',
          'altName': 'Milner',
          'elevation': 1200.0,
          'latitude': -41.2,
          'longitude': 146.1,
          'area': 'Central',
          'gridZoneDesignator': '55G',
          'mgrs100kId': 'DN',
          'easting': '17710',
          'northing': '03594',
          'verified': true,
          'sourceOfTruth': Peak.sourceOfTruthHwc,
        },
      ),
    );

    expect(peak.id, 42);
    expect(peak.altName, 'Milner');
    expect(peak.verified, isTrue);
  });

  test('routeToAdminRow exposes persisted route fields', () {
    final row = routeToAdminRow(
      Route(
        id: 7,
        name: 'Mt Ossa Route',
        desc: 'A scenic route',
        gpxRoute: [const LatLng(-41.5, 146.5)],
        gpxRouteElevations: [456],
        displayRoutePointsByZoom: '{"10":[]}',
        colour: 12,
        distance2d: 12.5,
        distance3d: 13.2,
        ascent: 850,
        descent: 840,
        startElevation: 120,
        endElevation: 1210,
        lowestElevation: 110,
        highestElevation: 1600,
      ),
    );

    expect(row.primaryKeyValue, 7);
    expect(row.values['name'], 'Mt Ossa Route');
    expect(row.values['desc'], 'A scenic route');
    expect(row.values['gpxRouteJson'], '[[-41.5,146.5,456]]');
    expect(row.values['displayRoutePointsByZoom'], '{"10":[]}');
    expect(row.values['colour'], 12);
    expect(row.values['distance2d'], 12.5);
    expect(row.values['highestElevation'], 1600);
  });

  test('peak admin field helpers expose required table and details order', () {
    final repository = ObjectBoxAdminRepositoryImpl(
      modelDefinition: getObjectBoxModel(),
    );
    final peakEntity = repository.getEntities().firstWhere(
      (entity) => entity.name == 'Peak',
    );

    expect(peakAdminTableFields(peakEntity).map((field) => field.name), [
      'name',
      'altName',
      'id',
      'elevation',
      'latitude',
      'longitude',
      'area',
      'gridZoneDesignator',
      'mgrs100kId',
      'easting',
      'northing',
      'verified',
      'osmId',
      'sourceOfTruth',
    ]);
    expect(peakAdminDetailsFields(peakEntity).map((field) => field.name), [
      'id',
      'name',
      'altName',
      'elevation',
      'latitude',
      'longitude',
      'area',
      'gridZoneDesignator',
      'mgrs100kId',
      'easting',
      'northing',
      'verified',
      'osmId',
      'sourceOfTruth',
    ]);
  });

  test('gpxTrackToAdminRow includes correlation fields', () {
    final track =
        GpxTrack(
            gpxTrackId: 7,
            contentHash: 'hash',
            trackName: 'Mt Ossa',
            trackDate: DateTime.utc(2025, 3, 10),
            startDateTime: DateTime.utc(2025, 3, 10, 8, 0),
            endDateTime: DateTime.utc(2025, 3, 10, 8, 54, 35),
            totalTimeMillis: 3275000,
            movingTime: 30000,
            restingTime: 1505000,
            pausedTime: 1740000,
            gpxFileRepaired: '<gpx><trkseg /></gpx>',
            peakCorrelationProcessed: true,
          )
          ..peaks.addAll([
            Peak(osmId: 11, name: 'Peak A', latitude: -41.0, longitude: 146.0),
            Peak(osmId: 22, name: 'Peak B', latitude: -41.1, longitude: 146.1),
          ]);

    final row = gpxTrackToAdminRow(track);

    expect(row.values['trackDate'], DateTime.utc(2025, 3, 10));
    expect(row.values['startDateTime'], DateTime.utc(2025, 3, 10, 8, 0));
    expect(row.values['endDateTime'], DateTime.utc(2025, 3, 10, 8, 54, 35));
    expect(row.values['totalTimeMillis'], 3275000);
    expect(row.values['movingTime'], 30000);
    expect(row.values['restingTime'], 1505000);
    expect(row.values['pausedTime'], 1740000);
    expect(row.values['gpxFileRepaired'], '<gpx><trkseg /></gpx>');
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

  test('peaksBaggedToAdminRow exposes scalar fields', () {
    final row = peaksBaggedToAdminRow(
      PeaksBagged(
        baggedId: 3,
        peakId: 11,
        gpxId: 7,
        date: DateTime.utc(2024, 1, 15),
      ),
    );

    expect(row.primaryKeyValue, 3);
    expect(row.values['peakId'], 11);
    expect(row.values['gpxId'], 7);
    expect(row.values['date'], DateTime.utc(2024, 1, 15));
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
