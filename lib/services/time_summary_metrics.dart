import '../models/gpx_track.dart';
import 'summary_card_service.dart';

/// Both series and navigation consume this same duration-pair eligibility.
/// Values stay in milliseconds through summation and averaging.
abstract final class TimeSummaryMetrics {
  static bool isEligible(GpxTrack track) {
    final total = track.totalTimeMillis;
    final moving = track.movingTime;
    return total != null && moving != null && moving >= 0 && moving <= total;
  }

  static const total = SummaryMetricDefinition(valueOf: _totalMillis);
  static const moving = SummaryMetricDefinition(valueOf: _movingMillis);

  static double? _totalMillis(GpxTrack track) =>
      track.totalTimeMillis?.toDouble();
  static double? _movingMillis(GpxTrack track) => track.movingTime?.toDouble();
}
