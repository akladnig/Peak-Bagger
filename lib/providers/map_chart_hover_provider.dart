import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final mapChartHoverProvider = NotifierProvider<MapChartHoverNotifier, LatLng?>(
  MapChartHoverNotifier.new,
);

class MapChartHoverNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void show(LatLng point) {
    if (!ref.mounted) {
      return;
    }

    state = point;
  }

  void clear() {
    if (!ref.mounted) {
      return;
    }

    state = null;
  }
}
