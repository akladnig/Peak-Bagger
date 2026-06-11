import 'dart:math' as math;

import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

class PeakBaggerCorrelationResult {
  const PeakBaggerCorrelationResult({
    required this.peak,
    required this.action,
    required this.detail,
    required this.note,
    required this.safeToCreate,
  });

  final Peak? peak;
  final String action;
  final String detail;
  final String note;
  final bool safeToCreate;

  bool get isMatched => peak != null;
}

class PeakBaggerCorrelationOptions {
  const PeakBaggerCorrelationOptions({
    this.exactNameOnly = false,
    this.elevationOnly = false,
    this.elevationToleranceMeters = 10,
  });

  final bool exactNameOnly;
  final bool elevationOnly;
  final int elevationToleranceMeters;

  bool get hasFilters => exactNameOnly || elevationOnly;
}

class PeakBaggerPeakCorrelationService {
  const PeakBaggerPeakCorrelationService({
    this.spatialThresholdMeters = 50,
    this.elevationThresholdMeters = 10,
    this.tieBreakToleranceMeters = 1,
  });

  final int spatialThresholdMeters;
  final int elevationThresholdMeters;
  final int tieBreakToleranceMeters;

  bool isStrongSpatialMatch({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required Peak peak,
  }) {
    if (!peakBaggerPeak.hasCoordinates) {
      return false;
    }

    final peakBaggerLatitude = peakBaggerPeak.latitude!;
    final peakBaggerLongitude = peakBaggerPeak.longitude!;
    final distanceMeters = haversineDistance(
      peakBaggerLatitude,
      peakBaggerLongitude,
      peak.latitude,
      peak.longitude,
    );
    if (distanceMeters > spatialThresholdMeters) {
      return false;
    }

    return _hasCompatibleElevation(peakBaggerPeak.elevation, peak.elevation);
  }

  PeakBaggerCorrelationResult correlate({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required List<Peak> peaks,
    PeakBaggerCorrelationOptions options = const PeakBaggerCorrelationOptions(),
  }) {
    if (options.hasFilters) {
      return _correlateWithFilters(
        peakBaggerPeak: peakBaggerPeak,
        peaks: peaks,
        options: options,
      );
    }

    final hasCoordinates = peakBaggerPeak.hasCoordinates;
    final nearestDistanceMeters = hasCoordinates
        ? _nearestDistanceMeters(peakBaggerPeak, peaks)
        : null;

    final exactPrimaryNameMatches = <Peak>[];
    final exactPrimaryNameMatchIds = <int>{};
    for (final peak in peaks) {
      if (_hasExactNameMatch(peakBaggerPeak.name, peak.name)) {
        if (exactPrimaryNameMatchIds.add(peak.id)) {
          exactPrimaryNameMatches.add(peak);
        }
      }
    }

    final spatialCandidates = <_SpatialCandidate>[];
    if (hasCoordinates) {
      final peakBaggerLatitude = peakBaggerPeak.latitude!;
      final peakBaggerLongitude = peakBaggerPeak.longitude!;
      for (final peak in peaks) {
        final distanceMeters = haversineDistance(
          peakBaggerLatitude,
          peakBaggerLongitude,
          peak.latitude,
          peak.longitude,
        );
        if (distanceMeters > spatialThresholdMeters) {
          continue;
        }

        if (!_hasCompatibleElevation(
          peakBaggerPeak.elevation,
          peak.elevation,
        )) {
          continue;
        }

        final elevationDifference =
            peakBaggerPeak.elevation == null || peak.elevation == null
            ? 0
            : (peakBaggerPeak.elevation! - peak.elevation!).abs().round();

        spatialCandidates.add(
          _SpatialCandidate(
            peak: peak,
            distanceMeters: distanceMeters,
            elevationDifference: elevationDifference,
          ),
        );
      }
    }

    if (spatialCandidates.isNotEmpty) {
      spatialCandidates.sort((a, b) {
        final distanceCompare = a.distanceMeters.compareTo(b.distanceMeters);
        if (distanceCompare != 0) {
          return distanceCompare;
        }
        final elevationCompare = a.elevationDifference.compareTo(
          b.elevationDifference,
        );
        if (elevationCompare != 0) {
          return elevationCompare;
        }
        return a.peak.id.compareTo(b.peak.id);
      });

      if (spatialCandidates.length == 1) {
        final candidate = spatialCandidates.single;
        final spatialResult = PeakBaggerCorrelationResult(
          peak: candidate.peak,
          action: 'spatial-match',
          detail:
              'matched within ${spatialThresholdMeters}m/${elevationThresholdMeters}m window',
          note: 'matched via strong spatial match',
          safeToCreate: false,
        );
        if (exactPrimaryNameMatches.length == 1 &&
            exactPrimaryNameMatches.single.id != candidate.peak.id) {
          return _exactNameResult(
            peakBaggerPeak: peakBaggerPeak,
            peak: exactPrimaryNameMatches.single,
          );
        }
        return spatialResult;
      }

      final best = spatialCandidates.first;
      final runnerUp = spatialCandidates[1];
      final distanceGap = runnerUp.distanceMeters - best.distanceMeters;
      if (distanceGap.abs() <= tieBreakToleranceMeters) {
        return PeakBaggerCorrelationResult(
          peak: null,
          action: 'closest-location-tie',
          detail:
              'closest candidates were effectively tied at ${best.distanceMeters.toStringAsFixed(1)}m',
          note: 'unresolved: closest-location tie',
          safeToCreate: false,
        );
      }

      final spatialResult = PeakBaggerCorrelationResult(
        peak: best.peak,
        action: 'closest-location-tie-break',
        detail:
            'selected ${best.peak.name} at ${best.distanceMeters.toStringAsFixed(1)}m over ${runnerUp.peak.name} at ${runnerUp.distanceMeters.toStringAsFixed(1)}m',
        note: 'matched via closest-location tie-break',
        safeToCreate: false,
      );
      if (exactPrimaryNameMatches.length == 1 &&
          exactPrimaryNameMatches.single.id != best.peak.id) {
        return _exactNameResult(
          peakBaggerPeak: peakBaggerPeak,
          peak: exactPrimaryNameMatches.single,
        );
      }
      return spatialResult;
    }

    final exactNameMatches = <Peak>[];
    final exactNameMatchIds = <int>{};
    final nameMatches = <Peak>[];
    final weakNameMatches = <Peak>[];
    for (final peak in peaks) {
      final hasExactNameMatch =
          _hasExactNameMatch(peakBaggerPeak.name, peak.altName) ||
          _hasExactNameMatch(peakBaggerPeak.altName, peak.name) ||
          _hasExactNameMatch(peakBaggerPeak.altName, peak.altName);
      if (hasExactNameMatch &&
          !exactPrimaryNameMatchIds.contains(peak.id) &&
          exactNameMatchIds.add(peak.id)) {
        exactNameMatches.add(peak);
      }

      final hasStrongNameMatch =
          _hasStrongNameConfirmation(peakBaggerPeak.name, peak.name) ||
          _hasStrongNameConfirmation(peakBaggerPeak.name, peak.altName) ||
          _hasStrongNameConfirmation(peakBaggerPeak.altName, peak.name) ||
          _hasStrongNameConfirmation(peakBaggerPeak.altName, peak.altName);
      if (hasStrongNameMatch) {
        nameMatches.add(peak);
        continue;
      }

      final hasWeakNameMatch =
          _hasWeakNameMatch(peakBaggerPeak.name, peak.name) ||
          _hasWeakNameMatch(peakBaggerPeak.name, peak.altName) ||
          _hasWeakNameMatch(peakBaggerPeak.altName, peak.name) ||
          _hasWeakNameMatch(peakBaggerPeak.altName, peak.altName);
      if (hasWeakNameMatch) {
        weakNameMatches.add(peak);
      }
    }

    final bestExactPrimaryMatch = _bestExactNameCandidate(
      peakBaggerPeak: peakBaggerPeak,
      peaks: exactPrimaryNameMatches,
    );
    if (bestExactPrimaryMatch != null) {
      return _exactNameResult(
        peakBaggerPeak: peakBaggerPeak,
        peak: bestExactPrimaryMatch,
      );
    }

    final bestExactNameMatch = _bestExactNameCandidate(
      peakBaggerPeak: peakBaggerPeak,
      peaks: exactNameMatches,
    );
    if (bestExactNameMatch != null) {
      return _exactNameResult(
        peakBaggerPeak: peakBaggerPeak,
        peak: bestExactNameMatch,
      );
    }

    if (exactPrimaryNameMatches.isNotEmpty || exactNameMatches.isNotEmpty) {
      final exactCandidates = [...exactPrimaryNameMatches, ...exactNameMatches];
      final distanceSuffix = _nearestDistanceSuffix(nearestDistanceMeters);
      return PeakBaggerCorrelationResult(
        peak: null,
        action: 'unresolved',
        detail:
            'no confident spatial match and multiple exact-name candidates${_candidateSummary(exactCandidates)}$distanceSuffix',
        note:
            'unresolved: no confident spatial match and multiple exact-name candidates${_candidateSummary(exactCandidates)}$distanceSuffix',
        safeToCreate: false,
      );
    }

    if (nameMatches.length == 1) {
      return PeakBaggerCorrelationResult(
        peak: nameMatches.single,
        action: 'strong-name-fallback',
        detail: 'matched by normalized name',
        note: 'matched via strong-name fallback',
        safeToCreate: false,
      );
    }

    if (nameMatches.length > 1) {
      final distanceSuffix = _nearestDistanceSuffix(nearestDistanceMeters);
      return PeakBaggerCorrelationResult(
        peak: null,
        action: 'unresolved',
        detail:
            'no confident spatial match and multiple strong-name candidates${_candidateSummary(nameMatches)}$distanceSuffix',
        note:
            'unresolved: no confident spatial match and multiple strong-name candidates${_candidateSummary(nameMatches)}$distanceSuffix',
        safeToCreate: false,
      );
    }

    final distanceSuffix = _nearestDistanceSuffix(nearestDistanceMeters);
    return PeakBaggerCorrelationResult(
      peak: null,
      action: 'unresolved',
      detail:
          'no confident spatial match and no strong-name match$distanceSuffix',
      note:
          'unresolved: no confident spatial match and no strong-name match$distanceSuffix',
      safeToCreate: weakNameMatches.isEmpty,
    );
  }

  PeakBaggerCorrelationResult _correlateWithFilters({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required List<Peak> peaks,
    required PeakBaggerCorrelationOptions options,
  }) {
    final nearestDistanceMeters = peakBaggerPeak.hasCoordinates
        ? _nearestDistanceMeters(peakBaggerPeak, peaks)
        : null;
    final weakNameMatches = _weakNameMatches(peakBaggerPeak, peaks);
    final filteredCandidates = peaks
        .where(
          (peak) => _matchesRequiredFilters(
            peakBaggerPeak: peakBaggerPeak,
            peak: peak,
            options: options,
          ),
        )
        .toList(growable: false);

    if (filteredCandidates.isEmpty) {
      final detail = _filteredNoMatchDetail(
        options: options,
        nearestDistanceMeters: nearestDistanceMeters,
      );
      return PeakBaggerCorrelationResult(
        peak: null,
        action: 'unresolved',
        detail: detail,
        note: 'unresolved: $detail',
        safeToCreate: weakNameMatches.isEmpty,
      );
    }

    final resolvedPeak = _resolveFilteredCandidate(
      peakBaggerPeak: peakBaggerPeak,
      peaks: filteredCandidates,
    );
    if (resolvedPeak == null) {
      final detail = _filteredMultipleMatchDetail(
        options: options,
        peaks: filteredCandidates,
      );
      return PeakBaggerCorrelationResult(
        peak: null,
        action: 'unresolved',
        detail: detail,
        note: 'unresolved: $detail',
        safeToCreate: false,
      );
    }

    return _filteredMatchResult(
      peakBaggerPeak: peakBaggerPeak,
      peak: resolvedPeak,
      options: options,
    );
  }

  double? _nearestDistanceMeters(
    PeakBaggerPeakDetails peakBaggerPeak,
    List<Peak> peaks,
  ) {
    final peakBaggerLatitude = peakBaggerPeak.latitude!;
    final peakBaggerLongitude = peakBaggerPeak.longitude!;
    double? nearestDistanceMeters;
    for (final peak in peaks) {
      final distanceMeters = haversineDistance(
        peakBaggerLatitude,
        peakBaggerLongitude,
        peak.latitude,
        peak.longitude,
      );
      if (nearestDistanceMeters == null ||
          distanceMeters < nearestDistanceMeters) {
        nearestDistanceMeters = distanceMeters;
      }
    }
    return nearestDistanceMeters;
  }

  String _nearestDistanceSuffix(double? nearestDistanceMeters) {
    if (nearestDistanceMeters == null || nearestDistanceMeters >= 1000) {
      return '';
    }
    return ' (nearest ${nearestDistanceMeters.toStringAsFixed(1)}m)';
  }

  String _candidateSummary(List<Peak> peaks) {
    if (peaks.isEmpty) {
      return '';
    }

    final labels = peaks
        .map((peak) => peak.name)
        .take(3)
        .toList(growable: false);
    final suffix = peaks.length > labels.length ? ', ...' : '';
    return ' (candidates: ${labels.join('; ')}$suffix)';
  }

  Peak? _bestExactNameCandidate({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required List<Peak> peaks,
  }) {
    final compatibleCandidates = peaks
        .where(
          (peak) =>
              _hasCompatibleElevation(peakBaggerPeak.elevation, peak.elevation),
        )
        .toList(growable: false);
    if (compatibleCandidates.isEmpty) {
      return null;
    }

    if (peakBaggerPeak.hasCoordinates) {
      final peakBaggerLatitude = peakBaggerPeak.latitude!;
      final peakBaggerLongitude = peakBaggerPeak.longitude!;
      compatibleCandidates.sort((a, b) {
        final distanceCompare =
            haversineDistance(
              peakBaggerLatitude,
              peakBaggerLongitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              haversineDistance(
                peakBaggerLatitude,
                peakBaggerLongitude,
                b.latitude,
                b.longitude,
              ),
            );
        if (distanceCompare != 0) {
          return distanceCompare;
        }

        final elevationCompare =
            _elevationDifferenceValue(
              peakBaggerPeak.elevation,
              a.elevation,
            ).compareTo(
              _elevationDifferenceValue(peakBaggerPeak.elevation, b.elevation),
            );
        if (elevationCompare != 0) {
          return elevationCompare;
        }

        return a.id.compareTo(b.id);
      });
    } else {
      compatibleCandidates.sort((a, b) {
        final elevationCompare =
            _elevationDifferenceValue(
              peakBaggerPeak.elevation,
              a.elevation,
            ).compareTo(
              _elevationDifferenceValue(peakBaggerPeak.elevation, b.elevation),
            );
        if (elevationCompare != 0) {
          return elevationCompare;
        }

        return a.id.compareTo(b.id);
      });
    }

    return compatibleCandidates.first;
  }

  Peak? _resolveFilteredCandidate({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required List<Peak> peaks,
  }) {
    if (peaks.length == 1) {
      return peaks.single;
    }
    if (!peakBaggerPeak.hasCoordinates) {
      return null;
    }

    final peakBaggerLatitude = peakBaggerPeak.latitude!;
    final peakBaggerLongitude = peakBaggerPeak.longitude!;
    final sortedPeaks = [...peaks]
      ..sort((a, b) {
        return haversineDistance(
          peakBaggerLatitude,
          peakBaggerLongitude,
          a.latitude,
          a.longitude,
        ).compareTo(
          haversineDistance(
            peakBaggerLatitude,
            peakBaggerLongitude,
            b.latitude,
            b.longitude,
          ),
        );
      });

    final best = sortedPeaks.first;
    final runnerUp = sortedPeaks[1];
    final bestDistance = haversineDistance(
      peakBaggerLatitude,
      peakBaggerLongitude,
      best.latitude,
      best.longitude,
    );
    final runnerUpDistance = haversineDistance(
      peakBaggerLatitude,
      peakBaggerLongitude,
      runnerUp.latitude,
      runnerUp.longitude,
    );
    if ((runnerUpDistance - bestDistance).abs() <= tieBreakToleranceMeters) {
      return null;
    }

    return best;
  }

  PeakBaggerCorrelationResult _exactNameResult({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required Peak peak,
  }) {
    final spatialDifference = _spatialDifferenceSuffix(
      peakBaggerPeak: peakBaggerPeak,
      peak: peak,
    );
    return PeakBaggerCorrelationResult(
      peak: peak,
      action: 'strong-name-exact',
      detail: 'exact name match$spatialDifference',
      note: 'exact name match$spatialDifference',
      safeToCreate: false,
    );
  }

  PeakBaggerCorrelationResult _filteredMatchResult({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required Peak peak,
    required PeakBaggerCorrelationOptions options,
  }) {
    if (options.exactNameOnly && !options.elevationOnly) {
      return _exactNameResult(peakBaggerPeak: peakBaggerPeak, peak: peak);
    }

    final spatialDifference = _spatialDifferenceSuffix(
      peakBaggerPeak: peakBaggerPeak,
      peak: peak,
    );
    if (options.exactNameOnly && options.elevationOnly) {
      return PeakBaggerCorrelationResult(
        peak: peak,
        action: 'name-elevation-match',
        detail:
            'exact name and elevation match within ${options.elevationToleranceMeters}m$spatialDifference',
        note: 'exact name and elevation match$spatialDifference',
        safeToCreate: false,
      );
    }

    return PeakBaggerCorrelationResult(
      peak: peak,
      action: 'elevation-match',
      detail:
          'elevation match within ${options.elevationToleranceMeters}m$spatialDifference',
      note: 'elevation match$spatialDifference',
      safeToCreate: false,
    );
  }

  String _filteredNoMatchDetail({
    required PeakBaggerCorrelationOptions options,
    required double? nearestDistanceMeters,
  }) {
    if (options.exactNameOnly && options.elevationOnly) {
      return 'no exact-name match within ${options.elevationToleranceMeters}m elevation tolerance';
    }
    if (options.exactNameOnly) {
      return 'no exact-name match';
    }
    return 'no elevation match within ${options.elevationToleranceMeters}m tolerance';
  }

  String _filteredMultipleMatchDetail({
    required PeakBaggerCorrelationOptions options,
    required List<Peak> peaks,
  }) {
    if (options.exactNameOnly && options.elevationOnly) {
      return 'multiple exact-name/elevation matches${_candidateSummary(peaks)}';
    }
    if (options.exactNameOnly) {
      return 'multiple exact-name matches${_candidateSummary(peaks)}';
    }
    return 'multiple elevation matches${_candidateSummary(peaks)}';
  }

  bool _matchesRequiredFilters({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required Peak peak,
    required PeakBaggerCorrelationOptions options,
  }) {
    if (options.exactNameOnly && !_hasAnyExactNameMatch(peakBaggerPeak, peak)) {
      return false;
    }
    if (options.elevationOnly &&
        !_hasRequiredElevationMatch(
          peakBaggerPeak.elevation,
          peak.elevation,
          options.elevationToleranceMeters,
        )) {
      return false;
    }
    return true;
  }

  List<Peak> _weakNameMatches(
    PeakBaggerPeakDetails peakBaggerPeak,
    List<Peak> peaks,
  ) {
    final weakNameMatches = <Peak>[];
    for (final peak in peaks) {
      final hasWeakNameMatch =
          _hasWeakNameMatch(peakBaggerPeak.name, peak.name) ||
          _hasWeakNameMatch(peakBaggerPeak.name, peak.altName) ||
          _hasWeakNameMatch(peakBaggerPeak.altName, peak.name) ||
          _hasWeakNameMatch(peakBaggerPeak.altName, peak.altName);
      if (hasWeakNameMatch) {
        weakNameMatches.add(peak);
      }
    }
    return weakNameMatches;
  }

  bool _hasAnyExactNameMatch(PeakBaggerPeakDetails peakBaggerPeak, Peak peak) {
    return _hasExactNameMatch(peakBaggerPeak.name, peak.name) ||
        _hasExactNameMatch(peakBaggerPeak.name, peak.altName) ||
        _hasExactNameMatch(peakBaggerPeak.altName, peak.name) ||
        _hasExactNameMatch(peakBaggerPeak.altName, peak.altName);
  }

  String _spatialDifferenceSuffix({
    required PeakBaggerPeakDetails peakBaggerPeak,
    required Peak peak,
  }) {
    if (!peakBaggerPeak.hasCoordinates) {
      return '';
    }

    final peakBaggerLatitude = peakBaggerPeak.latitude!;
    final peakBaggerLongitude = peakBaggerPeak.longitude!;
    final distanceMeters = haversineDistance(
      peakBaggerLatitude,
      peakBaggerLongitude,
      peak.latitude,
      peak.longitude,
    );
    final distanceText = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)}km'
        : '${distanceMeters.toStringAsFixed(1)}m';
    final elevationDifference =
        peakBaggerPeak.elevation != null && peak.elevation != null
        ? (peakBaggerPeak.elevation! - peak.elevation!).abs().round()
        : null;
    if (elevationDifference == null) {
      return ' (spatial diff: $distanceText)';
    }
    return ' (spatial diff: $distanceText, elev diff: ${elevationDifference}m)';
  }

  bool _hasCompatibleElevation(double? first, double? second) {
    if (first == null || second == null) {
      return true;
    }

    return (first - second).abs() <= elevationThresholdMeters;
  }

  bool _hasRequiredElevationMatch(
    double? first,
    double? second,
    int toleranceMeters,
  ) {
    if (first == null || second == null) {
      return false;
    }

    return (first - second).abs() <= toleranceMeters;
  }

  double _elevationDifferenceValue(double? first, double? second) {
    if (first == null || second == null) {
      return double.infinity;
    }

    return (first - second).abs();
  }

  bool _hasExactNameMatch(String csvName, String peakName) {
    final normalizedCsvName = _normalizeName(csvName);
    final normalizedPeakName = _normalizeName(peakName);
    return normalizedCsvName.isNotEmpty &&
        normalizedCsvName == normalizedPeakName;
  }

  bool _hasStrongNameConfirmation(String csvName, String peakName) {
    final normalizedCsvName = _normalizeName(csvName);
    final normalizedPeakName = _normalizeName(peakName);
    if (normalizedCsvName.isEmpty || normalizedPeakName.isEmpty) {
      return false;
    }

    final distance = _levenshteinDistance(
      normalizedCsvName,
      normalizedPeakName,
    );
    final maxLength = math.max(
      normalizedCsvName.length,
      normalizedPeakName.length,
    );
    return maxLength >= 6 && distance <= 2;
  }

  bool _hasWeakNameMatch(String csvName, String peakName) {
    final normalizedCsvName = _normalizeName(csvName);
    final normalizedPeakName = _normalizeName(peakName);
    if (normalizedCsvName.isEmpty || normalizedPeakName.isEmpty) {
      return false;
    }
    if (normalizedCsvName == normalizedPeakName) {
      return false;
    }

    final csvTokens = normalizedCsvName
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    final peakTokens = normalizedPeakName
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    if (csvTokens.length < 2 || peakTokens.length < 2) {
      return false;
    }

    final shorter = csvTokens.length <= peakTokens.length
        ? csvTokens
        : peakTokens;
    final longer = identical(shorter, csvTokens) ? peakTokens : csvTokens;
    return shorter.every(longer.contains);
  }

  String _normalizeName(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'\bmt\b'), 'mount');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final tokens =
        normalized
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty && token != 'the')
            .toList(growable: false)
          ..sort();
    return tokens.join(' ');
  }

  int _levenshteinDistance(String source, String target) {
    if (source.isEmpty) {
      return target.length;
    }
    if (target.isEmpty) {
      return source.length;
    }

    final previous = List<int>.generate(target.length + 1, (index) => index);
    final current = List<int>.filled(target.length + 1, 0);

    for (var i = 0; i < source.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < target.length; j++) {
        final cost = source[i] == target[j] ? 0 : 1;
        current[j + 1] = math.min(
          math.min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + cost,
        );
      }

      for (var j = 0; j < current.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous.last;
  }
}

class _SpatialCandidate {
  const _SpatialCandidate({
    required this.peak,
    required this.distanceMeters,
    required this.elevationDifference,
  });

  final Peak peak;
  final double distanceMeters;
  final int elevationDifference;
}
