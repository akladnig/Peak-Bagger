import 'package:objectbox/objectbox.dart';
import 'package:peak_bagger/models/peak.dart';
import '../objectbox.g.dart';

class PeakRepository {
  final Box<Peak> _peakBox;

  PeakRepository(Store store) : _peakBox = store.box<Peak>();

  int get peakCount => _peakBox.count();

  List<Peak> getAllPeaks() {
    return _peakBox.getAll();
  }

  List<Peak> getPeaksByName(String query) {
    final queryBuilder = _peakBox
        .query(Peak_.name.contains(query, caseSensitive: false))
        .build();
    final results = queryBuilder.find();
    queryBuilder.close();
    return results;
  }

  List<Peak> searchPeaks(String query) {
    if (query.isEmpty) return getAllPeaks();

    final queryLower = query.toLowerCase();
    final allPeaks = getAllPeaks();

    return allPeaks.where((peak) {
      final nameMatch = peak.name.toLowerCase().contains(queryLower);
      final elevMatch =
          peak.elevation != null && peak.elevation!.toString().contains(query);
      return nameMatch || elevMatch;
    }).toList();
  }

  Future<void> addPeaks(List<Peak> peaks) async {
    _peakBox.putMany(peaks);
  }

  Future<void> clearAll() async {
    _peakBox.removeAll();
  }

  bool isEmpty() {
    return _peakBox.isEmpty();
  }
}
