import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_repository.dart';

class TestPeakRepository extends PeakRepository {
  TestPeakRepository([List<Peak> peaks = const []])
    : super.test(InMemoryPeakStorage(peaks));
}
