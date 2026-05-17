import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_repository.dart';

final overpassServiceProvider = Provider<OverpassService>((ref) {
  throw UnimplementedError('overpassServiceProvider must be overridden');
});

final peakRepositoryProvider = Provider<PeakRepository>((ref) {
  throw UnimplementedError('peakRepositoryProvider must be overridden');
});

final peakRevisionProvider = NotifierProvider<PeakRevisionNotifier, int>(
  PeakRevisionNotifier.new,
);

final peakListRewritePortProvider = Provider<PeakListRewritePort>((ref) {
  throw UnimplementedError('peakListRewritePortProvider must be overridden');
});

final peakDeleteGuardProvider = Provider<PeakDeleteGuard>((ref) {
  throw UnimplementedError('peakDeleteGuardProvider must be overridden');
});

class PeakRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state += 1;
  }
}
