import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/local_topo_overlay_tile_provider.dart';

final localTopoOverlayOutageReporterProvider =
    Provider<OverlayTileOutageReporter>((ref) {
      final reporter = OverlayTileOutageReporter();
      ref.onDispose(reporter.dispose);
      return reporter;
    });
