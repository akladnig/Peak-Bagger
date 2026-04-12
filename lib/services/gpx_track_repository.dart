import 'package:peak_bagger/models/gpx_track.dart';
import '../objectbox.g.dart';

class GpxTrackRepository {
  final Box<GpxTrack> _box;

  GpxTrackRepository(Store store) : _box = store.box<GpxTrack>();

  int addTrack(GpxTrack track) {
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

  GpxTrack? findByFileLocation(String fileLocation) {
    final query = _box
        .query(GpxTrack_.fileLocation.equals(fileLocation))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
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
