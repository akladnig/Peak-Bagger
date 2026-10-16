import '../../core/number_formatters.dart';
import '../../services/summary_card_service.dart';
import 'summary_chart.dart';

typedef ElevationDisplayMode = SummaryDisplayMode;

List<String> formatElevationTooltipValues(
  SummaryBucket bucket,
  SummaryBucket? secondaryBucket,
) => [formatElevationWithThousandsSeparator(bucket.roundedValue)];

String formatElevationAxisLabel(double value) =>
    formatElevationWithThousandsSeparator(value.round());

String formatElevationTooltipTitle(
  SummaryBucket bucket,
  SummaryPeriodPreset period,
) {
  return defaultTooltipTitleText(bucket, period);
}
