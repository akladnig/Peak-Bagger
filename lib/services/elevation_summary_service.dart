import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/summary_card_service.dart';

typedef ElevationPeriodPreset = SummaryPeriodPreset;

class ElevationBucket {
  const ElevationBucket({
    required this.start,
    required this.endExclusive,
    required this.label,
    required this.ascentMetres,
    required this.trackCount,
  });

  factory ElevationBucket.fromSummary(SummaryBucket bucket) {
    return ElevationBucket(
      start: bucket.start,
      endExclusive: bucket.endExclusive,
      label: bucket.label,
      ascentMetres: bucket.value,
      trackCount: bucket.trackCount,
    );
  }

  final DateTime start;
  final DateTime endExclusive;
  final String label;
  final double ascentMetres;
  final int trackCount;

  int get roundedAscentMetres => ascentMetres.round();

  SummaryBucket toSummaryBucket() {
    return SummaryBucket(
      start: start,
      endExclusive: endExclusive,
      label: label,
      value: ascentMetres,
      trackCount: trackCount,
    );
  }
}

class ElevationTimeline {
  const ElevationTimeline({
    required this.period,
    required this.windowStart,
    required this.windowEndExclusive,
    required this.buckets,
  });

  const ElevationTimeline.empty({required this.period})
    : windowStart = null,
      windowEndExclusive = null,
      buckets = const [];

  factory ElevationTimeline.fromSummary(SummaryTimeline timeline) {
    return ElevationTimeline(
      period: timeline.period,
      windowStart: timeline.windowStart,
      windowEndExclusive: timeline.windowEndExclusive,
      buckets: timeline.buckets
          .map(ElevationBucket.fromSummary)
          .toList(growable: false),
    );
  }

  final ElevationPeriodPreset period;
  final DateTime? windowStart;
  final DateTime? windowEndExclusive;
  final List<ElevationBucket> buckets;

  bool get isEmpty => buckets.isEmpty;

  double get totalAscentMetres =>
      buckets.fold<double>(0, (sum, bucket) => sum + bucket.ascentMetres);

  int get totalMetres => totalAscentMetres.round();

  int get averageMetres {
    final summaryBuckets = buckets
        .map((bucket) => bucket.toSummaryBucket())
        .toList(growable: false);
    return _service.visibleAverageValue(summaryBuckets).round();
  }

  static const SummaryCardService _service = SummaryCardService();
}

class ElevationSummaryService {
  const ElevationSummaryService();

  static const SummaryMetricDefinition metric = SummaryMetricDefinition(
    valueOf: _trackAscent,
  );

  static const SummaryCardService _service = SummaryCardService();

  ElevationTimeline buildTimeline({
    required Iterable<GpxTrack> tracks,
    required ElevationPeriodPreset period,
    DateTime? now,
  }) {
    return ElevationTimeline.fromSummary(
      _service.buildTimeline(
        tracks: tracks,
        period: period,
        metric: metric,
        now: now,
      ),
    );
  }

  double shiftScrollOffset({
    required double currentOffset,
    required double viewportWidth,
    required double maxScrollExtent,
    required bool forward,
  }) {
    return _service.shiftScrollOffset(
      currentOffset: currentOffset,
      viewportWidth: viewportWidth,
      maxScrollExtent: maxScrollExtent,
      forward: forward,
    );
  }

  int shiftWindowStartIndex({
    required int currentStartIndex,
    required int visibleBucketCount,
    required int bucketCount,
    required bool forward,
  }) {
    return _service.shiftWindowStartIndex(
      currentStartIndex: currentStartIndex,
      visibleBucketCount: visibleBucketCount,
      bucketCount: bucketCount,
      forward: forward,
    );
  }

  int visibleAverageMetres(Iterable<ElevationBucket> buckets) {
    return _service
        .visibleAverageValue(buckets.map((bucket) => bucket.toSummaryBucket()))
        .round();
  }

  int visibleAverageMetresForPeriod({
    required ElevationPeriodPreset period,
    required Iterable<ElevationBucket> buckets,
  }) {
    return _service
        .visibleAverageValueForPeriod(
          period: period,
          buckets: buckets.map((bucket) => bucket.toSummaryBucket()),
        )
        .round();
  }

  int visibleTotalMetres(Iterable<ElevationBucket> buckets) {
    return _service
        .visibleTotalValue(buckets.map((bucket) => bucket.toSummaryBucket()))
        .round();
  }
}

double? _trackAscent(GpxTrack track) => track.ascent;
