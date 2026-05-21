import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';

final gpxExportServiceProvider = Provider<GpxExportService>((_) {
  return GpxExportService();
});
