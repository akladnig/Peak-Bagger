import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/services/natural_feature_refresh_service.dart';

final naturalFeatureRepositoryProvider = Provider<NaturalFeatureRepository>((
  ref,
) {
  throw UnimplementedError(
    'naturalFeatureRepositoryProvider must be overridden',
  );
});

typedef NaturalFeatureRefreshRunner =
    Future<NaturalFeatureRefreshResult> Function();

final naturalFeatureRefreshServiceProvider =
    Provider<NaturalFeatureRefreshService>((ref) {
      return NaturalFeatureRefreshService(
        ref.watch(naturalFeatureRepositoryProvider),
      );
    });

final naturalFeatureRefreshRunnerProvider =
    Provider<NaturalFeatureRefreshRunner>((ref) {
      final service = ref.watch(naturalFeatureRefreshServiceProvider);
      return service.refresh;
    });
