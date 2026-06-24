import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class TestObjectBoxAdminRepository implements ObjectBoxAdminRepository {
  TestObjectBoxAdminRepository({
    List<ObjectBoxAdminEntityDescriptor>? entities,
    Map<String, List<ObjectBoxAdminRow>>? rowsByEntity,
    this.exportPath = '/tmp/exported.gpx',
  }) : _entities = entities ?? _defaultEntities,
       _rowsByEntity = rowsByEntity ?? _defaultRowsByEntity;

  final List<ObjectBoxAdminEntityDescriptor> _entities;
  final Map<String, List<ObjectBoxAdminRow>> _rowsByEntity;
  final String exportPath;

  ObjectBoxAdminRow? exportedRow;
  int exportCallCount = 0;
  int getEntitiesCallCount = 0;
  int loadRowsCallCount = 0;

  static final _defaultEntities = [
    const ObjectBoxAdminEntityDescriptor(
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
          name: 'elevation',
          typeLabel: 'double',
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
          name: 'verified',
          typeLabel: 'bool',
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
          name: 'sourceOfTruth',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    ),
    const ObjectBoxAdminEntityDescriptor(
      name: 'PeakList',
      displayName: 'PeakList',
      primaryKeyField: 'peakListId',
      primaryNameField: 'name',
      fields: [
        ObjectBoxAdminFieldDescriptor(
          name: 'peakListId',
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
          name: 'peakList',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    ),
    const ObjectBoxAdminEntityDescriptor(
      name: 'Tasmap50k',
      displayName: 'Tasmap50k',
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
    ),
    const ObjectBoxAdminEntityDescriptor(
      name: 'GpxTrack',
      displayName: 'GpxTrack',
      primaryKeyField: 'gpxTrackId',
      primaryNameField: 'trackName',
      fields: [
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
      ],
    ),
    const ObjectBoxAdminEntityDescriptor(
      name: 'PeaksBagged',
      displayName: 'PeaksBagged',
      primaryKeyField: 'baggedId',
      primaryNameField: 'gpxId',
      fields: [
        ObjectBoxAdminFieldDescriptor(
          name: 'baggedId',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: true,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'peakId',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'gpxId',
          typeLabel: 'int',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: true,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'date',
          typeLabel: 'DateTime',
          nullable: true,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
      ],
    ),
    const ObjectBoxAdminEntityDescriptor(
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
        ObjectBoxAdminFieldDescriptor(
          name: 'gpxRouteJson',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'displayRoutePointsByZoom',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'colour',
          typeLabel: 'int',
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
          name: 'ascent',
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
      ],
    ),
  ];

  static final _defaultRowsByEntity = <String, List<ObjectBoxAdminRow>>{
    'Peak': [
      const ObjectBoxAdminRow(
        primaryKeyValue: 2,
        values: {
          'id': 2,
          'osmId': 202,
          'name': 'Ossa Spur',
          'altName': 'Little Ossa',
          'elevation': null,
          'latitude': -41.5,
          'longitude': 146.5,
          'region': 'Far East',
          'gridZoneDesignator': '55G',
          'mgrs100kId': 'DN',
          'easting': '12345',
          'northing': '67890',
          'verified': false,
          'sourceOfTruth': 'OSM',
        },
      ),
      const ObjectBoxAdminRow(
        primaryKeyValue: 1,
        values: {
          'id': 1,
          'osmId': 101,
          'name': 'Mt Ossa',
          'altName': 'Mount Ossa',
          'elevation': null,
          'latitude': -41.5,
          'longitude': 146.5,
          'region': 'Central',
          'gridZoneDesignator': '55G',
          'mgrs100kId': 'DN',
          'easting': '12345',
          'northing': '67890',
          'verified': true,
          'sourceOfTruth': 'HWC',
        },
      ),
    ],
    'PeakList': [
      const ObjectBoxAdminRow(
        primaryKeyValue: 1,
        values: {
          'peakListId': 1,
          'name': 'Abels',
          'peakList': '[{"peakOsmId":101,"points":"3"}]',
        },
      ),
    ],
    'Tasmap50k': const [],
    'GpxTrack': const [],
    'PeaksBagged': const [
      ObjectBoxAdminRow(
        primaryKeyValue: 1,
        values: {'baggedId': 1, 'peakId': 11, 'gpxId': 7, 'date': null},
      ),
    ],
    'Route': const [
      ObjectBoxAdminRow(
        primaryKeyValue: 1,
        values: {
          'id': 1,
          'name': 'Mt Ossa Route',
          'gpxRouteJson': '[[-41.5,146.5]]',
          'routeWaypointsJson': '[]',
          'displayRoutePointsByZoom': '{}',
          'colour': 0,
          'visible': true,
          'distance2d': 12.5,
          'distance3d': 13.2,
          'ascent': 850.0,
          'descent': 840.0,
          'startElevation': 150.0,
          'endElevation': 1200.0,
          'lowestElevation': 120.0,
          'highestElevation': 1600.0,
        },
      ),
    ],
  };

  @override
  List<ObjectBoxAdminEntityDescriptor> getEntities() {
    getEntitiesCallCount += 1;
    return _entities;
  }

  @override
  Future<List<ObjectBoxAdminRow>> loadRows(
    ObjectBoxAdminEntityDescriptor entity, {
    required String searchQuery,
    required bool ascending,
  }) async {
    loadRowsCallCount += 1;
    final rows = _rowsByEntity[entity.name] ?? const [];
    return objectBoxAdminFilterAndSortRows(
      entity,
      rows: rows,
      searchQuery: searchQuery,
      ascending: ascending,
    );
  }

  @override
  Future<String> exportGpxFile(ObjectBoxAdminRow row) async {
    exportCallCount += 1;
    exportedRow = row;
    return exportPath;
  }
}
