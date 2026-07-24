import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

typedef PeakListPeakResolver = Peak? Function(int peakOsmId);

class PeakListDerivedData {
  const PeakListDerivedData({
    required this.region,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final String region;
  final double? minLat;
  final double? maxLat;
  final double? minLng;
  final double? maxLng;

  PeakList applyTo(PeakList peakList) {
    return peakList.copyWith(
      region: region,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  bool matches(PeakList peakList) {
    return peakList.region == region &&
        peakList.minLat == minLat &&
        peakList.maxLat == maxLat &&
        peakList.minLng == minLng &&
        peakList.maxLng == maxLng;
  }
}

PeakListDerivedData derivePeakListDerivedData({
  required PeakList peakList,
  required Iterable<PeakListItem> items,
  required PeakListPeakResolver peakResolver,
}) {
  final resolvedPeaks = <Peak>[];

  for (final item in items) {
    final peak = peakResolver(item.peakOsmId);
    if (peak != null) {
      resolvedPeaks.add(peak);
    }
  }

  if (resolvedPeaks.isEmpty) {
    return PeakListDerivedData(
      region: normalizeStoredPeakListRegion(peakList.region),
      minLat: null,
      maxLat: null,
      minLng: null,
      maxLng: null,
    );
  }

  var minLat = resolvedPeaks.first.latitude;
  var maxLat = resolvedPeaks.first.latitude;
  var minLng = resolvedPeaks.first.longitude;
  var maxLng = resolvedPeaks.first.longitude;
  final canonicalRegions = <String>{};

  for (final peak in resolvedPeaks) {
    if (peak.latitude < minLat) {
      minLat = peak.latitude;
    }
    if (peak.latitude > maxLat) {
      maxLat = peak.latitude;
    }
    if (peak.longitude < minLng) {
      minLng = peak.longitude;
    }
    if (peak.longitude > maxLng) {
      maxLng = peak.longitude;
    }

    final region = canonicalPeakRegionKey(peak);
    if (region != null) {
      canonicalRegions.add(region);
    }
  }

  return PeakListDerivedData(
    region: switch (canonicalRegions.length) {
      > 1 => PeakList.mixedRegion,
      1 => canonicalRegions.single,
      _ => normalizeStoredPeakListRegion(peakList.region),
    },
    minLat: minLat,
    maxLat: maxLat,
    minLng: minLng,
    maxLng: maxLng,
  );
}

String normalizeStoredPeakListRegion(String region) {
  return normalizePeakListRegionKey(region) ?? Peak.defaultRegion;
}
