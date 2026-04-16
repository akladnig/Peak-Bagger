import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

final overpassServiceProvider = Provider<OverpassService>((ref) {
  throw UnimplementedError('overpassServiceProvider must be overridden');
});

final peakRepositoryProvider = Provider<PeakRepository>((ref) {
  throw UnimplementedError('peakRepositoryProvider must be overridden');
});
