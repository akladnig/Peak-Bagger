import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/overpass_service.dart';

class TestPeakOverpassService extends OverpassService {
  TestPeakOverpassService({List<Peak> peaks = const [], this.error})
    : _peaks = List<Peak>.unmodifiable(peaks);

  final List<Peak> _peaks;
  final Object? error;
  int fetchCallCount = 0;
  String? lastRegion;
  LatLngBounds? lastBounds;

  @override
  Future<List<Peak>> fetchPeaks({
    required String region,
    required LatLngBounds bounds,
  }) async {
    fetchCallCount += 1;
    lastRegion = region;
    lastBounds = bounds;
    if (error != null) {
      throw error!;
    }
    return _peaks
        .map((peak) => peak.copyWith(region: region))
        .toList(growable: false);
  }
}
