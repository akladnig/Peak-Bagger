import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class TestObjectBoxAdminRepository implements ObjectBoxAdminRepository {
  TestObjectBoxAdminRepository({
    List<ObjectBoxAdminEntityDescriptor>? entities,
    Map<String, List<ObjectBoxAdminRow>>? rowsByEntity,
  }) : _entities = entities ?? _defaultEntities,
       _rowsByEntity = rowsByEntity ?? _defaultRowsByEntity;

  final List<ObjectBoxAdminEntityDescriptor> _entities;
  final Map<String, List<ObjectBoxAdminRow>> _rowsByEntity;

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
    'Tasmap50k': const [],
    'GpxTrack': const [],
  };

  @override
  List<ObjectBoxAdminEntityDescriptor> getEntities() => _entities;

  @override
  Future<List<ObjectBoxAdminRow>> loadRows(
    ObjectBoxAdminEntityDescriptor entity, {
    required String searchQuery,
    required bool ascending,
  }) async {
    final rows = _rowsByEntity[entity.name] ?? const [];
    return objectBoxAdminFilterAndSortRows(
      entity,
      rows: rows,
      searchQuery: searchQuery,
      ascending: ascending,
    );
  }
}
