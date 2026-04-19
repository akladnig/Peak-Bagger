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
          name: 'p1',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p2',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p3',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p4',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p5',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p6',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p7',
          typeLabel: 'String',
          nullable: false,
          isPrimaryKey: false,
          isPrimaryName: false,
        ),
        ObjectBoxAdminFieldDescriptor(
          name: 'p8',
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
  ];

  static final _defaultRowsByEntity = <String, List<ObjectBoxAdminRow>>{
    'Peak': [
      const ObjectBoxAdminRow(
        primaryKeyValue: 2,
        values: {'id': 2, 'name': 'Ossa Spur'},
      ),
      const ObjectBoxAdminRow(
        primaryKeyValue: 1,
        values: {'id': 1, 'name': 'Mt Ossa'},
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
