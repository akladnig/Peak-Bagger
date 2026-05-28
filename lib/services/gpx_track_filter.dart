import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';

import 'gpx_filter.dart';

typedef GpxTrackFilterResult = GpxFilterResult;

class GpxTrackFilter {
  const GpxTrackFilter();

  GpxTrackFilterResult filter(
    String rawGpxXml, {
    required GpxFilterConfig config,
  }) {
    return const GpxFilter().filter(rawGpxXml, config: config);
  }
}
