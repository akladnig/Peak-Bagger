import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';

class RouteAdminFormState {
  const RouteAdminFormState({
    required this.name,
    required this.desc,
    required this.visible,
    required this.colour,
    required this.distance2d,
    required this.distance3d,
    required this.ascent,
    required this.descent,
    required this.startElevation,
    required this.endElevation,
    required this.lowestElevation,
    required this.highestElevation,
  });

  final String name;
  final String desc;
  final bool visible;
  final String colour;
  final String distance2d;
  final String distance3d;
  final String ascent;
  final String descent;
  final String startElevation;
  final String endElevation;
  final String lowestElevation;
  final String highestElevation;

  RouteAdminFormState copyWith({
    String? name,
    String? desc,
    bool? visible,
    String? colour,
    String? distance2d,
    String? distance3d,
    String? ascent,
    String? descent,
    String? startElevation,
    String? endElevation,
    String? lowestElevation,
    String? highestElevation,
  }) {
    return RouteAdminFormState(
      name: name ?? this.name,
      desc: desc ?? this.desc,
      visible: visible ?? this.visible,
      colour: colour ?? this.colour,
      distance2d: distance2d ?? this.distance2d,
      distance3d: distance3d ?? this.distance3d,
      ascent: ascent ?? this.ascent,
      descent: descent ?? this.descent,
      startElevation: startElevation ?? this.startElevation,
      endElevation: endElevation ?? this.endElevation,
      lowestElevation: lowestElevation ?? this.lowestElevation,
      highestElevation: highestElevation ?? this.highestElevation,
    );
  }
}

class RouteAdminValidationResult {
  const RouteAdminValidationResult({
    required this.fieldErrors,
    this.route,
  });

  final Map<String, String> fieldErrors;
  final Route? route;

  bool get isValid => route != null;
}

class RouteAdminEditor {
  static RouteAdminFormState normalize(Route route) {
    return RouteAdminFormState(
      name: route.name,
      desc: route.desc,
      visible: route.visible,
      colour: _formatHexColour(route.colour),
      distance2d: route.distance2d.toString(),
      distance3d: route.distance3d.toString(),
      ascent: route.ascent.toString(),
      descent: route.descent.toString(),
      startElevation: route.startElevation.toString(),
      endElevation: route.endElevation.toString(),
      lowestElevation: route.lowestElevation.toString(),
      highestElevation: route.highestElevation.toString(),
    );
  }

  static RouteAdminValidationResult validateAndBuild({
    required Route source,
    required RouteAdminFormState form,
  }) {
    final fieldErrors = <String, String>{};

    final name = form.name.trim();
    if (name.isEmpty) {
      fieldErrors['name'] = 'A route name is required';
    }

    final colour = _parseInt(
      value: form.colour,
      fieldName: 'colour',
      fieldErrors: fieldErrors,
    );
    final distance2d = _parseDouble(
      value: form.distance2d,
      fieldName: 'distance2d',
      fieldErrors: fieldErrors,
    );
    final distance3d = _parseDouble(
      value: form.distance3d,
      fieldName: 'distance3d',
      fieldErrors: fieldErrors,
    );
    final ascent = _parseDouble(
      value: form.ascent,
      fieldName: 'ascent',
      fieldErrors: fieldErrors,
    );
    final descent = _parseDouble(
      value: form.descent,
      fieldName: 'descent',
      fieldErrors: fieldErrors,
    );
    final startElevation = _parseDouble(
      value: form.startElevation,
      fieldName: 'startElevation',
      fieldErrors: fieldErrors,
    );
    final endElevation = _parseDouble(
      value: form.endElevation,
      fieldName: 'endElevation',
      fieldErrors: fieldErrors,
    );
    final lowestElevation = _parseDouble(
      value: form.lowestElevation,
      fieldName: 'lowestElevation',
      fieldErrors: fieldErrors,
    );
    final highestElevation = _parseDouble(
      value: form.highestElevation,
      fieldName: 'highestElevation',
      fieldErrors: fieldErrors,
    );

    if (fieldErrors.isNotEmpty) {
      return RouteAdminValidationResult(fieldErrors: fieldErrors);
    }

    final updated = Route(
      id: source.id,
      name: name,
      desc: form.desc,
      visible: form.visible,
      gpxRoute: List<LatLng>.from(source.gpxRoute, growable: false),
      gpxRouteElevations: List<int?>.from(
        source.gpxRouteElevations,
        growable: false,
      ),
      routeWaypoints: List<RouteWaypoint>.from(source.routeWaypoints),
      displayRoutePointsByZoom: source.displayRoutePointsByZoom,
      colour: colour!,
      distance2d: distance2d!,
      distance3d: distance3d!,
      ascent: ascent!,
      descent: descent!,
      startElevation: startElevation!,
      endElevation: endElevation!,
      lowestElevation: lowestElevation!,
      highestElevation: highestElevation!,
    );

    return RouteAdminValidationResult(fieldErrors: fieldErrors, route: updated);
  }

  static double? _parseDouble({
    required String value,
    required String fieldName,
    required Map<String, String> fieldErrors,
  }) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      fieldErrors[fieldName] = '$fieldName must be a number';
      return null;
    }
    return parsed;
  }

  static int? _parseInt({
    required String value,
    required String fieldName,
    required Map<String, String> fieldErrors,
  }) {
    final trimmed = value.trim();
    final parsed = trimmed.startsWith('0x') || trimmed.startsWith('0X')
        ? int.tryParse(trimmed.substring(2), radix: 16)
        : int.tryParse(trimmed);
    if (parsed == null) {
      fieldErrors[fieldName] = '$fieldName must be an integer';
      return null;
    }
    return parsed;
  }

  static String _formatHexColour(int value) {
    return '0x${value.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
