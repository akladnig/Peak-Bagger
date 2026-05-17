import '../../core/date_formatters.dart';
import '../../core/number_formatters.dart';
import '../../services/summary_card_service.dart';
import 'summary_chart.dart';

typedef ElevationDisplayMode = SummaryDisplayMode;

List<String> formatElevationTooltipValues(
  SummaryBucket bucket,
  SummaryBucket? secondaryBucket,
) => ['${formatElevationMetres(bucket.roundedValue)} m'];

String formatElevationAxisLabel(double value) => formatElevation(value);

String formatElevationTooltipTitle(
  SummaryBucket bucket,
  SummaryPeriodPreset period,
) {
  return switch (period) {
    SummaryPeriodPreset.week ||
    SummaryPeriodPreset.month ||
    SummaryPeriodPreset.last3Months ||
    SummaryPeriodPreset.last6Months => formatSummaryDayMonth(bucket.start),
    SummaryPeriodPreset.last12Months ||
    SummaryPeriodPreset.allTime => bucket.label,
  };
}
