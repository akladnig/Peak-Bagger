import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/objectbox_admin_field_policy.dart';
import 'package:objectbox/internal.dart' as obx;
import 'package:peak_bagger/services/route_timing_service.dart';

void main() {
  test(
    'reviewed app metadata covers exactly every persisted model member in order',
    () {
      final model = getObjectBoxModel();
      final repository = ObjectBoxAdminRepositoryImpl(modelDefinition: model);
      expect(repository.metadataCoverageIssues(), isEmpty);
      final entities = repository.getEntities();
      for (final entity in model.model.entities) {
        final descriptor = entities.singleWhere(
          (item) => item.name == entity.name,
        );
        final members = [
          ...entity.properties.map((p) => p.name),
          ...entity.relations.map((r) => r.name),
        ];
        expect(
          descriptor.fields.map((field) => field.name),
          members,
          reason: entity.name,
        );
        expect(
          descriptor.fields.map((field) => field.name).toSet(),
          hasLength(members.length),
        );
        expect(
          descriptor.fields.every((field) => field.metadata != null),
          isTrue,
        );
      }
      final broken = ObjectBoxAdminRepositoryImpl(
        appMetadata: {
          ...objectBoxAdminAppMetadata,
          'Contact': {
            'id': const AdminFieldMetadata('int'),
            'stale': const AdminFieldMetadata('String'),
          },
        },
      );
      expect(
        broken.metadataCoverageIssues(),
        containsAll(['Missing: Contact.firstName', 'Stale: Contact.stale']),
      );
    },
  );

  test(
    'schema semantics reflect declarations, not storage codes or record samples',
    () {
      final entities = ObjectBoxAdminRepositoryImpl().getEntities();
      ObjectBoxAdminFieldDescriptor field(String entity, String member) =>
          entities
              .singleWhere((e) => e.name == entity)
              .fields
              .singleWhere((f) => f.name == member);
      expect(
        field('Route', 'id').attributes,
        containsAll(['PK', 'Generated', 'Read-only']),
      );
      expect(
        field('Peak', 'id').attributes,
        containsAll(['PK', 'Assignable', 'Read-only']),
      );
      expect(field('Peak', 'id').attributes, isNot(contains('Generated')));
      expect(field('Peak', 'name').typeLabel, 'String');
      expect(field('Peak', 'name').attributes, [
        'Name',
        'Non-nullable',
        'Required',
      ]);
      expect(field('Peak', 'altName').attributes, ['Non-nullable']);
      expect(field('Peak', 'peakbaggerPid').typeLabel, 'int?');
      expect(field('Peak', 'peakbaggerPid').attributes, ['Nullable']);
      expect(field('Peak', 'osmId').isUnique, isTrue);
      expect(field('Contact', 'firstName').attributes, [
        'Name',
        'Non-nullable',
      ]);
      expect(field('GpxTrack', 'trackDate').typeLabel, 'DateTime?');
      expect(
        field('GpxTrack', 'trackDate').metadata!.dateMeaning,
        AdminDateMeaning.calendarDay,
      );
      expect(
        field('GpxTrack', 'trackDate').attributes,
        contains('Calendar day'),
      );
      expect(
        field('GpxTrack', 'startDateTime').metadata!.dateMeaning,
        AdminDateMeaning.timestamp,
      );
      expect(field('GpxTrack', 'peaks').typeLabel, 'ToMany<Peak>');
      expect(field('GpxTrack', 'peaks').relationshipTarget, 'Peak');
      final relation = field('PeakListItemEntity', 'peakListId');
      expect(relation.typeLabel, 'ToOne<PeakList>');
      expect(
        relation.attributes,
        containsAll(['Dart field: peakList', '→ PeakList', 'Read-only']),
      );
      expect(relation.attributes, isNot(contains('Required')));
      expect(field('PeaksBagged', 'peakId').typeLabel, 'int');
      expect(field('PeaksBagged', 'peakId').relationshipTarget, isNull);
      expect(field('Route', 'gpxRouteJson').typeLabel, 'String');
      expect(field('Route', 'gpxRouteJson').canEdit, isFalse);
      // Data's historical primary-column choices stay intact, independently of
      // whether the member is genuinely a display-name field in Schema.
      expect(field('RouteGraphChunk', 'chunkKey').isPrimaryName, isTrue);
      expect(
        field('RouteGraphChunk', 'chunkKey').attributes,
        isNot(contains('Name')),
      );
      expect(
        field('RouteGraphManifest', 'readinessState').isPrimaryName,
        isTrue,
      );
      expect(field('PeakListItemEntity', 'id').isPrimaryName, isTrue);
      for (final name in [
        'RouteGraphImportMetadata',
        'TrackDateMigrationMetadata',
        'PeakRegionFingerprint',
        'TrackReplacementRecoveryIssue',
      ]) {
        expect(
          entities
              .singleWhere((e) => e.name == name)
              .fields
              .any((f) => f.attributes.contains('Name')),
          isFalse,
        );
      }
    },
  );

  test('direct input policy retains only the five existing field sets', () {
    final expected = <String, Set<String>>{
      'Peak': {
        'name',
        'altName',
        'osmId',
        'peakbaggerPid',
        'elevation',
        'prominence',
        'country',
        'county',
        'range',
        'rating',
        'durationLabel',
        'difficulty',
        'viaFerrata',
        'notes',
        'latitude',
        'longitude',
        'region',
        'mgrs100kId',
        'easting',
        'northing',
        'verified',
      },
      'NaturalFeature': {
        'name',
        'altName',
        'tag',
        'country',
        'county',
        'region',
        'latitude',
        'longitude',
        'mgrs100kId',
        'easting',
        'northing',
        'sourceOfTruth',
      },
      'Contact': {'firstName', 'surname', 'nickname'},
      'Route': {
        'name',
        'desc',
        'visible',
        'colour',
        'distance2d',
        'distance3d',
        'ascent',
        'descent',
        'startElevation',
        'endElevation',
        'lowestElevation',
        'highestElevation',
      },
      'PeakList': {'colour'},
    };
    for (final entity in ObjectBoxAdminRepositoryImpl().getEntities()) {
      expect(
        entity.fields.where((f) => f.canEdit).map((f) => f.name).toSet(),
        expected[entity.name] ?? <String>{},
        reason: entity.name,
      );
      expect(
        entity.fields.where((f) => f.isPrimaryKey).every((f) => !f.canEdit),
        isTrue,
      );
    }
    final selector = objectBoxAdminFieldMetadata(
      'NaturalFeature',
      'sourceOfTruth',
    )!;
    expect(selector.input, AdminFieldInput.sourceOfTruthSelector);
    expect(
      objectBoxAdminFieldMetadata('Peak', 'sourceOfTruth')!.permitsDirectInput,
      isFalse,
    );
    expect(objectBoxAdminFieldMetadata('FutureEntity', 'name'), isNull);
    expect(
      const ObjectBoxAdminFieldDescriptor(
        name: 'id',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: true,
        isPrimaryName: false,
        metadata: AdminFieldMetadata('int', input: AdminFieldInput.text),
      ).canEdit,
      isFalse,
    );
    expect(
      const AdminFieldMetadata(
        'String',
        generated: true,
        input: AdminFieldInput.text,
      ).permitsDirectInput,
      isFalse,
    );
  });

  test(
    'unavailable app metadata browses actual names/storage and fails closed',
    () {
      final entities = ObjectBoxAdminRepositoryImpl(
        appMetadata: {},
      ).getEntities();
      final peak = entities.first;
      final name = peak.fields.singleWhere((f) => f.name == 'name');
      expect(name.typeLabel, 'Storage: string');
      expect(name.nullable, isNull);
      expect(name.attributes, ['Read-only', 'App metadata unavailable']);
      expect(entities.expand((e) => e.fields).every((f) => !f.canEdit), isTrue);
      final model = getObjectBoxModel();
      final property = model.model.entities.first.properties.first;
      final originalType = property.type;
      property.type =
          9876; // Only this isolated in-memory model, never generated files.
      addTearDown(() => property.type = originalType);
      final unknown = ObjectBoxAdminRepositoryImpl(
        modelDefinition: model,
        appMetadata: {},
      ).getEntities().first.fields.first;
      expect(unknown.typeLabel, 'Storage type 9876');
      expect(
        unknown.attributes,
        containsAll([
          'PK',
          'Assignable',
          'Read-only',
          'App metadata unavailable',
        ]),
      );
      expect(property.hasFlag(obx.OBXPropertyFlags.ID), isTrue);
    },
  );

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
      'Waypoints',
      'PeakListItemEntity',
      'RouteGraphImportMetadata',
      'TrackReplacementRecoveryIssue',
      'Contact',
      'NaturalFeature',
      'PeakRegionFingerprint',
      'TrackDateMigrationMetadata',
    ]);
    expect(
      entities.map((entity) => entity.name).toSet().length,
      entities.length,
    );
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
        'prominence',
        'country',
        'county',
        'range',
        'rating',
        'durationMinutes',
        'durationLabel',
        'difficulty',
        'viaFerrata',
        'notes',
        'latitude',
        'longitude',
        'region',
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
      'ToMany<Peak>',
    );
    expect(entities[3].primaryKeyField, 'peakListId');
    expect(entities[3].primaryNameField, 'name');
    expect(
      entities[3].fields.map((field) => field.name),
      containsAll([
        'peakListId',
        'name',
        'region',
        'colour',
        'minLat',
        'maxLat',
        'minLng',
        'maxLng',
      ]),
    );
    expect(
      entities[3].fields.map((field) => field.name),
      isNot(contains('peakList')),
    );
    expect(
      entities[3].fields.map((field) => field.name),
      isNot(contains('membershipState')),
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
    final waypointsEntity = entities.singleWhere(
      (entity) => entity.name == 'Waypoints',
    );
    expect(waypointsEntity.primaryKeyField, 'id');
    expect(waypointsEntity.primaryNameField, 'name');
    expect(
      waypointsEntity.fields.map((field) => field.name),
      containsAll(['id', 'name', 'type', 'latitude', 'longitude', 'mgrs']),
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
        'estimatedTime',
        'routeTimingSource',
        'routeTimingProfileJson',
        'walkingSpeedKmh',
        'routeTimingSegmentKindsJson',
      ]),
    );
    expect(entities[9].primaryKeyField, 'id');
    expect(entities[9].primaryNameField, 'recordKey');
    final peakListItemEntity = entities.singleWhere(
      (entity) => entity.name == 'PeakListItemEntity',
    );
    expect(peakListItemEntity.primaryKeyField, 'id');
    expect(peakListItemEntity.primaryNameField, 'id');
    expect(
      peakListItemEntity.fields.map((field) => field.name),
      containsAll(['id', 'peakListId', 'peakId', 'points']),
    );
  });

  test(
    'natural features use the dedicated display, row mapping, and search',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'objectbox-admin',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final store = await openStore(directory: directory.path);
      addTearDown(store.close);
      final box = store.box<NaturalFeature>();
      box.putMany([
        NaturalFeature(
          name: 'Blue Lake',
          altName: 'Azure',
          tag: 'water',
          country: 'Australia',
          county: 'Derwent',
          region: 'South',
          latitude: -42.8,
          longitude: 146.2,
          osmId: 1234,
          osmType: 'way',
        ),
        NaturalFeature(
          name: 'Red Hill',
          tag: 'peak',
          latitude: -42.7,
          longitude: 146.3,
          osmId: 5678,
          osmType: 'node',
        ),
      ]);
      final repository = ObjectBoxAdminRepositoryImpl(store: store);
      final entity = repository.getEntities().singleWhere(
        (entity) => entity.name == 'NaturalFeature',
      );

      expect(entity.displayName, 'Natural Features');
      expect(
        (await repository.loadRows(
          entity,
          searchQuery: 'AZURE',
          ascending: true,
        )).single.values['name'],
        'Blue Lake',
      );
      expect(
        (await repository.loadRows(
          entity,
          searchQuery: '1234',
          ascending: true,
        )).single.values['name'],
        'Blue Lake',
      );
      expect(
        await repository.loadRows(
          entity,
          searchQuery: 'derwent',
          ascending: true,
        ),
        isEmpty,
      );
      expect(
        await repository.loadRows(
          entity,
          searchQuery: '-42.8',
          ascending: true,
        ),
        isEmpty,
      );
      expect(
        (await repository.loadRows(
          entity,
          searchQuery: '',
          ascending: false,
        )).map((row) => row.primaryKeyValue),
        orderedEquals([2, 1]),
      );
    },
  );

  test(
    'contacts use their dedicated label, fields, search, and ID sort',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'objectbox-admin',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final store = await openStore(directory: directory.path);
      addTearDown(store.close);
      store.box<Contact>().putMany([
        Contact(firstName: 'Ada', surname: 'Lovelace', nickname: 'Countess'),
        Contact(firstName: 'Grace', surname: 'Hopper', nickname: 'Amazing'),
      ]);
      final repository = ObjectBoxAdminRepositoryImpl(store: store);
      final entity = repository.getEntities().singleWhere(
        (entity) => entity.name == 'Contact',
      );

      expect(entity.displayName, 'Contacts');
      expect(entity.fields.map((field) => field.name), [
        'id',
        'firstName',
        'surname',
        'nickname',
      ]);
      expect(
        (await repository.loadRows(
          entity,
          searchQuery: 'COUNTESS',
          ascending: true,
        )).single.values['firstName'],
        'Ada',
      );
      expect(
        await repository.loadRows(entity, searchQuery: '2', ascending: true),
        isEmpty,
      );
      expect(
        (await repository.loadRows(
          entity,
          searchQuery: '',
          ascending: false,
        )).map((row) => row.primaryKeyValue),
        orderedEquals([2, 1]),
      );
    },
  );

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
        rating: 4.4,
        durationMinutes: 300,
        durationLabel: '4-5 hours',
        difficulty: 'EE',
        viaFerrata: 'Optional',
        notes: 'Ridge scramble',
      ),
    );

    expect(row.primaryKeyValue, 42);
    expect(row.values['osmId'], 4242);
    expect(row.values['peakbaggerPid'], isNull);
    expect(row.values['altName'], 'Milner');
    expect(row.values['country'], '');
    expect(row.values['county'], '');
    expect(row.values['range'], '');
    expect(row.values['rating'], 4.4);
    expect(row.values['durationMinutes'], 300);
    expect(row.values['durationLabel'], '4-5 hours');
    expect(row.values['difficulty'], 'EE');
    expect(row.values['viaFerrata'], 'Optional');
    expect(row.values['notes'], 'Ridge scramble');
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
          'peakbaggerPid': 313,
          'name': 'Mount Milner',
          'altName': 'Milner',
          'elevation': 1200.0,
          'prominence': 340.0,
          'country': 'Australia',
          'county': 'Tasmania',
          'range': 'Central Highlands',
          'rating': 4.3,
          'durationMinutes': 300,
          'durationLabel': '4-5 hours',
          'difficulty': 'EE',
          'viaFerrata': 'Optional',
          'notes': 'Ridge scramble',
          'latitude': -41.2,
          'longitude': 146.1,
          'region': 'Central',
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
    expect(peak.peakbaggerPid, 313);
    expect(peak.altName, 'Milner');
    expect(peak.prominence, 340.0);
    expect(peak.country, 'Australia');
    expect(peak.county, 'Tasmania');
    expect(peak.range, 'Central Highlands');
    expect(peak.rating, 4.3);
    expect(peak.durationMinutes, 300);
    expect(peak.durationLabel, '4-5 hours');
    expect(peak.difficulty, 'EE');
    expect(peak.viaFerrata, 'Optional');
    expect(peak.notes, 'Ridge scramble');
    expect(peak.verified, isTrue);
  });

  test('peakAdminDetailsFields includes ranked metadata fields', () {
    final peakEntity = ObjectBoxAdminEntityDescriptor(
      name: 'Peak',
      displayName: 'Peak',
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
          name: 'elevation',
          typeLabel: 'double',
          nullable: true,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'peakbaggerPid',
          typeLabel: 'int',
          nullable: true,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'prominence',
          typeLabel: 'double',
          nullable: true,
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
          name: 'range',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'rating',
          typeLabel: 'double',
          nullable: true,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'durationMinutes',
          typeLabel: 'int',
          nullable: true,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'durationLabel',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'difficulty',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'viaFerrata',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'notes',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    );

    expect(
      peakAdminDetailsFields(peakEntity).map((field) => field.name),
      containsAll([
        'rating',
        'durationMinutes',
        'durationLabel',
        'difficulty',
        'viaFerrata',
        'notes',
      ]),
    );
  });

  test('routeToAdminRow exposes persisted route fields', () {
    final row = routeToAdminRow(
      Route(
        id: 7,
        name: 'Mt Ossa Route',
        desc: 'A scenic route',
        gpxRoute: [const LatLng(-41.5, 146.5)],
        gpxRouteElevations: [456],
        routeWaypoints: [
          const RouteWaypoint(
            latitude: -41.5,
            longitude: 146.5,
            label: 'Waypoint 1',
            sequence: 1,
            isPeakDerived: false,
          ),
        ],
        displayRoutePointsByZoom: '{"10":[]}',
        colour: 12,
        visible: false,
        distance2d: 12.5,
        distance3d: 13.2,
        ascent: 850,
        descent: 840,
        startElevation: 120,
        endElevation: 1210,
        lowestElevation: 110,
        highestElevation: 1600,
        estimatedTime: 5400000,
        routeTimingSource: 'naismith',
        routeTimingProfileJson: '[0,5400]',
        walkingSpeedKmh: 4.2,
        routeTimingSegmentKindsJson:
            '["${RouteTimingSegmentKinds.manualEstimated}"]',
      ),
    );

    expect(row.primaryKeyValue, 7);
    expect(row.values['name'], 'Mt Ossa Route');
    expect(row.values['desc'], 'A scenic route');
    expect(row.values['gpxRouteJson'], '[[-41.5,146.5,456]]');
    expect(
      row.values['routeWaypointsJson'],
      '[{"latitude":-41.5,"longitude":146.5,"label":"Waypoint 1","sequence":1,"isPeakDerived":false,"peakOsmId":null,"peakName":null}]',
    );
    expect(row.values['displayRoutePointsByZoom'], '{"10":[]}');
    expect(row.values['colour'], 12);
    expect(row.values['visible'], isFalse);
    expect(row.values['distance2d'], 12.5);
    expect(row.values['highestElevation'], 1600);
    expect(row.values['estimatedTime'], 5400000);
    expect(row.values['routeTimingSource'], 'naismith');
    expect(row.values['routeTimingProfileJson'], '[0,5400]');
    expect(row.values['walkingSpeedKmh'], 4.2);
    expect(
      row.values['routeTimingSegmentKindsJson'],
      '["${RouteTimingSegmentKinds.manualEstimated}"]',
    );
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
      'peakbaggerPid',
      'prominence',
      'country',
      'county',
      'range',
      'rating',
      'durationMinutes',
      'durationLabel',
      'difficulty',
      'viaFerrata',
      'notes',
      'latitude',
      'longitude',
      'region',
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
      'altName',
      'elevation',
      'peakbaggerPid',
      'prominence',
      'country',
      'county',
      'range',
      'rating',
      'durationMinutes',
      'durationLabel',
      'difficulty',
      'viaFerrata',
      'notes',
      'latitude',
      'longitude',
      'region',
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

  test('peakListToAdminRow includes previewable payload fields and bounds', () {
    final row = peakListToAdminRow(
      PeakList(
        peakListId: 9,
        name: 'Abels',
        minLat: -42.0,
        maxLat: -41.0,
        minLng: 145.0,
        maxLng: 146.0,
      ),
      membershipItems: const [
        PeakListItem(peakOsmId: 101, points: 3),
        PeakListItem(peakOsmId: 202, points: 6),
      ],
    );

    expect(row.primaryKeyValue, 9);
    expect(row.values['peakListId'], 9);
    expect(row.values['name'], 'Abels');
    expect(row.values['minLat'], -42.0);
    expect(row.values['maxLat'], -41.0);
    expect(row.values['minLng'], 145.0);
    expect(row.values['maxLng'], 146.0);
    expect(
      objectBoxAdminPreviewValue(row.values['membershipItems']),
      contains('peakOsmId'),
    );
  });

  test('peakListItemEntityToAdminRow exposes relational membership fields', () {
    final peakList = PeakList(peakListId: 9, name: 'Abels');
    final peak = Peak(
      osmId: 101,
      name: 'Alpha Peak',
      latitude: -42,
      longitude: 146,
    );
    final row = peakListItemEntityToAdminRow(
      PeakListItemEntity(id: 3, points: 7)
        ..peakList.target = peakList
        ..peak.target = peak,
    );

    expect(row.primaryKeyValue, 3);
    expect(row.values['peakListId'], 9);
    expect(row.values['peakId'], 101);
    expect(row.values['points'], 7);
    expect(row.values['peakListName'], 'Abels');
    expect(row.values['peakName'], 'Alpha Peak');
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
