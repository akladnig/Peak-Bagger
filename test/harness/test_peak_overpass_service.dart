import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/overpass_service.dart';

class TestPeakOverpassService extends OverpassService {
  TestPeakOverpassService({List<Peak> peaks = const [], this.error})
    : _peaks = List<Peak>.unmodifiable(peaks);

  final List<Peak> _peaks;
  final Object? error;
  int fetchCallCount = 0;

  @override
  Future<List<Peak>> fetchTasmaniaPeaks() async {
    fetchCallCount += 1;
    if (error != null) {
      throw error!;
    }
    return _peaks;
  }
}
