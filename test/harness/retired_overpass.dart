import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:peak_bagger/models/peak.dart';

/// Retired API token for older MapNotifier test constructors. Never performs
/// network I/O; manifest-backed bootstrap tests verify it is never consulted.
class OverpassService {
  Future<List<Peak>> fetchPeaks({
    required String region,
    required LatLngBounds bounds,
  }) => Future.error(StateError('Runtime Overpass has been retired.'));
}
