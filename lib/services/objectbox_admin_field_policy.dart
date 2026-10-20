/// App facts the persisted ObjectBox model cannot reliably supply. This is not
/// an entity-discovery list or a form generator. Keys are persisted member names.
enum AdminFieldInput { none, text, boolean, sourceOfTruthSelector }

enum AdminDateMeaning { calendarDay, timestamp }

class AdminFieldMetadata {
  const AdminFieldMetadata(
    this.dartType, {
    this.nullable = false,
    this.input = AdminFieldInput.none,
    this.requiredInput = false,
    this.isName = false,
    this.generated = false,
    this.dateMeaning,
  });

  final String dartType;
  final bool nullable;
  final AdminFieldInput input;
  final bool requiredInput;
  final bool isName;
  final bool generated;
  final AdminDateMeaning? dateMeaning;

  bool get permitsDirectInput => input != AdminFieldInput.none && !generated;
  String get typeLabel => '$dartType${nullable ? '?' : ''}';
}

/// Missing metadata never permits a new direct input. Domain actions (coordinate
/// conversion, duration parsing, Mark as HWC, source-key maintenance) are separate.
AdminFieldMetadata? objectBoxAdminFieldMetadata(String entity, String field) =>
    objectBoxAdminAppMetadata[entity]?[field];

const _string = AdminFieldMetadata('String');
const _optionalString = AdminFieldMetadata('String', nullable: true);
const _int = AdminFieldMetadata('int');
const _double = AdminFieldMetadata('double');
const _optionalDouble = AdminFieldMetadata('double', nullable: true);
const _optionalInt = AdminFieldMetadata('int', nullable: true);
const _bool = AdminFieldMetadata('bool');
const _name = AdminFieldMetadata('String', isName: true);
const _text = AdminFieldMetadata('String', input: AdminFieldInput.text);
const _number = AdminFieldMetadata('double', input: AdminFieldInput.text);
const _requiredNumber = AdminFieldMetadata(
  'double',
  input: AdminFieldInput.text,
  requiredInput: true,
);
const _requiredInt = AdminFieldMetadata(
  'int',
  input: AdminFieldInput.text,
  requiredInput: true,
);
const _editableName = AdminFieldMetadata(
  'String',
  input: AdminFieldInput.text,
  requiredInput: true,
  isName: true,
);
const _timestamp = AdminFieldMetadata(
  'DateTime',
  nullable: true,
  dateMeaning: AdminDateMeaning.timestamp,
);

// Reviewed against entity declarations, persisted getter/setters and the five
// existing Admin validators. Tests reject both missing and stale mappings.
const objectBoxAdminAppMetadata = <String, Map<String, AdminFieldMetadata>>{
  'Peak': {
    'id': _int,
    'osmId': _requiredInt,
    'peakbaggerPid': AdminFieldMetadata(
      'int',
      nullable: true,
      input: AdminFieldInput.text,
    ),
    'name': _editableName,
    'altName': _text,
    'elevation': AdminFieldMetadata(
      'double',
      nullable: true,
      input: AdminFieldInput.text,
    ),
    'prominence': AdminFieldMetadata(
      'double',
      nullable: true,
      input: AdminFieldInput.text,
    ),
    'country': _text,
    'county': _text,
    'range': _text,
    'rating': AdminFieldMetadata(
      'double',
      nullable: true,
      input: AdminFieldInput.text,
    ),
    'durationMinutes': _optionalInt,
    'durationLabel': _text,
    'difficulty': _text,
    'viaFerrata': _text,
    'notes': _text,
    'latitude': _number,
    'longitude': _number,
    'region': AdminFieldMetadata(
      'String',
      nullable: true,
      input: AdminFieldInput.text,
    ),
    'gridZoneDesignator': _string,
    'mgrs100kId': _text,
    'easting': _text,
    'northing': _text,
    'verified': AdminFieldMetadata('bool', input: AdminFieldInput.boolean),
    'sourceOfTruth': _string,
  },
  'Tasmap50k': {
    'id': _int,
    'series': _string,
    'name': _name,
    'parentSeries': _string,
    'mgrs100kIds': _string,
    'eastingMin': _int,
    'eastingMax': _int,
    'northingMin': _int,
    'northingMax': _int,
    'mgrsMid': _string,
    'eastingMid': _int,
    'northingMid': _int,
    'p1': _string,
    'p2': _string,
    'p3': _string,
    'p4': _string,
    'p5': _string,
    'p6': _string,
    'p7': _string,
    'p8': _string,
    'p9': _string,
    'p10': _string,
    'p11': _string,
    'p12': _string,
  },
  'GpxTrack': {
    'gpxTrackId': _int,
    'contentHash': _string,
    'trackName': _name,
    'trackDate': AdminFieldMetadata(
      'DateTime',
      nullable: true,
      dateMeaning: AdminDateMeaning.calendarDay,
    ),
    'trackDateStatus': _int,
    'trackDateDerivationVersion': _int,
    'trackDateTimezoneId': _optionalString,
    'trackDateFailureReason': _optionalString,
    'gpxFile': _string,
    'gpxFileRepaired': _string,
    'filteredTrack': _string,
    'displayTrackPointsByZoom': _string,
    'startDateTime': _timestamp,
    'endDateTime': _timestamp,
    'distance2d': _double,
    'distance3d': _double,
    'distanceToPeak': _double,
    'distanceFromPeak': _double,
    'lowestElevation': _double,
    'highestElevation': _double,
    'descent': _double,
    'startElevation': _double,
    'endElevation': _double,
    'elevationProfile': _string,
    'ascent': _optionalDouble,
    'totalTimeMillis': _optionalInt,
    'movingTime': _optionalInt,
    'restingTime': _optionalInt,
    'pausedTime': _optionalInt,
    'averageSpeedKmh': _double,
    'movingSpeedKmh': _double,
    'maxSpeedKmh': _double,
    'trackColour': _int,
    'visible': _bool,
    'peakCorrelationProcessed': _bool,
    'peaks': AdminFieldMetadata('ToMany<Peak>'),
  },
  'PeakList': {
    'peakListId': _int,
    'name': _name,
    'region': _string,
    'colour': _requiredInt,
    'minLat': _optionalDouble,
    'maxLat': _optionalDouble,
    'minLng': _optionalDouble,
    'maxLng': _optionalDouble,
  },
  'PeaksBagged': {
    'baggedId': _int,
    'peakId': _int,
    'gpxId': _int,
    'date': _timestamp,
  },
  'Route': {
    'id': _int,
    'name': _editableName,
    'desc': _text,
    'gpxRouteJson': _string,
    'routeWaypointsJson': _string,
    'displayRoutePointsByZoom': _string,
    'colour': _requiredInt,
    'visible': AdminFieldMetadata('bool', input: AdminFieldInput.boolean),
    'distance2d': _requiredNumber,
    'distance3d': _requiredNumber,
    'ascent': _requiredNumber,
    'descent': _requiredNumber,
    'startElevation': _requiredNumber,
    'endElevation': _requiredNumber,
    'lowestElevation': _requiredNumber,
    'highestElevation': _requiredNumber,
    'estimatedTime': _optionalInt,
    'routeTimingSource': _optionalString,
    'routeTimingProfileJson': _optionalString,
    'walkingSpeedKmh': _optionalDouble,
    'routeTimingSegmentKindsJson': _optionalString,
  },
  'RouteGraphChunk': {
    'id': _int,
    'recordKey': _string,
    'chunkKey': _string,
    'routingCoverageKey': _string,
    'generation': _int,
    'minLat': _double,
    'minLon': _double,
    'maxLat': _double,
    'maxLon': _double,
    'elementCount': _int,
    'payloadJson': _string,
  },
  'RouteGraphManifest': {
    'id': _int,
    'routingCoverageKey': _string,
    'sourceHash': _string,
    'schemaVersion': _string,
    'activeGeneration': _int,
    'importedAt': _timestamp,
    'chunkCount': _int,
    'nodeCount': _int,
    'edgeCount': _int,
    'wayIndexCount': _int,
    'trailDisplayChunkCount': _int,
    'readinessState': _string,
    'lastError': _optionalString,
    'sourceRegionKeysJson': _string,
    'unavailableFootprintJson': _string,
  },
  'RouteGraphWayIndex': {
    'id': _int,
    'recordKey': _string,
    'generation': _int,
    'routingCoverageKey': _string,
    'chunkKey': _string,
    'osmWayId': _int,
    'highway': _optionalString,
    'surface': _optionalString,
    'footway': _optionalString,
    'foot': _optionalString,
    'route': _optionalString,
    'access': _optionalString,
    'name': AdminFieldMetadata('String', nullable: true, isName: true),
    'normalizedName': _optionalString,
    'lengthMeters': _int,
    'tagCount': _int,
    'tagsJson': _string,
  },
  'RouteGraphTrailDisplayChunk': {
    'id': _int,
    'recordKey': _string,
    'generation': _int,
    'routingCoverageKey': _string,
    'cacheZoom': _int,
    'chunkKey': _string,
    'payloadJson': _string,
  },
  'Waypoints': {
    'id': _int,
    'name': _name,
    'type': _string,
    'latitude': _double,
    'longitude': _double,
    'mgrs': _string,
  },
  'PeakListItemEntity': {
    'id': _int,
    'points': _int,
    'peakListId': AdminFieldMetadata('ToOne<PeakList>'),
    'peakId': AdminFieldMetadata('ToOne<Peak>'),
  },
  'RouteGraphImportMetadata': {
    'id': _int,
    'multiCoverageMigrationComplete': _bool,
    'lastReservedGeneration': _int,
  },
  'TrackReplacementRecoveryIssue': {
    'id': _int,
    'sourcePath': _string,
    'destinationPath': _string,
    'backupPath': _optionalString,
    'reason': _string,
  },
  'Contact': {
    'id': _int,
    'firstName': AdminFieldMetadata(
      'String',
      input: AdminFieldInput.text,
      isName: true,
    ),
    'surname': _text,
    'nickname': _text,
  },
  'NaturalFeature': {
    'id': _int,
    'name': _editableName,
    'altName': _text,
    'tag': AdminFieldMetadata(
      'String',
      input: AdminFieldInput.text,
      requiredInput: true,
    ),
    'country': _text,
    'county': _text,
    'region': _text,
    'latitude': _number,
    'longitude': _number,
    'gridZoneDesignator': _string,
    'mgrs100kId': _text,
    'easting': _text,
    'northing': _text,
    'osmId': _int,
    'osmType': _string,
    'sourceOfTruth': AdminFieldMetadata(
      'String',
      input: AdminFieldInput.sourceOfTruthSelector,
      requiredInput: true,
    ),
    'sourceKey': AdminFieldMetadata('String', generated: true),
    'sourceRecordKey': AdminFieldMetadata(
      'String',
      nullable: true,
      generated: true,
    ),
  },
  'PeakRegionFingerprint': {
    'id': _int,
    'regionKey': _string,
    'fingerprint': _string,
  },
  'TrackDateMigrationMetadata': {
    'id': _int,
    'key': _string,
    'completedVersion': _int,
    'completedAt': _timestamp,
    'geographicDataVersion': _string,
    'ianaDataVersion': _string,
    'updatedCount': _int,
    'unchangedCount': _int,
    'skippedCount': _int,
    'skippedRecordsJson': _string,
  },
};
