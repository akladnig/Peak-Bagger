import 'package:peak_bagger/models/peak.dart';

abstract class PeakSource {
  List<Peak> getAllPeaks();
}

class InMemoryPeakSource implements PeakSource {
  InMemoryPeakSource([List<Peak> peaks = const []])
    : _peaks = List<Peak>.from(peaks);

  final List<Peak> _peaks;

  @override
  List<Peak> getAllPeaks() => List<Peak>.unmodifiable(_peaks);
}
