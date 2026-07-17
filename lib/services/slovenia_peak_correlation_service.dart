import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';

const List<String> sloveniaRankedPeakListCsvHeader = [
  'name',
  'osmId',
  'rating',
  'elevation',
  'prominence',
  'latitude',
  'longitude',
  'country',
  'region',
  'range',
  'county',
  'difficulty',
  'viaFerrata',
  'notes',
  'sourceOfTruth',
];

const List<String> sloveniaCorrelationReviewCsvHeader = [
  ...sloveniaRankedPeakListCsvHeader,
  'correlationReason',
];

const Set<String> sloveniaPeakCorrelationReasonCodes = {
  'missing_hribi_coordinates',
  'no_candidate_within_150m',
  'name_mismatch_beyond_50m',
  'multiple_tied_candidates',
  'multiple_name_confirmed_candidates',
  'insufficient_source_data_for_correlation',
  'no_canonical_region_match',
  'tied_canonical_region_priorities',
};

class SloveniaRankedPeakListCsvRow {
  const SloveniaRankedPeakListCsvRow({
    required this.name,
    required this.osmId,
    required this.rating,
    required this.elevation,
    required this.prominence,
    required this.latitude,
    required this.longitude,
    required this.country,
    required this.region,
    required this.range,
    required this.county,
    required this.difficulty,
    required this.viaFerrata,
    required this.notes,
    required this.sourceOfTruth,
  });

  final String name;
  final String osmId;
  final String rating;
  final String elevation;
  final String prominence;
  final String latitude;
  final String longitude;
  final String country;
  final String region;
  final String range;
  final String county;
  final String difficulty;
  final String viaFerrata;
  final String notes;
  final String sourceOfTruth;

  List<String> toCsvRow() {
    return [
      name,
      osmId,
      rating,
      elevation,
      prominence,
      latitude,
      longitude,
      country,
      region,
      range,
      county,
      difficulty,
      viaFerrata,
      notes,
      sourceOfTruth,
    ];
  }
}

class SloveniaCorrelationReviewCsvRow {
  const SloveniaCorrelationReviewCsvRow({
    required this.row,
    required this.correlationReason,
  });

  final SloveniaRankedPeakListCsvRow row;
  final String correlationReason;

  List<String> toCsvRow() {
    return [...row.toCsvRow(), correlationReason];
  }
}

class SloveniaPeakCorrelationOutput {
  const SloveniaPeakCorrelationOutput({
    required this.canonicalRows,
    required this.reviewRows,
  });

  final List<SloveniaRankedPeakListCsvRow> canonicalRows;
  final List<SloveniaCorrelationReviewCsvRow> reviewRows;
}

class SloveniaPeakCorrelationService {
  const SloveniaPeakCorrelationService({
    required this.peakSource,
    this.canonicalRegionResolver = const SloveniaCanonicalRegionResolver(),
  });

  final PeakSource peakSource;
  final SloveniaCanonicalRegionResolver canonicalRegionResolver;

  static const int candidateSearchRadiusMeters = 150;
  static const int strongNameThresholdMeters = 50;

  SloveniaPeakCorrelationOutput correlate({
    required Iterable<SloveniaHribiSourcePeakListRow> rows,
    int tieWindowMeters = 10,
  }) {
    if (tieWindowMeters < 0) {
      throw ArgumentError.value(
        tieWindowMeters,
        'tieWindowMeters',
        'Must be zero or greater.',
      );
    }

    final peaks = List<Peak>.from(peakSource.getAllPeaks(), growable: false);
    final canonicalRows = <SloveniaRankedPeakListCsvRow>[];
    final reviewRows = <SloveniaCorrelationReviewCsvRow>[];

    for (final row in rows) {
      final decision = _correlateRow(
        row: row,
        peaks: peaks,
        tieWindowMeters: tieWindowMeters,
      );
      if (decision.matchedPeak case final matchedPeak?) {
        final canonicalRowDecision = _buildCanonicalRow(
          row: row,
          peak: matchedPeak,
        );
        if (canonicalRowDecision.row case final canonicalRow?) {
          canonicalRows.add(canonicalRow);
        } else {
          reviewRows.add(
            SloveniaCorrelationReviewCsvRow(
              row: _buildReviewRow(row: row),
              correlationReason:
                  canonicalRowDecision.reviewReason ??
                  'tied_canonical_region_priorities',
            ),
          );
        }
      } else {
        reviewRows.add(
          SloveniaCorrelationReviewCsvRow(
            row: _buildReviewRow(row: row),
            correlationReason: decision.reviewReason!,
          ),
        );
      }
    }

    return SloveniaPeakCorrelationOutput(
      canonicalRows: List<SloveniaRankedPeakListCsvRow>.unmodifiable(
        canonicalRows,
      ),
      reviewRows: List<SloveniaCorrelationReviewCsvRow>.unmodifiable(
        reviewRows,
      ),
    );
  }

  _CorrelationDecision _correlateRow({
    required SloveniaHribiSourcePeakListRow row,
    required List<Peak> peaks,
    required int tieWindowMeters,
  }) {
    final normalizedName = _normalizeName(row.name);
    if (normalizedName.isEmpty) {
      return const _CorrelationDecision.review(
        'insufficient_source_data_for_correlation',
      );
    }

    final latitude = double.tryParse(row.latitude);
    final longitude = double.tryParse(row.longitude);
    if (latitude == null || longitude == null) {
      return const _CorrelationDecision.review('missing_hribi_coordinates');
    }

    final candidates = <_CorrelationCandidate>[];
    for (final peak in peaks) {
      final distanceMeters = haversineDistance(
        latitude,
        longitude,
        peak.latitude,
        peak.longitude,
      );
      if (distanceMeters > candidateSearchRadiusMeters) {
        continue;
      }

      candidates.add(
        _CorrelationCandidate(
          peak: peak,
          distanceMeters: distanceMeters,
          hasStrongNameConfirmation:
              _normalizeName(peak.name) == normalizedName ||
              _normalizeName(peak.altName) == normalizedName,
        ),
      );
    }

    if (candidates.isEmpty) {
      return const _CorrelationDecision.review('no_candidate_within_150m');
    }

    candidates.sort((left, right) {
      final distanceComparison = left.distanceMeters.compareTo(
        right.distanceMeters,
      );
      if (distanceComparison != 0) {
        return distanceComparison;
      }
      return left.peak.id.compareTo(right.peak.id);
    });

    final qualifyingCandidates = <_CorrelationCandidate>[];
    final nameConfirmedCandidates = <_CorrelationCandidate>[];
    for (final candidate in candidates) {
      final isWithinStrongSpatialWindow =
          candidate.distanceMeters <= strongNameThresholdMeters;
      if (candidate.hasStrongNameConfirmation) {
        nameConfirmedCandidates.add(candidate);
      }
      if (isWithinStrongSpatialWindow || candidate.hasStrongNameConfirmation) {
        qualifyingCandidates.add(candidate);
      }
    }

    if (qualifyingCandidates.isEmpty) {
      return const _CorrelationDecision.review('name_mismatch_beyond_50m');
    }

    final bestCandidate = qualifyingCandidates.first;
    if (qualifyingCandidates.length > 1) {
      final runnerUp = qualifyingCandidates[1];
      final distanceGap =
          runnerUp.distanceMeters - bestCandidate.distanceMeters;
      if (distanceGap.abs() <= tieWindowMeters) {
        return const _CorrelationDecision.review('multiple_tied_candidates');
      }
    }

    if (bestCandidate.distanceMeters > strongNameThresholdMeters &&
        nameConfirmedCandidates.length > 1) {
      return const _CorrelationDecision.review(
        'multiple_name_confirmed_candidates',
      );
    }

    return _CorrelationDecision.matched(bestCandidate.peak);
  }

  _CanonicalRowDecision _buildCanonicalRow({
    required SloveniaHribiSourcePeakListRow row,
    required Peak peak,
  }) {
    final latitude = double.tryParse(row.latitude) ?? peak.latitude;
    final longitude = double.tryParse(row.longitude) ?? peak.longitude;
    final canonicalization = canonicalRegionResolver.resolve(
      latitude: latitude,
      longitude: longitude,
      rawCountry: _firstNonBlank(row.country, peak.country),
      existingNotes: peak.notes,
    );
    if (canonicalization.reviewReason case final reviewReason?) {
      return _CanonicalRowDecision.review(reviewReason);
    }

    return _CanonicalRowDecision.success(
      SloveniaRankedPeakListCsvRow(
        name: row.name,
        osmId: peak.osmId.toString(),
        rating: row.rating,
        elevation: _firstNonBlank(row.altitude, _formatNumber(peak.elevation)),
        prominence: _formatNumber(peak.prominence),
        latitude: _formatNumber(latitude),
        longitude: _formatNumber(longitude),
        country: canonicalization.country!,
        region: canonicalization.region!,
        range: _firstNonBlank(row.mountainRange, peak.range),
        county: peak.county,
        difficulty: peak.difficulty,
        viaFerrata: peak.viaFerrata,
        notes: canonicalization.notes!,
        sourceOfTruth: row.sourceOfTruth,
      ),
    );
  }

  SloveniaRankedPeakListCsvRow _buildReviewRow({
    required SloveniaHribiSourcePeakListRow row,
  }) {
    return SloveniaRankedPeakListCsvRow(
      name: row.name,
      osmId: '0',
      rating: row.rating,
      elevation: row.altitude,
      prominence: '',
      latitude: row.latitude,
      longitude: row.longitude,
      country: row.country,
      region: 'Slovenia',
      range: row.mountainRange,
      county: '',
      difficulty: '',
      viaFerrata: '',
      notes: '',
      sourceOfTruth: row.sourceOfTruth,
    );
  }
}

class SloveniaCanonicalRegionResolver {
  const SloveniaCanonicalRegionResolver();

  static const _aggregateRegionKeys = {
    'italy',
    'italy-nord-est',
    'italy-nord-ovest',
  };

  static const _countryNameByRegionKey = {
    'tasmania': 'Australia',
    'new-south-wales': 'Australia',
    'fvg': 'Italy',
    'veneto': 'Italy',
    'trentino-alto-adige': 'Italy',
    'emilia-romagna': 'Italy',
    'italy': 'Italy',
    'italy-nord-est': 'Italy',
    'italy-nord-ovest': 'Italy',
    'slovenia': 'Slovenia',
    'croatia': 'Croatia',
  };

  SloveniaCanonicalRegionResolution resolve({
    required double latitude,
    required double longitude,
    required String rawCountry,
    required String existingNotes,
  }) {
    final point = LatLng(latitude, longitude);
    final allCandidateRegions = candidateRegionsForPoint(point);
    if (allCandidateRegions.isEmpty) {
      return const SloveniaCanonicalRegionResolution.review(
        'no_canonical_region_match',
      );
    }
    final candidateRegions = highestPriorityCandidateRegions(
      allCandidateRegions,
    );
    if (candidateRegions.length > 1) {
      return const SloveniaCanonicalRegionResolution.review(
        'tied_canonical_region_priorities',
      );
    }

    final winner = candidateRegions.single;
    if (_aggregateRegionKeys.contains(winner.key)) {
      return const SloveniaCanonicalRegionResolution.review(
        'no_canonical_region_match',
      );
    }

    final country = countryNameForRegionKey(winner.key);
    if (country == null) {
      return const SloveniaCanonicalRegionResolution.review(
        'no_canonical_region_match',
      );
    }

    final borderCountries = _borderCountries(
      rawCountry: rawCountry,
      canonicalCountry: country,
    );
    return SloveniaCanonicalRegionResolution.success(
      country: country,
      region: winner.name,
      notes: _appendBorderNote(existingNotes, borderCountries),
    );
  }

  List<RegionManifestRegionData> candidateRegionsForPoint(LatLng point) {
    return regionManifestCatalog.regionsForPointByPriority(point);
  }

  List<RegionManifestRegionData> highestPriorityCandidateRegions(
    List<RegionManifestRegionData> candidates,
  ) {
    if (candidates.isEmpty) {
      return const [];
    }

    final highestPriority = candidates.first.priority;
    return [
      for (final region in candidates)
        if (region.priority.compareTo(highestPriority) == 0) region,
    ];
  }

  String? countryNameForRegionKey(String regionKey) {
    return _countryNameByRegionKey[regionKey];
  }
}

class SloveniaCanonicalRegionResolution {
  const SloveniaCanonicalRegionResolution.success({
    required this.country,
    required this.region,
    required this.notes,
  }) : reviewReason = null;

  const SloveniaCanonicalRegionResolution.review(this.reviewReason)
    : country = null,
      region = null,
      notes = null;

  final String? country;
  final String? region;
  final String? notes;
  final String? reviewReason;
}

class _CorrelationDecision {
  const _CorrelationDecision.matched(this.matchedPeak) : reviewReason = null;

  const _CorrelationDecision.review(this.reviewReason) : matchedPeak = null;

  final Peak? matchedPeak;
  final String? reviewReason;
}

class _CorrelationCandidate {
  const _CorrelationCandidate({
    required this.peak,
    required this.distanceMeters,
    required this.hasStrongNameConfirmation,
  });

  final Peak peak;
  final double distanceMeters;
  final bool hasStrongNameConfirmation;
}

class _CanonicalRowDecision {
  const _CanonicalRowDecision.success(this.row) : reviewReason = null;

  const _CanonicalRowDecision.review(this.reviewReason) : row = null;

  final SloveniaRankedPeakListCsvRow? row;
  final String? reviewReason;
}

String _firstNonBlank(String preferred, String fallback) {
  return preferred.trim().isNotEmpty ? preferred : fallback;
}

List<String> _borderCountries({
  required String rawCountry,
  required String canonicalCountry,
}) {
  final seen = <String>{};
  final countries = <String>[];
  for (final token in rawCountry.split(',')) {
    final trimmed = token.trim();
    if (trimmed.isEmpty || trimmed == canonicalCountry || !seen.add(trimmed)) {
      continue;
    }
    countries.add(trimmed);
  }
  return countries;
}

String _appendBorderNote(String existingNotes, List<String> borderCountries) {
  if (borderCountries.isEmpty) {
    return existingNotes;
  }

  final borderNote = 'Border peak with ${borderCountries.join(', ')}';
  if (existingNotes.trim().isEmpty) {
    return borderNote;
  }

  return '${existingNotes.trim()}; $borderNote';
}

String _formatNumber(double? value) {
  if (value == null) {
    return '';
  }

  var text = value.toString();
  if (!text.contains('.')) {
    return text;
  }
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

String _normalizeName(String value) {
  var normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  normalized = _stripDiacritics(normalized);
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

String _stripDiacritics(String value) {
  return value
      .replaceAll(RegExp('[àáâãäåāăąǎȁȃạảấầẩẫậắằẳẵặ]'), 'a')
      .replaceAll(RegExp('[çćĉċč]'), 'c')
      .replaceAll(RegExp('[ďđ]'), 'd')
      .replaceAll(RegExp('[èéêëēĕėęěẹẻẽếềểễệ]'), 'e')
      .replaceAll(RegExp('[ĝğġģ]'), 'g')
      .replaceAll(RegExp('[ĥħ]'), 'h')
      .replaceAll(RegExp('[ìíîïĩīĭįı]'), 'i')
      .replaceAll(RegExp('[ĵ]'), 'j')
      .replaceAll(RegExp('[ķ]'), 'k')
      .replaceAll(RegExp('[ĺļľł]'), 'l')
      .replaceAll(RegExp('[ñńņň]'), 'n')
      .replaceAll(RegExp('[òóôõöøōŏőơǒọỏốồổỗộớờởỡợ]'), 'o')
      .replaceAll(RegExp('[ŕŗř]'), 'r')
      .replaceAll(RegExp('[śŝşšș]'), 's')
      .replaceAll(RegExp('[ťţț]'), 't')
      .replaceAll(RegExp('[ùúûüũūŭůűųưǔụủứừửữự]'), 'u')
      .replaceAll(RegExp('[ŵ]'), 'w')
      .replaceAll(RegExp('[ýÿŷ]'), 'y')
      .replaceAll(RegExp('[źżž]'), 'z')
      .replaceAll('æ', 'ae')
      .replaceAll('œ', 'oe')
      .replaceAll('ß', 'ss');
}
