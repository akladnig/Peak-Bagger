import 'dart:developer' as developer;

import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:objectbox/internal.dart' as obx_int;

abstract class ObjectBoxAdminRepository {
  List<ObjectBoxAdminEntityDescriptor> getEntities();

  Future<List<ObjectBoxAdminRow>> loadRows(
    ObjectBoxAdminEntityDescriptor entity, {
    required String searchQuery,
    required bool ascending,
  });
}

class ObjectBoxAdminRepositoryImpl implements ObjectBoxAdminRepository {
  ObjectBoxAdminRepositoryImpl({
    Store? store,
    obx_int.ModelDefinition? modelDefinition,
  }) : _store = store,
       _modelDefinition = modelDefinition ?? getObjectBoxModel();

  final Store? _store;
  final obx_int.ModelDefinition _modelDefinition;

  @override
  List<ObjectBoxAdminEntityDescriptor> getEntities() {
    return _modelDefinition.model.entities
        .map(_toEntityDescriptor)
        .toList(growable: false);
  }

  @override
  Future<List<ObjectBoxAdminRow>> loadRows(
    ObjectBoxAdminEntityDescriptor entity, {
    required String searchQuery,
    required bool ascending,
  }) async {
    await Future<void>.delayed(Duration.zero);

    final store = _store;
    if (store == null) {
      throw StateError('ObjectBox store is required to load rows.');
    }

    final trimmedQuery = searchQuery.trim().toLowerCase();

    final rows = switch (entity.name) {
      'Peak' => _loadPeakRows(store, trimmedQuery, ascending),
      'Tasmap50k' => _loadTasmapRows(store, trimmedQuery, ascending),
      'GpxTrack' => _loadTrackRows(store, trimmedQuery, ascending),
      _ => <ObjectBoxAdminRow>[],
    };

    return rows;
  }

  ObjectBoxAdminEntityDescriptor _toEntityDescriptor(
    obx_int.ModelEntity entity,
  ) {
    final displayName = entity.externalName ?? entity.name;
    final primaryKeyField = entity.idProperty.name;
    final primaryNameField = _primaryNameField(entity.name);

    final fields = entity.properties
        .map((property) {
          return ObjectBoxAdminFieldDescriptor(
            name: property.name,
            typeLabel: _describePropertyType(property),
            nullable: false,
            isPrimaryKey: property.name == primaryKeyField,
            isPrimaryName: property.name == primaryNameField,
          );
        })
        .toList(growable: false);

    return ObjectBoxAdminEntityDescriptor(
      name: entity.name,
      displayName: displayName,
      primaryKeyField: primaryKeyField,
      primaryNameField: primaryNameField,
      fields: fields,
    );
  }

  String _describePropertyType(obx_int.ModelProperty property) {
    return 'type${property.type}';
  }

  String _primaryNameField(String entityName) {
    return switch (entityName) {
      'Peak' => 'name',
      'Tasmap50k' => 'name',
      'GpxTrack' => 'trackName',
      _ => 'name',
    };
  }

  List<ObjectBoxAdminRow> _loadPeakRows(
    Store store,
    String query,
    bool ascending,
  ) {
    final box = store.box<Peak>();
    final items = box.getAll();
    final filtered = query.isEmpty
        ? items
        : items.where((peak) {
            return peak.name.toLowerCase().contains(query);
          }).toList();

    filtered.sort(
      (a, b) => ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id),
    );

    return filtered
        .map(
          (peak) => ObjectBoxAdminRow(
            primaryKeyValue: peak.id,
            values: {
              'id': peak.id,
              'name': peak.name,
              'elevation': peak.elevation,
              'latitude': peak.latitude,
              'longitude': peak.longitude,
              'area': peak.area,
            },
          ),
        )
        .toList(growable: false);
  }

  List<ObjectBoxAdminRow> _loadTasmapRows(
    Store store,
    String query,
    bool ascending,
  ) {
    final box = store.box<Tasmap50k>();
    final items = box.getAll();
    final filtered = query.isEmpty
        ? items
        : items.where((map) {
            return map.name.toLowerCase().contains(query);
          }).toList();

    filtered.sort(
      (a, b) => ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id),
    );

    return filtered
        .map(
          (map) => ObjectBoxAdminRow(
            primaryKeyValue: map.id,
            values: {
              'id': map.id,
              'series': map.series,
              'name': map.name,
              'parentSeries': map.parentSeries,
              'mgrs100kIds': map.mgrs100kIds,
              'eastingMin': map.eastingMin,
              'eastingMax': map.eastingMax,
              'northingMin': map.northingMin,
              'northingMax': map.northingMax,
              'mgrsMid': map.mgrsMid,
              'eastingMid': map.eastingMid,
              'northingMid': map.northingMid,
              'tl': map.tl,
              'tr': map.tr,
              'bl': map.bl,
              'br': map.br,
            },
          ),
        )
        .toList(growable: false);
  }

  List<ObjectBoxAdminRow> _loadTrackRows(
    Store store,
    String query,
    bool ascending,
  ) {
    final box = store.box<GpxTrack>();
    final items = box.getAll();
    final filtered = query.isEmpty
        ? items
        : items.where((track) {
            return track.trackName.toLowerCase().contains(query);
          }).toList();

    filtered.sort(
      (a, b) => ascending
          ? a.gpxTrackId.compareTo(b.gpxTrackId)
          : b.gpxTrackId.compareTo(a.gpxTrackId),
    );

    return filtered
        .map(
          (track) => ObjectBoxAdminRow(
            primaryKeyValue: track.gpxTrackId,
            values: {
              'gpxTrackId': track.gpxTrackId,
              'contentHash': track.contentHash,
              'trackName': track.trackName,
              'trackDate': track.trackDate,
              'gpxFile': track.gpxFile,
              'displayTrackPointsByZoom': track.displayTrackPointsByZoom,
              'startDateTime': track.startDateTime,
              'endDateTime': track.endDateTime,
              'distance': track.distance,
              'ascent': track.ascent,
              'totalTimeMillis': track.totalTimeMillis,
              'trackColour': track.trackColour,
            },
          ),
        )
        .toList(growable: false);
  }
}

class ObjectBoxAdminEntityDescriptor {
  const ObjectBoxAdminEntityDescriptor({
    required this.name,
    required this.displayName,
    required this.primaryKeyField,
    required this.primaryNameField,
    required this.fields,
  });

  final String name;
  final String displayName;
  final String primaryKeyField;
  final String primaryNameField;
  final List<ObjectBoxAdminFieldDescriptor> fields;
}

class ObjectBoxAdminFieldDescriptor {
  const ObjectBoxAdminFieldDescriptor({
    required this.name,
    required this.typeLabel,
    required this.nullable,
    required this.isPrimaryKey,
    required this.isPrimaryName,
  });

  final String name;
  final String typeLabel;
  final bool nullable;
  final bool isPrimaryKey;
  final bool isPrimaryName;
}

class ObjectBoxAdminRow {
  const ObjectBoxAdminRow({
    required this.primaryKeyValue,
    required this.values,
  });

  final Object? primaryKeyValue;
  final Map<String, Object?> values;
}

String objectBoxAdminFormatValue(Object? value) {
  return switch (value) {
    null => '—',
    DateTime() => value.toIso8601String(),
    Iterable() => value.map(objectBoxAdminFormatValue).join(', '),
    _ => value.toString(),
  };
}

String objectBoxAdminPreviewValue(Object? value, {int maxChars = 80}) {
  final text = objectBoxAdminFormatValue(value);
  if (text.length <= maxChars) {
    return text;
  }
  return '${text.substring(0, maxChars - 1)}…';
}

List<ObjectBoxAdminRow> objectBoxAdminFilterAndSortRows(
  ObjectBoxAdminEntityDescriptor entity, {
  required List<ObjectBoxAdminRow> rows,
  required String searchQuery,
  required bool ascending,
}) {
  final trimmedQuery = searchQuery.trim().toLowerCase();
  final filtered = trimmedQuery.isEmpty
      ? rows
      : rows
            .where((row) {
              final value = row.values[entity.primaryNameField];
              return objectBoxAdminFormatValue(
                value,
              ).toLowerCase().contains(trimmedQuery);
            })
            .toList(growable: false);

  final sorted = filtered.toList(growable: false)
    ..sort((left, right) {
      final leftValue = left.primaryKeyValue;
      final rightValue = right.primaryKeyValue;
      if (leftValue is Comparable && rightValue is Comparable) {
        final comparison = leftValue.compareTo(rightValue);
        return ascending ? comparison : -comparison;
      }
      return 0;
    });

  return sorted;
}

void logObjectBoxAdminError(
  Object error,
  StackTrace stackTrace,
  String context,
) {
  developer.log(context, error: error, stackTrace: stackTrace);
}
