class RouteWaypoint {
  const RouteWaypoint({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.sequence,
    required this.isPeakDerived,
    this.peakOsmId,
    this.peakName,
  });

  final double latitude;
  final double longitude;
  final String label;
  final int sequence;
  final bool isPeakDerived;
  final int? peakOsmId;
  final String? peakName;

  Map<String, Object?> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      'sequence': sequence,
      'isPeakDerived': isPeakDerived,
      'peakOsmId': peakOsmId,
      'peakName': peakName,
    };
  }

  static RouteWaypoint? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }

    final latitude = value['latitude'];
    final longitude = value['longitude'];
    final label = value['label'];
    final sequence = value['sequence'];
    final isPeakDerived = value['isPeakDerived'];
    if (latitude is! num ||
        longitude is! num ||
        label is! String ||
        sequence is! num ||
        isPeakDerived is! bool) {
      return null;
    }

    final peakOsmId = value['peakOsmId'];
    final peakName = value['peakName'];
    return RouteWaypoint(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      label: label,
      sequence: sequence.toInt(),
      isPeakDerived: isPeakDerived,
      peakOsmId: peakOsmId is num ? peakOsmId.toInt() : null,
      peakName: peakName is String ? peakName : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RouteWaypoint &&
            latitude == other.latitude &&
            longitude == other.longitude &&
            label == other.label &&
            sequence == other.sequence &&
            isPeakDerived == other.isPeakDerived &&
            peakOsmId == other.peakOsmId &&
            peakName == other.peakName;
  }

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    label,
    sequence,
    isPeakDerived,
    peakOsmId,
    peakName,
  );
}
