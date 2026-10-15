bool isRouteGraphTrailWayMetadata({
  required String? highway,
  required String? surface,
  required String? footway,
  required String? foot,
  required String? route,
  required String? access,
  required int lengthMeters,
  required int tagCount,
}) {
  if (access == 'private' ||
      <String>{
        'concrete',
        'asphalt',
        'paved',
        'paving_stones',
      }.contains(surface) ||
      footway == 'sidewalk' ||
      foot == 'no' ||
      route == 'mtb') {
    return false;
  }
  if (highway == 'path') {
    return true;
  }
  if (highway == 'track' && (surface == 'earth' || surface == 'dirt')) {
    return true;
  }
  return highway == 'footway' && lengthMeters > 500 && tagCount > 1;
}
