import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/route_placement_measurement.dart';

typedef RouteModeMeasurement = ({
  RoutePlacementMeasurement timing,
  int routingRequestId,
});

/// Bridges the controls overlay's mode-button event to the map's frame observer.
/// This metadata never changes route state or authorizes another routing action.
final routeModeMeasurementProvider =
    NotifierProvider<RouteModeMeasurementNotifier, RouteModeMeasurement?>(
      RouteModeMeasurementNotifier.new,
    );

class RouteModeMeasurementNotifier extends Notifier<RouteModeMeasurement?> {
  @override
  RouteModeMeasurement? build() => null;

  void started(RouteModeMeasurement measurement) => state = measurement;
}
