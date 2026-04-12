import 'package:peak_bagger/models/gpx_track.dart';
import '../objectbox.g.dart';

class GpxTrackRepository {
  final Box<GpxTrack> _box;

  GpxTrackRepository(Store store) : _box = store.box<GpxTrack>();

  int addTrack(GpxTrack track) {
    return _box.put(track);
  }

  int putTrack(GpxTrack track) {
    return _box.put(track);
  }

  List<GpxTrack> getAllTracks() {
    return _box.getAll();
  }

  int getTrackCount() {
    return _box.count();
  }

  bool isEmpty() {
    return _box.isEmpty();
  }

  GpxTrack? findById(int id) {
    return _box.get(id);
  }

  GpxTrack? findByContentHash(String contentHash) {
    final query = _box.query(GpxTrack_.contentHash.equals(contentHash)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  GpxTrack? findByTrackNameAndTrackDate(String trackName, DateTime trackDate) {
    final query = _box
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

  int replaceTrack({
    required GpxTrack existing,
    required GpxTrack replacement,
  }) {
    replacement.gpxTrackId = existing.gpxTrackId;
    return _box.put(replacement);
  }

  bool deleteTrack(int id) {
    return _box.remove(id);
  }

  List<GpxTrack> findTasmanianTracks() {
    return _box.getAll();
  }

  void deleteAll() {
    _box.removeAll();
  }
}
