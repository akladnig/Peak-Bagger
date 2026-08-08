import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';
import 'package:peak_bagger/services/gpx_storage_destination_resolver.dart';

final gpxExportServiceProvider = Provider<GpxExportService>((ref) {
  final routeElevationSampler = ref.watch(routeElevationSamplerProvider);
  final peakRepository = ref.watch(peakRepositoryProvider);
  return GpxExportService(
    routePointElevationsResolver: routeElevationSampler.samplePointElevations,
    peakListLoader: peakRepository.getAllPeaks,
    peakCorrelationThresholdsLoader: () async {
      final settings = await ref.read(peakCorrelationSettingsProvider.future);
      return (
        distanceMeters: settings.distanceMeters,
        elevationMeters: settings.elevationMeters,
      );
    },
    storageDestinationResolver: GpxStorageDestinationResolver(),
  );
});
