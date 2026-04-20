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

    return [
      'modelVersion:${model.modelVersion}',
      'Peak.osmId:${_hasProperty(peak, 'osmId')}',
      'Peak.sourceOfTruth:${_hasProperty(peak, 'sourceOfTruth')}',
      'PeakList.name:${_hasProperty(peakList, 'name')}',
      'PeakList.peakList:${_hasProperty(peakList, 'peakList')}',
      'GpxTrack.peaks:${_hasRelation(gpxTrack, 'peaks')}',
      'GpxTrack.peakCorrelationProcessed:${_hasProperty(gpxTrack, 'peakCorrelationProcessed')}',
      'PeaksBagged.peakId:${_hasProperty(peaksBagged, 'peakId')}',
      'PeaksBagged.gpxId:${_hasProperty(peaksBagged, 'gpxId')}',
      'PeaksBagged.date:${_hasProperty(peaksBagged, 'date')}',
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
