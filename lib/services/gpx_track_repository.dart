import 'package:peak_bagger/models/gpx_track.dart';
import '../objectbox.g.dart';

abstract class GpxTrackStorage {
  GpxTrack? getById(int id);

  List<GpxTrack> getAll();
}

class ObjectBoxGpxTrackStorage implements GpxTrackStorage {
  ObjectBoxGpxTrackStorage(this._box);

  final Box<GpxTrack> _box;

  int get count => _box.count();

  int put(GpxTrack track) => _box.put(track);

  bool remove(int id) => _box.remove(id);

  void removeAll() => _box.removeAll();

  @override
  GpxTrack? getById(int id) {
    return _box.get(id);
  }

  @override
  List<GpxTrack> getAll() {
    return _box.getAll();
  }
}

class InMemoryGpxTrackStorage implements GpxTrackStorage {
  InMemoryGpxTrackStorage([List<GpxTrack> tracks = const []])
      : _tracks = List<GpxTrack>.from(tracks);

  final List<GpxTrack> _tracks;

  @override
  GpxTrack? getById(int id) {
    for (final track in _tracks) {
      if (track.gpxTrackId == id) {
        return track;
      }
    }
    return null;
  }

  @override
  List<GpxTrack> getAll() {
    return List<GpxTrack>.unmodifiable(_tracks);
  }
}

class GpxTrackRepository {
  final GpxTrackStorage _storage;

  GpxTrackRepository(Store store) : _storage = ObjectBoxGpxTrackStorage(store.box<GpxTrack>());

  GpxTrackRepository.test(GpxTrackStorage storage) : _storage = storage;

  int putTrack(GpxTrack track) {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      return storage.put(track);
    }
    throw UnsupportedError('putTrack is not supported by the test storage');
  }

  List<GpxTrack> getAllTracks() {
    return _storage.getAll();
  }

  int getTrackCount() {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      return storage.count;
    }
    return _storage.getAll().length;
  }

  bool isEmpty() {
    return getTrackCount() == 0;
  }

  GpxTrack? findById(int id) {
    return _storage.getById(id);
  }

  GpxTrack? findByContentHash(String contentHash) {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      final box = storage._box;
      final query = box.query(GpxTrack_.contentHash.equals(contentHash)).build();
      final result = query.findFirst();
      query.close();
      return result;
    }

    for (final track in _storage.getAll()) {
      if (track.contentHash == contentHash) {
        return track;
      }
    }
    return null;
  }

  GpxTrack? findByTrackNameAndTrackDate(String trackName, DateTime trackDate) {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      final box = storage._box;
      final query = box
          .query(
            GpxTrack_.trackName.equals(trackName) &
                GpxTrack_.trackDate.equalsDate(trackDate) &
                GpxTrack_.startDateTime.notNull(),
          )
          .build();
      final matches = query.find();
      query.close();
      if (matches.isEmpty) {
        return null;
      }
      matches.sort((a, b) => b.gpxTrackId.compareTo(a.gpxTrackId));
      return matches.first;
    }

    final matches = _storage
        .getAll()
        .where(
          (track) =>
              track.trackName == trackName &&
              track.trackDate == trackDate &&
              track.startDateTime != null,
        )
        .toList(growable: false);
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.gpxTrackId.compareTo(a.gpxTrackId));
    return matches.first;
  }

  int replaceTrack({
    required GpxTrack existing,
    required GpxTrack replacement,
  }) {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      replacement.gpxTrackId = existing.gpxTrackId;
      return storage.put(replacement);
    }
    throw UnsupportedError('replaceTrack is not supported by the test storage');
  }

  bool deleteTrack(int id) {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      return storage.remove(id);
    }
    throw UnsupportedError('deleteTrack is not supported by the test storage');
  }

  List<GpxTrack> findTasmanianTracks() {
    return _storage.getAll();
  }

  void deleteAll() {
    if (_storage case final ObjectBoxGpxTrackStorage storage) {
      storage.removeAll();
      return;
    }
    throw UnsupportedError('deleteAll is not supported by the test storage');
  }
}
