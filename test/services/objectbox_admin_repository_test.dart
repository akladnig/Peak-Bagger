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
      entities.first.fields.map((field) => field.name),
      containsAll(['id', 'name', 'elevation', 'latitude', 'longitude', 'area']),
    );
    expect(entities.last.primaryKeyField, 'gpxTrackId');
    expect(entities.last.primaryNameField, 'trackName');
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
}
