import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_repository.dart';

class MapSearchService {
  MapSearchService({required PeakRepository peakRepository})
    : _peakRepository = peakRepository;

  final PeakRepository _peakRepository;

  List<Peak> searchPeaks(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }
    return _peakRepository.searchPeaks(trimmedQuery).take(20).toList();
  }
}
