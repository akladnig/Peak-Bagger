import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

import '../objectbox.g.dart';

abstract class WaypointsStorage {
  List<Waypoints> getAll();

  int put(Waypoints waypoint);

  void removeMany(List<int> ids);

  bool remove(int id);
}

class ObjectBoxWaypointsStorage implements WaypointsStorage {
  ObjectBoxWaypointsStorage(this._store) : _box = _store.box<Waypoints>();

  final Store _store;
  final Box<Waypoints> _box;

  @override
  List<Waypoints> getAll() {
    return _box.getAll();
  }

  @override
  int put(Waypoints waypoint) {
    return _store.runInTransaction(TxMode.write, () => _box.put(waypoint));
  }

  @override
  void removeMany(List<int> ids) {
    if (ids.isEmpty) {
      return;
    }
    _store.runInTransaction(TxMode.write, () {
      _box.removeMany(ids);
    });
  }

  @override
  bool remove(int id) {
    return _store.runInTransaction(TxMode.write, () => _box.remove(id));
  }
}

class InMemoryWaypointsStorage implements WaypointsStorage {
  InMemoryWaypointsStorage([List<Waypoints> rows = const []])
    : _rows = List<Waypoints>.from(rows),
      _nextId = _seedNextId(rows);

  List<Waypoints> _rows;
  int _nextId;

  static int _seedNextId(List<Waypoints> rows) {
    var nextId = 1;
    for (final row in rows) {
      if (row.id >= nextId) {
        nextId = row.id + 1;
      }
    }
    return nextId;
  }

  @override
  List<Waypoints> getAll() {
    return List<Waypoints>.unmodifiable(_rows);
  }

  @override
  int put(Waypoints waypoint) {
    final id = waypoint.id == 0 ? _nextId++ : waypoint.id;
    final saved = Waypoints(
      id: id,
      name: waypoint.name,
      type: waypoint.type,
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      mgrs: waypoint.mgrs,
    );
    _rows = [
      for (final existing in _rows)
        if (existing.id != id) existing,
      saved,
    ];
    return id;
  }

  @override
  void removeMany(List<int> ids) {
    final removeIds = ids.toSet();
    _rows = _rows
        .where((row) => !removeIds.contains(row.id))
        .toList(growable: false);
  }

  @override
  bool remove(int id) {
    final before = _rows.length;
    _rows = _rows.where((row) => row.id != id).toList(growable: false);
    return _rows.length != before;
  }
}

class WaypointsRepository {
  WaypointsRepository(Store store)
    : _storage = ObjectBoxWaypointsStorage(store);

  WaypointsRepository.test(WaypointsStorage storage) : _storage = storage;

  final WaypointsStorage _storage;

  List<Waypoints> getAll() {
    final rows = _storage.getAll().toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    return rows;
  }

  Waypoints? getCurrentMarker() {
    final markers = getAll()
        .where((row) => row.type == Waypoints.typeMarker)
        .toList(growable: false);
    if (markers.isEmpty) {
      return null;
    }
    markers.sort((left, right) => right.id.compareTo(left.id));
    return markers.first;
  }

  List<Waypoints> getFavourites() {
    final favourites = getAll()
        .where((row) => row.type == Waypoints.typeFavourite)
        .toList(growable: false);
    favourites.sort((left, right) {
      final nameCompare = left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      );
      if (nameCompare != 0) {
        return nameCompare;
      }
      return left.id.compareTo(right.id);
    });
    return favourites;
  }

  bool favouriteNameExists(String name, {int? excludingId}) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return getFavourites().any(
      (row) =>
          row.id != excludingId && row.name.trim().toLowerCase() == normalized,
    );
  }

  Future<Waypoints> saveMarker({
    required LatLng location,
    String name = 'Marker',
  }) async {
    final markerIds = getAll()
        .where((row) => row.type == Waypoints.typeMarker)
        .map((row) => row.id)
        .toList(growable: false);
    _storage.removeMany(markerIds);
    final waypoint = Waypoints(
      name: name.trim().isEmpty ? 'Marker' : name.trim(),
      type: Waypoints.typeMarker,
      latitude: _persistedCoordinate(location.latitude),
      longitude: _persistedCoordinate(location.longitude),
      mgrs: waypointMgrsFromLatLng(location),
    );
    waypoint.id = _storage.put(waypoint);
    return waypoint;
  }

  Future<Waypoints> saveFavourite({
    required String name,
    required LatLng location,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Favourite name cannot be blank');
    }
    final waypoint = Waypoints(
      name: trimmedName,
      type: Waypoints.typeFavourite,
      latitude: _persistedCoordinate(location.latitude),
      longitude: _persistedCoordinate(location.longitude),
      mgrs: waypointMgrsFromLatLng(location),
    );
    waypoint.id = _storage.put(waypoint);
    return waypoint;
  }

  Future<bool> delete(int id) async {
    return _storage.remove(id);
  }
}

double _persistedCoordinate(double value) {
  return double.parse(formatCoordinate(value));
}

String waypointMgrsFromLatLng(LatLng location) {
  final mgrs = PeakMgrsConverter.fromLatLng(location);
  return '${mgrs.gridZoneDesignator} ${mgrs.mgrs100kId} ${mgrs.easting} ${mgrs.northing}';
}
