import 'package:shared_preferences/shared_preferences.dart';

import '../objectbox.g.dart';

const _objectBoxSchemaSignatureKey = 'objectbox_schema_signature';

class ObjectBoxSchemaGuard {
  ObjectBoxSchemaGuard({
    Future<SharedPreferences> Function()? prefsLoader,
    String Function()? signatureLoader,
  }) : _prefsLoader = prefsLoader ?? SharedPreferences.getInstance,
       _signatureLoader = signatureLoader ?? _currentSchemaSignature;

  final Future<SharedPreferences> Function() _prefsLoader;
  final String Function() _signatureLoader;

  Future<void> verify() async {
    final prefs = await _prefsLoader();
    final currentSignature = _signatureLoader();

    await prefs.setString(_objectBoxSchemaSignatureKey, currentSignature);
  }

  static String debugCurrentSchemaSignature() {
    return _currentSchemaSignature();
  }

  static String _currentSchemaSignature() {
    final model = getObjectBoxModel().model;
    final peak = model.findEntityByName('Peak');
    final peakList = model.findEntityByName('PeakList');
    final gpxTrack = model.findEntityByName('GpxTrack');
    final peaksBagged = model.findEntityByName('PeaksBagged');
    final route = model.findEntityByName('Route');

    return [
      'modelVersion:${model.modelVersion}',
      'Peak.osmId:${_hasProperty(peak, 'osmId')}',
      'Peak.peakbaggerPid:${_hasProperty(peak, 'peakbaggerPid')}',
      'Peak.altName:${_hasProperty(peak, 'altName')}',
      'Peak.prominence:${_hasProperty(peak, 'prominence')}',
      'Peak.country:${_hasProperty(peak, 'country')}',
      'Peak.county:${_hasProperty(peak, 'county')}',
      'Peak.range:${_hasProperty(peak, 'range')}',
      'Peak.verified:${_hasProperty(peak, 'verified')}',
      'Peak.sourceOfTruth:${_hasProperty(peak, 'sourceOfTruth')}',
      'PeakList.name:${_hasProperty(peakList, 'name')}',
      'PeakList.peakList:${_hasProperty(peakList, 'peakList')}',
      'GpxTrack.peaks:${_hasRelation(gpxTrack, 'peaks')}',
      'GpxTrack.peakCorrelationProcessed:${_hasProperty(gpxTrack, 'peakCorrelationProcessed')}',
      'PeaksBagged.peakId:${_hasProperty(peaksBagged, 'peakId')}',
      'PeaksBagged.gpxId:${_hasProperty(peaksBagged, 'gpxId')}',
      'PeaksBagged.date:${_hasProperty(peaksBagged, 'date')}',
      'Route.name:${_hasProperty(route, 'name')}',
      'Route.desc:${_hasProperty(route, 'desc')}',
      'Route.gpxRouteJson:${_hasProperty(route, 'gpxRouteJson')}',
      'Route.routeWaypointsJson:${_hasProperty(route, 'routeWaypointsJson')}',
      'Route.estimatedTime:${_hasProperty(route, 'estimatedTime')}',
      'Route.routeTimingSource:${_hasProperty(route, 'routeTimingSource')}',
      'Route.routeTimingProfileJson:${_hasProperty(route, 'routeTimingProfileJson')}',
      'Route.walkingSpeedKmh:${_hasProperty(route, 'walkingSpeedKmh')}',
      'Route.routeTimingSegmentKindsJson:${_hasProperty(route, 'routeTimingSegmentKindsJson')}',
      'Route.displayRoutePointsByZoom:${_hasProperty(route, 'displayRoutePointsByZoom')}',
      'Route.colour:${_hasProperty(route, 'colour')}',
    ].join('|');
  }

  static bool _hasProperty(dynamic entity, String name) {
    if (entity == null) {
      return false;
    }

    return entity.properties.any((property) => property.name == name);
  }

  static bool _hasRelation(dynamic entity, String name) {
    if (entity == null) {
      return false;
    }

    return entity.relations.any((relation) => relation.name == name);
  }
}
